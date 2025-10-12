--[[
@description    Auto-Pin Tracks GUI with Auto-Saving Profile
@author         Hosi
@version        1.0
@provides
  [main] . > Hosi_Auto-Pin Tracks GUI.lua

@about
  # Auto-Pin Tracks GUI (Auto-Save Edition)

  This script provides a ReaImGui interface to manage track pinning based on keywords.
  The keyword list is automatically loaded on startup and saved whenever it's modified.

  ## Instructions:
  - Edit the keyword list directly in the text box (one per line). Changes are saved automatically.
  - Press "Pin Tracks by Keywords" to pin tracks whose names contain any of the keywords.
  - Press "Unpin by Keywords" to unpin tracks whose names contain any of the keywords.
  - Press "Unpin All Tracks" to unpin all tracks in the project.
  
  ## Requirements:
  - ReaImGui extension

@changelog
  + v1.0 (2025-10-12) - Initial release.
--]]
---------------------------------------------------------------------
-- INITIAL CONFIGURATION
---------------------------------------------------------------------
local config = {
  win_title = "Auto-Pin Tracks GUI",
  profile_filename = "Hosi_AutoPin_Profile.txt"
}

---------------------------------------------------------------------
-- REAIMGUI INITIALIZATION
---------------------------------------------------------------------
if not reaper.ImGui_CreateContext then
  reaper.ShowMessageBox("ReaImGui library is not installed.\nPlease install it via ReaPack.", "ReaImGui Error", 0)
  return
end
local ctx = reaper.ImGui_CreateContext(config.win_title)

---------------------------------------------------------------------
-- STATE VARIABLES
---------------------------------------------------------------------
local state = {
  is_open = true,
  keywords_text = "" -- Start with an empty string
}

---------------------------------------------------------------------
-- HELPER FUNCTIONS
---------------------------------------------------------------------

-- Returns the full path for the profile file
function GetProfilePath()
  return reaper.GetResourcePath() .. "/Scripts/" .. config.profile_filename
end

-- Forcefully updates the UI
function UpdateUI()
  reaper.TrackList_AdjustWindows(false)
  reaper.UpdateArrange()
end

-- Pins tracks based on the keyword list
function PinTracksByKeywords(keywords_table)
  if not keywords_table or #keywords_table == 0 then return end

  reaper.PreventUIRefresh(1)
  reaper.Undo_BeginBlock()

  for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    if track then
      local _, track_name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
      
      if track_name and track_name ~= "" then
        local upper_track_name = track_name:upper()
        
        for _, keyword in ipairs(keywords_table) do
          if keyword ~= "" and upper_track_name:match(keyword:upper()) then
            reaper.SetMediaTrackInfo_Value(track, "B_TCPPIN", 1)
            break
          end
        end
      end
    end
  end
  
  reaper.Undo_EndBlock("Pin Tracks by Keywords", -1)
  reaper.PreventUIRefresh(-1)
  UpdateUI()
end

-- Unpins tracks based on the keyword list
function UnpinTracksByKeywords(keywords_table)
  if not keywords_table or #keywords_table == 0 then return end

  reaper.PreventUIRefresh(1)
  reaper.Undo_BeginBlock()

  for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    if track then
      local _, track_name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
      
      if track_name and track_name ~= "" then
        local upper_track_name = track_name:upper()
        
        for _, keyword in ipairs(keywords_table) do
          if keyword ~= "" and upper_track_name:match(keyword:upper()) then
            reaper.SetMediaTrackInfo_Value(track, "B_TCPPIN", 0)
            break
          end
        end
      end
    end
  end
  
  reaper.Undo_EndBlock("Unpin Tracks by Keywords", -1)
  reaper.PreventUIRefresh(-1)
  UpdateUI()
end

-- Unpins all tracks
function UnpinAllTracks()
  reaper.PreventUIRefresh(1)
  reaper.Undo_BeginBlock()

  for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    if track then
      reaper.SetMediaTrackInfo_Value(track, "B_TCPPIN", 0)
    end
  end

  reaper.Undo_EndBlock("Unpin All Tracks", -1)
  reaper.PreventUIRefresh(-1)
  UpdateUI()
end

-- Saves the current keywords to a fixed file
function SaveKeywordsToFile()
  local filepath = GetProfilePath()
  local file, err = io.open(filepath, "w")
  
  if file then
    file:write(state.keywords_text)
    file:close()
  else
    reaper.ShowConsoleMsg("ERROR: Could not save profile file: " .. tostring(err) .. "\n")
  end
end

-- Loads keywords from a fixed file
function LoadKeywordsFromFile()
  local filepath = GetProfilePath()
  local file = io.open(filepath, "r")
  
  if file then
    local content = file:read("*a")
    state.keywords_text = content
    file:close()
  end
end

---------------------------------------------------------------------
-- SCRIPT INITIALIZATION
---------------------------------------------------------------------
LoadKeywordsFromFile() -- Automatically load keywords on script startup

---------------------------------------------------------------------
-- MAIN GUI LOOP
---------------------------------------------------------------------
function loop()
  local visible
  visible, state.is_open = reaper.ImGui_Begin(ctx, config.win_title, state.is_open)

  if visible then
    reaper.ImGui_Text(ctx, "Enter keywords (one per line):")
    
    reaper.ImGui_PushItemWidth(ctx, -1)
    local keywords_changed, new_keywords_text = reaper.ImGui_InputTextMultiline(ctx, '##KeywordsEditor', state.keywords_text, 0, -85)
    if keywords_changed then 
      state.keywords_text = new_keywords_text
      SaveKeywordsToFile() -- Automatically save on any change
    end
    reaper.ImGui_PopItemWidth(ctx)

    reaper.ImGui_Separator(ctx)
    
    if reaper.ImGui_Button(ctx, "Pin Tracks by Keywords", -1, 0) then
      local keywords_to_process = {}
      for word in state.keywords_text:gmatch("([^\n\r]+)") do
        table.insert(keywords_to_process, word)
      end
      PinTracksByKeywords(keywords_to_process)
    end

    if reaper.ImGui_Button(ctx, "Unpin by Keywords", -1, 0) then
      local keywords_to_process = {}
      for word in state.keywords_text:gmatch("([^\n\r]+)") do
        table.insert(keywords_to_process, word)
      end
      UnpinTracksByKeywords(keywords_to_process)
    end

    if reaper.ImGui_Button(ctx, "Unpin All Tracks", -1, 0) then
      UnpinAllTracks()
    end

    reaper.ImGui_End(ctx)
  end

  if state.is_open then
    reaper.defer(loop)
  end
end

-- Safety check before running
local track_check = reaper.GetTrack(0, 0)
if track_check then
  local ok, _ = pcall(reaper.GetMediaTrackInfo_Value, track_check, "B_TCPPIN")
  if ok then
    loop()
  else
    reaper.ShowMessageBox("Your version of REAPER does not support track pinning.", "Error", 0)
  end
else
   loop()
end

