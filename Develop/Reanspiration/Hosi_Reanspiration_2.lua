-- @description Reanspiration - Advanced MIDI Generation Toolkit
-- @version 2.4
-- @author Hosi (developed from original concept by phaselab)
-- @link Original Script by phaselab https://forum.cockos.com/showthread.php?t=291623
-- @about
--   An all-in-one toolkit for generating harmonically-aware musical ideas.
--
--   This script expands upon the original "Reanspiration" by phaselab, adding a comprehensive GUI and numerous features for creating chords, basslines, and melodies.
--
--   Features:
--   - Chord generation with expanded scale/progression library.
--   - Advanced chord extensions (9ths, 11ths, 13ths, alterations).
--   - Advanced voicing (spread, drop voicings).
--   - Smart bassline generator with multiple patterns.
--   - Integrated melody generator.
--   - Arpeggiator and Strummer.
--   - Humanizer for timing and velocity.
--   - Multi-level Undo for creative tool edits.
--   - Tabbed interface for improved workflow.
--	 - Delete Chords (Keep Bass/Melody)
-- @end

local reaper = reaper

-- Fix for ReaImGui library loading
if reaper.ImGui_GetBuiltinPath then
  -- Set the package path to find the built-in ImGui library
  package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
  
  -- Load and initialize the library. This call is necessary to make
  -- the legacy reaper.ImGui_* functions available in newer Reaper versions.
  require('imgui')('0.10')
end

math.randomseed(os.time())

local scales = {
  {name = "C", notes = {0, 2, 4, 5, 7, 9, 11}},
  {name = "C#/Db", notes = {1, 3, 5, 6, 8, 10, 0}},
  {name = "D", notes = {2, 4, 6, 7, 9, 11, 1}},
  {name = "D#/Eb", notes = {3, 5, 7, 8, 10, 0, 2}},
  {name = "E", notes = {4, 6, 8, 9, 11, 1, 3}},
  {name = "F", notes = {5, 7, 9, 10, 0, 2, 4}},
  {name = "F#/Gb", notes = {6, 8, 10, 11, 1, 3, 5}},
  {name = "G", notes = {7, 9, 11, 0, 2, 4, 6}},
  {name = "G#/Ab", notes = {8, 10, 0, 1, 3, 5, 7}},
  {name = "A", notes = {9, 11, 1, 2, 4, 6, 8}},
  {name = "A#/Bb", notes = {10, 0, 2, 3, 5, 7, 9}},
  {name = "B", notes = {11, 1, 3, 4, 6, 8, 10}},
}

local scale_types = {
  ["Major"] = {0, 2, 4, 5, 7, 9, 11},
  ["Natural Minor"] = {0, 2, 3, 5, 7, 8, 10},
  ["Harmonic Minor"] = {0, 2, 3, 5, 7, 8, 11},
  ["Melodic Minor"] = {0, 2, 3, 5, 7, 9, 11},
  ["Pentatonic"] = {0, 2, 4, 7, 9, 0, 2},
  ["Ionian"] = {0, 2, 4, 5, 7, 9, 11},
  ["Aeolian"] = {0, 2, 3, 5, 7, 8, 10},
  ["Dorian"] = {0, 2, 3, 5, 7, 9, 10},
  ["Mixolydian"] = {0, 2, 4, 5, 7, 9, 10},
  ["Phrygian"] = {0, 1, 3, 5, 7, 8, 10},
  ["Lydian"] = {0, 2, 4, 6, 7, 9, 11},
  ["Locrian"] = {0, 1, 3, 5, 6, 8, 10},
  ["Double Harmonic Major"] = {0, 1, 4, 5, 7, 8, 11},
  ["Neapolitan Major"] = {0, 1, 3, 5, 7, 9, 11},
  ["Neapolitan Minor"] = {0, 1, 3, 5, 7, 8, 11},
  ["Hungarian Minor"] = {0, 2, 3, 6, 7, 8, 11},
}

-- Chord Progression Library
local chord_progressions = {
  major = {
    ["Pop 1 (I-V-vi-IV)"] = {1, 5, 6, 4},
    ["Pop 2 (I-vi-IV-V)"] = {1, 6, 4, 5},
    ["Jazz (ii-V-I)"] = {2, 5, 1, 1},
    ["50s (I-vi-ii-V)"] = {1, 6, 2, 5},
    ["Canon (I-V-vi-iii-IV-I-IV-V)"] = {1, 5, 6, 3, 4, 1, 4, 5},
    ["Rock Anthem (I-IV-V)"] = {1, 4, 5, 5},
    ["Sensitive Pop (vi-IV-I-V)"] = {6, 4, 1, 5},
    ["Modern Pop (I-V-vi-iii)"] = {1, 5, 6, 3},
    ["Ascending (IV-V-vi)"] = {4, 5, 6, 6}
  },
  minor = {
    ["Standard (i-VI-III-VII)"] = {1, 6, 3, 7},
    ["Pop (i-iv-v-i)"] = {1, 4, 5, 1},
    ["Jazz (ii°-v-i)"] = {2, 5, 1, 1},
    ["Andalusian Cadence (i-VII-VI-V)"] = {1, 7, 6, 5},
    ["Rock Ballad (i-VI-iv-v)"] = {1, 6, 4, 5},
    ["Cinematic (i-iv-VII-III)"] = {1, 4, 7, 3},
    ["Dark Pop (i-VII-VI-iv)"] = {1, 7, 6, 4},
    ["Classic Minor (i-iv-v-VI)"] = {1, 4, 5, 6}
  }
}
local progression_options_major = {"Random"}
for name, _ in pairs(chord_progressions.major) do table.insert(progression_options_major, name) end
local progression_options_minor = {"Random"}
for name, _ in pairs(chord_progressions.minor) do table.insert(progression_options_minor, name) end

local selected_progression = 0

local transpose_values = {-24, -12, 0, 12, 24}
local transpose_labels = {"-2", "-1", "0", "+1", "+2"}
local selected_transpose_index = 2 -- initial index for "No Transposition"

local voicing_options = {"None", "Drop 2", "Drop 3", "Drop 4", "Drop 2+4"}
local selected_voicing = 0

local spread = 0 -- 0: Tight, 1: Medium, 2: Open

-- Arpeggiator/Strummer Variables
local arp_strum_options = {"None", "Arp Up", "Arp Down", "Arp Up/Down", "Arp Random", "Strum Down", "Strum Up", "Strum D-U-D-U", "Strum D-D-U"}
local selected_arp_strum_pattern = 0
local arp_rate = 2 -- Default to 1/16th note (index for rates table)
local arp_rate_options = {"1/4", "1/8", "1/16", "1/32", "Random"}
local arp_rate_values = {1, 0.5, 0.25, 0.125}
local strum_delay_ppq = 20 -- in PPQ
local strum_groove = 75 -- Velocity curve for up-strums (as a percentage)

-- Melody Generation Variables
local melody_density = 4 -- 1 (sparse) to 10 (dense)
local melody_octave_min = 4
local melody_octave_max = 5
local MELODY_CHANNEL = 15 -- MIDI channel 16 (0-indexed). Used for robustly identifying and deleting melody notes.

-- Bassline Generation Variables
local bass_pattern_options = {"None", "Root Notes", "Root + Fifth", "Simple Walk", "Arpeggio Up", "Pop Rhythm", "Octaves", "Classic Rock"}
local selected_bass_pattern = 1 -- Default to "Root Notes"

-- Humanize Variables
local humanize_strength_timing = 5
local humanize_strength_velocity = 8

-- Helper function to apply spread to a chord
local function applySpread(chord, spread_amount)
  table.sort(chord) -- Ensure notes are sorted by pitch
  if #chord < 3 or spread_amount == 0 then
    return chord
  end

  if spread_amount >= 1 and #chord >= 3 then
    -- Move the second highest note up an octave
    chord[#chord-1] = chord[#chord-1] + 12
  end
  if spread_amount >= 2 and #chord >= 4 then
    -- Move the third highest note up an octave as well
    chord[#chord-2] = chord[#chord-2] + 12
  end
  
  table.sort(chord)
  return chord
end

-- Helper function to apply drop voicings
local function applyDropVoicing(chord, voicing_type)
  table.sort(chord)
  if #chord < 4 or voicing_type == "None" then
    return chord -- Drop voicings typically require at least 4 notes
  end

  if voicing_type == "Drop 2" then
    -- Take the second note from the top and move it down an octave
    local note_to_move = table.remove(chord, #chord - 1)
    table.insert(chord, 1, note_to_move - 12)
  elseif voicing_type == "Drop 3" then
    -- Take the third note from the top and move it down an octave
    local note_to_move = table.remove(chord, #chord - 2)
    table.insert(chord, 1, note_to_move - 12)
  elseif voicing_type == "Drop 4" then
    -- Take the fourth note from the top (the root in a 4-note root position chord) and move it down
    if #chord >= 4 then
      local note_to_move = table.remove(chord, #chord - 3)
      table.insert(chord, 1, note_to_move - 12)
    end
  elseif voicing_type == "Drop 2+4" then
    -- Take the second and fourth notes from the top and move them down an octave
    if #chord >= 4 then
      local note_2 = table.remove(chord, #chord - 1) -- Second from top
      local note_4 = table.remove(chord, #chord - 2) -- Was fourth, now third from top
      table.insert(chord, 1, note_2 - 12)
      table.insert(chord, 1, note_4 - 12)
    end
  end
  
  table.sort(chord)
  return chord
end


local function selectRandom(list)
  return list[math.random(#list)]
end

local function tableContains(table, element)
  for _, value in pairs(table) do
    if value == element then
      return true
    end
  end
  return false
end

local function adjustChord(chord, scale_notes)
  local n = #chord
  table.sort(chord)

  for i = 2, n do
    while chord[i] - chord[i-1] > 12 do
      chord[i] = chord[i] - 12
    end
    if math.abs(chord[i] - chord[i-1]) <= 1 then
      if i < n then
        chord[i] = chord[i] + 12
      else
        chord[i-1] = chord[i-1] - 12
      end
    end
  end

  if scale_notes then
    for i = 1, #chord do
      local note_in_scale = false
      for _, sn in ipairs(scale_notes) do
        if chord[i] % 12 == sn then
          note_in_scale = true
          break
        end
      end
      if not note_in_scale then
        chord[i] = (chord[i] + 1) % 12
      end
    end
  end

  return chord
end

function table.indexOf(t, value)
  for i, v in ipairs(t) do
    if v == value then return i end -- Return 1-based index
  end
  return nil
end

local function getChord(scale, degree, type, complexity)
    if not scale or not degree or degree > #scale then return nil end
    local root = scale[degree] -- FIX: Degree is 1-based, and so is the scale table
    local chord = {root}

    -- Step 1: Build the basic triad quality
    if type == "major" or type == "dominant" then
        table.insert(chord, (root + 4) % 12) -- Major third
        table.insert(chord, (root + 7) % 12) -- Perfect fifth
    elseif type == "minor" then
        table.insert(chord, (root + 3) % 12) -- Minor third
        table.insert(chord, (root + 7) % 12) -- Perfect fifth
    elseif type == "diminished" then
        table.insert(chord, (root + 3) % 12) -- Minor third
        table.insert(chord, (root + 6) % 12) -- Diminished fifth
    elseif type == "sus2" then
        table.insert(chord, (root + 2) % 12) -- Major second
        table.insert(chord, (root + 7) % 12) -- Perfect fifth
    elseif type == "sus4" then
        table.insert(chord, (root + 5) % 12) -- Perfect fourth
        table.insert(chord, (root + 7) % 12) -- Perfect fifth
    end

    -- Step 2: Add extensions based on complexity
    if complexity >= 1 then -- 7ths
        if type == "dominant" then
            table.insert(chord, (root + 10) % 12) -- Minor seventh
        elseif type == "major" then
            table.insert(chord, (root + 11) % 12) -- Major seventh
        elseif type == "minor" then
            table.insert(chord, (root + 10) % 12) -- Minor seventh
        elseif type == "diminished" then
             table.insert(chord, (root + 10) % 12) -- Minor seventh for m7b5
        end
    end

    if complexity >= 2 then -- 9ths
        table.insert(chord, (root + 14) % 12) -- Major 9th
    end

    if complexity >= 3 then -- 11ths
        if type == "major" or type == "dominant" then
            table.insert(chord, (root + 18) % 12) -- Sharp 11th
        else
            table.insert(chord, (root + 17) % 12) -- Natural 11th
        end
    end
    
    if complexity >= 4 then -- 13ths
        if type ~= "diminished" then
            table.insert(chord, (root + 21) % 12) -- Major 13th
        end
    end

    if complexity >= 5 then -- Alterations
        if type == "dominant" then
            local fifth_index = table.indexOf(chord, (root + 7) % 12)
            local ninth_index = table.indexOf(chord, (root + 2) % 12) -- 14 % 12 = 2

            local alteration_type = selectRandom({1, 2, 3})
            if alteration_type == 1 and fifth_index then -- Altered 5th
                chord[fifth_index] = (root + selectRandom({6, 8})) % 12 -- b5 or #5
            elseif alteration_type == 2 and ninth_index then -- Altered 9th
                chord[ninth_index] = (root + selectRandom({1, 3})) % 12 -- b9 or #9
            else -- Add a random altered tone if others fail
                table.insert(chord, (root + selectRandom({1, 3, 6, 8})) % 12)
            end
        else
             local dissonant_notes = {1, 6, 8}
             table.insert(chord, (root + selectRandom(dissonant_notes)) % 12)
        end
    end
    
    while #chord > 7 do
        table.remove(chord, math.random(2, #chord)) -- Remove a random note other than the root
    end
    
    -- At highest complexity, allow notes outside the scale before snapping
    local snap_to_scale = complexity < 5
    local adjusted_chord = adjustChord(chord, snap_to_scale and scale or nil)

    return adjusted_chord
end

local function invertChord(chord, inversion)
  for i = 1, inversion do
    local note = table.remove(chord, 1)
    table.insert(chord, note + 12)
  end
  return chord
end

local function getChordInversion(chord, inversion)
  local new_chord = {table.unpack(chord)}
  return invertChord(new_chord, inversion)
end

local function deleteExistingNotes(take)
  local _, note_count, _, _ = reaper.MIDI_CountEvts(take)
  for i = note_count - 1, 0, -1 do
    reaper.MIDI_DeleteNote(take, i)
  end
end

-- New function to delete only chord notes, preserving bass and melody.
local function deleteExistingChords(take)
    local notes_to_delete = {}
    local note_idx = 0
    local pitch_threshold = 60 -- Heuristic for bass notes: C4

    while true do
        local ret, _, _, _, _, chan, pitch, _ = reaper.MIDI_GetNote(take, note_idx)
        if not ret then break end
        
        -- A note is a chord note if it's NOT a melody note (by channel)
        -- AND it's at or above the bass pitch threshold.
        if chan ~= MELODY_CHANNEL and pitch >= pitch_threshold then
            table.insert(notes_to_delete, note_idx)
        end
        note_idx = note_idx + 1
    end
    
    if #notes_to_delete > 0 then
        -- Delete from the end to avoid index shifting issues
        table.sort(notes_to_delete, function(a, b) return a > b end) 
        for _, index in ipairs(notes_to_delete) do
            reaper.MIDI_DeleteNote(take, index)
        end
    end
end


local function findBassNoteFromChord(chord)
  local bass_note = chord[1]
  local intervals = {3, 4} -- minor third and major third

  for i = 1, #chord do
    for j = i + 1, #chord do
      if tableContains(intervals, math.abs(chord[i] - chord[j]) % 12) then
        return chord[i]
      end
    end
  end

  return bass_note
end

-- Refactored to only insert chord tones, no bass.
local function insertChord(take, position, chord, length)
  for i, note in ipairs(chord) do
    reaper.MIDI_InsertNote(take, false, false, position, position + length, 0, note + 60, math.random(80, 110), true)
  end
end

-- Generates chords based on a list of degrees (either random or from a library)
local function createChordProgression(scale_notes, degrees, is_major, complexity, root_note_pitch)
  local chords = {}
  local chord_types_major = {"major", "minor", "minor", "major", "major", "minor", "diminished"}
  local chord_types_minor = {"minor", "diminished", "major", "minor", "minor", "major", "major"}
  
  for _, degree in ipairs(degrees) do
    local chord_type
    local use_borrowed = false

    -- Modal Interchange Logic: At complexity 4+, 25% chance to borrow a chord
    if complexity >= 4 and degree ~= 1 and math.random() < 0.25 then
      use_borrowed = true
    end

    local current_scale = scale_notes
    local current_chord_types = is_major and chord_types_major or chord_types_minor

    if use_borrowed then
      -- Use the parallel scale's notes and chord types
      local parallel_scale_type = is_major and "Natural Minor" or "Major"
      local parallel_scale_intervals = scale_types[parallel_scale_type]
      current_scale = {}
      for _, interval in ipairs(parallel_scale_intervals) do
        table.insert(current_scale, (root_note_pitch + interval) % 12)
      end
      current_chord_types = is_major and chord_types_minor or chord_types_major
    end
    
    if not current_chord_types[degree] then
      -- Fallback if degree is out of bounds (e.g., for pentatonic)
      chord_type = is_major and "major" or "minor"
    else
      chord_type = current_chord_types[degree]
    end

    -- Make the V chord in major keys a dominant 7th
    if is_major and degree == 5 then
        chord_type = "dominant"
    end

    local chord = getChord(current_scale, degree, chord_type, complexity)
    if not chord or #chord < 3 then
      chord = getChord(scale_notes, degree, is_major and "major" or "minor", 0) -- Fallback to simple triad
    end
    
    if chord then
      chord = adjustChord(chord, not use_borrowed and scale_notes or nil)
      table.insert(chords, {degree = degree, chord = chord, is_major = (chord_type == "major")})
    end
  end

  return chords
end

local function getClosestInversion(prev_chord, chord)
  local min_distance = math.huge
  local best_inversion = chord

  for i = 0, 2 do
    local inverted_chord = getChordInversion(chord, i)
    local distance = 0
    for j = 1, math.min(#prev_chord, #inverted_chord) do
      distance = distance + math.abs(inverted_chord[j] - prev_chord[j])
    end
    if distance < min_distance then
      min_distance = distance
      best_inversion = inverted_chord
    end
  end

  return best_inversion
end

-- Refactored to not handle bass notes directly.
local function createMIDIChords(take, chords, item_start_ppq, item_length_ppq)
  if #chords == 0 then return end
  local num_chords = #chords
  local chord_length = item_length_ppq / num_chords
  local position = item_start_ppq
  local prev_chord = chords[1].chord

  for _, chord_data in ipairs(chords) do
    local current_chord = chord_data.chord
    
    -- Apply voicing controls before finding the best inversion
    local voiced_chord = applyDropVoicing({table.unpack(current_chord)}, voicing_options[selected_voicing + 1])
    voiced_chord = applySpread(voiced_chord, spread)

    local best_inversion = getClosestInversion(prev_chord, voiced_chord)
    best_inversion = adjustChord(best_inversion)
    
    insertChord(take, position, best_inversion, chord_length)
    prev_chord = best_inversion
    position = position + chord_length
  end
end

-- Smart Bassline Generation
local function deleteExistingBassNotes(take)
    local notes_to_delete = {}
    local note_idx = 0
    -- Heuristic: Any note below C3 (MIDI pitch 60) is considered a bass note.
    local pitch_threshold = 60
    
    while true do
        local ret, _, _, _, _, _, pitch, _ = reaper.MIDI_GetNote(take, note_idx)
        if not ret then break end
        
        if pitch < pitch_threshold then
            table.insert(notes_to_delete, note_idx)
        end
        note_idx = note_idx + 1
    end
    
    if #notes_to_delete > 0 then
        table.sort(notes_to_delete, function(a, b) return a > b end)
        for _, index in ipairs(notes_to_delete) do
            reaper.MIDI_DeleteNote(take, index)
        end
    end
end

local function generateAndInsertBassline(take, chords, item_start_ppq, item_length_ppq, pattern)
    if pattern == "None" or #chords == 0 then return end

    local num_chords = #chords
    local chord_length = item_length_ppq / num_chords
    local bass_octave = 36 -- MIDI Pitch for C1

    for i = 1, num_chords do
        local position = item_start_ppq + (i - 1) * chord_length
        local chord_data = chords[i]
        local root_note_pc = chord_data.chord[1] % 12 -- Pitch class of the root
        local root_note = root_note_pc + bass_octave

        if pattern == "Root Notes" then
            reaper.MIDI_InsertNote(take, false, false, position, position + chord_length, 0, root_note, 100, true)
        
        elseif pattern == "Root + Fifth" then
            local half_length = chord_length / 2
            local fifth_note = root_note + 7
            reaper.MIDI_InsertNote(take, false, false, position, position + half_length, 0, root_note, 100, true)
            reaper.MIDI_InsertNote(take, false, false, position + half_length, position + chord_length, 0, fifth_note, 100, true)
        
        elseif pattern == "Simple Walk" then
            local quarter_length = chord_length / 4
            local next_root_pc = (i < num_chords) and chords[i+1].chord[1] % 12 or root_note_pc
            
            local third_note = root_note + (chord_data.is_major and 4 or 3)
            local fifth_note = root_note + 7
            
            -- Beat 1: Root
            reaper.MIDI_InsertNote(take, false, false, position, position + quarter_length, 0, root_note, 100, true)
            -- Beat 2: Third
            reaper.MIDI_InsertNote(take, false, false, position + quarter_length, position + 2*quarter_length, 0, third_note, 95, true)
            -- Beat 3: Fifth
            reaper.MIDI_InsertNote(take, false, false, position + 2*quarter_length, position + 3*quarter_length, 0, fifth_note, 95, true)
            -- Beat 4: Passing Tone to next chord's root
            local passing_note
            if (next_root_pc - root_note_pc) % 12 > 6 then -- Descending motion is shorter
                passing_note = root_note + ((next_root_pc - root_note_pc) % 12) - 12 + 1
            else -- Ascending motion is shorter
                passing_note = root_note + ((next_root_pc - root_note_pc) % 12) -1
            end
            reaper.MIDI_InsertNote(take, false, false, position + 3*quarter_length, position + chord_length, 0, passing_note, 90, true)
        
        elseif pattern == "Arpeggio Up" then
            local third_length = chord_length / 3
            local third_note = root_note + (chord_data.is_major and 4 or 3)
            local fifth_note = root_note + 7

            reaper.MIDI_InsertNote(take, false, false, position, position + third_length, 0, root_note, 100, true)
            reaper.MIDI_InsertNote(take, false, false, position + third_length, position + 2 * third_length, 0, third_note, 95, true)
            reaper.MIDI_InsertNote(take, false, false, position + 2 * third_length, position + chord_length, 0, fifth_note, 95, true)

        elseif pattern == "Pop Rhythm" then
            local quarter_length = chord_length / 4
            local eighth_length = chord_length / 8
            
            -- Beat 1 (Quarter note)
            reaper.MIDI_InsertNote(take, false, false, position, position + quarter_length, 0, root_note, 100, true)
            -- Beat 3 (Eighth note)
            reaper.MIDI_InsertNote(take, false, false, position + 2 * quarter_length, position + 2 * quarter_length + eighth_length, 0, root_note, 95, true)
            -- "And" of Beat 3 (Eighth note)
            reaper.MIDI_InsertNote(take, false, false, position + 2 * quarter_length + eighth_length, position + 3 * quarter_length, 0, root_note, 95, true)
        
        elseif pattern == "Octaves" then
            local half_length = chord_length / 2
            local octave_note = root_note + 12
            reaper.MIDI_InsertNote(take, false, false, position, position + half_length, 0, root_note, 100, true)
            reaper.MIDI_InsertNote(take, false, false, position + half_length, position + chord_length, 0, octave_note, 95, true)
        
        elseif pattern == "Classic Rock" then
            local quarter_len = chord_length / 4
            local eighth_len = chord_length / 8
            -- Beat 1
            reaper.MIDI_InsertNote(take, false, false, position, position + quarter_len, 0, root_note, 100, true)
            -- "And" of beat 2
            reaper.MIDI_InsertNote(take, false, false, position + quarter_len + eighth_len, position + 2*quarter_len, 0, root_note, 95, true)
            -- Beat 3
            reaper.MIDI_InsertNote(take, false, false, position + 2*quarter_len, position + 3*quarter_len, 0, root_note, 95, true)
        end
    end
end

local function transposeMIDI(take, transpose)
  local _, note_count, _, _ = reaper.MIDI_CountEvts(take)
  for i = 0, note_count - 1 do
    local _, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    reaper.MIDI_SetNote(take, i, selected, muted, startppqpos, endppqpos, chan, pitch + transpose, vel, false)
  end
end

-- Arpeggiator and Strummer Function
local function applyArpeggioOrStrum(take, pattern, rate_value, strum_delay, velocity_curve)
  reaper.MIDI_DisableSort(take)

  -- 1. Collect all notes and identify selected notes.
  local all_notes = {}
  local selected_notes = {}
  local has_selection = false
  
  local note_count = reaper.MIDI_CountEvts(take)
  for i = 0, note_count - 1 do
    local retval, selected, muted, start, endp, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    if retval then
      local note_info = {
        index = i, selected = selected, muted = muted, startppq = start, endppq = endp, chan = chan, pitch = pitch, vel = vel
      }
      table.insert(all_notes, note_info)
      if selected then
        table.insert(selected_notes, note_info)
        has_selection = true
      end
    end
  end

  -- 2. Determine which set of notes to process.
  local notes_to_process
  if has_selection then
    notes_to_process = selected_notes
  else
    notes_to_process = all_notes
  end
  
  if #notes_to_process == 0 then
    reaper.MIDI_Sort(take)
    reaper.UpdateArrange()
    return
  end
  
  -- 3. Group the notes to be processed into chords and identify their indices for deletion.
  local chords = {}
  local notes_to_delete = {}

  for _, note in ipairs(notes_to_process) do
    table.insert(notes_to_delete, note.index)
    if not chords[note.startppq] then
      chords[note.startppq] = {}
    end
    table.insert(chords[note.startppq], note)
  end

  -- 4. Delete ONLY the processed notes.
  table.sort(notes_to_delete, function(a, b) return a > b end)
  for _, index in ipairs(notes_to_delete) do
    reaper.MIDI_DeleteNote(take, index)
  end
  
  local ppq_per_beat = reaper.MIDI_GetPPQPosFromProjQN(take, 1)

  -- 5. Process each chord.
  for startppq, chord_notes in pairs(chords) do
    local original_duration = chord_notes[1].endppq - chord_notes[1].startppq
    
    local notes_in_chord = {}
    for _, n in ipairs(chord_notes) do
      table.insert(notes_in_chord, {pitch = n.pitch, vel = n.vel})
    end
    table.sort(notes_in_chord, function(a, b) return a.pitch < b.pitch end)

    if string.find(pattern, "Strum") then
      -- Strumming patterns
      local function performStrumHit(pos, direction, duration)
        local notes_to_strum = {}
        if direction == "D" then -- Down-strum
          for i = 1, #notes_in_chord do table.insert(notes_to_strum, notes_in_chord[i]) end
        else -- Up-strum
          for i = #notes_in_chord, 1, -1 do table.insert(notes_to_strum, notes_in_chord[i]) end
        end

        for i, note in ipairs(notes_to_strum) do
          local strum_offset = (i - 1) * strum_delay
          local final_vel = note.vel
          if direction == "U" then
            final_vel = math.max(1, math.floor(note.vel * (velocity_curve / 100)))
          end
          reaper.MIDI_InsertNote(take, false, false, pos + strum_offset, pos + strum_offset + duration, 0, note.pitch, final_vel, true)
        end
      end

      if pattern == "Strum Down" then
        performStrumHit(startppq, "D", original_duration)
      elseif pattern == "Strum Up" then
        performStrumHit(startppq, "U", original_duration)
      else
        -- Rhythmic Strumming Patterns
        local rhythms = {
          ["Strum D-U-D-U"] = {pattern = {"D", "U", "D", "U"}, rate = 0.5}, -- 8th notes
          ["Strum D-D-U"]   = {pattern = {"D", "D", "U"}, rate = 0.5}  -- 3x 8th notes
        }
        local rhythm_info = rhythms[pattern]
        
        if rhythm_info then
          local step_size = ppq_per_beat * rhythm_info.rate
          local note_len = step_size - (ppq_per_beat * 0.05) -- Create a small gap between strums
          local current_pos = startppq
          local step = 0
          
          while current_pos < startppq + original_duration do
            local direction = rhythm_info.pattern[(step % #rhythm_info.pattern) + 1]
            if not direction then break end
            
            performStrumHit(current_pos, direction, note_len)
            
            current_pos = current_pos + step_size
            step = step + 1
          end
        end
      end
    else -- Arpeggiator patterns
      local current_rate_value = rate_value
      if current_rate_value == -1 then
         local random_index = math.random(#arp_rate_values)
         current_rate_value = arp_rate_values[random_index]
      end
      local arp_note_len = ppq_per_beat * current_rate_value
      local arp_sequence = {}
      
      if pattern == "Arp Up" then
        arp_sequence = notes_in_chord
      elseif pattern == "Arp Down" then
        table.sort(notes_in_chord, function(a, b) return a.pitch > b.pitch end)
        arp_sequence = notes_in_chord
      elseif pattern == "Arp Up/Down" then
        arp_sequence = notes_in_chord
        for i = #notes_in_chord - 1, 2, -1 do
          table.insert(arp_sequence, notes_in_chord[i])
        end
      elseif pattern == "Arp Random" then
        for i = #notes_in_chord, 1, -1 do
          local j = math.random(i)
          notes_in_chord[i], notes_in_chord[j] = notes_in_chord[j], notes_in_chord[i]
        end
        arp_sequence = notes_in_chord
      end
      
      local current_pos = startppq
      local step = 0
      while current_pos < startppq + original_duration do
        if #arp_sequence == 0 then break end
        local note_to_play = arp_sequence[(step % #arp_sequence) + 1]
        if note_to_play then
          reaper.MIDI_InsertNote(take, false, false, current_pos, current_pos + arp_note_len, 0, note_to_play.pitch, note_to_play.vel, true)
        end
        current_pos = current_pos + arp_note_len
        step = step + 1
      end
    end
  end

  reaper.MIDI_Sort(take)
  reaper.UpdateArrange()
end

--[[--
REFACTOR (v2.6): The heuristic-based melody deletion was still unstable.
The function is now refactored to use a dedicated MIDI channel for melody notes.
This provides a 100% reliable way to identify and remove only the generated melody,
preserving the original performance completely.
--]]--
local function deleteExistingMelody(take)
    local notes_to_delete = {}
    local note_idx = 0
    
    while true do
        local ret, _, _, _, _, chan, _, _ = reaper.MIDI_GetNote(take, note_idx)
        if not ret then break end
        
        if chan == MELODY_CHANNEL then
            table.insert(notes_to_delete, note_idx)
        end
        note_idx = note_idx + 1
    end
    
    if #notes_to_delete > 0 then
        table.sort(notes_to_delete, function(a, b) return a > b end) -- Delete from the end
        for _, index in ipairs(notes_to_delete) do
            reaper.MIDI_DeleteNote(take, index)
        end
    end
end

local function analyzeChordsForMelody(take)
    -- Step 1: Group notes by start time to identify chords
    local notes_by_start_time = {}
    local all_notes = {}
    local note_idx = 0
    while true do
        local ret, sel, mut, startppq, endppq, chan, pitch, vel = reaper.MIDI_GetNote(take, note_idx)
        if not ret then break end
        
        if not notes_by_start_time[startppq] then
            notes_by_start_time[startppq] = 0
        end
        notes_by_start_time[startppq] = notes_by_start_time[startppq] + 1
        
        table.insert(all_notes, {
            index = note_idx,
            startppq = startppq,
            endppq = endppq,
            pitch = pitch
        })
        note_idx = note_idx + 1
    end

    -- Step 2: Build the scale from chord notes only
    local chord_tones = {}
    local ppq_per_beat = reaper.MIDI_GetPPQPosFromProjQN(take, 1)
    local length_threshold = ppq_per_beat -- quarter note

    for _, note in ipairs(all_notes) do
        local note_length = note.endppq - note.startppq
        local notes_at_same_time = notes_by_start_time[note.startppq]
        
        -- A note is part of a chord if it's long, OR if it's played with other notes
        if note_length >= (length_threshold - 1) or notes_at_same_time > 1 then
            chord_tones[note.pitch % 12] = true
        end
    end

    local unique_notes = {}
    for note_pc in pairs(chord_tones) do
        table.insert(unique_notes, note_pc)
    end
    
    return unique_notes
end

local function generateMelody(take, scale, density, oct_min, oct_max, item_start_ppq, item_length_ppq)
    if #scale == 0 then return {} end

    local melody = {}
    local ppq_per_beat = reaper.MIDI_GetPPQPosFromProjQN(take, 1)
    
    -- Density determines the number of steps per beat. 
    -- 1 = quarter notes, 2 = 8th notes, 4 = 16th notes.
    local step_size = (ppq_per_beat * 4) / (density * 2) 
    local note_length = step_size * 0.9 -- Make notes slightly shorter than the step to avoid overlap
    
    local current_pos = item_start_ppq
    while current_pos < item_start_ppq + item_length_ppq do
        -- Random chance to create a rest instead of a note
        if math.random() < 0.9 then -- 90% chance to place a note
            local base_note = selectRandom(scale)
            local octave = math.random(oct_min, oct_max)
            local final_pitch = base_note + (octave * 12)
            
            table.insert(melody, {pos = current_pos, length = note_length, note = final_pitch})
        end
        current_pos = current_pos + step_size
    end

    return melody
end

local function insertMelody(take, melody)
    for _, note_data in ipairs(melody) do
        reaper.MIDI_InsertNote(take, false, false, note_data.pos, note_data.pos + note_data.length, MELODY_CHANNEL, note_data.note, math.random(70, 100), true)
    end
end

-- Humanize Function
local function humanizeNotes(take, timing_strength, velocity_strength)
    reaper.MIDI_DisableSort(take)
    local note_count = reaper.MIDI_CountEvts(take)
    for i = 0, note_count - 1 do
        local ret, selected, muted, startppq, endppq, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
        if ret then
            -- Humanize Timing
            local timing_offset = math.random(-timing_strength, timing_strength)
            local new_startppq = startppq + timing_offset
            local new_endppq = endppq + timing_offset
            if new_startppq < 0 then new_startppq = 0 end
            if new_endppq < new_startppq then new_endppq = new_startppq + (endppq - startppq) end

            -- Humanize Velocity
            local velocity_offset = math.random(-velocity_strength, velocity_strength)
            local new_vel = vel + velocity_offset
            if new_vel < 1 then new_vel = 1 end
            if new_vel > 127 then new_vel = 127 end

            reaper.MIDI_SetNote(take, i, selected, muted, new_startppq, new_endppq, chan, pitch, new_vel, false)
        end
    end
    reaper.MIDI_Sort(take)
    reaper.UpdateArrange()
end


-- Change Rhythm Functions
local scriptName = "Change Chord Rhythms"
local initialStateKey = "initial_note_state"

-- Serialize table to a string
local function tableToString(tbl)
  local result = {}
  for _, note in ipairs(tbl) do
    table.insert(result, string.format("%d,%d,%d,%d,%d,%d,%d,%d",
        note.startppqpos, note.endppqpos, note.chan, note.pitch, note.vel, note.selected and 1 or 0, note.muted and 1 or 0, note.index))
  end
  return table.concat(result, ";")
end

-- Deserialize string to a table
local function stringToTable(str)
  local result = {}
  for noteStr in string.gmatch(str, "([^;]+)") do
    local startppqpos, endppqpos, chan, pitch, vel, selected, muted, index = string.match(noteStr, "(%d+),(%d+),(%d+),(%d+),(%d+),(%d+),(%d+),(%d+)")
    table.insert(result, {
      startppqpos = tonumber(startppqpos),
      endppqpos = tonumber(endppqpos),
      chan = tonumber(chan),
      pitch = tonumber(pitch),
      vel = tonumber(vel),
      selected = tonumber(selected) == 1,
      muted = tonumber(muted) == 1,
      index = tonumber(index)
    })
  end
  return result
end

local function storeInitialState(take)
  if take then
    local noteData = {}

    for i = 0, reaper.MIDI_CountEvts(take, nil, nil, nil) - 1 do
      local _, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
      table.insert(noteData, {startppqpos = startppqpos, endppqpos = endppqpos, chan = chan, pitch = pitch, vel = vel, selected = selected, muted = muted, index = i})
    end

    local noteDataString = tableToString(noteData)
    reaper.SetProjExtState(0, scriptName, initialStateKey, noteDataString)
  end
end

local function getInitialState()
  local _, noteDataString = reaper.GetProjExtState(0, scriptName, initialStateKey)
  if noteDataString and noteDataString ~= "" then
    return stringToTable(noteDataString)
  end
  return nil
end

local function detectPitchChange(initialNotes, currentNotes)
  if #initialNotes ~= #currentNotes then
    return true
  end

  for i, note in ipairs(initialNotes) do
    if note.pitch ~= currentNotes[i].pitch then
      return true
    end
  end

  return false
end

local function changeRhythm(take, initialNotes)
  reaper.MIDI_DisableSort(take)
  
  local currentNotes = {}
  for i = 0, reaper.MIDI_CountEvts(take, nil, nil, nil) - 1 do
    local _, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    table.insert(currentNotes, {startppqpos = startppqpos, endppqpos = endppqpos, chan = chan, pitch = pitch, vel = vel, selected = selected, muted = muted, index = i})
  end

  if #currentNotes ~= #initialNotes then
    return
  end

  local function findChords(notes)
    local chords = {}
    local activeNotes = {}

    for _, note in ipairs(notes) do
      if not activeNotes[note.startppqpos] then activeNotes[note.startppqpos] = {} end
      table.insert(activeNotes[note.startppqpos], note)
    end

    for startppqpos, chordNotes in pairs(activeNotes) do
      table.insert(chords, {startppqpos = startppqpos, notes = chordNotes})
    end

    table.sort(chords, function(a, b) return a.startppqpos < b.startppqpos end)
    return chords
  end

  local function applyRhythmChange(chords)
    local factors = {0.5, 1, 1.5, 2}
    local newDurations = {}
    local totalChange = 0

    for i, chord in ipairs(chords) do
      if chord.notes and chord.notes[1] then
        local originalDuration = chord.notes[1].endppqpos - chord.notes[1].startppqpos
        local factor = factors[math.random(1, #factors)]
        newDurations[i] = {
          original = originalDuration,
          new = math.floor(originalDuration * factor),
          factor = factor
        }
        totalChange = totalChange + (newDurations[i].new - originalDuration)
      end
    end

    while totalChange ~= 0 do
      local index = math.random(1, #chords)
      if newDurations[index] then
        local currentFactor = newDurations[index].factor
        local currentFactorIndex = table.indexOf(factors, currentFactor)

        if totalChange > 0 and currentFactorIndex > 1 then
          newDurations[index].factor = factors[currentFactorIndex - 1]
        elseif totalChange < 0 and currentFactorIndex < #factors then
          newDurations[index].factor = factors[currentFactorIndex + 1]
        else
          goto continue
        end

        local newDuration = math.floor(newDurations[index].original * newDurations[index].factor)
        totalChange = totalChange + (newDuration - newDurations[index].new)
        newDurations[index].new = newDuration
      end
      ::continue::
    end

    if #chords > 0 and chords[1].startppqpos then
      local currentPos = chords[1].startppqpos
      for i, chord in ipairs(chords) do
        if newDurations[i] then
          local newDuration = newDurations[i].new
          for _, note in ipairs(chord.notes) do
            reaper.MIDI_SetNote(take, note.index, note.selected, note.muted, currentPos, currentPos + newDuration, note.chan, note.pitch, note.vel, false)
          end
          currentPos = currentPos + newDuration
        end
      end
    end
  end

  local chords = findChords(initialNotes)
  if #chords > 0 then
    applyRhythmChange(chords)
  end

  reaper.MIDI_Sort(take)
  reaper.UpdateArrange()
end

-- Add Note Functions
local function addNote(take)
  local notes = {}
  for i = 0, reaper.MIDI_CountEvts(take, nil, nil, nil) - 1 do
    local _, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    table.insert(notes, {startppqpos = startppqpos, endppqpos = endppqpos, chan = chan, pitch = pitch, vel = vel, selected = selected, muted = muted, index = i})
  end

  if #notes == 0 then
    reaper.ShowConsoleMsg("Error: No notes found. Cannot add a new note.\n")
    return
  end

  -- Improved Scale Detection
  local pitch_counts = {}
  for _, note in ipairs(notes) do
    pitch_counts[note.pitch % 12] = (pitch_counts[note.pitch % 12] or 0) + 1
  end

  local detected_scale = {}
  for pitch, count in pairs(pitch_counts) do
    if count > 0 then
      table.insert(detected_scale, pitch)
    end
  end
  table.sort(detected_scale)

  -- Find the best matching scale
  local best_match_scale = nil
  local best_match_count = 0
  for _, scale in ipairs(scales) do
    local match_count = 0
    for _, note in ipairs(detected_scale) do
      if tableContains(scale.notes, note) then
        match_count = match_count + 1
      end
    end
    if match_count > best_match_count then
      best_match_scale = scale
      best_match_count = match_count
    end
  end

  if not best_match_scale then
    reaper.ShowConsoleMsg("Error: Could not detect a suitable scale. Cannot add a new note.\n")
    return
  end

  -- Find the chords
  local chords = {}
  for _, note in ipairs(notes) do
    if not chords[note.startppqpos] then
      chords[note.startppqpos] = {}
    end
    table.insert(chords[note.startppqpos], note)
  end

  local valid_chords = {}
  for startppqpos, chord_notes in pairs(chords) do
    if #chord_notes >= 3 then
      table.insert(valid_chords, chord_notes)
    end
  end

  if #valid_chords == 0 then
    reaper.ShowConsoleMsg("Error: No chords found. Cannot add a new note.\n")
    return
  end

  -- Choose a random chord
  local chosen_chord = selectRandom(valid_chords)
  table.sort(chosen_chord, function(a, b) return a.pitch < b.pitch end)

  local min_pitch = chosen_chord[2].pitch
  local max_pitch = chosen_chord[#chosen_chord].pitch + 24  -- Maximum 2 octaves above the highest note of the chord

  -- Choose a suitable note within the range and detected scale
  local new_pitch
  repeat
    local random_scale_note = best_match_scale.notes[math.random(#best_match_scale.notes)]
    local octave = math.random(math.floor(min_pitch / 12), math.floor(max_pitch / 12))
    new_pitch = random_scale_note + (octave * 12)
  until new_pitch >= min_pitch and new_pitch <= max_pitch

  -- Find all start positions of existing notes
  local used_positions = {}
  for _, note in ipairs(notes) do
    used_positions[note.startppqpos] = true
  end

  -- Choose a suitable position for the new note
  local new_position
  local new_length
  local position_options = {}

  -- Create a finer set of potential positions
  local chord_start = chosen_chord[1].startppqpos
  local chord_end = chosen_chord[1].endppqpos
  for i = 0, 7 do
    table.insert(position_options, chord_start + i * (chord_end - chord_start) / 8)
  end

  local attempts = 0
  local max_attempts = 1000 -- Increase the number of attempts
  repeat
    new_position = position_options[math.random(#position_options)]
    attempts = attempts + 1
    if attempts > max_attempts then

      return
    end
  until not used_positions[new_position]

  new_length = (chord_end - chord_start) * selectRandom({1, 0.75, 0.5})  -- 1, 3/4, or 1/2 of the chord length

  -- Shorten other notes if necessary
  for _, note in ipairs(notes) do
    if note.pitch == new_pitch then
      if note.startppqpos < new_position and note.endppqpos > new_position then
        reaper.MIDI_SetNote(take, note.index, note.selected, note.muted, note.startppqpos, new_position, note.chan, note.pitch, note.vel, false)
      elseif note.startppqpos < new_position + new_length and note.endppqpos > new_position + new_length then
        reaper.MIDI_SetNote(take, note.index, note.selected, note.muted, new_position + new_length, note.endppqpos, note.chan, note.pitch, note.vel, false)
      end
    end
  end

  reaper.MIDI_InsertNote(take, false, false, new_position, new_position + new_length, 0, new_pitch, math.random(80, 110), true)
  reaper.MIDI_Sort(take)
  reaper.UpdateArrange()
end


-- Global Variables for the GUI
local ctx
local scale_types_options = {"Random", "Major", "Natural Minor", "Harmonic Minor", "Melodic Minor", "Pentatonic", "Ionian", "Aeolian", "Dorian", "Mixolydian", "Phrygian", "Lydian", "Locrian", "Double Harmonic Major", "Neapolitan Major", "Neapolitan Minor", "Hungarian Minor"}
local selected_scale_type = 0 -- Index starts at 0 for ImGui
local num_chords = 4
local complexity = 0
local transpose = 0 -- Initial value for transposition
local generate = false
local change_rhythm = false
local add_note = false
local delete_chords_trigger = false
local apply_arp = false -- Trigger for arpeggiator
local generate_melody_trigger = false -- Trigger for melody generation
local humanize_trigger = false -- Trigger for humanize function
local undo_melody_trigger = false
local undo_arp_trigger = false
local undo_humanize_trigger = false
local window_open = true
local root_note_options = {"Random", "C", "C#/Db", "D", "D#/Eb", "E", "F", "F#/Gb", "G", "G#/Ab", "A", "A#/Bb", "B"}
local selected_root_note = 0 -- 0 is "Random"
local generation_info = "" -- Variable to store feedback message
local current_progression_options = progression_options_major
local melody_undo_stack = {}
local arp_undo_stack = {}
local humanize_undo_stack = {}

local function captureUndoState(take)
    if not take then return nil end
    local notes = {}
    local note_idx = 0
    while true do
        local ret, selected, muted, startppq, endppq, chan, pitch, vel = reaper.MIDI_GetNote(take, note_idx)
        if not ret then break end
        table.insert(notes, {
            selected = selected, muted = muted, startppq = startppq, endppq = endppq,
            chan = chan, pitch = pitch, vel = vel
        })
        note_idx = note_idx + 1
    end
    return notes
end

local function getRandomScaleType()
  local valid_scale_types = {"Major", "Natural Minor"}
  return selectRandom(valid_scale_types)
end

-- Function to draw the GUI
local function drawGUI()
  reaper.ImGui_SetNextWindowSize(ctx, 420, 0)
  
  local window_flags = reaper.ImGui_WindowFlags_TopMost()

  local visible, open = reaper.ImGui_Begin(ctx, 'Reanspiration - by Hosi (orig. phaselab)', true, window_flags)
  if visible then
    
    if reaper.ImGui_BeginTabBar(ctx, "MainTabBar") then
      
      -- Tab 1: Generation
      if reaper.ImGui_BeginTabItem(ctx, "Generation") then
        local changed
        changed, selected_root_note = reaper.ImGui_Combo(ctx, "Root Note", selected_root_note, table.concat(root_note_options, "\0") .. "\0")
        
        local scale_type_changed
        scale_type_changed, selected_scale_type = reaper.ImGui_Combo(ctx, "Scale Type", selected_scale_type, table.concat(scale_types_options, "\0") .. "\0")
        
        local is_major_scale = string.find(scale_types_options[selected_scale_type + 1]:lower(), "major") or string.find(scale_types_options[selected_scale_type + 1]:lower(), "ionian") or string.find(scale_types_options[selected_scale_type + 1]:lower(), "lydian") or string.find(scale_types_options[selected_scale_type + 1]:lower(), "mixolydian")
        
        if is_major_scale then
          current_progression_options = progression_options_major
        else
          current_progression_options = progression_options_minor
        end

        if scale_type_changed then
          selected_progression = 0 -- Reset to random when scale type changes
        end

        changed, selected_progression = reaper.ImGui_Combo(ctx, "Progression", selected_progression, table.concat(current_progression_options, "\0") .. "\0")

        local progression_name = current_progression_options[selected_progression + 1]
        if progression_name == "Random" then
          reaper.ImGui_BeginDisabled(ctx, false)
          local num_chords_changed
          num_chords_changed, num_chords = reaper.ImGui_InputInt(ctx, "Number of Chords", num_chords, 1, 1)
          if num_chords_changed then
            num_chords = math.max(1, math.min(16, num_chords))
          end
          reaper.ImGui_EndDisabled(ctx)
        else
          local p_type = is_major_scale and "major" or "minor"
          if chord_progressions[p_type] and chord_progressions[p_type][progression_name] then
              local num = #chord_progressions[p_type][progression_name]
              reaper.ImGui_BeginDisabled(ctx, true)
              reaper.ImGui_InputInt(ctx, "Number of Chords", num, 1, 1)
              reaper.ImGui_EndDisabled(ctx)
          else
              -- Fallback for safety
              reaper.ImGui_BeginDisabled(ctx, true)
              reaper.ImGui_InputInt(ctx, "Number of Chords", 4, 1, 1)
              reaper.ImGui_EndDisabled(ctx)
          end
        end
        
        changed, complexity = reaper.ImGui_SliderInt(ctx, "Complexity", complexity, 0, 5)
        reaper.ImGui_SameLine(ctx); reaper.ImGui_Text(ctx, "(?)"); if reaper.ImGui_IsItemHovered(ctx) then reaper.ImGui_SetTooltip(ctx, "0: Triads\n1: 7ths\n2: 9ths\n3: 11ths\n4: 13ths\n5: Altered") end
        
        changed, selected_bass_pattern = reaper.ImGui_Combo(ctx, "Bass Pattern", selected_bass_pattern, table.concat(bass_pattern_options, "\0") .. "\0")
        if reaper.ImGui_IsItemHovered(ctx) then reaper.ImGui_SetTooltip(ctx, "Selects the pattern for the generated bassline.") end

        reaper.ImGui_Separator(ctx)
        if reaper.ImGui_Button(ctx, "Generate Chords & Bass") then generate = true end
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, "Change Rhythm") then change_rhythm = true end
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, "Add Note") then add_note = true end
        
        reaper.ImGui_Separator(ctx)
        if reaper.ImGui_Button(ctx, "Delete Chords (Keep Bass/Melody)") then delete_chords_trigger = true end
        if reaper.ImGui_IsItemHovered(ctx) then reaper.ImGui_SetTooltip(ctx, "Deletes chord notes, keeping the generated bassline and melody.") end

        reaper.ImGui_EndTabItem(ctx)
      end

      -- Tab 2: Performance
      if reaper.ImGui_BeginTabItem(ctx, "Performance") then
        local changed
        local transpose_changed
        transpose_changed, selected_transpose_index = reaper.ImGui_Combo(ctx, "Transpose", selected_transpose_index, table.concat(transpose_labels, "\0") .. "\0")
        if transpose_changed then transpose = transpose_values[selected_transpose_index + 1] end
        
        changed, spread = reaper.ImGui_SliderInt(ctx, "Spread", spread, 0, 2)
        if reaper.ImGui_IsItemHovered(ctx) then reaper.ImGui_SetTooltip(ctx, "Controls spacing between chord notes (0=Tight, 2=Open).") end
        
        changed, selected_voicing = reaper.ImGui_Combo(ctx, "Voicing", selected_voicing, table.concat(voicing_options, "\0") .. "\0")
        if reaper.ImGui_IsItemHovered(ctx) then reaper.ImGui_SetTooltip(ctx, "Applies advanced voicing techniques (requires 4+ notes).") end
        
        reaper.ImGui_Separator(ctx)
        
        reaper.ImGui_Text(ctx, "Humanize")
        changed, humanize_strength_timing = reaper.ImGui_SliderInt(ctx, "Timing +/- (PPQ)", humanize_strength_timing, 0, 30)
        changed, humanize_strength_velocity = reaper.ImGui_SliderInt(ctx, "Velocity +/-", humanize_strength_velocity, 0, 30)
        if reaper.ImGui_Button(ctx, "Humanize Notes") then humanize_trigger = true end
        if reaper.ImGui_IsItemHovered(ctx) then reaper.ImGui_SetTooltip(ctx, "Slightly randomizes the timing and velocity of all notes in the item.") end
        if #humanize_undo_stack > 0 then
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "Undo Humanize") then undo_humanize_trigger = true end
        end

        reaper.ImGui_EndTabItem(ctx)
      end

      -- Tab 3: Creative Tools
      if reaper.ImGui_BeginTabItem(ctx, "Creative Tools") then
        local changed
        -- Melody Generation
        reaper.ImGui_Text(ctx, "Melody Generation")
        changed, melody_density = reaper.ImGui_SliderInt(ctx, "Density", melody_density, 1, 10)
        changed, melody_octave_min = reaper.ImGui_SliderInt(ctx, "Min Octave", melody_octave_min, 2, 7)
        changed, melody_octave_max = reaper.ImGui_SliderInt(ctx, "Max Octave", melody_octave_max, 2, 7)
        if melody_octave_max < melody_octave_min then melody_octave_max = melody_octave_min end
        if reaper.ImGui_Button(ctx, "Generate Melody") then generate_melody_trigger = true end
        if reaper.ImGui_IsItemHovered(ctx) then reaper.ImGui_SetTooltip(ctx, "Generates a new melody over existing chords.\nDeletes any previous melody.") end
        if #melody_undo_stack > 0 then
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "Undo Melody") then undo_melody_trigger = true end
        end
        
        reaper.ImGui_Separator(ctx)
        
        -- Arp/Strum
        reaper.ImGui_Text(ctx, "Arpeggiator / Strummer")
        changed, selected_arp_strum_pattern = reaper.ImGui_Combo(ctx, "Pattern", selected_arp_strum_pattern, table.concat(arp_strum_options, "\0") .. "\0")
        local pattern_name = arp_strum_options[selected_arp_strum_pattern + 1]
        
        if string.find(pattern_name, "Strum") then
          changed, strum_delay_ppq = reaper.ImGui_SliderInt(ctx, "Strum Delay (PPQ)", strum_delay_ppq, 1, 100)
          changed, strum_groove = reaper.ImGui_SliderInt(ctx, "Up-strum Velocity (%)", strum_groove, 0, 100)
          if reaper.ImGui_IsItemHovered(ctx) then reaper.ImGui_SetTooltip(ctx, "Sets the velocity of up-strums as a percentage of the original note's velocity.") end
        elseif pattern_name ~= "None" then
          changed, arp_rate = reaper.ImGui_Combo(ctx, "Arp Rate", arp_rate, table.concat(arp_rate_options, "\0") .. "\0")
        end

        if reaper.ImGui_Button(ctx, "Apply Arp/Strum") then apply_arp = true end
        if reaper.ImGui_IsItemHovered(ctx) then reaper.ImGui_SetTooltip(ctx, "Applies pattern to selected notes (or all if none selected).") end
        if #arp_undo_stack > 0 then
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "Undo Arp/Strum") then undo_arp_trigger = true end
        end
        
        reaper.ImGui_EndTabItem(ctx)
      end
      
      reaper.ImGui_EndTabBar(ctx)
    end
    
    if generation_info ~= "" then
      reaper.ImGui_Separator(ctx)
      reaper.ImGui_Text(ctx, generation_info)
    end

    reaper.ImGui_Separator(ctx)
    if reaper.ImGui_Button(ctx, "Donate") then
        reaper.CF_ShellExecute("https://paypal.me/nkstudio")
    end
    
    reaper.ImGui_End(ctx)
  end

  window_open = open
end


-- Function to update the GUI
local function loop()
  drawGUI()

  if generate then
    -- Invalidate all creative undo buffers on new generation
    melody_undo_stack = {}
    arp_undo_stack = {}
    humanize_undo_stack = {}
    reaper.Undo_BeginBlock()
    
    -- 1. Determine the selected scale type from the GUI to establish context
    local selected_scale_type_name = scale_types_options[selected_scale_type + 1]
    local is_major_context = string.find(selected_scale_type_name:lower(), "major") 
                           or string.find(selected_scale_type_name:lower(), "ionian") 
                           or string.find(selected_scale_type_name:lower(), "lydian") 
                           or string.find(selected_scale_type_name:lower(), "mixolydian")

    -- 2. Finalize the actual scale type name (resolve "Random")
    local final_scale_type_name = selected_scale_type_name
    if final_scale_type_name == "Random" then final_scale_type_name = getRandomScaleType() end

    -- 3. Finalize the root note info (resolve "Random")
    local final_scale_info
    if selected_root_note == 0 then
      final_scale_info = selectRandom(scales)
    else
      final_scale_info = scales[selected_root_note]
    end

    -- 4. Update GUI feedback
    generation_info = string.format("Generated: %s %s", final_scale_info.name, final_scale_type_name)

    -- 5. Build the final scale notes
    local scale_notes = {}
    local root_note_pitch = final_scale_info.notes[1]
    for _, note in ipairs(scale_types[final_scale_type_name]) do
      table.insert(scale_notes, (root_note_pitch + note) % 12)
    end

    -- 6. Get the progression degrees
    local degrees_to_generate
    local current_options = is_major_context and progression_options_major or progression_options_minor
    local progression_name = current_options[selected_progression + 1]
    
    if progression_name == "Random" then
      degrees_to_generate = {}
      local current_num_chords = num_chords
      for i=1, current_num_chords do table.insert(degrees_to_generate, math.random(1, 7)) end
    else
      -- Use the context from step 1 to look up the progression safely
      local p_type = is_major_context and "major" or "minor"
      degrees_to_generate = chord_progressions[p_type][progression_name]
    end
    
    -- 7. Create the chord progression
    -- This flag must be based on the FINAL scale, for modal interchange to work correctly.
    local is_major_final = string.find(final_scale_type_name:lower(), "major") 
                         or string.find(final_scale_type_name:lower(), "ionian") 
                         or string.find(final_scale_type_name:lower(), "lydian") 
                         or string.find(final_scale_type_name:lower(), "mixolydian")
    
    local chords = createChordProgression(scale_notes, degrees_to_generate, is_major_final, complexity, root_note_pitch)

    -- 8. Insert chords into the MIDI item
    local item = reaper.GetSelectedMediaItem(0, 0)
    if item then
      local take = reaper.GetMediaItemTake(item, 0)
      if take and reaper.TakeIsMIDI(take) then
        local item_start_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, reaper.GetMediaItemInfo_Value(item, "D_POSITION"))
        local item_length_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, reaper.GetMediaItemInfo_Value(item, "D_POSITION") + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")) - item_start_ppq

        reaper.MIDI_DisableSort(take)
        deleteExistingNotes(take)
        createMIDIChords(take, chords, item_start_ppq, item_length_ppq)
        generateAndInsertBassline(take, chords, item_start_ppq, item_length_ppq, bass_pattern_options[selected_bass_pattern + 1])
        transposeMIDI(take, transpose)
        reaper.MIDI_Sort(take)
        reaper.UpdateArrange()
        storeInitialState(take)
      end
    end

    generate = false
    reaper.Undo_EndBlock("Generate Chords", -1)
  end

  if generate_melody_trigger then
    local item = reaper.GetSelectedMediaItem(0, 0)
    if item then
      local take = reaper.GetMediaItemTake(item, 0)
      if take and reaper.TakeIsMIDI(take) then
        table.insert(melody_undo_stack, captureUndoState(take)) -- Add current state to undo stack
        reaper.Undo_BeginBlock()
        deleteExistingMelody(take) -- Delete old melody notes before generating new ones
        local item_start_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, reaper.GetMediaItemInfo_Value(item, "D_POSITION"))
        local item_length_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, reaper.GetMediaItemInfo_Value(item, "D_POSITION") + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")) - item_start_ppq
        
        local melody_scale = analyzeChordsForMelody(take)
        local melody = generateMelody(take, melody_scale, melody_density, melody_octave_min, melody_octave_max, item_start_ppq, item_length_ppq)
        insertMelody(take, melody)
        
        reaper.MIDI_Sort(take)
        reaper.UpdateArrange()
        reaper.Undo_EndBlock("Generate Melody", -1)
      end
    end
    generate_melody_trigger = false
  end

  if apply_arp then
    local item = reaper.GetSelectedMediaItem(0, 0)
    if item then
      local take = reaper.GetMediaItemTake(item, 0)
      if take and reaper.TakeIsMIDI(take) then
        local pattern = arp_strum_options[selected_arp_strum_pattern + 1]
        if pattern ~= "None" then
          table.insert(arp_undo_stack, captureUndoState(take)) -- Add current state to undo stack
          reaper.Undo_BeginBlock()
          
          local final_rate_value
          local rate_name = arp_rate_options[arp_rate + 1]
          if rate_name == "Random" then
            final_rate_value = -1 -- Signal for random rate per chord
          else
            final_rate_value = arp_rate_values[arp_rate + 1]
          end
          
          applyArpeggioOrStrum(take, pattern, final_rate_value, strum_delay_ppq, strum_groove)
          reaper.Undo_EndBlock("Apply Arp/Strum", -1)
        end
      end
    end
    apply_arp = false
  end

  if humanize_trigger then
      local item = reaper.GetSelectedMediaItem(0, 0)
      if item then
          local take = reaper.GetMediaItemTake(item, 0)
          if take and reaper.TakeIsMIDI(take) then
              table.insert(humanize_undo_stack, captureUndoState(take))
              reaper.Undo_BeginBlock()
              humanizeNotes(take, humanize_strength_timing, humanize_strength_velocity)
              reaper.Undo_EndBlock("Humanize Notes", -1)
          end
      end
      humanize_trigger = false
  end

  if undo_melody_trigger then
      local item = reaper.GetSelectedMediaItem(0, 0)
      if item then
          local take = reaper.GetMediaItemTake(item, 0)
          if take and reaper.TakeIsMIDI(take) and #melody_undo_stack > 0 then
              reaper.Undo_BeginBlock()
              local last_state = table.remove(melody_undo_stack)
              deleteExistingNotes(take)
              for _, note in ipairs(last_state) do
                  reaper.MIDI_InsertNote(take, note.selected, note.muted, note.startppq, note.endppq, note.chan, note.pitch, note.vel, true)
              end
              reaper.MIDI_Sort(take)
              reaper.UpdateArrange()
              reaper.Undo_EndBlock("Undo Melody", -1)
          end
      end
      undo_melody_trigger = false
  end

  if undo_arp_trigger then
      local item = reaper.GetSelectedMediaItem(0, 0)
      if item then
          local take = reaper.GetMediaItemTake(item, 0)
          if take and reaper.TakeIsMIDI(take) and #arp_undo_stack > 0 then
              reaper.Undo_BeginBlock()
              local last_state = table.remove(arp_undo_stack)
              deleteExistingNotes(take)
              for _, note in ipairs(last_state) do
                  reaper.MIDI_InsertNote(take, note.selected, note.muted, note.startppq, note.endppq, note.chan, note.pitch, note.vel, true)
              end
              reaper.MIDI_Sort(take)
              reaper.UpdateArrange()
              reaper.Undo_EndBlock("Undo Arp/Strum", -1)
          end
      end
      undo_arp_trigger = false
  end
  
  if undo_humanize_trigger then
      local item = reaper.GetSelectedMediaItem(0, 0)
      if item then
          local take = reaper.GetMediaItemTake(item, 0)
          if take and reaper.TakeIsMIDI(take) and #humanize_undo_stack > 0 then
              reaper.Undo_BeginBlock()
              local last_state = table.remove(humanize_undo_stack)
              deleteExistingNotes(take)
              for _, note in ipairs(last_state) do
                  reaper.MIDI_InsertNote(take, note.selected, note.muted, note.startppq, note.endppq, note.chan, note.pitch, note.vel, true)
              end
              reaper.MIDI_Sort(take)
              reaper.UpdateArrange()
              reaper.Undo_EndBlock("Undo Humanize", -1)
          end
      end
      undo_humanize_trigger = false
  end

  if change_rhythm then
    local item = reaper.GetSelectedMediaItem(0, 0)
    if item then
      local take = reaper.GetMediaItemTake(item, 0)
      if take and reaper.TakeIsMIDI(take) then
        local initialNotes = getInitialState()

        if not initialNotes then
          reaper.ShowConsoleMsg("Error: No initial state found. Generate chords first.\n")
        else
          reaper.Undo_BeginBlock()
          changeRhythm(take, initialNotes)
          reaper.Undo_EndBlock(scriptName, -1)
          reaper.MarkTrackItemsDirty(reaper.GetMediaItemTake_Track(take), reaper.GetMediaItemTake_Item(take))
        end
      end
    end

    change_rhythm = false
  end

  if add_note then
    local item = reaper.GetSelectedMediaItem(0, 0)
    if item then
      local take = reaper.GetMediaItemTake(item, 0)
      if take and reaper.TakeIsMIDI(take) then
        reaper.Undo_BeginBlock()
        addNote(take)
        reaper.Undo_EndBlock("Add Note", -1)
        reaper.MarkTrackItemsDirty(reaper.GetMediaItemTake_Track(take), reaper.GetMediaItemTake_Item(take))
      end
    end

    add_note = false
  end
  
  if delete_chords_trigger then
    local item = reaper.GetSelectedMediaItem(0, 0)
    if item then
      local take = reaper.GetMediaItemTake(item, 0)
      if take and reaper.TakeIsMIDI(take) then
        reaper.Undo_BeginBlock()
        deleteExistingChords(take)
        reaper.MIDI_Sort(take)
        reaper.UpdateArrange()
        reaper.Undo_EndBlock("Delete Chords Only", -1)
      end
    end
    delete_chords_trigger = false
  end

  if window_open then
    reaper.defer(loop)
  end
end

-- Main function
local function Main()
  ctx = reaper.ImGui_CreateContext('Chord Generator')
  reaper.defer(loop)
end

-- Run the main program
reaper.Undo_BeginBlock()
Main()
reaper.Undo_EndBlock("Generate Chords", -1)

