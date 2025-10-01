--[[
@description    Fadr Import chord regions from CSV file (with GUI)
@author         Hosi (Modified from original X-Raym script)
@version        0.1
@provides
  [main] . > Hosi_Fadr Import chord regions from CSV file (GUI).lua

@about
  # Fadr Import Chord Regions from CSV (with GUI)

  Imports chord data from a CSV file exported by Fadr.com to create
  project regions in REAPER. A ReaImGui window provides options
  to control the import process.

  ## Instructions:
  1. Run the script from the Action List.
  2. A window with options will appear.
  3. Click the import button and select your Fadr CSV file.

@changelog
  + v0.1 (2025-10-01) - Initial release for Fadr CSV files. Improved name normalization.
--]]

-- --- INITIALIZE REAIM GUI ---
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local imgui = require('imgui')('0.10')

if not imgui or type(imgui) ~= "table" then
  reaper.ShowMessageBox("Could not initialize ReaImGui library.\n\nPlease install it (v0.10+) via ReaPack.", "ReaImGui Error", 0)
  return
end

local ctx = imgui.CreateContext("FadrChord Importer")

-- --- SCRIPT SETTINGS & STATE ---
local settings = {
    -- Column indices (1-based for Lua arrays)
    col_chord = 1,
    col_start = 2,
    col_end = 3,
    sep = ",",

    -- GUI Options
    snap_to_grid = true,
    fill_gaps = true,
    use_simple_format = true,
    normalize_names_for_reatrak = true,
    
    -- Window State
    is_open = true
}

-- --- HELPER FUNCTIONS ---

function ColorHexToInt(hex)
  hex = hex:gsub("#", "")
  local R = tonumber("0x"..hex:sub(1,2))
  local G = tonumber("0x"..hex:sub(3,4))
  local B = tonumber("0x"..hex:sub(5,6))
  return reaper.ColorToNative(R, G, B)
end

function ParseCSVLine(line, sep)
  local res = {}
  local pos = 1
  sep = sep or ','
  while true do
    local c = string.sub(line, pos, pos)
    if (c == "") then break end
    if (c == '"') then
      local txt = ""
      repeat
        local startp, endp = string.find(line, '^%b""', pos)
        txt = txt .. string.sub(line, startp+1, endp-1)
        pos = endp + 1
        c = string.sub(line, pos, pos)
        if (c == '"') then txt = txt .. '"' end
      until (c ~= '"')
      table.insert(res, txt)
      assert(c == sep or c == "")
      pos = pos + 1
    else
      local startp, endp = string.find(line, sep, pos)
      if (startp) then
        table.insert(res, string.sub(line, pos, startp-1))
        pos = endp + 1
      else
        table.insert(res, string.sub(line, pos))
        break
      end
    end
  end
  return res
end

-- --- CORE LOGIC ---

function normalize_chord_name(name)
    -- Normalize minor variations to 'm'
    name = name:gsub("minor", "m")
    name = name:gsub("min", "m")
    
    -- Normalize major variations to 'Maj'
    name = name:gsub("major", "Maj")
    name = name:gsub("maj", "Maj")

    -- *** FIX: Remove colons (e.g., "D:maj" -> "Dmaj") before further processing ***
    name = name:gsub(":", "")

    -- If a chord is just a root note (e.g., "C", "D#"), explicitly make it Major.
    if name:match("^[A-G][#b]?$") then
        name = name .. "Maj"
    end
    
    return name
end

function process_csv_data(lines, opts)
  if not lines or #lines <= 1 then
    return
  end
  
  reaper.PreventUIRefresh(1)
  reaper.Undo_BeginBlock()

  -- Process data rows (skip header)
  for i = 2, #lines do
    local line = lines[i]
    if #line >= 3 then
      local chord_name = line[opts.col_chord] or ""
      local start_time = tonumber(line[opts.col_start]) or 0
      local end_time = tonumber(line[opts.col_end]) or 0

      if opts.normalize_names_for_reatrak then
        chord_name = normalize_chord_name(chord_name)
      end

      if opts.fill_gaps and i < #lines then
        local next_line = lines[i+1]
        if #next_line >= opts.col_start then
          local next_start_time = tonumber(next_line[opts.col_start])
          if next_start_time and next_start_time > start_time then
            end_time = next_start_time
          end
        end
      end

      if opts.snap_to_grid then
        start_time = reaper.SnapToGrid(0, start_time)
        end_time = reaper.SnapToGrid(0, end_time)
      end

      if chord_name ~= "" and end_time > start_time then
        local color = 0
        if chord_name:match("Maj") or chord_name:match("M") then
          color = ColorHexToInt("#4CAF50") | 0x1000000 -- Green (Major)
        elseif chord_name:match("m") then
          color = ColorHexToInt("#F44336") | 0x1000000 -- Red (Minor)
        -- *** FIX: Corrected typo from ColorHextoInt to ColorHexToInt ***
        elseif chord_name:match("7") then
          color = ColorHexToInt("#FF9800") | 0x1000000 -- Orange (Dominant 7th)
        elseif chord_name == "N" or chord_name == "None" then
          color = ColorHexToInt("#9E9E9E") | 0x1000000 -- Gray (No Chord)
        elseif opts.use_simple_format and not (chord_name:match("m") or chord_name:match("dim") or chord_name:match("sus") or chord_name:match("aug")) then
          color = ColorHexToInt("#4CAF50") | 0x1000000 -- Green (Major)
        else
          color = ColorHexToInt("#2196F3") | 0x1000000 -- Blue
        end
        reaper.AddProjectMarker2(0, true, start_time, end_time, chord_name, -1, color)
      end
    end
  end
  
  reaper.Undo_EndBlock("Import Chord Regions from CSV", -1)
  reaper.UpdateArrange()
  reaper.PreventUIRefresh(-1)
end


function run_import(opts)
  local retval, filetxt = reaper.GetUserFileNameForRead("", "Import Chord Regions from CSV", "csv")
  if not retval then return end
  
  local lines = {}
  local file = io.open(filetxt, "r")
  if not file then 
    reaper.ShowMessageBox("Could not open file: "..filetxt, "Error", 0)
    return 
  end
  
  for line in file:lines() do
    table.insert(lines, ParseCSVLine(line, opts.sep))
  end
  file:close()
  
  process_csv_data(lines, opts)
end

-- --- MAIN GUI LOOP ---

function loop()
  local visible
  visible, settings.is_open = imgui.Begin(ctx, "FadrChord Importer v5.3", settings.is_open, imgui.WindowFlags_AlwaysAutoResize)
  if visible then
      imgui.Text(ctx, "Import Options")
      imgui.Separator(ctx)

      local changed, new_val
      
      changed, new_val = imgui.Checkbox(ctx, "Snap Regions to Grid", settings.snap_to_grid)
      if changed then settings.snap_to_grid = new_val end
      
      changed, new_val = imgui.Checkbox(ctx, "Fill Gaps Between Regions", settings.fill_gaps)
      if changed then settings.fill_gaps = new_val end

      imgui.Separator(ctx)
      imgui.Text(ctx, "Chord Formatting")
      
      changed, new_val = imgui.Checkbox(ctx, "Color 'D' as Major, 'Dm' as Minor", settings.use_simple_format)
      if changed then settings.use_simple_format = new_val end
      
      changed, new_val = imgui.Checkbox(ctx, "Normalize Names for ReaTrak Script", settings.normalize_names_for_reatrak)
      if changed then settings.normalize_names_for_reatrak = new_val end

      imgui.Separator(ctx)

      if imgui.Button(ctx, "Import Chord Regions from CSV...", -1, 30) then
          settings.is_open = false -- Close the GUI window
          -- Defer the import function to allow the GUI to close first
          reaper.defer(function() run_import(settings) end) 
      end

      imgui.End(ctx)
  end

  if settings.is_open then
    reaper.defer(loop)
  end
end

reaper.defer(loop)

