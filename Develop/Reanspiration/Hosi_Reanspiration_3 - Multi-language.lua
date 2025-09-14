-- @description Reanspiration - Advanced MIDI Generation Toolkit
-- @version 3.7.6 (UI Compatibility Fix)
-- @author Hosi (developed from original concept by phaselab)
-- @link Original Script by phaselab [https://forum.cockos.com/showthread.php?t=291623](https://forum.cockos.com/showthread.php?t=291623)
-- @about
--   An all-in-one toolkit for generating harmonically-aware musical ideas.
--   Now supports external library file ('reanspiration_library.lua') for easy customization.
--
--   Features:
--   - Chord generation with expanded scale/progression library.
--   - Automatic Secondary Dominant insertion for richer harmony.
--   - Advanced Voice Leading algorithm for smoother chord transitions.
--   - Advanced chord extensions (9ths, 11ths, 13ths, alterations).
--   - Advanced voicing (spread, drop voicings).
--   - Smart bassline generator with multiple patterns.
--   - Integrated melody generator with contour and chord-targeting.
--   - Rhythmic pattern applicator for chords.
--   - Arpeggiator and Strummer.
--   - Humanizer for timing and velocity.
--   - Multi-level Undo for creative tool edits.
--   - Tabbed interface for improved workflow.
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

-- Load External Library for Chord Progressions and Bass Patterns
local function loadLibrary()
  local script_path_info = debug.getinfo(1,"S")
  if not script_path_info or not script_path_info.source then
      reaper.ShowMessageBox("Cannot determine script path. Please save the script to your computer and run it from there.", "Error", 0)
      return nil
  end
  
  -- FIX Remove leading '@' from the source path to prevent "Invalid argument" error on some systems.
  local clean_source_path = script_path_info.source:gsub("^@", "")
  
  local script_path = clean_source_path:match(".*[/\\]")
  if not script_path then
    reaper.ShowMessageBox("Could not determine script path. Make sure the script is saved to disk.", "Error", 0)
    return nil
  end
  
  local library_path = script_path .. "reanspiration_library.lua"
  local success, library = pcall(dofile, library_path)

  if not success or type(library) ~= "table" then
    reaper.ShowMessageBox("Could not load 'reanspiration_library.lua'.\n\nPlease ensure it is in the same directory as the main script.\n\nError: " .. tostring(library), "Library Error", 0)
    return nil
  end
  return library
end

-- NEW: Function to load the language file
local function loadLanguages()
  local script_path_info = debug.getinfo(1,"S")
  if not script_path_info or not script_path_info.source then
      return nil
  end
  local clean_source_path = script_path_info.source:gsub("^@", "")
  local script_path = clean_source_path:match(".*[/\\]")
  if not script_path then
    return nil
  end
  
  local lang_path = script_path .. "reanspiration_languages.lua"
  local success, lang_data = pcall(dofile, lang_path)

  if not success or type(lang_data) ~= "table" then
    reaper.ShowMessageBox("Could not load 'reanspiration_languages.lua'.\n\nPlease ensure it is in the same directory as the main script.\n\nError: " .. tostring(lang_data), "Language File Error", 0)
    return nil
  end
  return lang_data
end


local Library = loadLibrary()
if not Library then return end -- Stop script if library fails to load

-- NEW: Load language data
local LangData = loadLanguages()
if not LangData then return end -- Stop if languages fail to load

-- NEW: Language state variables
local available_languages = {"English", "Tiếng Việt", "日本語", "中文", "한국어"}
local language_keys = {"en", "vi", "ja", "zh", "ko"}
local selected_language_index = 0
local L = LangData[language_keys[selected_language_index + 1]] -- The current language table

-- NEW: Helper function to get translated text
local function T(key)
    return L[key] or key -- Return the key itself as a fallback if translation is missing
end


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

-- Library Data (Loaded from external file)
local chord_progressions = Library.chord_progressions
local bass_patterns = Library.bass_patterns
local rhythm_patterns = Library.rhythm_patterns

-- GUI Options Setup
local progression_options_major = {"Random"}
for name, _ in pairs(chord_progressions.major) do table.insert(progression_options_major, name) end
local progression_options_minor = {"Random"}
for name, _ in pairs(chord_progressions.minor) do table.insert(progression_options_minor, name) end

local bass_pattern_options = {"None"}
for _, pattern_data in ipairs(bass_patterns) do table.insert(bass_pattern_options, pattern_data.name) end

local rhythm_pattern_options = {"None"}
for _, pattern_data in ipairs(rhythm_patterns) do table.insert(rhythm_pattern_options, pattern_data.name) end

-- GUI State Variables
local selected_progression = 0
local selected_transpose_index = 2
local selected_voicing = 0
local voicing_options = {"None", "Drop 2", "Drop 3", "Drop 4", "Drop 2+4"}
local selected_arp_strum_pattern = 0
local selected_bass_pattern = 1
local selected_rhythm_pattern = 0
local add_secondary_dominants = false -- NEW (v3.2)

local spread = 0
local arp_rate = 2
local strum_delay_ppq = 20
local strum_groove = 75
local melody_density = 4
local melody_octave_min = 4
local melody_octave_max = 5
local humanize_strength_timing = 5
local humanize_strength_velocity = 8

-- Constants
local MELODY_CHANNEL = 15
local transpose_values = {-24, -12, 0, 12, 24}
local transpose_labels = {"-2", "-1", "0", "+1", "+2"}
local arp_rate_options = {"1/4", "1/8", "1/16", "1/32", "Random"}
local arp_rate_values = {1, 0.5, 0.25, 0.125}
local arp_strum_options = {"None", "Arp Up", "Arp Down", "Arp Up/Down", "Arp Random", "Strum Down", "Strum Up", "Strum D-U-D-U", "Strum D-D-U"}

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
    local root = scale[degree] 
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
    reaper.MIDI_InsertNote(take, false, false, position, position + length, 0, note, math.random(80, 110), true)
  end
end

-- UPDATED (v3.2) to handle secondary dominants
local function createChordProgression(scale_notes, degrees_specs, is_major, complexity, root_note_pitch)
  local chords = {}
  local chord_types_major = {"major", "minor", "minor", "major", "major", "minor", "diminished"}
  local chord_types_minor = {"minor", "diminished", "major", "minor", "minor", "major", "major"}
  
  for _, spec in ipairs(degrees_specs) do
    if spec.is_secondary_dominant then
        local target_degree = spec.target_degree
        local target_root_pc = scale_notes[target_degree]
        if target_root_pc then
            local sec_dom_root_pc = (target_root_pc + 7) % 12
            
            -- Create a temporary Mixolydian scale for the dominant chord
            local temp_scale = {}
            local mixolydian_intervals = {0, 2, 4, 5, 7, 9, 10}
            for _, interval in ipairs(mixolydian_intervals) do
                table.insert(temp_scale, (sec_dom_root_pc + interval) % 12)
            end
            
            -- Use getChord to build the V7 chord, treating it as the "I" of its own temporary scale
            local chord = getChord(temp_scale, 1, "dominant", complexity)
            if chord then
              -- Don't snap to the main scale. adjustChord with nil scale just handles spacing.
              chord = adjustChord(chord, nil)
              table.insert(chords, {
                  degree = "V/" .. target_degree,
                  chord = chord,
                  is_major = true -- Dominant chords have a major third
              })
            end
        end
    else
        -- Handle normal diatonic chord
        local degree = spec.degree
        local chord_type
        local use_borrowed = false

        -- Modal Interchange Logic
        if complexity >= 4 and degree ~= 1 and math.random() < 0.25 then
            use_borrowed = true
        end

        local current_scale = scale_notes
        local current_chord_types = is_major and chord_types_major or chord_types_minor

        if use_borrowed then
            local parallel_scale_type = is_major and "Natural Minor" or "Major"
            local parallel_scale_intervals = scale_types[parallel_scale_type]
            current_scale = {}
            for _, interval in ipairs(parallel_scale_intervals) do
                table.insert(current_scale, (root_note_pitch + interval) % 12)
            end
            current_chord_types = is_major and chord_types_minor or chord_types_major
        end
        
        if not current_chord_types[degree] then
            chord_type = is_major and "major" or "minor"
        else
            chord_type = current_chord_types[degree]
        end

        if is_major and degree == 5 then
            chord_type = "dominant"
        end

        local chord = getChord(current_scale, degree, chord_type, complexity)
        if not chord or #chord < 3 then
            chord = getChord(scale_notes, degree, is_major and "major" or "minor", 0) -- Fallback
        end
        
        if chord then
            chord = adjustChord(chord, not use_borrowed and scale_notes or nil)
            table.insert(chords, {degree = degree, chord = chord, is_major = (chord_type == "major" or chord_type == "dominant")})
        end
    end
  end

  return chords
end

--[[--
REPLACED (v3.3): Replaced getClosestInversion with a more advanced voice leading algorithm
that prioritizes smooth melodic movement in the top voice.
--]]--
local function getBestVoiceLeading(prev_chord, chord)
    local min_score = math.huge
    local best_voicing = chord

    -- Ensure previous chord is sorted to reliably get the top note
    table.sort(prev_chord)
    local prev_top_note = prev_chord[#prev_chord]

    -- Generate and test candidate voicings (inversions in different octaves)
    for i = 0, #chord - 1 do -- Inversions
        for oct_shift = -1, 1 do -- Octave shifts (-1, 0, 1) relative to middle C area
            local base_inversion = getChordInversion(chord, i)
            local candidate_chord = {}
            for _, note_pc in ipairs(base_inversion) do
                table.insert(candidate_chord, note_pc + 60 + (oct_shift * 12))
            end
            table.sort(candidate_chord)
            
            -- Calculate score for this candidate
            -- 1. Top note movement score (heavily weighted)
            local top_note = candidate_chord[#candidate_chord]
            local top_note_penalty = math.abs(top_note - prev_top_note)

            -- 2. Overall movement score (less weighted)
            local total_movement_penalty = 0
            for j = 1, math.min(#prev_chord, #candidate_chord) do
                total_movement_penalty = total_movement_penalty + math.abs(candidate_chord[j] - prev_chord[j])
            end

            -- 3. Weighted final score
            -- The top note's movement is 4 times more important than the sum of all movements.
            local score = (top_note_penalty * 4) + (total_movement_penalty * 1)

            if score < min_score then
                min_score = score
                best_voicing = candidate_chord
            end
        end
    end
    return best_voicing
end

-- Refactored to not handle bass notes directly.
local function createMIDIChords(take, chords, item_start_ppq, item_length_ppq)
  if #chords == 0 then return end
  local num_chords = #chords
  local chord_length = item_length_ppq / num_chords
  local position = item_start_ppq
  
  -- Create a reasonable starting chord around middle C for the first chord in the progression.
  local initial_chord_notes = {}
  for _, note_pc in ipairs(chords[1].chord) do
      table.insert(initial_chord_notes, note_pc + 60)
  end
  
  local prev_chord = initial_chord_notes

  for _, chord_data in ipairs(chords) do
    local current_chord = chord_data.chord
    
    -- Apply voicing controls before finding the best inversion
    local voiced_chord = applyDropVoicing({table.unpack(current_chord)}, voicing_options[selected_voicing + 1])
    voiced_chord = applySpread(voiced_chord, spread)

    local best_voicing = getBestVoiceLeading(prev_chord, voiced_chord)
    best_voicing = adjustChord(best_voicing)
    
    insertChord(take, position, best_voicing, chord_length)
    prev_chord = best_voicing
    position = position + chord_length
  end
end

-- Smart Bassline Generation (Now uses external library functions)
local function generateAndInsertBassline(take, chords, item_start_ppq, item_length_ppq, pattern_name)
    if pattern_name == "None" or #chords == 0 then return end

    -- Find the selected pattern's function in our library
    local pattern_func = nil
    for _, pattern_data in ipairs(bass_patterns) do
        if pattern_data.name == pattern_name then
            pattern_func = pattern_data.func
            break
        end
    end
    
    -- If we found a valid function, execute it for each chord
    if pattern_func then
        local num_chords = #chords
        local chord_length = item_length_ppq / num_chords
        local bass_octave = 36 -- MIDI Pitch for C1

        for i = 1, num_chords do
            local position = item_start_ppq + (i - 1) * chord_length
            local chord_data = chords[i]
            local root_note_pc = chord_data.chord[1] % 12
            local root_note = root_note_pc + bass_octave
            local next_root_pc = (i < num_chords) and chords[i+1].chord[1] % 12 or root_note_pc

            -- Call the specific pattern's function from the library
            pattern_func(take, position, chord_length, chord_data, root_note, next_root_pc)
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

--[[--
NEW ADVANCED MELODY ANALYSIS FUNCTION (v3.1)
Analyzes the MIDI take to extract both a detailed list of chords and the overall scale.
--]]--
local function analyzeChordsAndScale(take)
    -- This function now returns two things:
    -- 1. A sorted list of chord objects with detailed info.
    -- 2. A table of unique pitch classes for the overall scale.

    local notes_by_start_time = {}
    local all_note_pcs = {} -- For overall scale detection
    local note_idx = 0
    
    while true do
        local ret, _, _, startppq, endppq, _, pitch, _ = reaper.MIDI_GetNote(take, note_idx)
        if not ret then break end
        
        if not notes_by_start_time[startppq] then
            notes_by_start_time[startppq] = {}
        end
        table.insert(notes_by_start_time[startppq], {
            pitch = pitch,
            endppq = endppq
        })
        
        all_note_pcs[pitch % 12] = true
        note_idx = note_idx + 1
    end

    local analyzed_chords = {}
    for startppq, notes in pairs(notes_by_start_time) do
        -- Consider it a chord if 2 or more notes start at the same time.
        if #notes >= 2 then
            table.sort(notes, function(a, b) return a.pitch < b.pitch end)
            
            local chord_end_ppq = notes[1].endppq -- Assume all notes in chord have similar length
            local chord_tones_pc = {}
            for _, note in ipairs(notes) do
                chord_tones_pc[note.pitch % 12] = true
                if note.endppq > chord_end_ppq then chord_end_ppq = note.endppq end
            end
            
            table.insert(analyzed_chords, {
                startppq = startppq,
                endppq = chord_end_ppq,
                notes = notes, -- Full note info
                chord_tones_pc = chord_tones_pc,
                root_note_pc = notes[1].pitch % 12 -- Simple heuristic: lowest note is root
            })
        end
    end

    -- Sort chords by their start time, which is crucial for melody generation
    table.sort(analyzed_chords, function(a, b) return a.startppq < b.startppq end)

    -- Build the overall scale from all notes found
    local overall_scale = {}
    for note_pc in pairs(all_note_pcs) do
        table.insert(overall_scale, note_pc)
    end
    table.sort(overall_scale)
    
    return analyzed_chords, overall_scale
end

--[[--
NEW INTELLIGENT MELODY GENERATOR (v3.1)
Creates a melody that follows a user-defined contour and targets chord tones on strong beats.
--]]--
local function generateMelody(take, analyzed_chords, scale, density, oct_min, oct_max, item_start_ppq, item_length_ppq, contour_name, target_chord_tones)
    if #scale == 0 or #analyzed_chords == 0 then return {} end

    local melody = {}
    local ppq_per_beat = reaper.MIDI_GetPPQPosFromProjQN(take, 1)
    
    local step_size = (ppq_per_beat * 4) / (density * 2)
    local note_length = step_size * 0.9
    
    local min_pitch_abs = oct_min * 12
    local max_pitch_abs = (oct_max + 1) * 12 - 1
    
    local current_chord_index = 1
    local current_pos = item_start_ppq
    
    while current_pos < item_start_ppq + item_length_ppq do
        -- Determine which chord is active at the current position
        while current_chord_index < #analyzed_chords and current_pos >= analyzed_chords[current_chord_index + 1].startppq do
            current_chord_index = current_chord_index + 1
        end
        local active_chord = analyzed_chords[current_chord_index]

        -- 90% chance to place a note, 10% for a rest
        if math.random() < 0.9 then
            -- 1. Calculate the target pitch based on contour
            local progress = (current_pos - item_start_ppq) / item_length_ppq
            local target_pitch
            
            local contour = contour_name
            if contour == "Random" then contour = selectRandom({"Ascending", "Arch", "Descending", "Valley"}) end

            if contour == "Ascending" then
                target_pitch = min_pitch_abs + (max_pitch_abs - min_pitch_abs) * progress
            elseif contour == "Descending" then
                target_pitch = max_pitch_abs - (max_pitch_abs - min_pitch_abs) * progress
            elseif contour == "Arch" then
                local multiplier = math.sin(progress * math.pi)
                target_pitch = min_pitch_abs + (max_pitch_abs - min_pitch_abs) * multiplier
            elseif contour == "Valley" then
                 local multiplier = math.cos(progress * math.pi * 2) * -0.5 + 0.5
                 target_pitch = min_pitch_abs + (max_pitch_abs - min_pitch_abs) * multiplier
            else -- Default to a mid-range target
                target_pitch = (min_pitch_abs + max_pitch_abs) / 2
            end

            -- 2. Determine the pool of candidate notes
            local candidate_pool = {}
            local is_strong_beat = (current_pos - item_start_ppq) % (ppq_per_beat / 2) < step_size -- 8th note is strong enough

            if target_chord_tones and is_strong_beat and math.random() < 0.8 then -- 80% chance to target chord tone
                for pc in pairs(active_chord.chord_tones_pc) do table.insert(candidate_pool, pc) end
            else
                candidate_pool = {table.unpack(scale)}
            end
            
            if #candidate_pool == 0 then candidate_pool = {table.unpack(scale)} end

            -- 3. Find the best note from the pool
            local best_note_pitch = -1
            local min_dist = math.huge
            
            -- Search across all available octaves for the best fit
            for oct = oct_min, oct_max do
                for _, pc in ipairs(candidate_pool) do
                    local current_pitch = pc + oct * 12
                    local dist = math.abs(current_pitch - target_pitch)
                    
                    if dist < min_dist then
                        min_dist = dist
                        best_note_pitch = current_pitch
                    end
                end
            end
            
            if best_note_pitch ~= -1 then
                table.insert(melody, {pos = current_pos, length = note_length, note = best_note_pitch})
            end
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


-- Rhythm Functions
local scriptName = "Reanspiration Actions"
local initialStateKey = "initial_note_state"

-- FIX v3.4: Re-added helper functions for state serialization that were accidentally removed.
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
    local note_idx = 0
    while true do
        local ret, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, note_idx)
        if not ret then break end
        table.insert(noteData, {startppqpos = startppqpos, endppqpos = endppqpos, chan = chan, pitch = pitch, vel = vel, selected = selected, muted = muted, index = note_idx})
        note_idx = note_idx + 1
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

local function changeRhythmRandomly(take, initialNotes)
  reaper.MIDI_DisableSort(take)
  
  local currentNotes = {}
  local note_idx = 0
  while true do
    local ret, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, note_idx)
    if not ret then break end
    table.insert(currentNotes, {startppqpos = startppqpos, endppqpos = endppqpos, chan = chan, pitch = pitch, vel = vel, selected = selected, muted = muted, index = note_idx})
    note_idx = note_idx + 1
  end

  if #currentNotes ~= #initialNotes then
    reaper.MIDI_Sort(take)
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

local function applyRhythmPattern(take, initialNotes, rhythm_pattern)
    reaper.MIDI_DisableSort(take)
    
    local function findChords(notes)
        local chords = {}
        local activeNotes = {}
        for _, note in ipairs(notes) do
            if note.chan ~= MELODY_CHANNEL and note.pitch >= 60 then
                if not activeNotes[note.startppqpos] then activeNotes[note.startppqpos] = {} end
                table.insert(activeNotes[note.startppqpos], note)
            end
        end
        for startppqpos, chordNotes in pairs(activeNotes) do
            table.insert(chords, {startppqpos = startppqpos, notes = chordNotes})
        end
        table.sort(chords, function(a, b) return a.startppqpos < b.startppqpos end)
        return chords
    end

    local initial_chords = findChords(initialNotes)
    if #initial_chords == 0 then
        reaper.MIDI_Sort(take)
        return
    end

    local notes_to_delete = {}
    local current_note_idx = 0
    local initial_chord_starts = {}
    for _, ch in ipairs(initial_chords) do initial_chord_starts[ch.startppqpos] = true end
    
    while true do
        local ret, _, _, startppq, _, chan, pitch, _ = reaper.MIDI_GetNote(take, current_note_idx)
        if not ret then break end
        if initial_chord_starts[startppq] and chan ~= MELODY_CHANNEL and pitch >= 60 then
            table.insert(notes_to_delete, current_note_idx)
        end
        current_note_idx = current_note_idx + 1
    end
    
    table.sort(notes_to_delete, function(a, b) return a > b end)
    for _, index in ipairs(notes_to_delete) do
        reaper.MIDI_DeleteNote(take, index)
    end
    
    for i, chord in ipairs(initial_chords) do
        local chord_start_pos = chord.startppqpos
        local chord_duration
        
        if initial_chords[i+1] then
            chord_duration = initial_chords[i+1].startppqpos - chord.startppqpos
        else
            chord_duration = chord.notes[1].endppqpos - chord.notes[1].startppqpos
        end
        
        if chord_duration <= 0 then goto continue end

        for _, rhythm_hit in ipairs(rhythm_pattern) do
            local new_start = chord_start_pos + (chord_duration * rhythm_hit.start)
            local new_duration = (chord_duration * rhythm_hit.duration) * 0.98
            local new_end = new_start + new_duration
            
            for _, note in ipairs(chord.notes) do
                reaper.MIDI_InsertNote(take, false, false, new_start, new_end, note.chan, note.pitch, note.vel, true)
            end
        end
        ::continue::
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
    reaper.ShowConsoleMsg(T("add_note_error_no_notes"))
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
    reaper.ShowConsoleMsg(T("add_note_error_no_scale"))
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
    reaper.ShowConsoleMsg(T("add_note_error_no_chords"))
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
local num_chords = 4
local complexity = 0
local transpose = 0 -- Initial value for transposition
local generate = false
local add_note = false
local apply_rhythm_trigger = false
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
local scale_types_options = {"Random", "Major", "Natural Minor", "Harmonic Minor", "Melodic Minor", "Pentatonic", "Ionian", "Aeolian", "Dorian", "Mixolydian", "Phrygian", "Lydian", "Locrian", "Double Harmonic Major", "Neapolitan Major", "Neapolitan Minor", "Hungarian Minor"}
local selected_scale_type = 0

-- NEW MELODY VARIABLES (v3.1)
local melody_contour_options = {"Random", "Ascending", "Arch", "Descending", "Valley"}
local selected_melody_contour = 0
local melody_target_chord_tones = true

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

  local visible, open = reaper.ImGui_Begin(ctx, T('window_title'), true, window_flags)
  if visible then

    if reaper.ImGui_BeginTabBar(ctx, "MainTabBar") then
      
      -- Tab 1: Generation
      if reaper.ImGui_BeginTabItem(ctx, T("tab_generation")) then
        local changed
        changed, selected_root_note = reaper.ImGui_Combo(ctx, T("root_note_label"), selected_root_note, table.concat(root_note_options, "\0") .. "\0")
        
        local scale_type_changed
        scale_type_changed, selected_scale_type = reaper.ImGui_Combo(ctx, T("scale_type_label"), selected_scale_type, table.concat(scale_types_options, "\0") .. "\0")
        
        local is_major_scale = string.find(scale_types_options[selected_scale_type + 1]:lower(), "major") or string.find(scale_types_options[selected_scale_type + 1]:lower(), "ionian") or string.find(scale_types_options[selected_scale_type + 1]:lower(), "lydian") or string.find(scale_types_options[selected_scale_type + 1]:lower(), "mixolydian")
        
        if is_major_scale then
          current_progression_options = progression_options_major
        else
          current_progression_options = progression_options_minor
        end

        if scale_type_changed then
          selected_progression = 0 -- Reset to random when scale type changes
        end

        changed, selected_progression = reaper.ImGui_Combo(ctx, T("progression_label"), selected_progression, table.concat(current_progression_options, "\0") .. "\0")

        local progression_name = current_progression_options[selected_progression + 1]
        if progression_name == "Random" then
          reaper.ImGui_BeginDisabled(ctx, false)
          local num_chords_changed
          num_chords_changed, num_chords = reaper.ImGui_InputInt(ctx, T("num_chords_label"), num_chords, 1, 1)
          if num_chords_changed then
            num_chords = math.max(1, math.min(16, num_chords))
          end
          reaper.ImGui_EndDisabled(ctx)
        else
          local p_type = is_major_scale and "major" or "minor"
          if chord_progressions[p_type] and chord_progressions[p_type][progression_name] then
              local num = #chord_progressions[p_type][progression_name]
              reaper.ImGui_BeginDisabled(ctx, true)
              reaper.ImGui_InputInt(ctx, T("num_chords_label"), num, 1, 1)
              reaper.ImGui_EndDisabled(ctx)
          else
              -- Fallback for safety
              reaper.ImGui_BeginDisabled(ctx, true)
              reaper.ImGui_InputInt(ctx, T("num_chords_label"), 4, 1, 1)
              reaper.ImGui_EndDisabled(ctx)
          end
        end
        
        changed, complexity = reaper.ImGui_SliderInt(ctx, T("complexity_label"), complexity, 0, 5)
        reaper.ImGui_SameLine(ctx); reaper.ImGui_Text(ctx, "(?)"); if reaper.ImGui_IsItemHovered(ctx) then reaper.ImGui_SetTooltip(ctx, T("tooltip_complexity")) end
        
        -- NEW WIDGET (v3.2)
        local changed_sec_dom
        changed_sec_dom, add_secondary_dominants = reaper.ImGui_Checkbox(ctx, T("sec_dom_checkbox"), add_secondary_dominants)
        if reaper.ImGui_IsItemHovered(ctx) then reaper.ImGui_SetTooltip(ctx, T("tooltip_sec_dom")) end
        
        changed, selected_bass_pattern = reaper.ImGui_Combo(ctx, T("bass_pattern_label"), selected_bass_pattern, table.concat(bass_pattern_options, "\0") .. "\0")
        if reaper.ImGui_IsItemHovered(ctx) then reaper.ImGui_SetTooltip(ctx, T("tooltip_bass_pattern")) end

        reaper.ImGui_Separator(ctx)
        if reaper.ImGui_Button(ctx, T("generate_button")) then generate = true end
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, T("add_note_button")) then add_note = true end
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, T("delete_chords_button")) then delete_chords_trigger = true end
        if reaper.ImGui_IsItemHovered(ctx) then reaper.ImGui_SetTooltip(ctx, T("tooltip_delete_chords")) end
        
        reaper.ImGui_EndTabItem(ctx)
      end

      -- Tab 2: Performance
      if reaper.ImGui_BeginTabItem(ctx, T("tab_performance")) then
        local changed
        local transpose_changed
        transpose_changed, selected_transpose_index = reaper.ImGui_Combo(ctx, T("transpose_label"), selected_transpose_index, table.concat(transpose_labels, "\0") .. "\0")
        if transpose_changed then transpose = transpose_values[selected_transpose_index + 1] end
        
        changed, spread = reaper.ImGui_SliderInt(ctx, T("spread_label"), spread, 0, 2)
        if reaper.ImGui_IsItemHovered(ctx) then reaper.ImGui_SetTooltip(ctx, T("tooltip_spread")) end
        
        changed, selected_voicing = reaper.ImGui_Combo(ctx, T("voicing_label"), selected_voicing, table.concat(voicing_options, "\0") .. "\0")
        if reaper.ImGui_IsItemHovered(ctx) then reaper.ImGui_SetTooltip(ctx, T("tooltip_voicing")) end
        
        reaper.ImGui_Separator(ctx)
        
        reaper.ImGui_Text(ctx, T("humanize_section_title"))
        changed, humanize_strength_timing = reaper.ImGui_SliderInt(ctx, T("humanize_timing_label"), humanize_strength_timing, 0, 30)
        changed, humanize_strength_velocity = reaper.ImGui_SliderInt(ctx, T("humanize_velocity_label"), humanize_strength_velocity, 0, 30)
        if reaper.ImGui_Button(ctx, T("humanize_button")) then humanize_trigger = true end
        if reaper.ImGui_IsItemHovered(ctx) then reaper.ImGui_SetTooltip(ctx, T("tooltip_humanize")) end
        if #humanize_undo_stack > 0 then
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, T("undo_humanize_button")) then undo_humanize_trigger = true end
        end

        reaper.ImGui_EndTabItem(ctx)
      end

      -- Tab 3: Creative Tools
      if reaper.ImGui_BeginTabItem(ctx, T("tab_creative_tools")) then
        local changed
        -- Melody Generation
        reaper.ImGui_Text(ctx, T("melody_section_title"))
        
        -- NEW WIDGETS (v3.1)
        changed, selected_melody_contour = reaper.ImGui_Combo(ctx, T("melody_contour_label"), selected_melody_contour, table.concat(melody_contour_options, "\0") .. "\0")
        reaper.ImGui_SameLine(ctx); reaper.ImGui_Text(ctx, "(?)"); if reaper.ImGui_IsItemHovered(ctx) then reaper.ImGui_SetTooltip(ctx, T("tooltip_melody_contour")) end
        
        changed, melody_target_chord_tones = reaper.ImGui_Checkbox(ctx, T("melody_target_checkbox"), melody_target_chord_tones)
        if reaper.ImGui_IsItemHovered(ctx) then reaper.ImGui_SetTooltip(ctx, T("tooltip_melody_target")) end

        changed, melody_density = reaper.ImGui_SliderInt(ctx, T("melody_density_label"), melody_density, 1, 10)
        changed, melody_octave_min = reaper.ImGui_SliderInt(ctx, T("melody_min_oct_label"), melody_octave_min, 2, 7)
        changed, melody_octave_max = reaper.ImGui_SliderInt(ctx, T("melody_max_oct_label"), melody_octave_max, 2, 7)
        if melody_octave_max < melody_octave_min then melody_octave_max = melody_octave_min end
        
        if reaper.ImGui_Button(ctx, T("melody_generate_button")) then generate_melody_trigger = true end
        if reaper.ImGui_IsItemHovered(ctx) then reaper.ImGui_SetTooltip(ctx, T("tooltip_melody_generate")) end
        if #melody_undo_stack > 0 then
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, T("undo_melody_button")) then undo_melody_trigger = true end
        end
        
        reaper.ImGui_Separator(ctx)
        
        -- Arp/Strum
        reaper.ImGui_Text(ctx, T("arp_strum_section_title"))
        changed, selected_arp_strum_pattern = reaper.ImGui_Combo(ctx, T("arp_strum_pattern_label"), selected_arp_strum_pattern, table.concat(arp_strum_options, "\0") .. "\0")
        local pattern_name = arp_strum_options[selected_arp_strum_pattern + 1]
        
        if string.find(pattern_name, "Strum") then
          changed, strum_delay_ppq = reaper.ImGui_SliderInt(ctx, T("arp_strum_delay_label"), strum_delay_ppq, 1, 100)
          changed, strum_groove = reaper.ImGui_SliderInt(ctx, T("arp_strum_velocity_label"), strum_groove, 0, 100)
          if reaper.ImGui_IsItemHovered(ctx) then reaper.ImGui_SetTooltip(ctx, T("tooltip_arp_strum_velocity")) end
        elseif pattern_name ~= "None" then
          changed, arp_rate = reaper.ImGui_Combo(ctx, T("arp_rate_label"), arp_rate, table.concat(arp_rate_options, "\0") .. "\0")
        end

        if reaper.ImGui_Button(ctx, T("arp_apply_button")) then apply_arp = true end
        if reaper.ImGui_IsItemHovered(ctx) then reaper.ImGui_SetTooltip(ctx, T("tooltip_arp_apply")) end
        if #arp_undo_stack > 0 then
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, T("undo_arp_button")) then undo_arp_trigger = true end
        end

        reaper.ImGui_Separator(ctx)
        
        -- Rhythm Pattern Application
        reaper.ImGui_Text(ctx, T("rhythm_section_title"))
        changed, selected_rhythm_pattern = reaper.ImGui_Combo(ctx, T("rhythm_pattern_label"), selected_rhythm_pattern, table.concat(rhythm_pattern_options, "\0") .. "\0")
        if reaper.ImGui_Button(ctx, T("rhythm_apply_button")) then apply_rhythm_trigger = true end
        if reaper.ImGui_IsItemHovered(ctx) then reaper.ImGui_SetTooltip(ctx, T("tooltip_rhythm_apply")) end

        
        reaper.ImGui_EndTabItem(ctx)
      end
      
      reaper.ImGui_EndTabBar(ctx)
    end
    
    if generation_info ~= "" then
      reaper.ImGui_Separator(ctx)
      reaper.ImGui_Text(ctx, generation_info)
    end

    reaper.ImGui_Separator(ctx)
    if reaper.ImGui_Button(ctx, T("donate_button")) then
        reaper.CF_ShellExecute("[https://paypal.me/nkstudio](https://paypal.me/nkstudio)")
    end
    
    -- Language button on the same line, aligned to the right
    local lang_button_text = available_languages[selected_language_index+1]
    local text_width_x, _ = reaper.ImGui_CalcTextSize(ctx, lang_button_text)
    local frame_padding_x, _ = reaper.ImGui_GetStyleVar(ctx, 1) -- 1 is ImGui_StyleVar_FramePadding
    local button_width = text_width_x + (frame_padding_x * 2)
    
    local content_width, _ = reaper.ImGui_GetContentRegionAvail(ctx)
    
    -- Position the button on the same line, aligned to the far right of the content area
    reaper.ImGui_SameLine(ctx, content_width - button_width)

    if reaper.ImGui_Button(ctx, lang_button_text) then
        reaper.ImGui_OpenPopup(ctx, "language_popup")
    end
    
    if reaper.ImGui_BeginPopup(ctx, "language_popup") then
        for i, lang_name in ipairs(available_languages) do
            if reaper.ImGui_MenuItem(ctx, lang_name) then
                if selected_language_index ~= (i - 1) then
                    selected_language_index = i - 1
                    L = LangData[language_keys[selected_language_index + 1]]
                end
            end
        end
        reaper.ImGui_EndPopup(ctx)
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
    generation_info = string.format(T("feedback_generated"), final_scale_info.name, final_scale_type_name)

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
    
    -- This flag must be based on the FINAL scale, for modal interchange to work correctly.
    local is_major_final = string.find(final_scale_type_name:lower(), "major") 
                         or string.find(final_scale_type_name:lower(), "ionian") 
                         or string.find(final_scale_type_name:lower(), "lydian") 
                         or string.find(final_scale_type_name:lower(), "mixolydian")

    -- 7. Pre-process degrees for secondary dominants (NEW v3.2)
    local degrees_specs = {}
    if add_secondary_dominants then
        local chord_types_major = {"major", "minor", "minor", "major", "major", "minor", "diminished"}
        local chord_types_minor = {"minor", "diminished", "major", "minor", "minor", "major", "major"}
        local chord_types = is_major_final and chord_types_major or chord_types_minor
        
        for i, degree in ipairs(degrees_to_generate) do
            local chord_quality = chord_types[degree]
            local is_valid_target = degree ~= 1 and (chord_quality == 'major' or chord_quality == 'minor')
            
            if is_valid_target and math.random() < 0.5 then
                table.insert(degrees_specs, { is_secondary_dominant = true, target_degree = degree })
            end
            table.insert(degrees_specs, { is_secondary_dominant = false, degree = degree })
        end
    else
        for _, degree in ipairs(degrees_to_generate) do
            table.insert(degrees_specs, { is_secondary_dominant = false, degree = degree })
        end
    end

    -- 8. Create the chord progression
    local chords = createChordProgression(scale_notes, degrees_specs, is_major_final, complexity, root_note_pitch)

    -- 9. Insert chords into the MIDI item
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
        
        -- UPDATED MELODY LOGIC (v3.1)
        local analyzed_chords, overall_scale = analyzeChordsAndScale(take)
        
        if #analyzed_chords > 0 then
          local contour_choice = melody_contour_options[selected_melody_contour + 1]
          local melody = generateMelody(take, analyzed_chords, overall_scale, melody_density, melody_octave_min, melody_octave_max, item_start_ppq, item_length_ppq, contour_choice, melody_target_chord_tones)
          insertMelody(take, melody)
        else
          reaper.ShowMessageBox(T("melody_error_no_chords"), T("melody_section_title"), 0)
        end
        
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

  if apply_rhythm_trigger then
      local pattern_name = rhythm_pattern_options[selected_rhythm_pattern + 1]
      if pattern_name and pattern_name ~= "None" then
          local item = reaper.GetSelectedMediaItem(0, 0)
          if item then
              local take = reaper.GetMediaItemTake(item, 0)
              if take and reaper.TakeIsMIDI(take) then
                  local initialNotes = getInitialState()
                  if not initialNotes then
                      reaper.ShowConsoleMsg(T("rhythm_error_no_state"))
                  else
                      reaper.Undo_BeginBlock()
                      if pattern_name == "Random" then
                          changeRhythmRandomly(take, initialNotes)
                      else
                          local selected_pattern_data
                          for _, p in ipairs(rhythm_patterns) do
                              if p.name == pattern_name then
                                  selected_pattern_data = p
                                  break
                              end
                          end
                          if selected_pattern_data then
                              applyRhythmPattern(take, initialNotes, selected_pattern_data.pattern)
                          end
                      end
                      reaper.Undo_EndBlock("Apply Rhythm", -1)
                  end
              end
          end
      end
      apply_rhythm_trigger = false
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

