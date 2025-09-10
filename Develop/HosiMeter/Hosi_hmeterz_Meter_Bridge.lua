--[[
@description Hosi hmeterz Meter Bridge (ReaImGui Edition)
@author      Hosi
@version     0.6
@provides
  [main] . > Hosi_hmeterz_Meter_Bridge.lua

@about
  # Hosi hmeterz Meter Bridge (ReaImGui Edition)

  Displays meters from all hmeterz groups in a single window using ReaImGui.
   
  v0.6:
  - Added "Mini View" mode to display only meter bars for a compact interface.
  
  v0.5:
  - Added "Solo Group" Mode.
  - Added Layout Customization. "Reset to Default" for layout sliders by Right-click.
  - Added "Sync Colors" to auto-color tracks.
  - Redesigned Toolbar with a consolidated "Menu" button.
  
  v0.4: Auto-displays track names, adds DR visualization & "Find Track".
  v0.3: Allows custom names for each group.
  v0.2: Auto-inserts a marker when a clip is detected.


  ## Requirements:
  - 'ReaImGui' library (install via ReaPack).
  - 'hmeterztx' JSFX plugin.
  - 'hmeterz' JSFX plugin.

  ## Instructions:
  1. Insert 'hmeterztx' JSFX onto tracks to monitor.
  2. Insert 'hmeterz' JSFX onto a monitor track.
  3. Run this script.
  4. Use the "Menu" button for all functions and settings.
--]]


local reaper = reaper

-- =============================================================================
-- INITIALIZE AND CHECK REAIMGUI
-- =============================================================================
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local imgui = require('imgui')('0.10')

if not imgui or type(imgui) ~= "table" then
    reaper.ShowMessageBox("Error: Could not initialize ReaImGui library.\n\nPlease install ReaImGui (v0.10+ recommended) from ReaPack to run this script.", "Library Error", 0)
    return
end

-- =============================================================================
-- CONNECT TO SHARED MEMORY
-- =============================================================================
reaper.gmem_attach("meterz")

-- =============================================================================
-- CONSTANTS AND CONFIGURATION
-- =============================================================================

-- 'meterz' memory layout (compatible with the original JSFX)
local _NGRP, _NTX = 16, 16
local _PRMSZ, _PRMP = _NGRP * 16, 256
local _TXSZ = _NGRP * _NTX
local gmem_base = {
  _TXON      = _PRMP + _PRMSZ,
  _RMS       = _PRMP + _PRMSZ + _TXSZ * 1,
  _PK        = _PRMP + _PRMSZ + _TXSZ * 2,
  _PKHOLD    = _PRMP + _PRMSZ + _TXSZ * 3,
  _HUE       = _PRMP + _PRMSZ + _TXSZ * 4,
  _CLIP      = _PRMP + _PRMSZ + _TXSZ * 5,
  _CLIPCOUNT = _PRMP + _PRMSZ + _TXSZ * 6,
}
local _LDB = 8.685889638065 -- 20/ln(10)

-- GUI Configuration
local SCRIPT_NAME = "Hosi hmeterz Meter Bridge"
local DB_MIN, DB_MAX = -60, 6
local DB_RANGE = DB_MAX - DB_MIN
local METER_INACTIVE_TIMEOUT = 1.0 -- (seconds) Time to keep an inactive meter on the UI
local script_enabled = true
local show_max_peak = true
local show_settings = false
local is_mini_view = false -- ++ NEW: State for Mini View mode

-- ++ LAYOUT SETTINGS (with defaults) ++
local layout_defaults = {
  width = 20,
  height = 200,
  group_spacing = 15,
  meter_spacing = 10
}
local layout_settings = {
  width = layout_defaults.width,
  height = layout_defaults.height,
  group_spacing = layout_defaults.group_spacing,
  meter_spacing = layout_defaults.meter_spacing
}


local ctx = imgui.CreateContext(SCRIPT_NAME)
local is_open = true
local flags = imgui.WindowFlags_HorizontalScrollbar

-- Color Palette
local colors = {
  meter_bg        = {  60,  60,  60, 255 },
  peak_hold_temp  = { 220, 220, 220, 255 },
  peak_hold_max   = { 255, 255, 100, 255 },
  clip            = { 255,  40,  40, 255 },
  text            = { 200, 200, 200, 255 },
  group_label     = { 255, 200, 100, 255 },
  text_on_meter   = { 240, 240, 240, 255 },
  dynamic_range   = { 255, 255, 255,  70 },
  solo_button_on  = { 255, 220,   0, 255 },
  solo_text_on    = {   0,   0,   0, 255 },
}

-- Meter color palette, matching the original hmeterz colors
local meter_colors = {
  rms = {
    {   0, 166,  26, 255 }, { 166,  89, 166, 255 }, { 204, 145,   0, 255 }, {  89, 115, 217, 255 },
    { 204,  77,  89, 255 }, {  26, 140, 179, 255 }, { 102, 102, 102, 255 }, { 153, 153, 153, 255 },
    -- Re-using first 8 colors for the next 8 groups
    {   0, 166,  26, 255 }, { 166,  89, 166, 255 }, { 204, 145,   0, 255 }, {  89, 115, 217, 255 },
    { 204,  77,  89, 255 }, {  26, 140, 179, 255 }, { 102, 102, 102, 255 }, { 153, 153, 153, 255 },
  },
  peak = {
    {  80, 220, 100, 200 }, { 200, 150, 200, 200 }, { 255, 180,  60, 200 }, { 150, 170, 255, 200 },
    { 255, 130, 150, 200 }, { 100, 180, 220, 200 }, { 160, 160, 160, 200 }, { 200, 200, 200, 200 },
    {  80, 220, 100, 200 }, { 200, 150, 200, 200 }, { 255, 180,  60, 200 }, { 150, 170, 255, 200 },
    { 255, 130, 150, 200 }, { 100, 180, 220, 200 }, { 160, 160, 160, 200 }, { 200, 200, 200, 200 },
  }
}

-- State tables
local known_meters = {}
local highest_peaks = {}
local clip_detected = {}
local group_names = {}
local track_map = {} -- Will store { name = "...", ptr = track_pointer }
local highest_dr_values = {}
local lowest_dr_values = {}
local solo_group_idx = nil
-- =============================================================================
-- UTILITY FUNCTIONS
-- =============================================================================

function PackColor(r, g, b, a)
  return ((a or 255) << 24) | (b << 16) | (g << 8) | r
end

function lin_to_db(lin)
  if lin < 0.000001 then return DB_MIN end
  return math.max(DB_MIN, _LDB * math.log(lin))
end

function db_to_y_pos(db, y, h)
  local pos = math.max(0, math.min(1, (db - DB_MIN) / DB_RANGE))
  return y + h * (1 - pos)
end

function get_group_char(group_idx)
  return string.char(string.byte('A') + group_idx)
end

function add_clip_marker(gmem_index)
  local pos = reaper.GetPlayPosition()
  local group_idx = math.floor((gmem_index - 1) / _NTX)
  local channel_num = (gmem_index - 1) % _NTX + 1
  local group_char = get_group_char(group_idx)
  local marker_name = string.format("[CLIP] %s-%d", group_char, channel_num)
  reaper.AddProjectMarker(0, false, pos, 0, marker_name, 1)
end

-- ++ SAVE/LOAD FUNCTIONS for settings ++

function SaveGroupNames()
  local names_string = table.concat(group_names, "|")
  reaper.SetProjExtState(0, SCRIPT_NAME, "GroupNames", names_string)
end

function LoadGroupNames()
  local _, names_string = reaper.GetProjExtState(0, SCRIPT_NAME, "GroupNames", "")
  if names_string ~= "" then
    local temp_names = {}
    for name in string.gmatch(names_string, "([^|]*)") do
      table.insert(temp_names, name)
    end
    for i = 1, _NGRP do
      group_names[i] = temp_names[i] or ""
    end
  else
    for i = 1, _NGRP do
      group_names[i] = ""
    end
  end
end

function SaveLayoutSettings()
  local layout_string = table.concat({
    layout_settings.width,
    layout_settings.height,
    layout_settings.group_spacing,
    layout_settings.meter_spacing,
    is_mini_view and 1 or 0 -- ++ NEW: Save Mini View state
  }, "|")
  reaper.SetProjExtState(0, SCRIPT_NAME, "LayoutSettings", layout_string)
end

function LoadLayoutSettings()
  local _, layout_string = reaper.GetProjExtState(0, SCRIPT_NAME, "LayoutSettings", "")
  if layout_string ~= "" then
    local values = {}
    for val in string.gmatch(layout_string, "([^|]+)") do
      table.insert(values, tonumber(val))
    end
    if #values >= 4 then -- Backward compatibility for old saves
      layout_settings.width = values[1]
      layout_settings.height = values[2]
      layout_settings.group_spacing = values[3]
      layout_settings.meter_spacing = values[4]
    end
    if #values >= 5 then -- Load new Mini View state if it exists
        is_mini_view = (values[5] == 1)
    end
  end
end


function ScanProjectForTracks()
  track_map = {}
  local num_tracks = reaper.CountTracks(0)
  for i = 0, num_tracks - 1 do
    local track = reaper.GetTrack(0, i)
    local num_fx = reaper.TrackFX_GetCount(track)

    for fx_index = 0, num_fx - 1 do
      local _, fx_name = reaper.TrackFX_GetFXName(track, fx_index, "")

      if fx_name and string.match(string.lower(fx_name), "hmeterz tx") then
        local group_idx = math.floor(reaper.TrackFX_GetParam(track, fx_index, 0) + 0.5)
        local meter_num = math.floor(reaper.TrackFX_GetParam(track, fx_index, 1) + 0.5)

        if meter_num > 0 then
          local _, track_name_str = reaper.GetTrackName(track, "")

          if not track_map[group_idx] then
            track_map[group_idx] = {}
          end
          track_map[group_idx][meter_num] = { name = track_name_str, ptr = track }
        end
      end
    end
  end
end

-- ++ NEW: Function to sync track colors ++
function SyncTrackColors()
  reaper.Undo_BeginBlock()
  local colored_tracks = 0
  local total_tracks = reaper.CountTracks(0)

  for i = 0, total_tracks - 1 do
    local track = reaper.GetTrack(0, i)
    if track then
      local fx_count = reaper.TrackFX_GetCount(track)
      for fx_index = 0, fx_count - 1 do
        local _, fx_name = reaper.TrackFX_GetFXName(track, fx_index, "")
        if fx_name and string.match(string.lower(fx_name), "hmeterz tx") then
          -- ++ FIX: Read the 'color' parameter (index 2) instead of the 'group' parameter (index 0) ++
          -- The base color is determined by slider3 'a_color' in hmeterztx, which is parameter index 2.
          local color_param_index = 2
          local color_idx = math.floor(reaper.TrackFX_GetParam(track, fx_index, color_param_index) + 0.5)

          -- Use the meter_colors.rms palette for consistency
          local color = meter_colors.rms[color_idx + 1]
          if color then
            -- The 0x1000000 flag tells REAPER it's a custom color
            local native_color = reaper.ColorToNative(color[1], color[2], color[3]) | 0x1000000
            reaper.SetTrackColor(track, native_color)
            colored_tracks = colored_tracks + 1
            break -- Found the FX, colored the track, move to the next track
          end
        end
      end
    end
  end

  reaper.Undo_EndBlock("Sync Track Colors to hmeterz Groups", -1)
  reaper.UpdateArrange()
  reaper.ShowMessageBox(colored_tracks .. " track(s) have been colored based on their hmeterz color setting.", "Color Sync Complete", 0)
end


-- =============================================================================
-- MAIN DRAWING FUNCTION
-- =============================================================================
function loop()
  local visible
  visible, is_open = imgui.Begin(ctx, SCRIPT_NAME, is_open, flags)

  if visible then
    -- ++ v0.8: Exit mechanism for Mini View ++
    if is_mini_view then
        -- Allow right-clicking anywhere in the window to exit
        if imgui.IsWindowHovered(ctx) and imgui.IsMouseReleased(ctx, 1) then
            is_mini_view = false
        end
        -- Also show a small button for discoverability
        if imgui.SmallButton(ctx, "Full View") then
            is_mini_view = false
        end
        if imgui.IsItemHovered(ctx) then imgui.SetTooltip(ctx, "Right-click background to exit Mini View") end
    end
    
    -- Menu Toolbar (hidden in Mini View)
    if not is_mini_view then
        if imgui.Button(ctx, "Menu") then
          imgui.OpenPopup(ctx, "main_menu")
        end

        if imgui.BeginPopup(ctx, "main_menu") then
          if imgui.MenuItem(ctx, "Reset All Clips") then
            for i = 1, (_NGRP * _NTX) + 1 do
              reaper.gmem_write(gmem_base._CLIP + i, 0)
              reaper.gmem_write(gmem_base._CLIPCOUNT + i, 0)
              reaper.gmem_write(gmem_base._PKHOLD + i, 0)
            end
            highest_peaks = {}
            highest_dr_values = {}
            lowest_dr_values = {}
          end
          imgui.Separator(ctx)

          local changed_enabled, new_enabled = imgui.MenuItem(ctx, "Metering Enabled", "", script_enabled)
          if changed_enabled then script_enabled = new_enabled end

          local changed_peak_mode, new_peak_mode = imgui.MenuItem(ctx, "Show Max Peak", "", show_max_peak)
          if changed_peak_mode then show_max_peak = new_peak_mode end
          if imgui.IsItemHovered(ctx) then imgui.SetTooltip(ctx, "If unchecked, shows a decaying peak hold instead.") end

          imgui.Separator(ctx)
          if imgui.MenuItem(ctx, "Rescan Tracks for Names") then ScanProjectForTracks() end
          if imgui.MenuItem(ctx, "Sync Track Colors to Groups") then SyncTrackColors() end
          imgui.Separator(ctx)

          local changed_settings, new_settings = imgui.MenuItem(ctx, "Show Settings Panel", "", show_settings)
          if changed_settings then show_settings = new_settings end

          imgui.Separator(ctx)
          local changed_mini_view, new_mini_view = imgui.MenuItem(ctx, "Mini View Mode", "", is_mini_view)
          if changed_mini_view then is_mini_view = new_mini_view end

          imgui.EndPopup(ctx)
        end
    end

    -- ++ SETTINGS PANEL (hidden in Mini View) ++
    if show_settings and not is_mini_view then
      imgui.Separator(ctx)
      imgui.Text(ctx, "Custom Group Names:")
      if imgui.BeginTable(ctx, "group_names_table", 4) then
        for i = 1, _NGRP do
          imgui.TableNextColumn(ctx)
          imgui.PushID(ctx, i)
          local changed, new_name = imgui.InputText(ctx, "##groupname", group_names[i] or "", 64)
          group_names[i] = new_name
          if changed or imgui.IsItemDeactivatedAfterEdit(ctx) then
            SaveGroupNames()
          end
          imgui.SameLine(ctx)
          imgui.Text(ctx, get_group_char(i - 1))
          imgui.PopID(ctx)
        end
        imgui.EndTable(ctx)
      end
      imgui.Separator(ctx)

      -- ++ LAYOUT CONTROLS ++
      imgui.Text(ctx, "Layout Customization:")
      imgui.PushItemWidth(ctx, 200)

      -- Meter Width Slider
      local changed_width, new_width = imgui.SliderInt(ctx, "Meter Width", layout_settings.width, 10, 50)
      if imgui.IsItemClicked(ctx, 1) then new_width = layout_defaults.width; changed_width = true end
      if imgui.IsItemHovered(ctx) then imgui.SetTooltip(ctx, "Right-click to reset to default") end

      -- Meter Height Slider
      local changed_height, new_height = imgui.SliderInt(ctx, "Meter Height", layout_settings.height, 50, 400)
      if imgui.IsItemClicked(ctx, 1) then new_height = layout_defaults.height; changed_height = true end
      if imgui.IsItemHovered(ctx) then imgui.SetTooltip(ctx, "Right-click to reset to default") end

      -- Group Spacing Slider
      local changed_g_space, new_g_space = imgui.SliderInt(ctx, "Group Spacing", layout_settings.group_spacing, 5, 50)
      if imgui.IsItemClicked(ctx, 1) then new_g_space = layout_defaults.group_spacing; changed_g_space = true end
      if imgui.IsItemHovered(ctx) then imgui.SetTooltip(ctx, "Right-click to reset to default") end

      -- Meter Spacing Slider
      local changed_m_space, new_m_space = imgui.SliderInt(ctx, "Meter Spacing", layout_settings.meter_spacing, 2, 30)
      if imgui.IsItemClicked(ctx, 1) then new_m_space = layout_defaults.meter_spacing; changed_m_space = true end
      if imgui.IsItemHovered(ctx) then imgui.SetTooltip(ctx, "Right-click to reset to default") end

      imgui.PopItemWidth(ctx)

      if changed_width or changed_height or changed_g_space or changed_m_space then
          layout_settings.width = new_width
          layout_settings.height = new_height
          layout_settings.group_spacing = new_g_space
          layout_settings.meter_spacing = new_m_space
          SaveLayoutSettings()
      end
      imgui.Separator(ctx)
    end

    if script_enabled then
      -- STEP 1: Update the state buffer 'known_meters'
      local current_time = reaper.time_precise()
      for g = 0, _NGRP - 1 do
        for n = 1, _NTX do
          local index = n + g * _NTX
          if reaper.gmem_read(gmem_base._TXON + index) == 1 then
            known_meters[index] = current_time
          end
        end
      end

      -- STEP 2: Build the drawing data structure
      local active_data = {}
      for index, last_seen in pairs(known_meters) do
        if current_time - last_seen > METER_INACTIVE_TIMEOUT then
          known_meters[index] = nil
          highest_peaks[index] = nil
          highest_dr_values[index] = nil
          lowest_dr_values[index] = nil
        else
          local g = math.floor((index - 1) / _NTX)
          local n = (index - 1) % _NTX + 1
          if not active_data[g] then active_data[g] = { index = g, meters = {} } end
          table.insert(active_data[g].meters, {
            num = n,
            rms_val = math.sqrt(reaper.gmem_read(gmem_base._RMS + index)),
            peak_val = reaper.gmem_read(gmem_base._PK + index),
            pkh_val = reaper.gmem_read(gmem_base._PKHOLD + index),
            is_clipped = reaper.gmem_read(gmem_base._CLIP + index),
            clip_count = reaper.gmem_read(gmem_base._CLIPCOUNT + index),
            hue = reaper.gmem_read(gmem_base._HUE + index)
          })
        end
      end

      -- STEP 3: Draw the GUI
      local is_first_group = true
      -- ++ NEW: Use dynamic spacing for Mini View
      local current_group_spacing = is_mini_view and 5 or layout_settings.group_spacing
      local current_meter_spacing = is_mini_view and 4 or layout_settings.meter_spacing

      for g = 0, _NGRP - 1 do
        local group_info = active_data[g]
        if group_info then
          if solo_group_idx == nil or solo_group_idx == group_info.index then

            table.sort(group_info.meters, function(a, b) return a.num < b.num end)

            if not is_first_group then imgui.SameLine(ctx, 0, current_group_spacing) end
            is_first_group = false

            imgui.BeginGroup(ctx)
            
            -- ++ NEW: Conditional drawing for labels and buttons
            if not is_mini_view then
                local group_width = #group_info.meters * layout_settings.width + (#group_info.meters - 1) * layout_settings.meter_spacing
                local custom_name = group_names[group_info.index + 1]
                local group_label = (custom_name and custom_name ~= "") and custom_name or get_group_char(group_info.index)

                local text_w = imgui.CalcTextSize(ctx, group_label)
                imgui.SetCursorPosX(ctx, imgui.GetCursorPosX(ctx) + (group_width - text_w) / 2)
                imgui.PushStyleColor(ctx, imgui.Col_Text, PackColor(table.unpack(colors.group_label)))
                imgui.Text(ctx, group_label)
                imgui.PopStyleColor(ctx, 1)

                local is_this_group_soloed = (solo_group_idx == g)
                if is_this_group_soloed then
                  imgui.PushStyleColor(ctx, imgui.Col_Button, PackColor(table.unpack(colors.solo_button_on)))
                  imgui.PushStyleColor(ctx, imgui.Col_ButtonHovered, PackColor(table.unpack(colors.solo_button_on)))
                  imgui.PushStyleColor(ctx, imgui.Col_ButtonActive, PackColor(table.unpack(colors.solo_button_on)))
                  imgui.PushStyleColor(ctx, imgui.Col_Text, PackColor(table.unpack(colors.solo_text_on)))
                end

                local solo_button_w = 20
                imgui.SetCursorPosX(ctx, imgui.GetCursorPosX(ctx) + (group_width - solo_button_w) / 2)
                if imgui.Button(ctx, "S##" .. g, solo_button_w, 18) then
                  if is_this_group_soloed then
                    solo_group_idx = nil
                  else
                    solo_group_idx = g
                  end
                end

                if is_this_group_soloed then
                  imgui.PopStyleColor(ctx, 4)
                end
            end

            for i, meter_data in ipairs(group_info.meters) do
              if i > 1 then imgui.SameLine(ctx, 0, current_meter_spacing) end

              local x, y = imgui.GetCursorScreenPos(ctx)
              local draw_list = imgui.GetWindowDrawList(ctx)
              local gmem_index = meter_data.num + group_info.index * _NTX

              local CLIP_AREA_HEIGHT = 14
              local meter_bar_y = y + CLIP_AREA_HEIGHT
              local meter_bar_height = layout_settings.height - CLIP_AREA_HEIGHT

              if meter_data.is_clipped == 1 and not clip_detected[gmem_index] then
                  add_clip_marker(gmem_index)
                  clip_detected[gmem_index] = true
              elseif meter_data.is_clipped == 0 then
                  clip_detected[gmem_index] = false
              end

              local rms_db = lin_to_db(meter_data.rms_val)
              local peak_db = lin_to_db(meter_data.peak_val)
              local pkh_db = lin_to_db(meter_data.pkh_val)

              if not highest_peaks[gmem_index] or meter_data.peak_val > highest_peaks[gmem_index] then
                highest_peaks[gmem_index] = meter_data.peak_val
              end
              local max_peak_db_so_far = lin_to_db(highest_peaks[gmem_index] or 0)

              if rms_db > DB_MIN then
                  local raw_dr_value = peak_db - rms_db
                  if raw_dr_value < 0 then raw_dr_value = 0 end

                  if not highest_dr_values[gmem_index] or raw_dr_value > highest_dr_values[gmem_index] then
                      highest_dr_values[gmem_index] = raw_dr_value
                  end

                  if peak_db > (max_peak_db_so_far - 10.0) then
                      if not lowest_dr_values[gmem_index] or raw_dr_value < lowest_dr_values[gmem_index] then
                          lowest_dr_values[gmem_index] = raw_dr_value
                      end
                  end
              end

              local color_index = math.floor(meter_data.hue) + 1
              local rms_color = meter_colors.rms[color_index] or meter_colors.rms[1]
              local peak_color = meter_colors.peak[color_index] or meter_colors.peak[1]

              local rms_y = db_to_y_pos(rms_db, meter_bar_y, meter_bar_height)
              local peak_y = db_to_y_pos(peak_db, meter_bar_y, meter_bar_height)

              imgui.DrawList_AddRectFilled(draw_list, x, meter_bar_y, x + layout_settings.width, meter_bar_y + meter_bar_height, PackColor(table.unpack(colors.meter_bg)))
              imgui.DrawList_AddRectFilled(draw_list, x, peak_y, x + layout_settings.width, meter_bar_y + meter_bar_height, PackColor(table.unpack(peak_color)))

              if rms_y > peak_y then
                imgui.DrawList_AddRectFilled(draw_list, x, peak_y, x + layout_settings.width, rms_y, PackColor(table.unpack(colors.dynamic_range)))
              end

              imgui.DrawList_AddRectFilled(draw_list, x + 2, rms_y, x + layout_settings.width - 2, meter_bar_y + meter_bar_height, PackColor(table.unpack(rms_color)))

              if show_max_peak then
                  local max_peak_val = highest_peaks[gmem_index] or 0
                  local max_peak_db = lin_to_db(max_peak_val)
                  local pkh_y = db_to_y_pos(pkh_db, meter_bar_y, meter_bar_height)
                  if pkh_y < meter_bar_y + meter_bar_height - 1 then
                     imgui.DrawList_AddLine(draw_list, x, pkh_y, x + layout_settings.width, pkh_y, PackColor(table.unpack(colors.peak_hold_temp)))
                  end
                  local max_pkh_y = db_to_y_pos(max_peak_db, meter_bar_y, meter_bar_height)
                  imgui.DrawList_AddRectFilled(draw_list, x, max_pkh_y, x + layout_settings.width, max_pkh_y + 2, PackColor(table.unpack(colors.peak_hold_max)))
                  local max_pkh_str = string.format("%.1f", max_peak_db)
                  local max_pkh_text_w = imgui.CalcTextSize(ctx, max_pkh_str)
                  local text_y_pos = max_pkh_y > (meter_bar_y + meter_bar_height - 10) and max_pkh_y - 14 or max_pkh_y + 4
                  imgui.SetCursorScreenPos(ctx, x + (layout_settings.width - max_pkh_text_w) / 2, text_y_pos)
                  imgui.PushStyleColor(ctx, imgui.Col_Text, PackColor(table.unpack(colors.text_on_meter)))
                  imgui.Text(ctx, max_pkh_str)
                  imgui.PopStyleColor(ctx, 1)
              else
                  local pkh_y = db_to_y_pos(pkh_db, meter_bar_y, meter_bar_height)
                  if pkh_y < meter_bar_y + meter_bar_height - 1 then
                     imgui.DrawList_AddRectFilled(draw_list, x, pkh_y, x + layout_settings.width, pkh_y + 2, PackColor(table.unpack(colors.peak_hold_max)))
                  end
                  if pkh_db > DB_MIN then
                    local pkh_str = string.format("%.1f", pkh_db)
                    local pkh_text_w = imgui.CalcTextSize(ctx, pkh_str)
                    local text_y_pos = pkh_y > (meter_bar_y + meter_bar_height - 10) and pkh_y - 14 or pkh_y + 4
                    imgui.SetCursorScreenPos(ctx, x + (layout_settings.width - pkh_text_w) / 2, text_y_pos)
                    imgui.PushStyleColor(ctx, imgui.Col_Text, PackColor(table.unpack(colors.text_on_meter)))
                    imgui.Text(ctx, pkh_str)
                    imgui.PopStyleColor(ctx, 1)
                  end
              end

              if meter_data.clip_count > 0 then
                imgui.DrawList_AddRectFilled(draw_list, x, y, x + layout_settings.width, y + CLIP_AREA_HEIGHT - 1, PackColor(table.unpack(colors.clip)))
                local clip_count_str = tostring(meter_data.clip_count)
                local clip_count_w = imgui.CalcTextSize(ctx, clip_count_str)
                imgui.SetCursorScreenPos(ctx, x + (layout_settings.width - clip_count_w) / 2, y + 1)
                imgui.PushStyleColor(ctx, imgui.Col_Text, PackColor(table.unpack(colors.text_on_meter)))
                imgui.Text(ctx, clip_count_str)
                imgui.PopStyleColor(ctx, 1)
              end

              imgui.SetCursorScreenPos(ctx, x, y)
              imgui.InvisibleButton(ctx, "meter"..gmem_index, layout_settings.width, layout_settings.height)

              if imgui.IsItemHovered(ctx) then
                imgui.BeginTooltip(ctx)
                local min_dr = lowest_dr_values[gmem_index]
                local max_dr = highest_dr_values[gmem_index]
                local min_dr_str = min_dr and string.format("%.1f", min_dr) or "---"
                local max_dr_str = max_dr and string.format("%.1f", max_dr) or "---"
                imgui.Text(ctx, string.format("DR (Min/Max): %s / %s dB", min_dr_str, max_dr_str))
                imgui.EndTooltip(ctx)
              end

              if imgui.IsItemClicked(ctx, 0) then -- Left-click
                 reaper.gmem_write(gmem_base._CLIP + gmem_index, 0)
                 reaper.gmem_write(gmem_base._CLIPCOUNT + gmem_index, 0)
                 reaper.gmem_write(gmem_base._PKHOLD + gmem_index, 0)
                 highest_peaks[gmem_index] = nil
                 highest_dr_values[gmem_index] = nil
                 lowest_dr_values[gmem_index] = nil
              end

              if imgui.IsItemClicked(ctx, 1) then -- Right-click
                  if track_map[group_info.index] and track_map[group_info.index][meter_data.num] then
                      local target_track = track_map[group_info.index][meter_data.num].ptr
                      if target_track then
                          reaper.Main_OnCommand(40297, 0) -- Unselect all tracks
                          reaper.SetTrackSelected(target_track, true)
                      end
                  end
              end

              -- ++ NEW: Conditional drawing for bottom labels and spacing
              if not is_mini_view then
                  local meter_label = tostring(meter_data.num)
                  if track_map[group_info.index] and track_map[group_info.index][meter_data.num] then
                      meter_label = track_map[group_info.index][meter_data.num].name
                  end

                  local meter_label_w = imgui.CalcTextSize(ctx, meter_label)
                  imgui.SetCursorScreenPos(ctx, x + (layout_settings.width - meter_label_w) / 2, y + layout_settings.height + 4)
                  imgui.PushStyleColor(ctx, imgui.Col_Text, PackColor(table.unpack(colors.text)))
                  imgui.Text(ctx, meter_label)
                  imgui.PopStyleColor(ctx, 1)

                  imgui.SetCursorScreenPos(ctx, x, y)
                  imgui.Dummy(ctx, layout_settings.width, layout_settings.height + 40)
              else
                  -- In Mini View, just reserve space for the meter bar and clip area
                  imgui.SetCursorScreenPos(ctx, x, y)
                  imgui.Dummy(ctx, layout_settings.width, layout_settings.height)
              end

            end
            imgui.EndGroup(ctx)
          end
        end
      end
    else
      imgui.Text(ctx, "Metering is disabled.")
    end

    imgui.End(ctx)
  end

  if is_open then
    reaper.defer(loop)
  else
    SaveGroupNames()
    SaveLayoutSettings()
  end
end

-- =============================================================================
-- SCRIPT ENTRY POINT
-- =============================================================================
LoadGroupNames()
LoadLayoutSettings()
ScanProjectForTracks()
reaper.defer(loop)

