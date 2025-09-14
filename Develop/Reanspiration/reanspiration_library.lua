-- @description Library file for Reanspiration script. Contains chord progressions, bass patterns, and rhythm patterns.
-- @version 2.1 (Expanded with more Pop patterns by Gemini)
-- @author Hosi
-- @provides [main]Reanspiration - Library
-- @about
--   This is a library file required by the main 'Hosi_Reanspiration_3.lua' script.
--   It must be placed in the same directory as the main script.
--   You can safely edit this file to add your own custom chord progressions, bass, and rhythm patterns.

local M = {}

-------------------------------------------
-- 1. CHORD PROGRESSION LIBRARY
-------------------------------------------
-- To add a progression, add a new entry to the 'major' or 'minor' tables.
-- The key is the name that will appear in the GUI (e.g., ["My Progression (I-ii-iii)"]).
-- The value is a table of numbers representing the scale degrees (e.g., {1, 2, 3}).

M.chord_progressions = {
  major = {
    -- Original Progressions
    ["Pop 1 (I-V-vi-IV)"] = {1, 5, 6, 4},
    ["Pop 2 (I-vi-IV-V)"] = {1, 6, 4, 5},
    ["Jazz (ii-V-I)"] = {2, 5, 1, 1},
    ["50s (I-vi-ii-V)"] = {1, 6, 2, 5},
    ["Canon (I-V-vi-iii-IV-I-IV-V)"] = {1, 5, 6, 3, 4, 1, 4, 5},
    ["Rock Anthem (I-IV-V)"] = {1, 4, 5, 5},
    ["Sensitive Pop (vi-IV-I-V)"] = {6, 4, 1, 5},
    ["Modern Pop (I-V-vi-iii)"] = {1, 5, 6, 3},
    ["Ascending (IV-V-vi)"] = {4, 5, 6, 6},
    
    -- Added Progressions --
    ["Royal Road (IV-V-iii-vi)"] = {4, 5, 3, 6},
    ["Folk (I-IV-I-V)"] = {1, 4, 1, 5},
    ["Ascending Bass (I-ii-iii-IV)"] = {1, 2, 3, 4},
    ["Gospel (I-iii-IV-V)"] = {1, 3, 4, 5},
    ["Classic Rock (I-bVII-IV-I)"] = {1, 7, 4, 1},
    ["Lydian Dream (I-II-V-I)"] = {1, 2, 5, 1},
    ["Doo-Wop (I-IV-V-IV)"] = {1, 4, 5, 4},

    -- NEW POP PROGRESSIONS --
    ["EDM Pop (vi-IV-I-V)"] = {6, 4, 1, 5},
    ["Simple Pop (I-IV-V-IV)"] = {1, 4, 5, 4},
    ["Uplifting Pop (IV-I-V-vi)"] = {4, 1, 5, 6}
  },
  minor = {
    -- Original Progressions
    ["Standard (i-VI-III-VII)"] = {1, 6, 3, 7},
    ["Pop (i-iv-v-i)"] = {1, 4, 5, 1},
    ["Jazz (ii°-v-i)"] = {2, 5, 1, 1},
    ["Andalusian Cadence (i-VII-VI-V)"] = {1, 7, 6, 5},
    ["Rock Ballad (i-VI-iv-v)"] = {1, 6, 4, 5},
    ["Cinematic (i-iv-VII-III)"] = {1, 4, 7, 3},
    ["Dark Pop (i-VII-VI-iv)"] = {1, 7, 6, 4},
    ["Classic Minor (i-iv-v-VI)"] = {1, 4, 5, 6},

    -- Added Progressions --
    ["Dorian Groove (i-IV-i-IV)"] = {1, 4, 1, 4},
    ["Sad Descending (i-v-iv-III)"] = {1, 5, 4, 3},
    ["Phrygian Metal (i-II-i-v)"] = {1, 2, 1, 5},
    ["Sentimental (i-v-VI-V)"] = {1, 5, 6, 5},
    ["James Bond (i-bVI-V)"] = {1, 6, 5, 5},
    ["Pop/R&B (i-VII-v-VI)"] = {1, 7, 5, 6},

    -- NEW POP PROGRESSIONS --
    ["Trap/HipHop (i-VI-VII-i)"] = {1, 6, 7, 1},
    ["Emotional Pop (VI-VII-i-v)"] = {6, 7, 1, 5}
  }
}

-------------------------------------------
-- 2. BASS PATTERN LIBRARY
-------------------------------------------
-- To add a new bass pattern:
--   a) Copy and paste an existing pattern block.
--   b) Change the 'name' to what you want to see in the GUI.
--   c) Edit the 'func' (function) to create the MIDI notes for your pattern.
-- The list below is ordered. The order you define them in here is the order they will appear in the GUI.

M.bass_patterns = {
    -- Original Patterns
    {
        name = "Root Notes",
        func = function(take, position, chord_length, chord_data, root_note, next_root_pc)
            reaper.MIDI_InsertNote(take, false, false, position, position + chord_length, 0, root_note, 100, true)
        end
    },
    {
        name = "Root + Fifth",
        func = function(take, position, chord_length, chord_data, root_note, next_root_pc)
            local half_length = chord_length / 2
            local fifth_note = root_note + 7
            reaper.MIDI_InsertNote(take, false, false, position, position + half_length, 0, root_note, 100, true)
            reaper.MIDI_InsertNote(take, false, false, position + half_length, position + chord_length, 0, fifth_note, 100, true)
        end
    },
    -- Added Patterns --
    {
        name = "Quarter Notes",
        func = function(take, position, chord_length, chord_data, root_note, next_root_pc)
            local quarter_length = chord_length / 4
            reaper.MIDI_InsertNote(take, false, false, position, position + quarter_length, 0, root_note, 100, true)
            reaper.MIDI_InsertNote(take, false, false, position + quarter_length, position + 2*quarter_length, 0, root_note, 95, true)
            reaper.MIDI_InsertNote(take, false, false, position + 2*quarter_length, position + 3*quarter_length, 0, root_note, 95, true)
            reaper.MIDI_InsertNote(take, false, false, position + 3*quarter_length, position + chord_length, 0, root_note, 95, true)
        end
    },
    -- NEW POP PATTERNS --
    {
        name = "Pop - Pushing 8ths",
        func = function(take, position, chord_length, chord_data, root_note, next_root_pc)
            local eighth_length = chord_length / 8
            for i = 0, 7 do
                reaper.MIDI_InsertNote(take, false, false, position + i*eighth_length, position + (i+1)*eighth_length, 0, root_note, 100 - i*2, true)
            end
        end
    },
    {
        name = "Pop - Synth Octaves",
        func = function(take, position, chord_length, chord_data, root_note, next_root_pc)
            local eighth = chord_length / 8
            reaper.MIDI_InsertNote(take, false, false, position, position + eighth, 0, root_note, 100, true)
            reaper.MIDI_InsertNote(take, false, false, position + 2*eighth, position + 3*eighth, 0, root_note, 95, true)
            reaper.MIDI_InsertNote(take, false, false, position + 4*eighth, position + 5*eighth, 0, root_note+12, 100, true)
            reaper.MIDI_InsertNote(take, false, false, position + 6*eighth, position + 7*eighth, 0, root_note, 95, true)
        end
    },
    {
        name = "Pop - Ballad",
        func = function(take, position, chord_length, chord_data, root_note, next_root_pc)
            local half = chord_length / 2
            reaper.MIDI_InsertNote(take, false, false, position, position + half, 0, root_note, 100, true)
            reaper.MIDI_InsertNote(take, false, false, position + half, position + half + chord_length / 4, 0, root_note+7, 90, true)
        end
    },
    -- Added Patterns Continued --
    {
        name = "Alberti Bass",
        func = function(take, position, chord_length, chord_data, root_note, next_root_pc)
            local quarter_length = chord_length / 4
            local third_note = root_note + (chord_data.is_major and 4 or 3)
            local fifth_note = root_note + 7
            reaper.MIDI_InsertNote(take, false, false, position, position + quarter_length, 0, root_note, 100, true)
            reaper.MIDI_InsertNote(take, false, false, position + quarter_length, position + 2*quarter_length, 0, fifth_note, 95, true)
            reaper.MIDI_InsertNote(take, false, false, position + 2*quarter_length, position + 3*quarter_length, 0, third_note, 95, true)
            reaper.MIDI_InsertNote(take, false, false, position + 3*quarter_length, position + chord_length, 0, fifth_note, 95, true)
        end
    },
    {
        name = "Funk Groove",
        func = function(take, position, chord_length, chord_data, root_note, next_root_pc)
            local sixteenth = chord_length / 16
            reaper.MIDI_InsertNote(take, false, false, position, position + sixteenth, 0, root_note, 100, true)
            reaper.MIDI_InsertNote(take, false, false, position + 2*sixteenth, position + 3*sixteenth, 0, root_note, 90, true)
            reaper.MIDI_InsertNote(take, false, false, position + 5*sixteenth, position + 6*sixteenth, 0, root_note + 12, 95, true)
            reaper.MIDI_InsertNote(take, false, false, position + 6*sixteenth, position + 7*sixteenth, 0, root_note, 90, true)
            reaper.MIDI_InsertNote(take, false, false, position + 10*sixteenth, position + 11*sixteenth, 0, root_note, 95, true)
            reaper.MIDI_InsertNote(take, false, false, position + 14*sixteenth, position + 15*sixteenth, 0, root_note, 95, true)
        end
    },
    {
        name = "Reggae 'One Drop'",
        func = function(take, position, chord_length, chord_data, root_note, next_root_pc)
            local half_length = chord_length / 2
            -- Note on beat 3
            reaper.MIDI_InsertNote(take, false, false, position + half_length, position + chord_length, 0, root_note, 100, true)
        end
    },
    -- Original Patterns Continued
    {
        name = "Simple Walk",
        func = function(take, position, chord_length, chord_data, root_note, next_root_pc)
            local quarter_length = chord_length / 4
            local root_note_pc = root_note % 12
            local third_note = root_note + (chord_data.is_major and 4 or 3)
            local fifth_note = root_note + 7
            
            reaper.MIDI_InsertNote(take, false, false, position, position + quarter_length, 0, root_note, 100, true)
            reaper.MIDI_InsertNote(take, false, false, position + quarter_length, position + 2*quarter_length, 0, third_note, 95, true)
            reaper.MIDI_InsertNote(take, false, false, position + 2*quarter_length, position + 3*quarter_length, 0, fifth_note, 95, true)
            
            local passing_note
            if (next_root_pc - root_note_pc) % 12 > 6 then -- Descending motion is shorter
                passing_note = root_note + ((next_root_pc - root_note_pc) % 12) - 12 + 1
            else -- Ascending motion is shorter
                passing_note = root_note + ((next_root_pc - root_note_pc) % 12) -1
            end
            reaper.MIDI_InsertNote(take, false, false, position + 3*quarter_length, position + chord_length, 0, passing_note, 90, true)
        end
    },
    {
        name = "Arpeggio Up",
        func = function(take, position, chord_length, chord_data, root_note, next_root_pc)
            local third_length = chord_length / 3
            local third_note = root_note + (chord_data.is_major and 4 or 3)
            local fifth_note = root_note + 7
            reaper.MIDI_InsertNote(take, false, false, position, position + third_length, 0, root_note, 100, true)
            reaper.MIDI_InsertNote(take, false, false, position + third_length, position + 2 * third_length, 0, third_note, 95, true)
            reaper.MIDI_InsertNote(take, false, false, position + 2 * third_length, position + chord_length, 0, fifth_note, 95, true)
        end
    },
    {
        name = "Pop Rhythm",
        func = function(take, position, chord_length, chord_data, root_note, next_root_pc)
            local quarter_length = chord_length / 4
            local eighth_length = chord_length / 8
            reaper.MIDI_InsertNote(take, false, false, position, position + quarter_length, 0, root_note, 100, true)
            reaper.MIDI_InsertNote(take, false, false, position + 2 * quarter_length, position + 2 * quarter_length + eighth_length, 0, root_note, 95, true)
            reaper.MIDI_InsertNote(take, false, false, position + 2 * quarter_length + eighth_length, position + 3 * quarter_length, 0, root_note, 95, true)
        end
    },
    {
        name = "Octaves",
        func = function(take, position, chord_length, chord_data, root_note, next_root_pc)
            local half_length = chord_length / 2
            local octave_note = root_note + 12
            reaper.MIDI_InsertNote(take, false, false, position, position + half_length, 0, root_note, 100, true)
            reaper.MIDI_InsertNote(take, false, false, position + half_length, position + chord_length, 0, octave_note, 95, true)
        end
    },
    {
        name = "Classic Rock",
        func = function(take, position, chord_length, chord_data, root_note, next_root_pc)
            local quarter_len = chord_length / 4
            local eighth_len = chord_length / 8
            reaper.MIDI_InsertNote(take, false, false, position, position + quarter_len, 0, root_note, 100, true)
            reaper.MIDI_InsertNote(take, false, false, position + quarter_len + eighth_len, position + 2*quarter_len, 0, root_note, 95, true)
            reaper.MIDI_InsertNote(take, false, false, position + 2*quarter_len, position + 3*quarter_len, 0, root_note, 95, true)
        end
    }
}

-------------------------------------------
-- 3. RHYTHM PATTERN LIBRARY
-------------------------------------------
-- To add a new rhythm pattern:
--   a) Copy and paste an existing pattern block.
--   b) Change the 'name' to what you want to see in the GUI.
--   c) Edit the 'pattern' table. Each entry is a note with:
--      - 'start': The start position as a fraction of the total chord duration (0.0 to 1.0).
--      - 'duration': The note's duration as a fraction of the total chord duration.
M.rhythm_patterns = {
    {
        name = "Sustained", -- Default long chord
        pattern = {
            { start = 0, duration = 1 }
        }
    },
    {
        name = "Ballad",
        pattern = {
            { start = 0, duration = 0.5 },
            { start = 0.5, duration = 0.5 }
        }
    },
    -- Added Patterns --
    {
        name = "March",
        pattern = {
            { start = 0, duration = 0.25 },
            { start = 0.5, duration = 0.25 }
        }
    },
    -- NEW POP PATTERNS --
    {
        name = "Pop - Four on the Floor",
        pattern = {
            { start = 0, duration = 0.25 },
            { start = 0.25, duration = 0.25 },
            { start = 0.5, duration = 0.25 },
            { start = 0.75, duration = 0.25 }
        }
    },
    {
        name = "Pop - Modern Syncopation",
        pattern = {
            { start = 0, duration = 0.125 },
            { start = 0.375, duration = 0.125 },
            { start = 0.625, duration = 0.25 }
        }
    },
    {
        name = "Pop - Piano Ballad",
        pattern = {
            { start = 0, duration = 0.25 },
            { start = 0.375, duration = 0.125 },
            { start = 0.5, duration = 0.25 },
            { start = 0.875, duration = 0.125 }
        }
    },
    -- Added Patterns Continued
    {
        name = "Reggae Skank",
        pattern = {
            { start = 0.25, duration = 0.25 },
            { start = 0.75, duration = 0.25 }
        }
    },
    {
        name = "Waltz",
        pattern = {
            { start = 0, duration = 0.333 },
            { start = 0.333, duration = 0.333 },
            { start = 0.666, duration = 0.333 }
        }
    },
    {
        name = "Dotted 8th",
        pattern = {
            { start = 0, duration = 0.375 },
            { start = 0.375, duration = 0.125 },
            { start = 0.5, duration = 0.375 },
            { start = 0.875, duration = 0.125 }
        }
    },
    {
        name = "Power Ballad",
        pattern = {
            { start = 0, duration = 0.125 }, 
            { start = 0.125, duration = 0.125 },
            { start = 0.25, duration = 0.125 },
            { start = 0.375, duration = 0.625 }
        }
    },
    {
        name = "Funk Stabs",
        pattern = {
            { start = 0.125, duration = 0.125 },
            { start = 0.625, duration = 0.125 }
        }
    },
    -- Original Patterns Continued
    {
        name = "Syncopated Pop",
        pattern = {
            { start = 0.375, duration = 0.375 },
            { start = 0.75, duration = 0.25 }
        }
    },
    {
        name = "Bossa Nova",
        pattern = {
            { start = 0, duration = 0.375 },
            { start = 0.5, duration = 0.375 }
        }
    },
    {
        name = "Swing Quarters",
        pattern = {
            { start = 0, duration = 0.25 },
            { start = 0.333, duration = 0.25 },
            { start = 0.666, duration = 0.25 }
        }
    },
    {
        name = "Random",
        -- This is a special case handled by the main script to generate a random rhythm.
        pattern = {}
    }
}


-- This is essential for the main script to be able to load the library.
return M

