--[[
@description Script Generator for Hosi's Toggle Plugin
@author      Hosi
@version     1.0
@about
  Run this script to automatically generate multiple "Hosi_Toggle Plugin by Slot X.lua" files.
  A dialog box will appear asking for the desired number of slots.
--]]
-- The template for the script file is stored in a long string.
local template = [=[
--[[
* ReaScript: Toggle Plugin by Slot Position
* Author: Hosi
* Description:
* Toggles the plugin window at a SPECIFIC SLOT POSITION on the currently selected track.
*
* INSTRUCTIONS:
* 1. Change the number on the "local fx_slot_index = 0" line to select the desired plugin slot.
* (0 = first slot, 1 = second slot, 2 = third slot, etc.)
* 2. Create multiple copies of this script to control different slots.
--]]

-- ##### CHANGE THE NUMBER HERE #####
local fx_slot_index = {slot_index} -- 0 is the first plugin slot position.
--------------------------------

function main()
  -- Count the number of selected tracks
  local selected_tracks = reaper.CountSelectedTracks(0)
  
  -- Only run the script if at least one track is selected
  if selected_tracks > 0 then
    -- Get the first selected track
    local track = reaper.GetSelectedTrack(0, 0)
    
    if track then
      -- Check if a plugin exists at that slot position
      if reaper.TrackFX_GetCount(track) > fx_slot_index then
        
        -- Explicit toggle logic: Check the window's current state first.
        local is_window_open = reaper.TrackFX_GetOpen(track, fx_slot_index)
        
        if is_window_open then
          -- If the window is open, close it.
          reaper.TrackFX_Show(track, fx_slot_index, 0) -- 0 = close window
        else
          -- If the window is closed, open it.
          reaper.TrackFX_Show(track, fx_slot_index, 1) -- 1 = show floating window
        end
        
      else
        reaper.ShowConsoleMsg(string.format("Plugin not found at slot position #%d.\n", fx_slot_index + 1))
      end
    end
  else
    reaper.ShowConsoleMsg("Please select a track first.\n")
  end
end

reaper.defer(main)
]=]

-- Main function to ask the user and create the files
function create_scripts()
  -- Show a dialog box to ask the user for input
  local title = "Automatic Script Generator"
  local num_inputs = 1
  local captions_csv = "Number of slots to create:"
  local retvals_csv = "8" -- Default value is 8

  local ok, result_csv = reaper.GetUserInputs(title, num_inputs, captions_csv, retvals_csv)

  -- If the user clicks "Cancel", stop the script
  if not ok then return end

  -- Get the user's input and convert it to a number
  local num_slots_to_create = tonumber(result_csv)

  -- Check if the input is a valid number
  if not num_slots_to_create or num_slots_to_create <= 0 then
    reaper.ShowConsoleMsg("Please enter a valid number greater than 0.\n")
    return
  end

  -- Get the path to Reaper's Scripts directory
  local scripts_path = reaper.GetResourcePath() .. '/Scripts/'
  
  if not scripts_path then
    reaper.ShowConsoleMsg("Could not find Reaper's Scripts directory.\n")
    return
  end

  -- Loop to create the files
  for i = 1, num_slots_to_create do
    -- The slot index in Lua starts from 0 (Slot 1 -> index 0)
    local slot_index = i - 1
    
    -- Replace the placeholder {slot_index} with the actual number
    local file_content = template:gsub("{slot_index}", tostring(slot_index))
    
    -- Create the file name and full path
    local file_name = "Hosi_Toggle Plugin by Slot " .. i .. ".lua"
    local full_path = scripts_path .. file_name
    
    -- Open the file for writing
    local file, err = io.open(full_path, "w")
    
    if file then
      file:write(file_content)
      file:close()
      reaper.ShowConsoleMsg("Successfully created file: " .. file_name .. "\n")
    else
      reaper.ShowConsoleMsg("Error creating file " .. file_name .. ": " .. tostring(err) .. "\n")
    end
  end
  
  -- After the loop, print a final confirmation message to the console with the path
  reaper.ShowConsoleMsg("--------------------------------------------------\n")
  reaper.ShowConsoleMsg(string.format("Done! Created %d script(s).\n", num_slots_to_create))
  reaper.ShowConsoleMsg("They have been saved in your Reaper Scripts folder:\n")
  reaper.ShowConsoleMsg(scripts_path .. "\n")
  reaper.ShowConsoleMsg("--------------------------------------------------\n")
end

-- Run the main function
create_scripts()
