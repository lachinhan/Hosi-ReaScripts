--[[
@description    Import Chordino Chords to MIDI (Fixed with Snap to Grid)
@author         Hosi, X-Raym, ReaTrak
@version        2.1
@reaper_version 5.0
@about
  # Import Chordino Chords to MIDI

  Imports a .txt or .csv chord file from Chordino and directly creates MIDI items
  with the corresponding chords on a new track. The items will snap to the project grid.

  ## Instructions:
  1. Run the script from the Action List.
  2. Select a .txt or .csv file exported from Chordino.
  3. The script will create a new track with MIDI items representing the chords, snapped to the grid.
--]]


-- Configuration Area
local console = true -- true/false: display debug messages in the console
local col_pos = 1    -- Column index for chord start time in the CSV/TXT file
local col_name = 2   -- Column index for chord name in the CSV/TXT file

-- Function to display a message in the console for debugging
function Msg(variable)
  if console then
    reaper.ShowConsoleMsg(tostring(variable) .. "\n")
  end
end

-- Function to parse a single line from a CSV/TXT file
-- From script by X-Raym
function ParseCSVLine(line, sep)
  local res = {}
  local pos = 1
  sep = sep or ','
  while true do
    local c = string.sub(line, pos, pos)
    if (c == "") then break end
    if (c == '"') then
      -- quoted value (ignore separator within)
      local txt = ""
      repeat
        local startp, endp = string.find(line, '^%b""', pos)
        txt = txt .. string.sub(line, startp + 1, endp - 1)
        pos = endp + 1
        c = string.sub(line, pos, pos)
        if (c == '"') then txt = txt .. '"' end
      until (c ~= '"')
      table.insert(res, txt)
      assert(c == sep or c == "")
      pos = pos + 3
    else
      -- no quotes used, just look for the first separator
      local startp, endp = string.find(line, sep, pos)
      if (startp) then
        table.insert(res, string.sub(line, pos, startp - 1))
        pos = endp + 1
      else
        -- no separator found -> use rest of string and terminate
        table.insert(res, string.sub(line, pos))
        break
      end
    end
  end
  return res
end

-- Function to read all lines from the specified file
function read_lines(filepath, separator)
  local lines = {}
  local f = io.open(filepath, "r")
  if not f then return nil end
  for s in f:lines() do
    table.insert(lines, ParseCSVLine(s, separator))
  end
  f:close()
  return lines
end

-- Function to build the MIDI chord inside a take
-- Logic adapted from "ReaTrak create midi chords from region chord name.lua"
function build_chord_in_take(take, chord_name)

  if not take or not chord_name then return end
  
  local length = reaper.BR_GetMidiSourceLenPPQ(take)
  
  -- Skip regions marked with '@'
  if string.match(chord_name, "@.*") then return end
  
  -- Parse chord name into root, quality, and slash note
  local root, chord, slash, slashnote
  if string.find(chord_name, "/") then
    root, chord, slash = string.match(chord_name, "(%w[#b]?)(.*)(/%a[#b]?)$")
  else
    root, chord = string.match(chord_name, "(%w[#b]?)(.*)$")
    slashnote = 0
    slash = ""
  end

  if not root then return end -- Invalid chord name, skip.
  if not chord or #chord == 0 then chord = "Maj" end
  if not slash then slash = "" end

  -- Convert root note name to MIDI pitch (60 = C4)
  local note1 = 0
  if root == "C" then note1 = 60
  elseif root == "C#" then note1 = 61
  elseif root == "Db" then note1 = 61
  elseif root == "D" then note1 = 62
  elseif root == "D#" then note1 = 63
  elseif root == "Eb" then note1 = 63
  elseif root == "E" then note1 = 64
  elseif root == "F" then note1 = 65
  elseif root == "F#" then note1 = 66
  elseif root == "Gb" then note1 = 66
  elseif root == "G" then note1 = 67
  elseif root == "G#" then note1 = 68
  elseif root == "Ab" then note1 = 68
  elseif root == "A" then note1 = 69
  elseif root == "A#" then note1 = 70
  elseif root == "Bb" then note1 = 70
  elseif root == "B" then note1 = 71
  end
  if note1 == 0 then return end -- If root note was not found, exit

  -- Convert slash note name to MIDI pitch (48 = C3)
  slashnote = 0
  if slash == "/C" then slashnote = 48
  elseif slash == "/C#" then slashnote = 49
  elseif slash == "/Db" then slashnote = 49
  elseif slash == "/D" then slashnote = 50
  elseif slash == "/D#" then slashnote = 51
  elseif slash == "/Eb" then slashnote = 51
  elseif slash == "/E" then slashnote = 52
  elseif slash == "/F" then slashnote = 53
  elseif slash == "/F#" then slashnote = 54
  elseif slash == "/Gb" then slashnote = 54
  elseif slash == "/G" then slashnote = 55
  elseif slash == "/G#" then slashnote = 56
  elseif slash == "/Ab" then slashnote = 56
  elseif slash == "/A" then slashnote = 57
  elseif slash == "/A#" then slashnote = 58
  elseif slash == "/Bb" then slashnote = 58
  elseif slash == "/B" then slashnote = 59
  end
  
  local octave = note1 - slashnote
  if octave > 12 and slashnote > 0 then slashnote = slashnote + 12 end

  -- Define chord intervals based on chord quality string
  local note2, note3, note4, note5, note6, note7 = 0, 0, 0, 0, 0, 0
  
  -- This is the chord definition library. Each line checks for various text aliases for a chord type.
  if string.find(",Maj,M,", ","..chord..",", 1, true) then note2=4  note3=7 end      
  if string.find(",m,min,", ","..chord..",", 1, true) then note2=3  note3=7 end      
  if string.find(",dim,m-5,mb5,m(b5),0,", ","..chord..",", 1, true) then note2=3  note3=6 end   
  if string.find(",aug,+,+5,(#5),", ","..chord..",", 1, true) then note2=4  note3=8 end   
  if string.find(",-5,(b5),", ","..chord..",", 1, true) then note2=4  note3=6 end   
  if string.find(",sus2,", ","..chord..",", 1, true) then note2=2  note3=7 end   
  if string.find(",sus4,sus,(sus4),", ","..chord..",", 1, true) then note2=5  note3=7 end   
  if string.find(",5,", ","..chord..",", 1, true) then note2=7 note3=12 end   
  if string.find(",5add7,5/7,", ","..chord..",", 1, true) then note2=7  note3=10 note4=10 end   
  if string.find(",add2,(add2),", ","..chord..",", 1, true) then note2=2  note3=4  note4=7 end   
  if string.find(",add4,(add4),", ","..chord..",", 1, true) then note2=4  note3=5  note4=7 end   
  if string.find(",madd4,m(add4),", ","..chord..",", 1, true) then note2=3  note3=5  note4=7 end   
  if string.find(",11,", ","..chord..",", 1, true) then note2=4  note3=7  note4=10  note5=14  note6=17 end  
  if string.find(",11sus4,", ","..chord..",", 1, true) then note2=5  note3=7  note4=10  note5=14  note6=17 end  
  if string.find(",m11,min11,-11,", ","..chord..",", 1, true) then note2=3  note3=7  note4=10  note5=14  note6=17 end  
  if string.find(",Maj11,maj11,M11,Maj7(add11),M7(add11),", ","..chord..",", 1, true) then note2=4  note3=7  note4=11  note5=14  note6=17 end     
  if string.find(",mMaj11,minmaj11,mM11,", ","..chord..",", 1, true) then note2=3  note3=7  note4=11  note5=14  note6=17 end  
  if string.find(",aug11,9+11,9aug11,", ","..chord..",", 1, true) then note2=4  note3=7  note4=10  note5=14  note6=18 end  
  if string.find(",augm11, m9#11,", ","..chord..",", 1, true) then note2=3  note3=7  note4=10  note5=14  note6=18 end  
  if string.find(",11b5,11-5,11(b5),", ","..chord..",", 1, true) then note2=4  note3=6  note4=10  note5=14  note6=17 end  
  if string.find(",11#5,11+5,11(#5),", ","..chord..",", 1, true) then note2=4  note3=8  note4=10  note5=14  note6=17 end  
  if string.find(",11b9,11-9,11(b9),", ","..chord..",", 1, true) then note2=4  note3=7  note4=10  note5=13  note6=17 end  
  if string.find(",11#9,11+9,11(#9),", ","..chord..",", 1, true) then note2=4  note3=7  note4=10  note5=15  note6=17 end  
  if string.find(",11b5b9,11-5-9,11(b5b9),", ","..chord..",", 1, true) then note2=4  note3=6  note4=10  note5=13  note6=17 end  
  if string.find(",11#5b9,11+5-9,11(#5b9),", ","..chord..",", 1, true) then note2=4  note3=8  note4=10  note5=13  note6=17 end  
  if string.find(",11b5#9,11-5+9,11(b5#9),", ","..chord..",", 1, true) then note2=4  note3=6  note4=10  note5=15  note6=17 end  
  if string.find(",11#5#9,11+5+9,11(#5#9),", ","..chord..",", 1, true) then note2=4  note3=8  note4=10  note5=15  note6=17 end  
  if string.find(",m11b5,m11-5,m11(b5),", ","..chord..",", 1, true) then note2=3  note3=6  note4=10  note5=14  note6=17 end  
  if string.find(",m11#5,m11+5,m11(#5),", ","..chord..",", 1, true) then note2=3  note3=8  note4=10  note5=14  note6=17 end  
  if string.find(",m11b9,m11-9,m11(b9),", ","..chord..",", 1, true) then note2=3  note3=7  note4=10  note5=13  note6=17 end  
  if string.find(",m11#9,m11+9,m11(#9),", ","..chord..",", 1, true) then note2=3  note3=7  note4=10  note5=15  note6=17 end  
  if string.find(",m11b5b9,m11-5-9,m11(b5b9),", ","..chord..",", 1, true) then note2=3  note3=6  note4=10  note5=13  note6=17 end
  if string.find(",m11#5b9,m11+5-9,m11(#5b9),", ","..chord..",", 1, true) then note2=3  note3=8  note4=10  note5=13  note6=17 end
  if string.find(",m11b5#9,m11-5+9,m11(b5#9),", ","..chord..",", 1, true) then note2=3  note3=6  note4=10  note5=15  note6=17 end
  if string.find(",m11#5#9,m11+5+9,m11(#5#9),", ","..chord..",", 1, true) then note2=3  note3=8  note4=10  note5=15  note6=17 end
  if string.find(",Maj11b5,maj11b5,maj11-5,maj11(b5),", ","..chord..",", 1, true)    then note2=4  note3=6  note4=11  note5=14  note6=17 end
  if string.find(",Maj11#5,maj11#5,maj11+5,maj11(#5),", ","..chord..",", 1, true)    then note2=4  note3=8  note4=11  note5=14  note6=17 end
  if string.find(",Maj11b9,maj11b9,maj11-9,maj11(b9),", ","..chord..",", 1, true)    then note2=4  note3=7  note4=11  note5=13  note6=17 end
  if string.find(",Maj11#9,maj11#9,maj11+9,maj11(#9),", ","..chord..",", 1, true)    then note2=4  note3=7  note4=11  note5=15  note6=17 end
  if string.find(",Maj11b5b9,maj11b5b9,maj11-5-9,maj11(b5b9),", ","..chord..",", 1, true)   then note2=4  note3=6  note4=11  note5=13  note6=17 end
  if string.find(",Maj11#5b9,maj11#5b9,maj11+5-9,maj11(#5b9),", ","..chord..",", 1, true)   then note2=4  note3=8  note4=11  note5=13  note6=17 end
  if string.find(",Maj11b5#9,maj11b5#9,maj11-5+9,maj11(b5#9),", ","..chord..",", 1, true)   then note2=4  note3=6  note4=11  note5=15  note6=17 end
  if string.find(",Maj11#5#9,maj11#5#9,maj11+5+9,maj11(#5#9),", ","..chord..",", 1, true)   then note2=4  note3=8  note4=11  note5=15  note6=17 end
  if string.find(",13,", ","..chord..",", 1, true) then note2=4  note3=7  note4=10  note5=14  note6=17  note7=21 end  
  if string.find(",m13,min13,-13,", ","..chord..",", 1, true) then note2=3  note3=7  note4=10  note5=14  note6=17  note7=21 end  
  if string.find(",Maj13,maj13,M13,Maj7(add13),M7(add13),min,", ","..chord..",", 1, true)   then note2=4  note3=7  note4=11  note5=14  note6=17  note7=21 end  
  if string.find(",mMaj13,minmaj13,mM13,", ","..chord..",", 1, true) then note2=3  note3=7  note4=11  note5=14  note6=17  note7=21 end  
  if string.find(",13b5,13-5,", ","..chord..",", 1, true) then note2=4  note3=6  note4=10  note5=14  note6=17  note7=21 end  
  if string.find(",13#5,13+5,", ","..chord..",", 1, true) then note2=4  note3=8  note4=10  note5=14  note6=17  note7=21 end  
  if string.find(",13b9,13-9,", ","..chord..",", 1, true) then note2=4  note3=7  note4=10  note5=13  note6=17  note7=21 end  
  if string.find(",13#9,13+9,", ","..chord..",", 1, true) then note2=4  note3=7  note4=10  note5=15  note6=17  note7=21 end  
  if string.find(",13#11,13+11,", ","..chord..",", 1, true) then note2=4  note3=7  note4=10  note5=15  note6=18  note7=21 end  
  if string.find(",13b5b9,13-5-9,", ","..chord..",", 1, true) then note2=4  note3=6  note4=10  note5=13  note6=17  note7=21 end  
  if string.find(",13#5b9,13+5-9,", ","..chord..",", 1, true) then note2=4  note3=8  note4=10  note5=13  note6=17  note7=21 end  
  if string.find(",13b5#9,13-5+9,", ","..chord..",", 1, true) then note2=4  note3=6  note4=10  note5=15  note6=17  note7=21 end  
  if string.find(",13#5#9,13+5+9,", ","..chord..",", 1, true) then note2=4  note3=8  note4=10  note5=15  note6=17  note7=21 end  
  if string.find(",13b9#11,13-9+11,", ","..chord..",", 1, true) then note2=4  note3=7  note4=10  note5=13  note6=18  note7=21 end  
  if string.find(",m13b5,m13-5,", ","..chord..",", 1, true) then note2=3  note3=6  note4=10  note5=14  note6=17  note7=21 end  
  if string.find(",m13#5,m13+5,", ","..chord..",", 1, true) then note2=3  note3=8  note4=10  note5=14  note6=17  note7=21 end  
  if string.find(",m13b9,m13-9,", ","..chord..",", 1, true) then note2=3  note3=7  note4=10  note5=13  note6=17  note7=21 end  
  if string.find(",m13#9,m13+9,", ","..chord..",", 1, true) then note2=3  note3=7  note4=10  note5=15  note6=17  note7=21 end  
  if string.find(",m13b5b9,m13-5-9,", ","..chord..",", 1, true) then note2=3  note3=6  note4=10  note5=13  note6=17  note7=21 end  
  if string.find(",m13#5b9,m13+5-9,", ","..chord..",", 1, true) then note2=3  note3=8  note4=10  note5=13  note6=17  note7=21 end  
  if string.find(",m13b5#9,m13-5+9,", ","..chord..",", 1, true) then note2=3  note3=6  note4=10  note5=15  note6=17  note7=21 end  
  if string.find(",m13#5#9,m13+5+9,", ","..chord..",", 1, true) then note2=3  note3=8  note4=10  note5=15  note6=17  note7=21 end  
  if string.find(",Maj13b5,maj13b5,maj13-5,", ","..chord..",", 1, true) then note2=4  note3=6  note4=11  note5=14  note6=17  note7=21 end  
  if string.find(",Maj13#5,maj13#5,maj13+5,", ","..chord..",", 1, true) then note2=4  note3=8  note4=11  note5=14  note6=17  note7=21 end  
  if string.find(",Maj13b9,maj13b9,maj13-9,", ","..chord..",", 1, true) then note2=4  note3=7  note4=11  note5=13  note6=17  note7=21 end  
  if string.find(",Maj13#9,maj13#9,maj13+9,", ","..chord..",", 1, true) then note2=4  note3=7  note4=11  note5=15  note6=17  note7=21 end  
  if string.find(",Maj13b5b9,maj13b5b9,maj13-5-9,", ","..chord..",", 1, true) then note2=4  note3=6  note4=11  note5=13  note6=17  note7=21 end  
  if string.find(",Maj13#5b9,maj13#5b9,maj13+5-9,", ","..chord..",", 1, true) then note2=4  note3=8  note4=11  note5=13  note6=17  note7=21 end  
  if string.find(",Maj13b5#9,maj13b5#9,maj13-5+9,", ","..chord..",", 1, true) then note2=4  note3=6  note4=11  note5=15  note6=17  note7=21 end  
  if string.find(",Maj13#5#9,maj13#5#9,maj13+5+9,", ","..chord..",", 1, true) then note2=4  note3=8  note4=11  note5=15  note6=17  note7=21 end  
  if string.find(",Maj13#11,maj13#11,maj13+11,", ","..chord..",", 1, true) then note2=4  note3=7  note4=11  note5=14  note6=18  note7=21 end  
  if string.find(",13#11,13+11,", ","..chord..",", 1, true) then note2=4  note3=7  note4=10  note5=14  note6=18  note7=21 end  
  if string.find(",m13#11,", ","..chord..",", 1, true) then note2=3  note3=7  note4=10  note5=14  note6=18  note7=21 end  
  if string.find(",13sus4,", ","..chord..",", 1, true) then note2=5  note3=7  note4=10  note5=14  note6=17  note7=21 end  
  if string.find(",6,M6,Maj6,maj6,", ","..chord..",", 1, true) then note2=4  note3=7  note4=9 end   
  if string.find(",m6,min6,", ","..chord..",", 1, true) then note2=3  note3=7  note4=9 end   
  if string.find(",6add4,6/4,6(add4),Maj6(add4),M6(add4),", ","..chord..",", 1, true)    then note2=4  note3=5  note4=7  note5=9 end   
  if string.find(",m6add4,m6/4,m6(add4),", ","..chord..",", 1, true) then note2=3  note3=5  note4=7  note5=9 end   
  if string.find(",69,6add9,6/9,6(add9),Maj6(add9),M6(add9),", ","..chord..",", 1, true)   then note2=4  note3=7  note4=9  note5=14 end  
  if string.find(",m6add9,m6/9,m6(add9),", ","..chord..",", 1, true) then note2=3  note3=7  note4=9  note5=14 end  
  if string.find(",6sus2,", ","..chord..",", 1, true) then note2=2  note3=7  note4=9 end   
  if string.find(",6sus4,", ","..chord..",", 1, true) then note2=5  note3=7  note4=9 end   
  if string.find(",6add11,6/11,6(add11),Maj6(add11),M6(add11),", ","..chord..",", 1, true)   then note2=4  note3=7  note4=9  note5=17 end  
  if string.find(",m6add11,m6/11,m6(add11),m6(add11),", ","..chord..",", 1, true)    then note2=3  note3=7  note4=9  note5=17 end  
  if string.find(",7,dom,", ","..chord..",", 1, true) then note2=4  note3=7  note4=10 end   
  if string.find(",7add2,", ","..chord..",", 1, true) then note2=2  note3=4  note4=7  note5=10 end  
  if string.find(",7add4,", ","..chord..",", 1, true) then note2=4  note3=5  note4=7  note5=10 end  
  if string.find(",m7,min7,-7,", ","..chord..",", 1, true) then note2=3  note3=7  note4=10 end   
  if string.find(",m7add4,", ","..chord..",", 1, true) then note2=3  note3=5  note4=7  note5=10 end  
  if string.find(",Maj7,maj7,Maj7,M7,", ","..chord..",", 1, true) then note2=4  note3=7  note4=11 end   
  if string.find(",dim7,07,", ","..chord..",", 1, true) then note2=3  note3=6  note4=9 end   
  if string.find(",mMaj7,minmaj7,mmaj7,min/maj7,mM7,m(addM7),m(+7),-(M7),", ","..chord..",", 1, true)  then note2=3  note3=7  note4=11 end    
  if string.find(",7sus2,", ","..chord..",", 1, true) then note2=2  note3=7  note4=10 end   
  if string.find(",7sus4,7sus,7sus11,", ","..chord..",", 1, true) then note2=5  note3=7  note4=10 end   
  if string.find(",Maj7sus2,maj7sus2,M7sus2,", ","..chord..",", 1, true) then note2=2  note3=7  note4=11 end    
  if string.find(",Maj7sus4,maj7sus4,M7sus4,", ","..chord..",", 1, true) then note2=5  note3=7  note4=11 end    
  if string.find(",aug7,+7,", ","..chord..",", 1, true) then note2=4  note3=8  note4=10 end   
  if string.find(",7b5,7-5,", ","..chord..",", 1, true) then note2=4  note3=6  note4=10 end   
  if string.find(",7#5,7+5,7+,", ","..chord..",", 1, true) then note2=4  note3=8  note4=10 end   
  if string.find(",m7b5,m7-5,", ","..chord..",", 1, true) then note2=3  note3=6  note4=10 end   
  if string.find(",m7#5,m7+5,", ","..chord..",", 1, true) then note2=3  note3=8  note4=10 end   
  if string.find(",Maj7b5,maj7b5,maj7-5,M7b5,", ","..chord..",", 1, true) then note2=4  note3=6  note4=11 end   
  if string.find(",Maj7#5,maj7#5,maj7+5,M7+5,", ","..chord..",", 1, true) then note2=4  note3=8  note4=11 end   
  if string.find(",7b9,7-9,7(addb9),", ","..chord..",", 1, true) then note2=4  note3=7  note4=10  note5=13 end  
  if string.find(",7#9,7+9,7(add#9),", ","..chord..",", 1, true) then note2=4  note3=7  note4=10  note5=15 end  
  if string.find(",m7b9, m7-9,", ","..chord..",", 1, true) then note2=3  note3=7  note4=10  note5=13 end  
  if string.find(",m7#9, m7+9,", ","..chord..",", 1, true) then note2=3  note3=7  note4=10  note5=15 end  
  if string.find(",Maj7b9,maj7b9,maj7-9,maj7(addb9),", ","..chord..",", 1, true)    then note2=4  note3=7  note4=11  note5=13 end 
  if string.find(",Maj7#9,maj7#9,maj7+9,maj7(add#9),", ","..chord..",", 1, true)    then note2=4  note3=7  note4=11  note5=15 end 
  if string.find(",7b9b13,7-9-13,", ","..chord..",", 1, true) then note2=4  note3=7  note4=10  note5=13  note6=20 end  
  if string.find(",m7b9b13, m7-9-13,", ","..chord..",", 1, true) then note2=3  note3=7  note4=10  note5=13  note6=20 end
  if string.find(",7b13,7-13,", ","..chord..",", 1, true) then note2=4  note3=7  note4=10  note5=14  note6=20 end  
  if string.find(",m7b13,m7-13,", ","..chord..",", 1, true) then note2=3  note3=7  note4=10  note5=14  note6=20 end  
  if string.find(",7#9b13,7+9-13,", ","..chord..",", 1, true) then note2=4  note3=7  note4=10  note5=15  note6=20 end  
  if string.find(",m7#9b13,m7+9-13,", ","..chord..",", 1, true) then note2=3  note3=7  note4=10  note5=15  note6=20 end  
  if string.find(",7b5b9,7-5-9,", ","..chord..",", 1, true) then note2=4  note3=6  note4=10  note5=13 end  
  if string.find(",7b5#9,7-5+9,", ","..chord..",", 1, true) then note2=4  note3=6  note4=10  note5=15 end  
  if string.find(",7#5b9,7+5-9,", ","..chord..",", 1, true) then note2=4  note3=8  note4=10  note5=13 end  
  if string.find(",7#5#9,7+5+9,", ","..chord..",", 1, true) then note2=4  note3=8  note4=10  note5=15 end  
  if string.find(",7#11,", ","..chord..",", 1, true) then note2=4  note3=7  note4=10  note5=18 end  
  if string.find(",7add6,7/6,", ","..chord..",", 1, true) then note2=4  note3=7  note4=9  note5=10 end  
  if string.find(",7add11,", ","..chord..",", 1, true) then note2=4  note3=7  note4=10  note5=17 end  
  if string.find(",7add13,7/13,", ","..chord..",", 1, true) then note2=4  note3=7  note4=10  note5=21 end  
  if string.find(",m7add11,", ","..chord..",", 1, true) then note2=3  note3=7  note4=10  note5=17 end  
  if string.find(",m7b5b9,m7-5-9,", ","..chord..",", 1, true) then note2=3  note3=6  note4=10  note5=13 end  
  if string.find(",m7b5#9,m7-5+9,", ","..chord..",", 1, true) then note2=3  note3=6  note4=10  note5=15 end  
  if string.find(",m7#5b9,m7+5-9,", ","..chord..",", 1, true) then note2=3  note3=8  note4=10  note5=13 end  
  if string.find(",m7#5#9,m7+5+9,", ","..chord..",", 1, true) then note2=3  note3=8  note4=10  note5=15 end  
  if string.find(",m7#11,", ","..chord..",", 1, true) then note2=3  note3=7  note4=10  note5=18 end  
  if string.find(",Maj7b5b9,maj7b5b9,maj7-5-9,", ","..chord..",", 1, true) then note2=4  note3=6  note4=11  note5=13 end 
  if string.find(",Maj7b5#9,maj7b5#9,maj7-5+9,", ","..chord..",", 1, true) then note2=4  note3=6  note4=11  note5=15 end 
  if string.find(",Maj7#5b9,maj7#5b9,maj7+5-9,", ","..chord..",", 1, true) then note2=4  note3=8  note4=11  note5=13 end 
  if string.find(",Maj7#5#9,maj7#5#9,maj7+5+9,", ","..chord..",", 1, true) then note2=4  note3=8  note4=11  note5=15 end 
  if string.find(",Maj7add11,maj7add11,", ","..chord..",", 1, true) then note2=4  note3=7  note4=11  note5=17 end  
  if string.find(",Maj7#11,maj7#11,", ","..chord..",", 1, true) then note2=4  note3=7  note4=11  note5=18 end  
  if string.find(",9,7(add9),", ","..chord..",", 1, true) then note2=4  note3=7  note4=10  note5=14 end  
  if string.find(",m9,min9,-9,", ","..chord..",", 1, true) then note2=3  note3=7  note4=10  note5=14 end  
  if string.find(",Maj9,maj9,M9,Maj7(add9),M7(add9),", ","..chord..",", 1, true)    then note2=4  note3=7  note4=11  note5=14 end 
  if string.find(",Maj9sus4,maj9sus4,", ","..chord..",", 1, true) then note2=5  note3=7  note4=11  note5=14 end  
  if string.find(",mMaj9,minmaj9,mmaj9,min/maj9,mM9,m(addM9),m(+9),-(M9),", ","..chord..",", 1, true)  then note2=3  note3=7  note4=11  note5=14 end 
  if string.find(",9sus4,9sus,", ","..chord..",", 1, true) then note2=5  note3=7  note4=10  note5=14 end  
  if string.find(",aug9,+9,", ","..chord..",", 1, true) then note2=4  note3=7  note4=10  note5=15 end  
  if string.find(",9add6,9/6,", ","..chord..",", 1, true) then note2=4  note3=7  note4=9  note5=10  note6=14 end  
  if string.find(",m9add6,m9/6,", ","..chord..",", 1, true) then note2=3  note3=7  note4=9  note5=14 end  
  if string.find(",9b5,9-5,", ","..chord..",", 1, true) then note2=4  note3=6  note4=10  note5=14 end  
  if string.find(",9#5,9+5,", ","..chord..",", 1, true) then note2=4  note3=8  note4=10  note5=14 end  
  if string.find(",m9b5,m9-5,", ","..chord..",", 1, true) then note2=3  note3=6  note4=10  note5=14 end  
  if string.find(",m9#5,m9+5,", ","..chord..",", 1, true) then note2=3  note3=8  note4=10  note5=14 end  
  if string.find(",Maj9b5,maj9b5,", ","..chord..",", 1, true) then note2=4  note3=6  note4=11  note5=14 end  
  if string.find(",Maj9#5,maj9#5,", ","..chord..",", 1, true) then note2=4  note3=8  note4=11  note5=14 end  
  if string.find(",Maj9#11,maj9#11,", ","..chord..",", 1, true) then note2=4  note3=7  note4=11  note5=14  note6=18 end  
  if string.find(",b9#11,-9+11,", ","..chord..",", 1, true) then note2=4  note3=7  note4=10  note5=13  note6=18 end  
  if string.find(",add9,2,", ","..chord..",", 1, true) then note2=4  note3=7  note4=14 end   
  if string.find(",madd9,m(add9),-(add9),", ","..chord..",", 1, true) then note2=3  note3=7  note4=14 end   
  if string.find(",add11,", ","..chord..",", 1, true) then note2=4  note3=7  note4=17 end   
  if string.find(",madd11,m(add11),-(add11),", ","..chord..",", 1, true) then note2=3  note3=7  note4=17 end    
  if string.find(",(b9),", ","..chord..",", 1, true) then note2=4  note3=7  note4=13 end   
  if string.find(",(#9),", ","..chord..",", 1, true) then note2=4  note3=7  note4=15 end   
  if string.find(",(b5b9),", ","..chord..",", 1, true) then note2=4  note3=6  note4=13 end   
  if string.find(",(#5b9),", ","..chord..",", 1, true) then note2=4  note3=8  note4=13 end   
  if string.find(",(b5#9),", ","..chord..",", 1, true) then note2=4  note3=6  note4=15 end   
  if string.find(",(#5#9),", ","..chord..",", 1, true) then note2=4  note3=8  note4=15 end   
  if string.find(",m(b9), mb9,", ","..chord..",", 1, true) then note2=3  note3=7  note4=13 end   
  if string.find(",m(#9), m#9,", ","..chord..",", 1, true) then note2=3  note3=7  note4=15 end   
  if string.find(",m(b5b9), mb5b9,", ","..chord..",", 1, true) then note2=3  note3=6  note4=13 end   
  if string.find(",m(#5b9), m#5b9,", ","..chord..",", 1, true) then note2=3  note3=8  note4=13 end   
  if string.find(",m(b5#9), mb5#9,", ","..chord..",", 1, true) then note2=3  note3=6  note4=15 end   
  if string.find(",m(#5#9), m#5#9,", ","..chord..",", 1, true) then note2=3  note3=8  note4=15 end   
  if string.find(",m(#11), m#11,", ","..chord..",", 1, true) then note2=3  note3=7  note4=18 end   
  if string.find(",(#11),", ","..chord..",", 1, true) then note2=4  note3=7  note4=18 end   
  if string.find(",m#5,", ","..chord..",", 1, true) then note2=3  note3=8 end   
  if string.find(",maug,augaddm3,augadd(m3),", ","..chord..",", 1, true) then note2=3  note3=7 note4=8 end  
  if string.find(",13#9#11,", ","..chord..",", 1, true) then note2=4  note3=7  note4=10  note5=15  note6=18  note7=21 end  
  if string.find(",13#11,", ","..chord..",", 1, true) then note2=4  note3=7  note4=10  note5=14  note6=18  note7=21 end  
  if string.find(",13susb5,", ","..chord..",", 1, true) then note2=5  note3=6  note4=10  note5=14  note6=17  note7=21 end  
  if string.find(",13susb5#9,", ","..chord..",", 1, true) then note2=5  note3=6  note4=10  note5=15  note6=21 end  
  if string.find(",13susb5b9,", ","..chord..",", 1, true) then note2=5  note3=6  note4=10  note5=13  note6=17  note7=21 end  
  if string.find(",13susb9,", ","..chord..",", 1, true) then note2=5  note3=7  note4=10  note5=13  note6=17  note7=21 end  
  if string.find(",13susb9#11,", ","..chord..",", 1, true) then note2=5  note3=7  note4=10  note5=13  note6=18  note7=21 end  
  if string.find(",13sus#5,", ","..chord..",", 1, true) then note2=5  note3=8  note4=10  note5=17  note6=21 end  
  if string.find(",13sus#5b9,", ","..chord..",", 1, true) then note2=5  note3=8  note4=10  note5=13  note6=17  note7=21 end  
  if string.find(",13sus#5b9#11,", ","..chord..",", 1, true) then note2=5  note3=8  note4=10  note5=13  note6=18  note7=21 end  
  if string.find(",13sus#5#11,", ","..chord..",", 1, true) then note2=5  note3=8  note4=10  note5=18 end  
  if string.find(",13sus#5#9#11,", ","..chord..",", 1, true) then note2=5  note3=8  note4=10  note5=15  note6=18 end
  if string.find(",13sus#9,", ","..chord..",", 1, true) then note2=5  note3=7  note4=10  note5=15  note6=17  note7=21 end  
  if string.find(",13sus#9#11,", ","..chord..",", 1, true) then note2=5  note3=7  note4=10  note5=15  note6=18  note7=21 end  
  if string.find(",13sus#11,", ","..chord..",", 1, true) then note2=5  note3=7  note4=10  note5=14  note6=18  note7=21 end  
  if string.find(",7b5b13,", ","..chord..",", 1, true) then note2=4  note3=6  note4=10 note5=17  note6=20 end   
  if string.find(",7b5#9b13,", ","..chord..",", 1, true) then note2=4  note3=6  note4=10  note5=15  note6=20 end  
  if string.find(",7#5#11,", ","..chord..",", 1, true) then note2=4  note3=8  note4=10  note5=18 end  
  if string.find(",7#5#9#11,", ","..chord..",", 1, true) then note2=4  note3=8  note4=10  note5=15  note6=18 end  
  if string.find(",7#5b9#11,", ","..chord..",", 1, true) then note2=4  note3=8  note4=10  note5=13  note6=18 end  
  if string.find(",7#9#11b13,", ","..chord..",", 1, true) then note2=4  note3=7  note4=10  note5=15  note6=18 note7=20 end  
  if string.find(",7#11,", ","..chord..",", 1, true) then note2=4  note3=7  note4=10 note5=18 end   
  if string.find(",7#11b13,", ","..chord..",", 1, true) then note2=4  note3=7  note4=10  note5=18  note6=20 end  
  if string.find(",7susb5,", ","..chord..",", 1, true) then note2=5  note3=6  note4=10 end   
  if string.find(",7susb5b9,", ","..chord..",", 1, true) then note2=5  note3=6  note4=10  note5=13 end  
  if string.find(",7b5b9b13,", ","..chord..",", 1, true) then note2=5  note3=6  note4=10  note5=13  note6=20 end  
  if string.find(",7susb5b13,", ","..chord..",", 1, true) then note2=5  note3=6  note4=10  note5=14  note6=20 end  
  if string.find(",7susb5#9,", ","..chord..",", 1, true) then note2=5  note3=6  note4=10  note5=15 end  
  if string.find(",7susb5#9b13,", ","..chord..",", 1, true) then note2=5  note3=6  note4=10  note5=15  note6=20 end  
  if string.find(",7susb9,", ","..chord..",", 1, true) then note2=5  note3=7  note4=10  note5=13 end  
  if string.find(",7susb9b13,", ","..chord..",", 1, true) then note2=5  note3=7  note4=10  note5=13  note6=20 end  
  if string.find(",7susb9#11,", ","..chord..",", 1, true) then note2=5  note3=7  note4=10  note5=13  note6=18 end  
  if string.find(",7susb9#11b13,", ","..chord..",", 1, true) then note2=5  note3=7  note4=10  note5=13  note6=18  note7=20 end  
  if string.find(",7susb13,", ","..chord..",", 1, true) then note2=5  note3=7  note4=10  note5=20 end  
  if string.find(",7sus#5,", ","..chord..",", 1, true) then note2=5  note3=8  note4=10 end   
  if string.find(",7sus#5#9#11,", ","..chord..",", 1, true) then note2=5  note3=8  note4=10  note5=15  note6=18 end  
  if string.find(",7sus#5#11,", ","..chord..",", 1, true) then note2=5  note3=8  note4=10  note5=18 end  
  if string.find(",7sus#9,", ","..chord..",", 1, true) then note2=5  note3=7  note4=10  note5=15 end  
  if string.find(",7sus#9b13,", ","..chord..",", 1, true) then note2=5  note3=7  note4=10  note5=15  note6=20 end  
  if string.find(",7sus#9#11b13,", ","..chord..",", 1, true) then note2=5  note3=7  note4=10  note5=15  note6=18  note7=20 end  
  if string.find(",7sus#11,", ","..chord..",", 1, true) then note2=5  note3=7  note4=10  note5=18 end  
  if string.find(",7sus#11b13,", ","..chord..",", 1, true) then note2=5  note3=7  note4=10  note5=18  note6=20 end  
  if string.find(",9b5b13,", ","..chord..",", 1, true) then note2=4  note3=6  note4=10  note5=14  note6=20 end  
  if string.find(",9b13,", ","..chord..",", 1, true) then note2=4  note3=7  note4=10  note5=14  note6=20 end  
  if string.find(",9#5#11,", ","..chord..",", 1, true) then note2=4  note3=8  note4=10  note5=14  note6=18 end  
  if string.find(",9#11,", ","..chord..",", 1, true) then note2=4  note3=7  note4=10  note5=14  note6=18 end  
  if string.find(",9#11b13,", ","..chord..",", 1, true) then note2=4  note3=7  note4=10  note5=14  note6=18  note7=20 end  
  if string.find(",9susb5,", ","..chord..",", 1, true) then note2=5  note3=6  note4=10  note5=14  end  
  if string.find(",9susb5b13,", ","..chord..",", 1, true) then note2=5  note3=6  note4=10  note5=14 note6=20 end  
  if string.find(",9sus#11,", ","..chord..",", 1, true) then note2=5  note3=7  note4=10  note5=14 note6=18 end  
  if string.find(",9susb5#9,", ","..chord..",", 1, true) then note2=5  note3=6  note4=10  note5=14  note6=15 end  
  if string.find(",9sus#5#11,", ","..chord..",", 1, true) then note2=5  note3=8  note4=10  note5=14  note6=18 end   
  if string.find(",quartal,", ","..chord..",", 1, true) then note2=5  note3=10  note4=15 end
  if string.find(",sowhat,", ","..chord..",", 1, true) then note2=5  note3=10  note4=16 end

  -- Insert the calculated notes into the take
  local vel = 100 -- Set velocity for created notes
  reaper.MIDI_InsertNote(take, true, false, 0, length - 2, 0, note1, vel, false)
  if slashnote > 0 then reaper.MIDI_InsertNote(take, true, false, 0, length - 2, 0, slashnote, vel, false) end
  if note2 > 0 then reaper.MIDI_InsertNote(take, true, false, 0, length - 2, 0, note1 + note2, vel, false) end
  if note3 > 0 then reaper.MIDI_InsertNote(take, true, false, 0, length - 2, 0, note1 + note3, vel, false) end
  if note4 > 0 then reaper.MIDI_InsertNote(take, true, false, 0, length - 2, 0, note1 + note4, vel, false) end
  if note5 > 0 then reaper.MIDI_InsertNote(take, true, false, 0, length - 2, 0, note1 + note5, vel, false) end
  if note6 > 0 then reaper.MIDI_InsertNote(take, true, false, 0, length - 2, 0, note1 + note6, vel, false) end
  if note7 > 0 then reaper.MIDI_InsertNote(take, true, false, 0, length - 2, 0, note1 + note7, vel, false) end
end


-- Main function that runs the entire workflow
function main_workflow()

  -- Show instructions
  local Info = [[This script will import chords from a file generated by Chordino.

How to get the file:
1. Load your audio into Sonic Visualiser.
2. Go to Transform > Chordino.
3. After analysis, go to File > Export Annotation Layer...
4. Save as a .txt or .csv file.
]]
  reaper.MB(Info, "How to create a chord file", 0)

  -- Ask user to choose file type
  local retval, input_choose = reaper.GetUserInputs("Choose File Type", 1, "txt or csv", "csv")
  if not retval then return end

  local sep
  if input_choose == "txt" then sep = "\t" else sep = "," end

  -- Ask user to select the file
  local retval, file_path = reaper.GetUserFileNameForRead("", "Import Chordino chords to MIDI", input_choose)
  if not retval then return end
  
  -- FIX: Bật chế độ snap để hàm SnapToGrid hoạt động
  reaper.Main_OnCommand(40754, 0) -- Action: Toggle snap to grid

  reaper.PreventUIRefresh(1)
  reaper.Undo_BeginBlock()

  -- Read all chord data from the selected file
  local chord_lines = read_lines(file_path, sep)

  if not chord_lines or #chord_lines < 2 then -- Check if file is empty or just has a header
    reaper.ShowMessageBox("Error: The selected file is empty or could not be read.", "File Error", 0)
    reaper.Undo_EndBlock("Import Chordino to MIDI (failed)", -1)
    reaper.PreventUIRefresh(-1)
    return
  end
  
  -- Create a new track to hold the chord items
  reaper.InsertTrackAtIndex(reaper.CountTracks(), true)
  local track_index = reaper.CountTracks() - 1
  local track = reaper.GetTrack(0, track_index)
  reaper.SetOnlyTrackSelected(track)
  
  -- Name the new track based on the filename
  local filename = file_path:match("([^/\\]+)$")
  reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "Chords (" .. filename .. ")", true)

  -- Process each line from the chord file to create a MIDI item
  for i = 2, #chord_lines do -- Start from 2 to skip the header row
    local current_line = chord_lines[i]
    local chord_name = current_line[col_name]
    
    -- Skip empty lines or lines marked as "No Chord"
    if chord_name and chord_name ~= "N" and chord_name ~= "" then
      local start_pos = tonumber(current_line[col_pos])
      local end_pos
      
      -- Determine the end position of the chord item
      if i < #chord_lines then
        -- The end time is the start time of the next chord
        local next_line = chord_lines[i+1]
        end_pos = tonumber(next_line[col_pos])
      else
        -- For the last chord, extend it to the end of the next measure for a natural duration
        local qn_pos = reaper.TimeMap_timeToQN(start_pos)
        local _, beats_per_measure = reaper.GetProjectTimeSignature2(0)
        local measure_end_qn = (math.floor(qn_pos / beats_per_measure) + 1) * beats_per_measure
        end_pos = reaper.TimeMap_QNToTime(measure_end_qn)
      end
      
      -- FIX: Snap the start and end positions to the grid BEFORE creating the item
      -- Dịch: Căn chỉnh vị trí bắt đầu và kết thúc vào lưới TRƯỚC KHI tạo item
      local snapped_start_pos = reaper.SnapToGrid(0, start_pos)
      local snapped_end_pos = reaper.SnapToGrid(0, end_pos)
      
      -- Create the MIDI item on the new track using the SNAPPED positions
      -- Dịch: Tạo MIDI item trên track mới bằng vị trí ĐÃ ĐƯỢC CĂN CHỈNH
      if snapped_start_pos and snapped_end_pos and snapped_end_pos > snapped_start_pos then
        local item = reaper.CreateNewMIDIItemInProj(track, snapped_start_pos, snapped_end_pos, false)
        if item then
          reaper.SetMediaItemSelected(item, true) -- Chọn item vừa tạo
          local take = reaper.GetActiveTake(item)
          -- Call the function to parse the name and add MIDI notes
          build_chord_in_take(take, chord_name)
        end
      end
    end
  end

  reaper.Undo_EndBlock("Import Chordino Chords to MIDI", -1)
  reaper.UpdateArrange()
  reaper.PreventUIRefresh(-1)
  
end

-- Run the main workflow
main_workflow()
