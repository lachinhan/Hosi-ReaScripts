-- @description Library file for Reanspiration script. Contains chord progressions, bass patterns, rhythm, and drum patterns.
-- @version 2.3 (MIDI Channel Update)
-- @author Hosi
-- @about
--   This is a library file required by the main 'Hosi_Reanspiration_3.lua' script.
--   It must be placed in the same directory as the main script.
--   You can safely edit this file to add your own custom chord progressions, bass, rhythm, and drum patterns.

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
        func = function(take, position, chord_length, chord_data, root_note, next_root_pc, channel)
            reaper.MIDI_InsertNote(take, false, false, position, position + chord_length, channel, root_note, 100, true)
        end
    },
    {
        name = "Root + Fifth",
        func = function(take, position, chord_length, chord_data, root_note, next_root_pc, channel)
            local half_length = chord_length / 2
            local fifth_note = root_note + 7
            reaper.MIDI_InsertNote(take, false, false, position, position + half_length, channel, root_note, 100, true)
            reaper.MIDI_InsertNote(take, false, false, position + half_length, position + chord_length, channel, fifth_note, 100, true)
        end
    },
    -- Added Patterns --
    {
        name = "Quarter Notes",
        func = function(take, position, chord_length, chord_data, root_note, next_root_pc, channel)
            local quarter_length = chord_length / 4
            reaper.MIDI_InsertNote(take, false, false, position, position + quarter_length, channel, root_note, 100, true)
            reaper.MIDI_InsertNote(take, false, false, position + quarter_length, position + 2*quarter_length, channel, root_note, 95, true)
            reaper.MIDI_InsertNote(take, false, false, position + 2*quarter_length, position + 3*quarter_length, channel, root_note, 95, true)
            reaper.MIDI_InsertNote(take, false, false, position + 3*quarter_length, position + chord_length, channel, root_note, 95, true)
        end
    },
    -- NEW POP PATTERNS --
    {
        name = "Pop - Pushing 8ths",
        func = function(take, position, chord_length, chord_data, root_note, next_root_pc, channel)
            local eighth_length = chord_length / 8
            for i = 0, 7 do
                reaper.MIDI_InsertNote(take, false, false, position + i*eighth_length, position + (i+1)*eighth_length, channel, root_note, 100 - i*2, true)
            end
        end
    },
    {
        name = "Pop - Synth Octaves",
        func = function(take, position, chord_length, chord_data, root_note, next_root_pc, channel)
            local eighth = chord_length / 8
            reaper.MIDI_InsertNote(take, false, false, position, position + eighth, channel, root_note, 100, true)
            reaper.MIDI_InsertNote(take, false, false, position + 2*eighth, position + 3*eighth, channel, root_note, 95, true)
            reaper.MIDI_InsertNote(take, false, false, position + 4*eighth, position + 5*eighth, channel, root_note+12, 100, true)
            reaper.MIDI_InsertNote(take, false, false, position + 6*eighth, position + 7*eighth, channel, root_note, 95, true)
        end
    },
    {
        name = "Pop - Ballad",
        func = function(take, position, chord_length, chord_data, root_note, next_root_pc, channel)
            local half = chord_length / 2
            reaper.MIDI_InsertNote(take, false, false, position, position + half, channel, root_note, 100, true)
            reaper.MIDI_InsertNote(take, false, false, position + half, position + half + chord_length / 4, channel, root_note+7, 90, true)
        end
    },
    -- Added Patterns Continued --
    {
        name = "Alberti Bass",
        func = function(take, position, chord_length, chord_data, root_note, next_root_pc, channel)
            local quarter_length = chord_length / 4
            local third_note = root_note + (chord_data.is_major and 4 or 3)
            local fifth_note = root_note + 7
            reaper.MIDI_InsertNote(take, false, false, position, position + quarter_length, channel, root_note, 100, true)
            reaper.MIDI_InsertNote(take, false, false, position + quarter_length, position + 2*quarter_length, channel, fifth_note, 95, true)
            reaper.MIDI_InsertNote(take, false, false, position + 2*quarter_length, position + 3*quarter_length, channel, third_note, 95, true)
            reaper.MIDI_InsertNote(take, false, false, position + 3*quarter_length, position + chord_length, channel, fifth_note, 95, true)
        end
    },
    {
        name = "Funk Groove",
        func = function(take, position, chord_length, chord_data, root_note, next_root_pc, channel)
            local sixteenth = chord_length / 16
            reaper.MIDI_InsertNote(take, false, false, position, position + sixteenth, channel, root_note, 100, true)
            reaper.MIDI_InsertNote(take, false, false, position + 2*sixteenth, position + 3*sixteenth, channel, root_note, 90, true)
            reaper.MIDI_InsertNote(take, false, false, position + 5*sixteenth, position + 6*sixteenth, channel, root_note + 12, 95, true)
            reaper.MIDI_InsertNote(take, false, false, position + 6*sixteenth, position + 7*sixteenth, channel, root_note, 90, true)
            reaper.MIDI_InsertNote(take, false, false, position + 10*sixteenth, position + 11*sixteenth, channel, root_note, 95, true)
            reaper.MIDI_InsertNote(take, false, false, position + 14*sixteenth, position + 15*sixteenth, channel, root_note, 95, true)
        end
    },
    {
        name = "Reggae 'One Drop'",
        func = function(take, position, chord_length, chord_data, root_note, next_root_pc, channel)
            local half_length = chord_length / 2
            -- Note on beat 3
            reaper.MIDI_InsertNote(take, false, false, position + half_length, position + chord_length, channel, root_note, 100, true)
        end
    },
    -- Original Patterns Continued
    {
        name = "Simple Walk",
        func = function(take, position, chord_length, chord_data, root_note, next_root_pc, channel)
            local quarter_length = chord_length / 4
            local root_note_pc = root_note % 12
            local third_note = root_note + (chord_data.is_major and 4 or 3)
            local fifth_note = root_note + 7
            
            reaper.MIDI_InsertNote(take, false, false, position, position + quarter_length, channel, root_note, 100, true)
            reaper.MIDI_InsertNote(take, false, false, position + quarter_length, position + 2*quarter_length, channel, third_note, 95, true)
            reaper.MIDI_InsertNote(take, false, false, position + 2*quarter_length, position + 3*quarter_length, channel, fifth_note, 95, true)
            
            local passing_note
            if (next_root_pc - root_note_pc) % 12 > 6 then -- Descending motion is shorter
                passing_note = root_note + ((next_root_pc - root_note_pc) % 12) - 12 + 1
            else -- Ascending motion is shorter
                passing_note = root_note + ((next_root_pc - root_note_pc) % 12) -1
            end
            reaper.MIDI_InsertNote(take, false, false, position + 3*quarter_length, position + chord_length, channel, passing_note, 90, true)
        end
    },
    {
        name = "Arpeggio Up",
        func = function(take, position, chord_length, chord_data, root_note, next_root_pc, channel)
            local third_length = chord_length / 3
            local third_note = root_note + (chord_data.is_major and 4 or 3)
            local fifth_note = root_note + 7
            reaper.MIDI_InsertNote(take, false, false, position, position + third_length, channel, root_note, 100, true)
            reaper.MIDI_InsertNote(take, false, false, position + third_length, position + 2 * third_length, channel, third_note, 95, true)
            reaper.MIDI_InsertNote(take, false, false, position + 2 * third_length, position + chord_length, channel, fifth_note, 95, true)
        end
    },
    {
        name = "Pop Rhythm",
        func = function(take, position, chord_length, chord_data, root_note, next_root_pc, channel)
            local quarter_length = chord_length / 4
            local eighth_length = chord_length / 8
            reaper.MIDI_InsertNote(take, false, false, position, position + quarter_length, channel, root_note, 100, true)
            reaper.MIDI_InsertNote(take, false, false, position + 2 * quarter_length, position + 2 * quarter_length + eighth_length, channel, root_note, 95, true)
            reaper.MIDI_InsertNote(take, false, false, position + 2 * quarter_length + eighth_length, position + 3 * quarter_length, channel, root_note, 95, true)
        end
    },
    {
        name = "Octaves",
        func = function(take, position, chord_length, chord_data, root_note, next_root_pc, channel)
            local half_length = chord_length / 2
            local octave_note = root_note + 12
            reaper.MIDI_InsertNote(take, false, false, position, position + half_length, channel, root_note, 100, true)
            reaper.MIDI_InsertNote(take, false, false, position + half_length, position + chord_length, channel, octave_note, 95, true)
        end
    },
    {
        name = "Classic Rock",
        func = function(take, position, chord_length, chord_data, root_note, next_root_pc, channel)
            local quarter_len = chord_length / 4
            local eighth_len = chord_length / 8
            reaper.MIDI_InsertNote(take, false, false, position, position + quarter_len, channel, root_note, 100, true)
            reaper.MIDI_InsertNote(take, false, false, position + quarter_len + eighth_len, position + 2*quarter_len, channel, root_note, 95, true)
            reaper.MIDI_InsertNote(take, false, false, position + 2*quarter_len, position + 3*quarter_len, channel, root_note, 95, true)
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

-------------------------------------------
-- 4. DRUM PATTERN LIBRARY (NEW v2.2)
-------------------------------------------
-- To add a new drum pattern:
--   a) Add a new entry to the M.drum_patterns table.
--   b) Give it a 'name' for the GUI.
--   c) Define the 'pattern' table. This is a list of instruments.
--   d) Each instrument has:
--      - 'pitch': The MIDI note number (GM Standard: 36=Kick, 38=Snare, 42=Closed Hat).
--      - 'vel': The MIDI velocity (1-127).
--      - 'positions': A table of start positions as a fraction of a 4-beat measure (0.0 to 1.0).
--         - 0.0 = Beat 1, 0.25 = Beat 2, 0.5 = Beat 3, 0.75 = Beat 4
--         - 0.125 = 8th note upbeat, etc.
M.drum_patterns = {
    {
        name = "Pop/Rock - Four on the Floor",
        pattern = {
            { pitch = 36, vel = 120, positions = {0, 0.25, 0.5, 0.75} }, -- Kick
            { pitch = 38, vel = 110, positions = {0.25, 0.75} }, -- Snare
            { pitch = 42, vel = 90,  positions = {0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875} } -- Hi-hat 8ths
        }
    },
    {
        name = "Basic Rock",
        pattern = {
            { pitch = 36, vel = 120, positions = {0, 0.5} }, -- Kick
            { pitch = 38, vel = 110, positions = {0.25, 0.75} }, -- Snare
            { pitch = 42, vel = 90,  positions = {0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875} } -- Hi-hat 8ths
        }
    },
    {
        name = "Hip-Hop - Classic",
        pattern = {
            { pitch = 36, vel = 125, positions = {0, 0.0625, 0.5, 0.5625} }, -- Kick
            { pitch = 38, vel = 115, positions = {0.25, 0.75} }, -- Snare
            { pitch = 42, vel = 90,  positions = {0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875} } -- Hi-hat 8ths
        }
    },
    {
        name = "Hip-Hop - Modern",
        pattern = {
            { pitch = 36, vel = 125, positions = {0, 0.375, 0.5} }, -- Kick
            { pitch = 38, vel = 115, positions = {0.25, 0.75} }, -- Snare
            { pitch = 42, vel = 80,  positions = {0, 0.0625, 0.125, 0.1875, 0.25, 0.3125, 0.375, 0.4375, 0.5, 0.5625, 0.625, 0.6875, 0.75, 0.8125, 0.875, 0.9375} } -- Hi-hat 16ths
        }
    },
    {
        name = "Trap",
        pattern = {
            { pitch = 36, vel = 127, positions = {0, 0.3125, 0.6875} }, -- Kick
            { pitch = 38, vel = 120, positions = {0.5} }, -- Snare on 3
            { pitch = 42, vel = 90,  positions = {0, 0.125, 0.25, 0.375, 0.5, 0.5625, 0.625, 0.6875, 0.75, 0.875} }, -- Hi-hat with rolls
            { pitch = 46, vel = 100, positions = {0.9375} } -- Open Hat
        }
    },
    {
        name = "Dubstep",
        pattern = {
            { pitch = 36, vel = 127, positions = {0, 0.625} }, -- Kick
            { pitch = 38, vel = 125, positions = {0.5} }, -- Snare on 3
            { pitch = 42, vel = 90,  positions = {0.1875, 0.4375, 0.6875, 0.9375} }, -- Closed Hat
            { pitch = 46, vel = 100, positions = {0.3125} } -- Open Hat
        }
    },
    {
        name = "UK Garage",
        pattern = {
            { pitch = 36, vel = 120, positions = {0, 0.375, 0.625} }, -- Kick
            { pitch = 39, vel = 110, positions = {0.25, 0.75} }, -- Clap
            { pitch = 42, vel = 100, positions = {0.125, 0.625} }, -- Closed Hat
            { pitch = 46, vel = 105, positions = {0.875} }, -- Open Hat
            { pitch = 47, vel = 95,  positions = {0.1875} } -- Mid Tom
        }
    },
    {
        name = "Drum 'N' Bass",
        pattern = {
            { pitch = 36, vel = 125, positions = {0, 0.625} }, -- Kick
            { pitch = 38, vel = 120, positions = {0.25, 0.75} }, -- Snare
            { pitch = 42, vel = 100, positions = {0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875} }, -- Closed Hat 8ths
            { pitch = 46, vel = 110, positions = {0.4375, 0.9375} } -- Open Hat
        }
    },
    {
        name = "Deep House",
        pattern = {
            { pitch = 36, vel = 115, positions = {0, 0.25, 0.5, 0.75} }, -- Kick
            { pitch = 39, vel = 105, positions = {0.25, 0.75} }, -- Clap
            { pitch = 42, vel = 90,  positions = {0, 0.25, 0.5, 0.75} }, -- Closed Hat on beat
            { pitch = 46, vel = 100, positions = {0.125, 0.375, 0.625, 0.875} } -- Open Hat off-beat
        }
    },
    {
        name = "Disco",
        pattern = {
            { pitch = 36, vel = 120, positions = {0, 0.25, 0.5, 0.75} }, -- Kick
            { pitch = 38, vel = 110, positions = {0.25, 0.75} }, -- Snare
            { pitch = 46, vel = 100, positions = {0.125, 0.375, 0.625, 0.875} } -- Open Hi-hat on the off-beats
        }
    },
    {
        name = "Reggae 'One Drop' Beat",
        pattern = {
            { pitch = 36, vel = 110, positions = {0.5} }, -- Kick on beat 3
            { pitch = 40, vel = 120, positions = {0.5} }, -- Rimshot/Snare on beat 3
            { pitch = 42, vel = 90,  positions = {0.125, 0.375, 0.625, 0.875} } -- Hi-hat on off-beats
        }
    },
    -- NEW PATTERNS FROM REFERENCE
    {
        name = "Rock - 80s Beat",
        pattern = {
            { pitch = 36, vel = 120, positions = {0, 0.375, 0.5} }, -- Kick
            { pitch = 38, vel = 110, positions = {0.25, 0.75} }, -- Snare
            { pitch = 42, vel = 95,  positions = {0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875} } -- Hi-hat
        }
    },
    {
        name = "Pop - Syncopated Kick",
        pattern = {
            { pitch = 36, vel = 125, positions = {0, 0.1875, 0.375, 0.625, 0.8125} }, -- Kick
            { pitch = 38, vel = 115, positions = {0.25, 0.75} }, -- Snare
            { pitch = 42, vel = 90,  positions = {0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875} } -- Hi-hat
        }
    },
    {
        name = "Motown Beat",
        pattern = {
            { pitch = 36, vel = 115, positions = {0, 0.25, 0.5, 0.75} }, -- Kick
            { pitch = 38, vel = 120, positions = {0.25, 0.75} }, -- Snare
            { pitch = 54, vel = 100, positions = {0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875} } -- Tambourine
        }
    },
    {
        name = "Slow Blues Shuffle",
        pattern = {
            { pitch = 36, vel = 110, positions = {0, 0.375} }, -- Kick
            { pitch = 38, vel = 100, positions = {0.25, 0.75} }, -- Snare
            { pitch = 51, vel = 90,  positions = {0, 0.1875, 0.25, 0.375, 0.5625, 0.625, 0.75} } -- Ride Cymbal with swing feel
        }
    },
    {
        name = "Shuffle Feel",
        pattern = {
            { pitch = 36, vel = 115, positions = {0, 0.25, 0.5, 0.75} }, -- Kick
            { pitch = 38, vel = 110, positions = {0.25, 0.75} }, -- Snare
            { pitch = 42, vel = 90,  positions = {0, 0.1875, 0.375, 0.5625, 0.75} } -- Hi-hat with shuffle feel
        }
    },
    {
        name = "Funk - Syncopated Snare",
        pattern = {
            { pitch = 36, vel = 125, positions = {0, 0.4375, 0.625} }, -- Kick
            { pitch = 38, vel = 120, positions = {0.1875, 0.75} }, -- Snare
            { pitch = 42, vel = 95,  positions = {0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875} }, -- Closed Hat
            { pitch = 46, vel = 105, positions = {0.9375} } -- Open Hat
        }
    },
    {
        name = "Funk - Tom Groove",
        pattern = {
            { pitch = 36, vel = 120, positions = {0, 0.1875, 0.4375, 0.8125} }, -- Kick
            { pitch = 38, vel = 115, positions = {0.3125, 0.75} }, -- Snare
            { pitch = 42, vel = 100, positions = {0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875} }, -- Closed Hat
            { pitch = 50, vel = 110, positions = {0.625} }, -- High Tom
            { pitch = 45, vel = 110, positions = {0.875} }  -- Low Tom
        }
    },
    -- NEW PATTERNS FROM CHEAT SHEET PDF
    {
        name = "Riddim",
        pattern = {
            { pitch = 36, vel = 125, positions = {0, 0.5} }, -- Kick
            { pitch = 38, vel = 115, positions = {0.25, 0.75} }, -- Snare
            { pitch = 39, vel = 105, positions = {0.25, 0.75} }, -- Clap
            { pitch = 42, vel = 90,  positions = {0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875} } -- Closed Hat 8ths
        }
    },
    {
        name = "Hip-Hop - Dirty South",
        pattern = {
            { pitch = 36, vel = 127, positions = {0, 0.25, 0.875} }, -- Kick & Sub Kick
            { pitch = 38, vel = 110, positions = {0.25, 0.75} }, -- Snare
            { pitch = 40, vel = 100, positions = {0.75, 0.9375} }, -- Clave (using Rimshot)
            { pitch = 42, vel = 90,  positions = {0, 0.25, 0.5, 0.75} }, -- Closed Hat 4ths
            { pitch = 46, vel = 100, positions = {0.375} } -- Open Hat
        }
    },
    {
        name = "Moombahton",
        pattern = {
            { pitch = 36, vel = 120, positions = {0, 0.375, 0.75, 0.875} }, -- Kick
            { pitch = 38, vel = 115, positions = {0.25, 0.625} }, -- Snare
            { pitch = 42, vel = 95,  positions = {0.1875, 0.6875} } -- Closed Hat
        }
    },
    {
        name = "Classic House",
        pattern = {
            { pitch = 36, vel = 120, positions = {0, 0.25, 0.5, 0.75} }, -- Kick
            { pitch = 38, vel = 110, positions = {0.25, 0.75} }, -- Snare
            { pitch = 42, vel = 90,  positions = {0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875} }, -- Closed Hat 8ths
            { pitch = 46, vel = 100, positions = {0.125, 0.375, 0.625, 0.875} } -- Open Hat off-beat
        }
    },
    {
        name = "Trance",
        pattern = {
            { pitch = 36, vel = 127, positions = {0, 0.25, 0.5, 0.75} }, -- Kick
            { pitch = 39, vel = 110, positions = {0.25, 0.75} }, -- Clap
            { pitch = 42, vel = 90,  positions = {0, 0.0625, 0.125, 0.1875, 0.25, 0.3125, 0.375, 0.4375, 0.5, 0.5625, 0.625, 0.6875, 0.75, 0.8125, 0.875, 0.9375} }, -- Closed Hat 16ths
            { pitch = 46, vel = 105, positions = {0.125, 0.375, 0.625, 0.875} } -- Open Hat off-beat
        }
    },
    {
        name = "Trap - Variant",
        pattern = {
            { pitch = 36, vel = 127, positions = {0, 0.5625} }, -- Kick
            { pitch = 38, vel = 115, positions = {0.25, 0.75} }, -- Snare
            { pitch = 46, vel = 100, positions = {0.125} } -- Open Hat
        }
    },
    {
        name = "Hip-Hop - 16th Hats",
        pattern = {
            { pitch = 36, vel = 120, positions = {0, 0.1875, 0.375, 0.625} }, -- Kick
            { pitch = 38, vel = 115, positions = {0.25, 0.75} }, -- Snare
            { pitch = 42, vel = 85,  positions = {0, 0.0625, 0.125, 0.1875, 0.25, 0.3125, 0.375, 0.4375, 0.5, 0.5625, 0.625, 0.6875, 0.75, 0.8125, 0.875, 0.9375} } -- Hi-hat 16ths
        }
    },
    {
        name = "Dubstep - Half-Time Variant",
        pattern = {
            { pitch = 36, vel = 127, positions = {0} }, -- Kick
            { pitch = 38, vel = 125, positions = {0.5} }, -- Snare
            { pitch = 42, vel = 90,  positions = {0.375, 0.875} }, -- Closed Hat
            { pitch = 46, vel = 100, positions = {0.125, 0.625} } -- Open Hat
        }
    },
    {
        name = "Deep House - Variant",
        pattern = {
            { pitch = 36, vel = 120, positions = {0, 0.25, 0.5, 0.75} }, -- Kick
            { pitch = 39, vel = 110, positions = {0.25, 0.75} }, -- Clap
            { pitch = 42, vel = 90,  positions = {0, 0.5} }, -- Closed Hat (simplified from image)
            { pitch = 46, vel = 100, positions = {0.125, 0.375, 0.625, 0.875} } -- Open Hat off-beat
        }
    },
    {
        name = "Jungle Breakbeat",
        pattern = {
            { pitch = 36, vel = 125, positions = {0, 0.5625} }, -- Kick
            { pitch = 38, vel = 120, positions = {0.25, 0.6875, 0.75} }, -- Snare
            { pitch = 42, vel = 100, positions = {0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.875} }, -- Closed Hat
            { pitch = 46, vel = 110, positions = {0.75} } -- Open Hat (with snare)
        }
    },
    {
        name = "Salsa Tumbao",
        pattern = {
            { pitch = 36, vel = 90, positions = {0, 0.5} }, -- Kick (Tumbadora bass)
            { pitch = 75, vel = 110, positions = {0, 0.1875, 0.375, 0.625, 0.75} }, -- Clave
            { pitch = 63, vel = 100, positions = {0.25, 0.75} }, -- High Conga (Slap)
            { pitch = 64, vel = 105, positions = {0.375, 0.875} }, -- Low Conga (Open)
            { pitch = 40, vel = 80, positions = {0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875} } -- Rimshot (Cascara simulation)
        }
    },
    {
        name = "R&B - Beat Starter",
        pattern = {
            { pitch = 36, vel = 127, positions = {0} }, -- Kick
            { pitch = 38, vel = 100, positions = {0.375, 0.875} }, -- Snare (Less Velocity)
            { pitch = 42, vel = 127, positions = {0, 0.125, 0.25, 0.4375, 0.5, 0.625, 0.75, 0.9375} }, -- Closed Hats (Full Velocity)
            { pitch = 42, vel = 100, positions = {0.0625, 0.5625} }, -- Closed Hats (Less Velocity)
            { pitch = 46, vel = 100, positions = {0.3125, 0.8125} }  -- Open Hats (Less Velocity)
        }
    },
    {
        name = "Trap - Beat Starter",
        pattern = {
            { pitch = 36, vel = 127, positions = {0, 0.0625, 0.5, 0.8125, 0.875} }, -- Kick
            { pitch = 38, vel = 100, positions = {0.375, 0.875} }, -- Snare
            { pitch = 42, vel = 127, positions = {0, 0.25, 0.5, 0.6875, 0.75} }, -- Closed Hats (Full Velocity)
            { pitch = 42, vel = 100, positions = {0.125, 0.375, 0.5625, 0.625, 0.8125, 0.875, 0.9375} }  -- Closed Hats (Less Velocity)
        }
    },
	{
        name = "Trap - Beat Starter 8",
        pattern = {
            { pitch = 36, vel = 127, positions = {0, 0.125, 0.75} }, -- Kick
            { pitch = 38, vel = 100, positions = {0.25, 0.75} }, -- Snare
            { pitch = 42, vel = 127, positions = {0, 0.25, 0.5, 0.75} }, -- Closed Hats (Full Velocity)
            { pitch = 42, vel = 100, positions = {0.125, 0.375, 0.625, 0.875} }  -- Closed Hats (Less Velocity)
        }
    }
}


-- This is essential for the main script to be able to load the library.
return M

