--[[
@description    Create chord regions from MIDI text events with simplified naming
@author         Hosi
@version        0.1
@provides
  [main] . > Hosi_Create chord regions from MIDI item (Fixed).lua

@about
  # Create Chord Regions from MIDI Item

  Creates project regions from MIDI text events found within a selected MIDI item.
  
  This script includes an option to normalize and simplify chord names for better
  readability and compatibility. For example:
  - 'Dmaj' or 'D major' becomes 'D'
  - 'Dmin' or 'D minor' becomes 'Dm'
  - 'DDom7th' becomes 'D7'
  - 'Em7th' becomes 'Em7'

  ## Instructions:
  1. Select a MIDI item that contains chord information as text events.
  2. Run the script from the Action List.

@changelog
  + v0.1 (2025-10-01) - Initial release.
--]]

-- --- HELPER FUNCTIONS (for normalization and coloring) ---

function ColorHexToInt(hex)
  hex = hex:gsub("#", "")
  local R = tonumber("0x"..hex:sub(1,2))
  local G = tonumber("0x"..hex:sub(3,4))
  local B = tonumber("0x"..hex:sub(5,6))
  return reaper.ColorToNative(R, G, B)
end

function normalize_chord_name(name)
    -- Step 1: CRITICAL FIX - Remove any non-printable control characters (e.g., null terminators)
    name = name:gsub("[\001-\031\127]", "")

    -- Step 2: Trim whitespace from both ends
    name = name:match("^%s*(.-)%s*$")

    -- Step 3: Remove any text in parentheses (e.g., "(grid)")
    name = name:gsub("%s*%b()", "")

    -- Step 4: Standardize minor variations to 'm'
    name = name:gsub("[Mm]inor", "m")
    name = name:gsub("[Mm]in", "m")
    
    -- Step 5: Standardize major variations. We will remove the words "major" or "maj" entirely.
    name = name:gsub("[Mm]ajor", "")
    name = name:gsub("[Mm]aj", "")

    -- FIX A: Standardize dominant variations. "Dom" is redundant with "7", so we remove it.
    name = name:gsub("[Dd]om", "")

    -- FIX B (REVISED): Remove ordinal indicators like "th", "st", "nd", "rd" from numbers.
    -- The previous pattern was incorrect for Lua. This version uses separate, case-insensitive replacements.
    name = name:gsub("([1-9])[tT][hH]", "%1")
    name = name:gsub("([1-9])[sS][tT]", "%1")
    name = name:gsub("([1-9])[nN][dD]", "%1")
    name = name:gsub("([1-9])[rR][dD]", "%1")

    -- Step 6: Remove colons (e.g., "D:m" -> "Dm")
    name = name:gsub(":", "")

    -- Step 7: Remove all remaining spaces to create a compact chord name like "Cm7"
    name = name:gsub("%s+", "")
    
    return name
end

-- --- MAIN SCRIPT LOGIC ---

-- Get the active MIDI editor and the take
reaper.Main_OnCommand(40153, 0) -- Item: Open in built-in MIDI editor
local hwnd = reaper.MIDIEditor_GetActive()
if not hwnd then return end -- Stop if no MIDI editor is open
local take = reaper.MIDIEditor_GetTake(hwnd)
if not take then return end -- Stop if no take is found

reaper.Undo_BeginBlock2(0)

-- Identify chords and get all MIDI events
reaper.MIDIEditor_OnCommand(hwnd, 41281) -- Notation: Identify chords on editor grid
reaper.MIDI_Sort(take)
local ok, midi_blob = reaper.MIDI_GetAllEvts(take, "")

-- Table to store chord information
local chords = {}
local string_pos, ticks = 1, 0

-- Loop through the MIDI events to find chord text
while string_pos < midi_blob:len() do
    local offset, flags, msg, new_pos = string.unpack("i4Bs4", midi_blob, string_pos)
    string_pos = new_pos
    ticks = ticks + offset
    
    -- Check for MIDI meta-message (0xFF) which contains text events
    if msg:byte(1) == 0xFF then
        local chord_name = msg:match("text (.+)")
        if not chord_name and msg:byte(2) == 0x01 then
            local len_byte_start = 3
            local data_start = len_byte_start + 1
            if msg:len() >= data_start then
              chord_name = msg:sub(data_start)
            end
        end

        if chord_name then
            -- Normalize the name before adding it to the table
            local normalized_name = normalize_chord_name(chord_name)
            table.insert(chords, {name = normalized_name, ticks = ticks})
        end
    end
end

-- Get the length of the item to create the final region
local item = reaper.GetMediaItemTake_Item(take)
local item_length_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, reaper.GetMediaItemInfo_Value(item, "D_LENGTH"))

-- Add a final entry to mark the end of the last chord
table.insert(chords, {ticks = item_length_ppq})

-- Convert PPQ positions to project time
for i = 1, #chords do
    chords[i].time = reaper.MIDI_GetProjTimeFromPPQPos(take, chords[i].ticks)
end

-- Create regions from the chord data
for i = 1, #chords - 1 do
    local current_chord_name = chords[i].name
    if current_chord_name and #current_chord_name > 0 then
        -- Dynamic color coding based on chord name
        local color = 0
        if current_chord_name:match("m") then
          color = ColorHexToInt("#F44336") | 0x1000000 -- Red (Minor)
        elseif current_chord_name:match("7") then
          color = ColorHexToInt("#FF9800") | 0x1000000 -- Orange (Dominant 7th)
        elseif current_chord_name == "N" or current_chord_name == "None" then
          color = ColorHexToInt("#9E9E9E") | 0x1000000 -- Gray (No Chord)
        else
          -- Default to Major color (Green) for anything not minor, etc.
          color = ColorHexToInt("#4CAF50") | 0x1000000 -- Green (Major)
        end
        
        reaper.AddProjectMarker2(0, true, chords[i].time, chords[i+1].time, current_chord_name, -1, color)
    end
end

reaper.UpdateArrange()
reaper.Undo_EndBlock2(0, "Convert MIDI chords to regions (Fixed)", -1)

-- Close the MIDI editor window
reaper.MIDIEditor_OnCommand(hwnd, 40029) -- File: Close window

