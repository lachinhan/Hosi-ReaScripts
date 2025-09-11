--[[
@description Manage hmeterzTX (Add/Configure, Offline/Online or Remove All)
@author      Hosi
@version     0.4
@provides
  [main] . > Hosi_Manage hmeterzTX.lua

@about
  # Manage hmeterzTX

  This script combines the functionality of adding, configuring, toggling offline
  state, and removing the 'hmeterzTX' JSFX.

   v0.4:
  - Added "Offline All" and "Online All" functions to quickly bypass or
    enable all hmeterzTX instances in the project, saving CPU.

  ## ACTIONS:
  1. Add with Auto-Grouping: Adds 'hmeterzTX' and automatically assigns groups based on track names.
  2. Add Manually: Adds 'hmeterzTX' to a single specified group.
  3. Toggle Offline/Online All: Sets all instances to be bypassed (offline) or active (online).
  4. Remove All from Project: Scans the entire project and removes all
     instances of 'hmeterzTX'.

  ## REQUIREMENTS:
  - ReaImGui library (install via ReaPack)

  ## INSTRUCTIONS:
  1. In REAPER, go to Actions > Show action list...
  2. Click "New Action" > "Load ReaScript..."
  3. Select this file.
  4. Run the script from the Actions list.
--]]

-- --- CONFIGURATION ---
-- The string to find when removing the FX (case-insensitive)
local FX_NAME_TO_FIND = "hmeterz tx"
-- The exact FX name to add. You MAY need to change the version number!
local FX_NAME_TO_ADD = "JS: hmeterz tx"

-- ++ AUTO-GROUPING RULES ++
-- Add keywords for your tracks here. The script will find the first match.
-- Keywords are NOT case-sensitive.
local AUTO_GROUP_RULES = {
  -- Group 'a' (index 0) - Vocals
  { group_idx = 0, keywords = {"Acapella","Vocal", "VOX", "LeadV", "BGV", "Singer"} },
  -- Group 'b' (index 1) - Bass
  { group_idx = 1, keywords = {"Bass", "Banjo", "Bongos", "Bau", "Bagpipes", "Bassoon", "SUB"} },
  -- Group 'c' (index 2) - Cello
  { group_idx = 2, keywords = {"Cello", "Clarinette", "Campanelle", "Conga", "Castanets", "Cong Chieng"} },
  -- Group 'd' (index 3) - Dizi/Dan/Drum
  { group_idx = 3, keywords = {"Dizi", "Dan Day", "Dan Co", "Dan Kim", "Dan Tranh", "Kick", "Snare", "Tom", "OH", "Hat", "Cym", "Drum", "DR"} },
  -- Group 'e' (index 4) - Electric/Sampler
  { group_idx = 4, keywords = {"Electric", "Sampler"} },
  -- Group 'f' (index 5) - FX
  { group_idx = 5, keywords = {"FX", "Reverb", "Delay", "EQ"} },
  -- Group 'g' (index 6) - Guitar
  { group_idx = 6, keywords = {"GTR", "Guitar", "Guit"} },
  -- Group 'h' (index 7) -
  { group_idx = 7, keywords = {"Harmonica", "Harpe", "Hichiriki"} },
  -- Group 'i' (index 8) -
  { group_idx = 8, keywords = {"Indian flute", "Irish harp"} },
  -- Group 'j' (index 9) -
  --{ group_idx = 9, keywords = {"Indian flute", "Irish harp"} },
  -- Group 'k' (index 10) - Keyboard
  { group_idx = 10, keywords = {"Keys", "Keyboards"} },
  -- Group 'l' (index 11) -
  --{ group_idx = 11, keywords = {"Indian flute", "Irish harp"} },
  -- Group 'm' (index 12) - Maracas
  { group_idx = 12, keywords = {"Maracas", "Tambourine", "trombone"} },
  -- Group 'n' (index 13) -
  --{ group_idx = 13, keywords = {"Indian flute", "Irish harp"} },
  -- Group 'o' (index 14) - Ocarina/Organ
  { group_idx = 14, keywords = {"Ocarina", "Organ"} },
  -- Group 'p' (index 14) - Piano
  { group_idx = 14, keywords = {"Piano", "Pianica", "Synth", "Pad"} },

}
-- ---------------------

local reaper = reaper

-- Initialize ReaImGui
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local imgui = require('imgui')('0.10')

if not imgui or type(imgui) ~= "table" then
    reaper.ShowMessageBox("Failed to initialize ReaImGui library.\n\nPlease ensure it is installed (v0.10+ recommended) and up to date via ReaPack.", "Error", 0)
    return
end

local ctx = imgui.CreateContext('hMeterzTX Manager')

---------------------------------------------------------------------
-- HELPER AND LOGIC FUNCTIONS
---------------------------------------------------------------------

-- Function to get group from track name
function GetGroupFromTrackName(track_name)
  local name_lower = string.lower(track_name)
  for _, rule in ipairs(AUTO_GROUP_RULES) do
    for _, keyword in ipairs(rule.keywords) do
      if string.find(name_lower, string.lower(keyword), 1, true) then
        return rule.group_idx
      end
    end
  end
  return nil -- No match found
end

-- Helper function to check if a track already has the target FX
function TrackHas_hmeterzTX(track)
  local fx_count = reaper.TrackFX_GetCount(track)
  for i = 0, fx_count - 1 do
    local _, current_fx_name = reaper.TrackFX_GetFXName(track, i, "", 1024)
    if string.match(string.lower(current_fx_name), FX_NAME_TO_FIND) then
      return true
    end
  end
  return false
end

-- Scans the project for the first hmeterzTX instance and returns its offline state
function GetCurrentFXState()
  local tracks_count = reaper.CountTracks(0)
  for i = 0, tracks_count - 1 do
    local track = reaper.GetTrack(0, i)
    if track then
      local fx_count = reaper.TrackFX_GetCount(track)
      for fx_index = 0, fx_count - 1 do
        local _, current_fx_name = reaper.TrackFX_GetFXName(track, fx_index, "", 1024)
        if string.match(string.lower(current_fx_name), FX_NAME_TO_FIND) then
          return reaper.TrackFX_GetOffline(track, fx_index)
        end
      end
    end
  end
  return nil
end


-- Core logic to add and configure hmeterzTX on selected tracks
function AddAndConfigure_hmeterzTX(group_idx, start_meter, skip_folders, use_auto_grouping)
  local selected_tracks_count = reaper.CountSelectedTracks(0)

  if selected_tracks_count == 0 then
    reaper.ShowMessageBox("Please select one or more tracks first.", "No Tracks Selected", 0)
    return
  end

  reaper.Undo_BeginBlock()

  local tracks_processed = 0
  local meter_counters_per_group = {}

  for i = 0, selected_tracks_count - 1 do
    local track = reaper.GetSelectedTrack(0, i)
    if track then
      if skip_folders then
        local folder_depth = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
        if folder_depth == 1 then goto continue_loop end
      end

      if TrackHas_hmeterzTX(track) then goto continue_loop end

      local fx_index = reaper.TrackFX_AddByName(track, FX_NAME_TO_ADD, false, -1)
      if fx_index > -1 then
        local group_to_use = group_idx

        if use_auto_grouping then
          local _, track_name = reaper.GetTrackName(track, "")
          local auto_group = GetGroupFromTrackName(track_name)
          if auto_group then
            group_to_use = auto_group
          end
        end

        if not meter_counters_per_group[group_to_use] then
            meter_counters_per_group[group_to_use] = start_meter - 1
        end
        meter_counters_per_group[group_to_use] = meter_counters_per_group[group_to_use] + 1
        local meter_number = meter_counters_per_group[group_to_use]

        if meter_number > 16 then
            meter_number = 1
            meter_counters_per_group[group_to_use] = 1
        end

        reaper.TrackFX_SetParam(track, fx_index, 0, group_to_use)
        reaper.TrackFX_SetParam(track, fx_index, 1, meter_number)
        reaper.TrackFX_SetParam(track, fx_index, 2, math.random(0, 7))

        tracks_processed = tracks_processed + 1
      else
        reaper.ShowMessageBox("Could not find the FX: '" .. FX_NAME_TO_ADD .. "'.\nPlease check the FX name and version in the script's CONFIGURATION section.", "FX Not Found", 0)
        reaper.Undo_EndBlock("Auto-Setup hmeterzTX (Failed)", -1)
        return
      end
    end
    ::continue_loop::
  end

  reaper.Undo_EndBlock("Auto-Setup hmeterzTX on " .. tracks_processed .. " tracks", -1)
  reaper.UpdateArrange()
  reaper.ShowMessageBox("Added " .. tracks_processed .. " instance(s) of hmeterzTX.", "Setup Complete", 0)
end

-- Core logic to remove all instances from the project
function RemoveAll_hmeterzTX()
  local tracks_count = reaper.CountTracks(0)
  local removed_count = 0

  reaper.Undo_BeginBlock()

  for i = 0, tracks_count - 1 do
    local track = reaper.GetTrack(0, i)
    if track then
      local fx_count = reaper.TrackFX_GetCount(track)
      for fx_index = fx_count - 1, 0, -1 do
        local _, current_fx_name = reaper.TrackFX_GetFXName(track, fx_index, "", 1024)
        if string.match(string.lower(current_fx_name), FX_NAME_TO_FIND) then
          reaper.TrackFX_Delete(track, fx_index)
          removed_count = removed_count + 1
        end
      end
    end
  end

  reaper.Undo_EndBlock("Remove " .. removed_count .. " hmeterzTX instances", -1)
  reaper.ShowMessageBox(removed_count .. " instance(s) of hmeterzTX have been removed from the project.", "Cleanup Complete", 0)
  reaper.UpdateArrange()
end

-- Core logic to toggle the offline state of all instances
function ToggleOfflineAll_hmeterzTX(go_offline)
  local tracks_count = reaper.CountTracks(0)
  local processed_count = 0
  local action_text = go_offline and "Offlined" or "Onlined"
  local undo_text = go_offline and "Offline" or "Online"

  reaper.Undo_BeginBlock()

  for i = 0, tracks_count - 1 do
    local track = reaper.GetTrack(0, i)
    if track then
      local fx_count = reaper.TrackFX_GetCount(track)
      for fx_index = 0, fx_count - 1 do
        local _, current_fx_name = reaper.TrackFX_GetFXName(track, fx_index, "", 1024)
        if string.match(string.lower(current_fx_name), FX_NAME_TO_FIND) then
          reaper.TrackFX_SetOffline(track, fx_index, go_offline)
          processed_count = processed_count + 1
        end
      end
    end
  end

  reaper.Undo_EndBlock(undo_text .. " " .. processed_count .. " hmeterzTX instances", -1)
  reaper.ShowMessageBox(processed_count .. " instance(s) of hmeterzTX have been " .. string.lower(action_text) .. ".", action_text .. " Complete", 0)
  reaper.UpdateArrange()
end


---------------------------------------------------------------------
-- GUI STATE AND DRAWING
---------------------------------------------------------------------

-- GUI State Variables
local current_view = 'main'
local is_open = true
local flags = imgui.WindowFlags_NoResize | imgui.WindowFlags_AlwaysAutoResize

-- State for 'Add' views
local groups_table = {'a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p'}
local groups_string = table.concat(groups_table, "\0") .. "\0"
local group_idx = 0
local start_meter = 1
local skip_folders = true

-- Main GUI loop
function loop()
  local visible
  visible, is_open = imgui.Begin(ctx, 'hMeterzTX Manager', is_open, flags)

  if visible then
    imgui.PushStyleVar(ctx, imgui.StyleVar_FramePadding, 8, 5)
    imgui.PushStyleVar(ctx, imgui.StyleVar_ItemSpacing, 8, 6)
    
    local content_width = imgui.GetContentRegionAvail(ctx)

    -- MAIN MENU VIEW
    if current_view == 'main' then
      imgui.Text(ctx, "Please choose an action:")
      imgui.Separator(ctx)

      if imgui.Button(ctx, "Add with Auto-Grouping", content_width, 30) then
        current_view = 'add_auto'
      end

      if imgui.Button(ctx, "Add Manually (to one Group)", content_width, 30) then
        current_view = 'add_manual'
      end

      imgui.Separator(ctx)

      local fx_are_offline = GetCurrentFXState()
      if fx_are_offline ~= nil then
        local button_text, action_is_to_go_offline
        if fx_are_offline then
          button_text = "Set All FX Online"
          action_is_to_go_offline = false
        else
          button_text = "Set All FX Offline"
          action_is_to_go_offline = true
        end

        if imgui.Button(ctx, button_text, content_width, 30) then
          ToggleOfflineAll_hmeterzTX(action_is_to_go_offline)
        end
      end

      if imgui.Button(ctx, "Remove All from Project", content_width, 30) then
        current_view = 'remove'
      end
      
      imgui.Separator(ctx)
      if imgui.Button(ctx, "Close", content_width, 30) then
        is_open = false
      end

    -- ADD WITH AUTO-GROUPING VIEW
    elseif current_view == 'add_auto' then
      imgui.Text(ctx, "Configure Auto-Grouping")
      imgui.Separator(ctx)
      imgui.TextWrapped(ctx, "Adds hmeterzTX to selected tracks, guessing the group from the track name.")

      imgui.PushItemWidth(ctx, -1)
      imgui.Combo(ctx, "Fallback Group", group_idx, groups_string)
      imgui.SliderInt(ctx, "Starting Meter", start_meter, 1, 16)
      imgui.PopItemWidth(ctx)

      imgui.Checkbox(ctx, "Skip Folder Tracks", skip_folders)
      imgui.Separator(ctx)
      
      if imgui.Button(ctx, "Apply and Close", content_width * 0.5 - 4, 30) then
        AddAndConfigure_hmeterzTX(group_idx, start_meter, skip_folders, true)
        is_open = false
      end
      imgui.SameLine(ctx, 0, 8)
      if imgui.Button(ctx, "Back", content_width * 0.5 - 4, 30) then
        current_view = 'main'
      end

    -- ADD MANUALLY VIEW
    elseif current_view == 'add_manual' then
      imgui.Text(ctx, "Configure Manual Add")
      imgui.Separator(ctx)
      imgui.TextWrapped(ctx, "Adds hmeterzTX to selected tracks, assigning all to a single group.")
      
      imgui.PushItemWidth(ctx, -1)
      imgui.Combo(ctx, "Target Group", group_idx, groups_string)
      imgui.SliderInt(ctx, "Starting Meter", start_meter, 1, 16)
      imgui.PopItemWidth(ctx)

      imgui.Checkbox(ctx, "Skip Folder Tracks", skip_folders)
      imgui.Separator(ctx)
      
      if imgui.Button(ctx, "Apply and Close", content_width * 0.5 - 4, 30) then
        AddAndConfigure_hmeterzTX(group_idx, start_meter, skip_folders, false)
        is_open = false
      end
      imgui.SameLine(ctx, 0, 8)
      if imgui.Button(ctx, "Back", content_width * 0.5 - 4, 30) then
        current_view = 'main'
      end

    -- REMOVE CONFIRMATION VIEW
    elseif current_view == 'remove' then
      imgui.Text(ctx, "Confirm Removal")
      imgui.Separator(ctx)
      imgui.TextWrapped(ctx, "This will scan the ENTIRE project and permanently remove all instances of '" .. FX_NAME_TO_FIND .. "'. This action cannot be undone. Are you sure?")
      imgui.Separator(ctx)
      
      if imgui.Button(ctx, "YES, REMOVE ALL", content_width * 0.5 - 4, 30) then
        RemoveAll_hmeterzTX()
        is_open = false
      end
      
      imgui.SameLine(ctx, 0, 8)
      if imgui.Button(ctx, "Cancel", content_width * 0.5 - 4, 30) then
        current_view = 'main'
      end
    end

    imgui.PopStyleVar(ctx, 2)
    imgui.End(ctx)
  end

  if is_open then
    reaper.defer(loop)
  end
end

---------------------------------------------------------------------
-- SCRIPT ENTRY POINT
---------------------------------------------------------------------
math.randomseed(os.time())
reaper.defer(loop)

