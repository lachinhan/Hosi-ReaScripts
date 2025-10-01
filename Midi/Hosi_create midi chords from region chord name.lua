--[[
* ReaScript Name: Create MIDI chords from region chord name
* Author: MusoBob - ReaTrak - Fixed by Hosi
* Version: 1.1
* Instructions: Name your regions with chord names (e.g., C, Gm7, F#sus4/A). Run the script to generate MIDI items with the corresponding chords in each region. Requires SWS/S&M Extension.
* Changelog:
* v1.2 - Overhauled loop and parsing logic for stability and correctness. Script now iterates through regions by index instead of cursor position to prevent skipping. Fixed chord name parsing syntax error. Added a single undo point.
* v1.1 - Attempted to fix a bug that caused the script to skip the first region.
* v1.0 - Initial release
--]]

-- @description Create MIDI chords from region chord name
-- @version 1.1
-- @author MusoBob - ReaTrak - Fixed by Hosi
-- @provides [main] .

function Msg(variable)
  reaper.ShowConsoleMsg(tostring(variable) .. "\n")
end

local proj = 0 -- Use current project
local region_count = reaper.CountProjectMarkers(proj)

reaper.Undo_BeginBlock() -- Start a single undo block for the whole script
reaper.PreventUIRefresh(1) -- Prevent UI updates for performance

-- NEW: A more reliable loop that iterates through regions by their index, not by cursor position.
for i = 0, region_count - 1 do
  -- Using EnumProjectMarkers3 to get region info by index
  retval, isrgn, region_pos, region_end, region_name, region_index, region_color = reaper.EnumProjectMarkers3(proj, i)

  if isrgn then
    -- Set time selection to the current region's boundaries
    reaper.GetSet_LoopTimeRange(true, true, region_pos, region_end, false)

    -- Insert a new MIDI item in the time selection
    reaper.Main_OnCommand(40214, 0)
    local media = reaper.GetSelectedMediaItem(0, 0)

    if media then
      local take = reaper.GetMediaItemTake(media, 0)
      local length = reaper.BR_GetMidiSourceLenPPQ(take)

      -- FIX: This entire block was previously commented out or had syntax errors.
      -- It is now active and syntactically correct.
      local root, chord, slash
      if string.match(region_name, "@.*") then goto skip end -- skip region marked @ ignore
      
      if string.find(region_name, "/") then
        root, chord, slash = string.match(region_name, "(%w[#b]?)(.*)(/%a[#b]?)$")
      else
        root, chord = string.match(region_name, "(%w[#b]?)(.*)$")
        slash = "" -- Ensure slash is initialized
      end

      if not chord or #chord == 0 then chord = "Maj" end
      if not slash then slash = "" end

      local note1 = 0
      -- 60 = C3
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

      local slashnote = 0
      -- 48 = C2
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

      local note2, note3, note4, note5, note6, note7 = 0, 0, 0, 0, 0, 0

      -- Chord definition library (unchanged)
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

      if note1 > 0 then
        reaper.MIDI_InsertNote(take, true, false, 0, length - 2, 0, note1, 100, false)
        if slashnote > 0 then reaper.MIDI_InsertNote(take, true, false, 0, length - 2, 0, slashnote, 100, false) end
        if note2 > 0 then reaper.MIDI_InsertNote(take, true, false, 0, length - 2, 0, note1 + note2, 100, false) end
        if note3 > 0 then reaper.MIDI_InsertNote(take, true, false, 0, length - 2, 0, note1 + note3, 100, false) end
        if note4 > 0 then reaper.MIDI_InsertNote(take, true, false, 0, length - 2, 0, note1 + note4, 100, false) end
        if note5 > 0 then reaper.MIDI_InsertNote(take, true, false, 0, length - 2, 0, note1 + note5, 100, false) end
        if note6 > 0 then reaper.MIDI_InsertNote(take, true, false, 0, length - 2, 0, note1 + note6, 100, false) end
        if note7 > 0 then reaper.MIDI_InsertNote(take, true, false, 0, length - 2, 0, note1 + note7, 100, false) end
      end
    end
    ::skip::
  end
end

reaper.Main_OnCommand(40635, 0) -- Time selection: Remove time selection
reaper.PreventUIRefresh(-1) -- Allow UI updates again
reaper.Undo_EndBlock("Create MIDI chords from regions", -1) -- End the undo block
reaper.UpdateArrange() -- Update the arrangement view to show new items

