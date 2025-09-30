-- @description Export project regions to a simple .txt chord sheet with a ReaImGui save dialog.
-- @version 0.1
-- @author Hosi
-- @website https://www.lachinhan.xyz
-- @changelog
-- v0.1: 30 - Sep - 2025

-- Initialize ReaImGui
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local imgui = require('imgui')('0.10')

if not imgui or type(imgui) ~= "table" then
    reaper.ShowMessageBox("Failed to initialize ReaImGui library.\nPlease ensure it is installed (v0.10+ recommended) and up to date via ReaPack.", "Error", 0)
    return
end

---------------------------------------------------------------------
-- LOGIC FUNCTIONS (Based on stable version 2.2)
---------------------------------------------------------------------

function GenerateChordSheet()
  -- 1. Get basic project information
  local proj = 0
  local proj_name_full, _ = reaper.GetProjectName(proj, "")
  local proj_name
  
  if proj_name_full and proj_name_full ~= "" then
    proj_name = proj_name_full:match("([^/\\\\]+)$")
    if proj_name then proj_name = proj_name:gsub("%.Rpp$", "") else proj_name = "Untitled" end
  else
    proj_name = "Untitled"
  end
  
  local tempo = reaper.Master_GetTempo()

  -- 2. Collect Regions and their beat positions
  local regions = {}
  local num_markers = reaper.CountProjectMarkers(proj)
  local max_measure = 0

  for i = 0, num_markers - 1 do
    local _, is_region, pos, _, name = reaper.EnumProjectMarkers3(proj, i)
    if is_region then
      local _, measures, cml, full_beats = reaper.TimeMap2_timeToBeats(proj, pos)
      local bar = measures + 1
      local beat_in_measure = (full_beats % cml)
      local beat_slot = math.floor(beat_in_measure) + 1
      
      table.insert(regions, { name = name, bar = bar, beat_slot = beat_slot, pos = pos })
      if bar > max_measure then max_measure = bar end
    end
  end
  
  if #regions == 0 then
    reaper.ShowMessageBox("No regions found in the project.", "Export Regions", 0)
    return nil, nil
  end

  table.sort(regions, function(a, b) return a.pos < b.pos end)
  
  -- 3. Create a beat grid for all measures
  local measures_grid = {}
  for i = 1, max_measure do
    measures_grid[i] = {"-", "-", "-", "-"}
  end

  for _, region in ipairs(regions) do
    if measures_grid[region.bar] and region.beat_slot >= 1 and region.beat_slot <= 4 then
      if measures_grid[region.bar][region.beat_slot] == "-" then
        measures_grid[region.bar][region.beat_slot] = region.name
      else
        measures_grid[region.bar][region.beat_slot] = measures_grid[region.bar][region.beat_slot] .. "/" .. region.name
      end
    end
  end

  -- 4. Build the text file content from the beat grid
  local text_content = {}
  local column_width = 25

  table.insert(text_content, "Song: " .. proj_name)
  table.insert(text_content, string.format("Tempo: %.0f", tempo))
  table.insert(text_content, string.rep("=", column_width * 4))

  for i = 1, max_measure, 4 do
    local line_str = ""
    for j = 0, 3 do
      local current_bar = i + j
      if current_bar <= max_measure then
        local bar_label = string.format("[%d]", current_bar)
        local chords_in_bar = table.concat(measures_grid[current_bar], " | ")
        local cell_content = bar_label .. " " .. chords_in_bar
        line_str = line_str .. cell_content .. string.rep(" ", column_width - #cell_content)
      end
    end
    table.insert(text_content, line_str)
  end
  
  return table.concat(text_content, "\n"), proj_name
end


function ShowSaveDialog(content_to_save, default_proj_name)
    local default_path = reaper.GetProjectPath()
    if default_path == "" then
      default_path = reaper.GetResourcePath() .. "/Projects/" .. default_proj_name .. ".txt"
    else
      default_path = default_path .. "/" .. default_proj_name .. ".txt"
    end

    local ctx = imgui.CreateContext('Save Dialog')
    local is_open = true
    local flags = imgui.WindowFlags_NoResize | imgui.WindowFlags_AlwaysAutoResize
    local file_path_buffer = default_path -- Use a buffer for the text input

    local function loop()
        local visible
        visible, is_open = imgui.Begin(ctx, 'Save Chord File', is_open, flags)

        if visible then
            imgui.PushStyleVar(ctx, imgui.StyleVar_FramePadding, 8, 5)
            imgui.PushStyleVar(ctx, imgui.StyleVar_ItemSpacing, 8, 8)
            
            imgui.AlignTextToFramePadding(ctx)
            imgui.Text(ctx, "File path:")
            imgui.SameLine(ctx)
            imgui.PushItemWidth(ctx, 350)
            -- Use InputText which returns the buffer and a status
            local changed, new_path = imgui.InputText(ctx, "##filepath", file_path_buffer)
            if changed then file_path_buffer = new_path end -- Update buffer if text changes
            imgui.PopItemWidth(ctx)

            imgui.Spacing(ctx)
            imgui.Separator(ctx)
            imgui.Spacing(ctx)
            
            -- Center buttons
            local content_width = imgui.GetContentRegionAvail(ctx)
            local button_width = 80
            imgui.SetCursorPosX(ctx, (content_width - (button_width * 2 + 8)) * 0.5)

            if imgui.Button(ctx, "OK", button_width, 0) then
                local file = io.open(file_path_buffer, "w")
                if file then
                    file:write(content_to_save)
                    file:close()
                    reaper.ShowMessageBox("Successfully exported regions to:\n" .. file_path_buffer, "Export Complete", 0)
                else
                    reaper.ShowMessageBox("Error: Could not write to file:\n" .. file_path_buffer, "Export Error", 0)
                end
                is_open = false -- Close window
            end

            imgui.SameLine(ctx)

            if imgui.Button(ctx, "Cancel", button_width, 0) then
                is_open = false -- Close window without a message
            end
            
            imgui.PopStyleVar(ctx, 2)
            imgui.End(ctx)
        end

        if is_open then
            reaper.defer(loop)
        else
            -- Cleanup when the window is closed
            reaper.Undo_EndBlock("Export regions to .txt", -1)
        end
    end
    reaper.defer(loop)
end

---------------------------------------------------------------------
-- SCRIPT ENTRY POINT
---------------------------------------------------------------------

function main()
    reaper.Undo_BeginBlock()
    
    local chord_sheet_text, project_name = GenerateChordSheet()
    
    if chord_sheet_text then
        ShowSaveDialog(chord_sheet_text, project_name)
    else
        reaper.Undo_EndBlock("Export to .txt (failed or no regions)", -1)
    end
end

main()

