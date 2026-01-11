-- @description Session Player (Ultimate Edition)
-- @version 3.2
-- @author Hosi
-- @about
--   # Session Player
--   A Grid-based Session View for REAPER, tailored for live performance and arrangement.
--   
--   ## Features
--   - Clip Launching with Quantization
--   - Dynamic Scene Management (Add/Remove items and scenes on the fly)
--   - Live Performance Recording to Timeline
--   - Drag & Drop Support
--   - Optimized Waveform Preview
-- @changelog
--   + Added Dynamic Scene Management (Add/Remove Scenes instantly via UI)
--   + Optimized Waveform Rendering (Visibility culling for high performance)
--   + Improved Track Folder Logic (Prevents swallowing of external tracks like Send FX)
--   + Added Persistence for Grid Size (Remembers Track and Scene counts)
--   + Fixed "Ghost Waveform" visual bug when clearing cells
--   + Added Auto-Waveform Generation for new items and duplicates
--   + Added Scene Color Customization (Right-click Scene -> Set Scene Color)
--   + Optimized Memory Management (Auto-clear waveform cache)
--   + Optimized Loop Engine (Uses B_LOOPSRC for infinite looping without item clutter)
--   + Optimized Undo History (Prevents "Loop Extension" spam during playback)
--   + Added MIDI Visualization (Piano Roll view for MIDI cells)
--   + Added Dynamic Content Coloring (Notes/Waveforms inherit Track or Custom Cell colors)
--   + Improved Global Recording Stability (Auto-save on exit, fixed data loss on playback restart)
--   + Added Scene Follow Actions (Auto-sequence scenes: Next, First, Stop after N bars)
-- @provides
--   [main] .

local ctx = reaper.ImGui_CreateContext('Session Player')
local SCRIPT_NAME = "Session Player"

-- ====== Constants ======
local COLS_MAX = 32 
local numRows = 8
local LOOP_LOOKAHEAD = 8.0
local STOP_DELAY_BARS = 0.5
local SCENE_STOP_DELAY_BARS = 0.5
local REC_BARS = 1 -- Fixed 1 Bar recording for now (or use current quantize)
local DONATE_URL = "https://paypal.me/nkstudio" 

-- ====== State ======
local numCols = 8
local slotStateSnapshot = nil

-- Quantize Settings
local quantize_options = {"None", "1/8", "1/4", "1/2", "1 Bar", "2 Bars", "4 Bars"}
local quantize_values = {0, 0.5, 1, 2, 4, 8, 16} -- In beats
local current_quantize_idx = 4 -- Default to "1 Bar" (index 5 -> value 4)

-- Playback State
local cellMemory = {} 
local slotPath = {}   
local slotItem = {}   
local slotName = {}
local cellLoop = {}   
local cellWaveforms = {} -- Waveform Cache: [idx] = { data = {}, minVal, maxVal, sampleRate }
local cellFlashTime = {}
local cellStopPending = {}
local cellLoopLastEnd = {}
local cellRecording = {} -- { state="WAIT"|"REC", start=time, end=time, track=tr }
local scenePlaying = {}
local sceneTriggered = {}
local sceneFlashTime = {}
local queuedScene = nil
local sceneNames = {} -- NEW: Store custom scene names
local sceneFollowAction = {} -- "None", "Next", "First", "Stop"
local sceneFollowDuration = {} -- Duration in bars (default 4)
local activeSceneRow = -1 -- Currently active scene for follow action tracking
local activeSceneStartTime = 0 
local global_performance_record = false -- Toggle for "Global Record" mode
local performanceRecordingItems = {} -- [col] = item (Active recording items on timeline)


local selectedCell = -1

-- Initialize Arrays
for i = 1, COLS_MAX * numRows do
    cellMemory[i] = { path = nil, loop = false, name = nil, color = nil, sourceGUID = nil, followAction = "None" }
    slotItem[i] = {}
    cellFlashTime[i] = 0
    cellLoop[i] = false
end
for r = 1, numRows do
    scenePlaying[r] = false
    sceneFlashTime[r] = 0
    sceneNames[r] = "Scene " .. r -- Default names
    sceneFollowAction[r] = "None"
    sceneFollowDuration[r] = 4
end





-- ====== THEME DEFINITIONS ======
local themes = {
    ["Modern Dark"] = {
        WinBg = 0x121212FF,
        ChildBg = 0x1E1E1EFF,
        FrameBg = 0x2C2C3EFF,
        Button = 0x2C2C3EFF,
        ButtonHovered = 0x3D3D55FF,
        ButtonActive = 0x4A90E2FF,
        Header = 0x2C2C3EFF,
        Text = 0xE0E0E0FF,
        Border = 0x40404077,
        CellIdle = 0x2C2C3EFF, 
        CellActive = 0x4A90E2FF,
        CellRec = 0xFF4444FF,
        CellPlay = 0x00CC66FF
    },
    ["Midnight Blue"] = {
        WinBg = 0x0F111AFF,
        ChildBg = 0x161925FF,
        FrameBg = 0x202436FF,
        Button = 0x202436FF,
        ButtonHovered = 0x2E344EFF,
        ButtonActive = 0x00D9D9FF,
        Header = 0x202436FF,
        Text = 0xDDE6FFFF,
        Border = 0x30365077,
        CellIdle = 0x202436FF,
        CellActive = 0x00D9D9FF,
        CellRec = 0xFF5555FF,
        CellPlay = 0x00AAFFFF
    },
    ["Classic"] = {
        WinBg = 0x333333FF,
        ChildBg = 0x282828FF,
        FrameBg = 0x454545FF,
        Button = 0x454545FF,
        ButtonHovered = 0x555555FF,
        ButtonActive = 0x777777FF,
        Header = 0x454545FF,
        Text = 0xDDDDDDFF,
        Border = 0x00000077,
        CellIdle = 0x454545FF,
        CellActive = 0xAAAAAAFF,
        CellRec = 0xCC4444FF,
        CellPlay = 0x44CC44FF
    }
}
local current_theme_name = "Modern Dark"
local theme_names = {"Modern Dark", "Midnight Blue", "Classic"}

-- Helper: unpacking colors
local function hex2rgba(hex)
    local r = ((hex >> 24) & 0xFF) / 255.0
    local g = ((hex >> 16) & 0xFF) / 255.0
    local b = ((hex >> 8) & 0xFF) / 255.0
    local a = (hex & 0xFF) / 255.0
    return r, g, b, a
end

local function nativeColorToRgba(native_color)
    if native_color == 0 then return nil end -- Default color
    local r, g, b = reaper.ColorFromNative(native_color)
    return (r << 24) | (g << 16) | (b << 8) | 0xFF
end

-- ====== Persistence (Save/Load) ======
-- (Keep existing serialization functions)
local function serializeTable(val, name, skipnewlines, depth)
    skipnewlines = skipnewlines or false
    depth = depth or 0
    local tmp = string.rep(" ", depth)
    
    if name then 
        if type(name) == "number" then
            tmp = tmp .. "[" .. name .. "] = "
        elseif type(name) == "string" then
            if string.match(name, "^[%a_][%w_]*$") then
                tmp = tmp .. name .. " = "
            else
                tmp = tmp .. string.format("[%q] = ", name)
            end
        else
            tmp = tmp .. "[\"" .. tostring(name) .. "\"] = "
        end
    end

    if type(val) == "table" then
        tmp = tmp .. "{" .. (not skipnewlines and "\n" or "")
        for k, v in pairs(val) do
            tmp =  tmp .. serializeTable(v, k, skipnewlines, depth + 1) .. "," .. (not skipnewlines and "\n" or "")
        end
        tmp = tmp .. string.rep(" ", depth) .. "}"
    elseif type(val) == "number" then
        tmp = tmp .. tostring(val)
    elseif type(val) == "string" then
        tmp = tmp .. string.format("%q", val)
    elseif type(val) == "boolean" then
        tmp = tmp .. (val and "true" or "false")
    else
        tmp = tmp .. "\"[inserializeable datatype:" .. type(val) .. "]\""
    end
    return tmp
end

local function deserializeTable(str)
    local f, err = load("return " .. str)
    if f then return f() else return nil end
end

local function resizeScenes(targetRows)
    if targetRows < 1 then return end
    
    if targetRows > numRows then
        -- Expand
        for i = (COLS_MAX * numRows) + 1, COLS_MAX * targetRows do
            cellMemory[i] = { path = nil, loop = false, name = nil, color = nil, sourceGUID = nil, followAction = "None" }
            slotItem[i] = {}
            cellFlashTime[i] = 0
            cellLoop[i] = false
        end
        for r = numRows + 1, targetRows do
            scenePlaying[r] = false
            sceneFlashTime[r] = 0
            sceneNames[r] = "Scene " .. r
            sceneFollowAction[r] = "None"
            sceneFollowDuration[r] = 4
        end
    elseif targetRows < numRows then
        -- Shrink
        for i = (COLS_MAX * targetRows) + 1, COLS_MAX * numRows do
            cellMemory[i] = nil
            slotItem[i] = nil
            cellFlashTime[i] = nil
            cellLoop[i] = nil
            slotPath[i] = nil
            slotName[i] = nil
            cellWaveforms[i] = nil -- Memory Cleanup
        end
        for r = targetRows + 1, numRows do
            scenePlaying[r] = nil
            sceneFlashTime[r] = nil
            sceneNames[r] = nil
            sceneFollowAction[r] = nil
            sceneFollowDuration[r] = nil
        end
    end
    
    numRows = targetRows
end

local function saveState()
    local serialized = serializeTable(cellMemory)
    reaper.SetProjExtState(0, "HosiSessionView", "CellData", serialized)
    reaper.SetProjExtState(0, "HosiSessionView", "QuantizeIdx", tostring(current_quantize_idx))
    reaper.SetProjExtState(0, "HosiSessionView", "Theme", current_theme_name)
    
    -- New Data
    local sceneNamesSerialized = serializeTable(sceneNames)
    reaper.SetProjExtState(0, "HosiSessionView", "SceneNames", sceneNamesSerialized)
    
    local sfa = serializeTable(sceneFollowAction)
    reaper.SetProjExtState(0, "HosiSessionView", "SceneFollowAction", sfa)
    
    local sfd = serializeTable(sceneFollowDuration)
    reaper.SetProjExtState(0, "HosiSessionView", "SceneFollowDuration", sfd)
    
    reaper.SetProjExtState(0, "HosiSessionView", "RecMode", tostring(rec_length_mode))
    reaper.SetProjExtState(0, "HosiSessionView", "ShowWaveforms", show_waveforms and "1" or "0")
    reaper.SetProjExtState(0, "HosiSessionView", "NumCols", tostring(numCols))
    reaper.SetProjExtState(0, "HosiSessionView", "NumRows", tostring(numRows))
end

local function loadState()
    local retval, str = reaper.GetProjExtState(0, "HosiSessionView", "CellData")
    if retval == 1 and str ~= "" then
        local data = deserializeTable(str)
        if data and type(data) == "table" then
            cellMemory = data
            -- Sync volatile arrays
            for i, mem in pairs(cellMemory) do
                if mem.path then
                    slotPath[i] = mem.path
                    slotName[i] = mem.name
                    if mem.loop then 
                        cellLoop[i] = true
                        -- Init Loop Source if needed...
                    end
                end
            end
        end
    end
    local retval2, qVal = reaper.GetProjExtState(0, "HosiSessionView", "QuantizeIdx")
    if retval2 == 1 then current_quantize_idx = tonumber(qVal) end
    
    local retval3, thm = reaper.GetProjExtState(0, "HosiSessionView", "Theme")
    if retval3 == 1 then current_theme_name = thm end
    
    local retval4, snStr = reaper.GetProjExtState(0, "HosiSessionView", "SceneNames")
    if retval4 == 1 and snStr ~= "" then 
        local t = deserializeTable(snStr)
        if t then sceneNames = t end
    end
    
    local retvalFA, faStr = reaper.GetProjExtState(0, "HosiSessionView", "SceneFollowAction")
    if retvalFA == 1 and faStr ~= "" then 
        local t = deserializeTable(faStr)
        if t then sceneFollowAction = t end
    end
    
    local retvalFD, fdStr = reaper.GetProjExtState(0, "HosiSessionView", "SceneFollowDuration")
    if retvalFD == 1 and fdStr ~= "" then 
        local t = deserializeTable(fdStr)
        if t then sceneFollowDuration = t end
    end
    
    local retval5, rmStr = reaper.GetProjExtState(0, "HosiSessionView", "RecMode")
    if retval5 == 1 then rec_length_mode = tonumber(rmStr) end
    
    local retval6, wfStr = reaper.GetProjExtState(0, "HosiSessionView", "ShowWaveforms")
    if retval6 == 1 then show_waveforms = (wfStr == "1") end
    
    local retval7, ncStr = reaper.GetProjExtState(0, "HosiSessionView", "NumCols")
    if retval7 == 1 then numCols = tonumber(ncStr) end
    
    local retval8, nrStr = reaper.GetProjExtState(0, "HosiSessionView", "NumRows")
    if retval8 == 1 then 
        local nr = tonumber(nrStr)
        if nr and nr ~= numRows then
            resizeScenes(nr)
        end
    end
end

local function cleanupOnExit()
    -- Finalize any active performance recordings
    if global_performance_record then
        local playPos = reaper.GetPlayPosition()
        for col, item in pairs(performanceRecordingItems) do
            if reaper.ValidatePtr(item, "MediaItem*") then
                local startPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                local length = playPos - startPos
                
                if length < 0.1 then
                    -- Trash tiny items
                    reaper.DeleteTrackMediaItem(reaper.GetMediaItemTrack(item), item)
                else
                    -- Finalize length
                    reaper.SetMediaItemInfo_Value(item, "D_LENGTH", length)
                    -- Turn off looping for the final item so it doesn't look weird
                    reaper.SetMediaItemInfo_Value(item, "B_LOOPSRC", 0) 
                    reaper.UpdateItemInProject(item)
                end
            end
        end
    end
    
    saveState()
end

reaper.atexit(cleanupOnExit)

-- ====== Helper Functions ======

local function ensureProjectExtendsTo(time)
    if type(time) ~= "number" then return end
    local endTime = reaper.GetSetProjectInfo(0, "PROJECT_LENGTH", 0, false)
    if endTime < time then
        reaper.GetSetProjectInfo(0, "PROJECT_LENGTH", time, true)
    end
end

local function atNextStopGrid(bars)
    local playPos = ((reaper.GetPlayState() & 1) == 1) and reaper.GetPlayPosition() or reaper.GetCursorPosition()
    local qn = reaper.TimeMap2_timeToQN(0, playPos)
    local targetQN = math.floor(qn / bars + 1) * bars
    return reaper.TimeMap2_QNToTime(0, targetQN)
end

-- NEW: Dynamic Quantize Calculation
local function getQuantizedLaunchTime()
    local playPos = ((reaper.GetPlayState() & 1) == 1) and reaper.GetPlayPosition() or reaper.GetCursorPosition()
    local qn = reaper.TimeMap2_timeToQN(0, playPos)
    
    -- Get current quantize value
    local q = quantize_values[current_quantize_idx + 1] -- imgui combos are 0-based usually, but here handled by index
    
    if q == 0 then return playPos end -- None/Instant
    
    -- Snap to next grid
    local quantizedQN = math.ceil(qn / q) * q
    
    -- If we are VERY close to the grid (latency compensation), just launch now or next
    if quantizedQN - qn < 0.01 then quantizedQN = quantizedQN + q end
    
    return reaper.TimeMap2_QNToTime(0, quantizedQN)
end

-- ====== Track Management (Same as original) ======
local parentTrack = nil
local function validTrack(tr) return tr and reaper.ValidatePtr(tr, "MediaTrack*") end
local function getTrackName(tr) local _, n = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false); return n end
local function setTrackName(tr, n) reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", n, true) end

local function findOrCreateParent()
    for i = 0, reaper.CountTracks(0) - 1 do
        local tr = reaper.GetTrack(0, i)
        if validTrack(tr) and getTrackName(tr) == "Session Player" then
            parentTrack = tr
            return
        end
    end
    reaper.InsertTrackAtIndex(0, true)
    parentTrack = reaper.GetTrack(0, 0)
    setTrackName(parentTrack, "Session Player")
    reaper.SetMediaTrackInfo_Value(parentTrack, "I_FOLDERDEPTH", 1)
end

local function getChildTracks()
    local t = {}
    if not validTrack(parentTrack) then return t end
    
    local parentIdx = reaper.GetMediaTrackInfo_Value(parentTrack, "IP_TRACKNUMBER") -- 1-based
    local count = reaper.CountTracks(0)
    
    -- Iterate tracks immediately following parent
    local currentDepth = 0
    -- Parent is at depth 0 relative to itself. Children are at depth 1.
    -- But accessing absolute folder depth is tricky.
    -- Alternative: Iterate and stop when we hit a track that closes the folder level of parent.
    
    for i = parentIdx, count - 1 do
        local tr = reaper.GetTrack(0, i)
        t[#t + 1] = tr
        
        -- Check if this track closes the folder
        local depth = reaper.GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH")
        -- If depth is negative, it might close our parent folder.
        -- "ReaGion Player" is depth 1. Its children are inside.
        -- When a child has depth -1, it closes the parent.
        if depth < 0 then break end
    end
    
    return t
end

local function syncTCP()
    if not validTrack(parentTrack) then findOrCreateParent() end
    local kids = getChildTracks()
    local pidx = reaper.GetMediaTrackInfo_Value(parentTrack, "IP_TRACKNUMBER")
    
    -- Create missing tracks
    for i = #kids + 1, numCols do
        reaper.InsertTrackAtIndex(pidx + i - 1, true)
        setTrackName(reaper.GetTrack(0, pidx + i - 1), "Track " .. i)
    end
    
    -- Remove excess tracks (Safe Mode)
    for i = #kids, numCols + 1, -1 do
        if kids[i] and validTrack(kids[i]) then
            -- SAFETY CHECK: Only delete if name is default "Track X" or empty.
            -- This prevents deleting user's custom tracks that might have been accidentally "swallowed" into the folder.
            local trName = getTrackName(kids[i])
            if trName == "" or trName:match("^Track %d+$") then
                 reaper.DeleteTrack(kids[i])
            else
                 -- User track found implies folder leak. DO NOT DELETE.
                 -- Instead, we will fix the folder boundary below, effectively "ejecting" this track.
            end
        end
    end
    
    -- Update Folder Structure (Strict Enforcement)
    reaper.SetMediaTrackInfo_Value(parentTrack, "I_FOLDERDEPTH", 1)
    
    -- FORCE Update all session tracks by INDEX
    -- This ensures we catch the newly added tracks which might not be in 'kids' yet
    for i = 1, numCols do
        local tr = reaper.GetTrack(0, pidx + i - 1)
        if validTrack(tr) then
            -- Last intended track closes the folder (-1)
            reaper.SetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH", (i == numCols) and -1 or 0)
            
            -- Only set name if empty (new track)
            local currentName = getTrackName(tr)
            if currentName == "" then
                 setTrackName(tr, "Track " .. i)
            end
        end
    end
end

-- ====== Playback Logic (Same as original but uses new getQuantizedLaunchTime) ======

local function stopCell(i)
    local col = ((i - 1) % COLS_MAX) + 1
    
    -- Stop extension of Performance Recording item


    if slotItem[i] and #slotItem[i] > 0 then
        reaper.Undo_BeginBlock() 
        for _, itm in ipairs(slotItem[i]) do
            if reaper.ValidatePtr(itm, "MediaItem*") then
                reaper.DeleteTrackMediaItem(reaper.GetMediaItemTrack(itm), itm)
            end
        end
        reaper.Undo_EndBlock("Stop Cell", -1) 
    end
    cellLoopLastEnd[i] = nil
    slotItem[i] = {}
    cellFlashTime[i] = 0
end

local function playSample(i)
    if not slotPath[i] then return end
    
    local col = ((i - 1) % COLS_MAX) + 1
    local tr = getChildTracks()[col]
    if not validTrack(tr) then syncTCP(); tr = getChildTracks()[col] end
    if not validTrack(tr) then return end

    stopCell(i) 
    
    -- Vertical Exclusion: Stop all other cells in this column
    for r = 1, numRows do
        local otherIdx = (r - 1) * COLS_MAX + col
        if otherIdx ~= i and slotItem[otherIdx] and #slotItem[otherIdx] > 0 then
            stopCell(otherIdx)
        end
    end

    sceneTriggered[i] = false -- Reset Follow Action trigger flag

    reaper.Undo_BeginBlock()

    local src = reaper.PCM_Source_CreateFromFile(slotPath[i])
    if not src then reaper.Undo_EndBlock("Play Fail", -1); return end

    local itm = reaper.AddMediaItemToTrack(tr)
    local tk = reaper.AddTakeToMediaItem(itm)
    reaper.SetMediaItemTake_Source(tk, src)
    reaper.SetMediaItemTakeInfo_Value(tk, "D_STARTOFFS", 0)
    reaper.SetMediaItemInfo_Value(itm, "C_BEATATTACHMODE", 1)
    
    local pos = getQuantizedLaunchTime()
    reaper.SetMediaItemInfo_Value(itm, "D_POSITION", pos)
    
    local length, _ = reaper.GetMediaSourceLength(src)
    reaper.SetMediaItemInfo_Value(itm, "D_LENGTH", length)
    
    reaper.UpdateItemInProject(itm)
    
    reaper.UpdateItemInProject(itm)
    
    reaper.Undo_EndBlock("Launch Clip", -1)

    if (reaper.GetPlayState() & 1) == 0 then
        reaper.OnPlayButton()
    end

    slotItem[i] = { itm }
    cellLoopLastEnd[i] = pos + length
    
    -- PERFORMANCE RECORDING LOGIC
    if global_performance_record then
        -- Create a separate item for the arrangement
        local recItem = reaper.AddMediaItemToTrack(tr)
        local recTake = reaper.AddTakeToMediaItem(recItem)
        reaper.SetMediaItemTake_Source(recTake, src)
        reaper.SetMediaItemTakeInfo_Value(recTake, "D_STARTOFFS", 0)
        
        reaper.SetMediaItemInfo_Value(recItem, "D_POSITION", pos)
        reaper.SetMediaItemInfo_Value(recItem, "D_LENGTH", 0.001) -- Start length
        reaper.SetMediaItemInfo_Value(recItem, "B_LOOPSRC", 1) -- Auto loop source
        
        reaper.UpdateItemInProject(recItem)
        
        performanceRecordingItems[col] = recItem
    end
    

end

local function updateLoopedCell(cellIndex)
    if cellStopPending[cellIndex] then return end
    if (reaper.GetPlayState() & 1) == 0 then return end
    
    local item = slotItem[cellIndex] and slotItem[cellIndex][1]
    if not item or not reaper.ValidatePtr(item, "MediaItem*") then return end
    
    local playPos = reaper.GetPlayPosition()
    
    -- LOOP LOGIC
    -- LOOP LOGIC
    if cellLoop[cellIndex] then
        -- OPTIMIZED: Extend item length using Loop Source
        if cellLoopLastEnd[cellIndex] < playPos + LOOP_LOOKAHEAD then
            -- Ensure Loop Source is active
            if reaper.GetMediaItemInfo_Value(item, "B_LOOPSRC") == 0 then
                reaper.SetMediaItemInfo_Value(item, "B_LOOPSRC", 1)
            end
            
            local take = reaper.GetActiveTake(item)
            local src = reaper.GetMediaItemTake_Source(take)
            local srcLen, _ = reaper.GetMediaSourceLength(src)
            if srcLen <= 0.001 then srcLen = 2.0 end -- Safety fallback
            
            -- Calculate target end time (keep decent buffer ahead)
            local currentItemPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            local currentItemLen = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
            
            -- Extend by source length chunks until we are safe
            local targetEnd = playPos + LOOP_LOOKAHEAD + srcLen 
            local newLen = targetEnd - currentItemPos
            
            -- Snap newLen to exact multiple of srcLen (optional but cleaner for audio)
            local loops = math.ceil(newLen / srcLen)
            newLen = loops * srcLen
            
            reaper.SetMediaItemInfo_Value(item, "D_LENGTH", newLen)
            reaper.UpdateItemInProject(item)
            
            cellLoopLastEnd[cellIndex] = currentItemPos + newLen
            ensureProjectExtendsTo(cellLoopLastEnd[cellIndex] + LOOP_LOOKAHEAD) 
        end
    else
        -- FOLLOW ACTION LOGIC (Loop is OFF)
        local action = cellMemory[cellIndex].followAction
        if action and action ~= "None" and not cellStopPending[cellIndex] then
             -- Trigger shortly before end to allow quantization queue
             local endTime = cellLoopLastEnd[cellIndex]
             -- Trigger 1 BEAT before end? Or just 0.5s?
             -- If we trigger too late, it might miss the quantization grid of the Next bar.
             -- If we trigger too early, we might cut short? 
             -- `playCell` logic calculates `startQN` based on NEXT bar.
             -- So we should trigger it BEFORE the current item ends, allowing `playCell` to schedule the Next item exactly at `endTime`.
             
             local preRoll = 0.5 -- seconds. Good enough?
             
             if playPos >= endTime - preRoll and not sceneTriggered[cellIndex] then -- recycling sceneTriggered or add new?
                 -- Let's use a specific flag in cellMemory? No, run-time state.
                 -- Validating: "Next", "Prev", "First", "Random", "Stop"
                 
                 local target = -1
                 local col = ((cellIndex - 1) % COLS_MAX) + 1
                 local row = math.floor((cellIndex - 1) / COLS_MAX) + 1
                 
                 if action == "Next" then
                     if row < numRows then target = cellIndex + COLS_MAX end
                 elseif action == "Prev" then
                     if row > 1 then target = cellIndex - COLS_MAX end
                 elseif action == "First" then
                     target = col -- Row 1
                 elseif action == "Random" then
                     local r = math.random(1, numRows)
                     target = (r - 1) * COLS_MAX + col
                 elseif action == "Stop" then
                     stopCell(cellIndex)
                 end
                 
                 if target ~= -1 and target ~= cellIndex then
                     -- Trigger Play
                     playSample(target)
                 end
                 
                 sceneTriggered[cellIndex] = true -- reusing this table as "followTriggered" since it's per-index
             end
        end
    end
end

local function stopSceneRow(r)
    local stopTime = atNextStopGrid(SCENE_STOP_DELAY_BARS)
    for c = 1, numCols do
        local i = (r - 1) * COLS_MAX + c
        if slotItem[i] and #slotItem[i] > 0 then
            cellStopPending[i] = stopTime
            cellFlashTime[i] = reaper.time_precise()
        end
    end
    scenePlaying[r] = false
    if activeSceneRow == r then
        activeSceneRow = -1
    end
end

-- ====== Scene Helpers (Moved here to access stopSceneRow) ======
local sceneClipboard = nil

local function captureScene(r)
    for c = 1, numCols do
        local playingInfo = nil
        for rr = 1, numRows do
            local idx = (rr - 1) * COLS_MAX + c
            if slotItem[idx] and #slotItem[idx] > 0 then
                playingInfo = cellMemory[idx]
                break
            end
        end
        if playingInfo then
            local target = (r - 1) * COLS_MAX + c
            cellMemory[target] = {
                path = playingInfo.path,
                loop = playingInfo.loop,
                name = playingInfo.name,
                color = playingInfo.color,
                sourceGUID = playingInfo.sourceGUID,
                followAction = playingInfo.followAction or "None"
            }
            slotPath[target] = playingInfo.path
            slotName[target] = playingInfo.name
            cellLoop[target] = playingInfo.loop
            if show_waveforms then generateWaveform(target) end
        end
    end
end

local function copyScene(r)
    local data = {}
    for c = 1, numCols do
        local idx = (r - 1) * COLS_MAX + c
        data[c] = {
            path = cellMemory[idx].path,
            loop = cellMemory[idx].loop,
            name = cellMemory[idx].name,
            color = cellMemory[idx].color,
            sourceGUID = cellMemory[idx].sourceGUID,
            followAction = cellMemory[idx].followAction or "None"
        }
    end
    sceneClipboard = data
end

local function pasteScene(r)
    if not sceneClipboard then return end
    for c = 1, numCols do
        if sceneClipboard[c] then
            local idx = (r - 1) * COLS_MAX + c
            local src = sceneClipboard[c]
            cellMemory[idx] = {
                path = src.path,
                loop = src.loop,
                name = src.name,
                color = src.color,
                sourceGUID = src.sourceGUID,
                followAction = src.followAction or "None"
            }
            slotPath[idx] = src.path
            slotName[idx] = src.name
            cellLoop[idx] = src.loop
            if show_waveforms then generateWaveform(idx) end
        end
    end
end

local function clearScene(r)
    stopSceneRow(r) 
    for c = 1, numCols do
        local idx = (r - 1) * COLS_MAX + c
        cellMemory[idx] = { path = nil, loop = false, name = nil, color = nil, sourceGUID = nil, followAction = "None" }
        slotPath[idx] = nil
        slotName[idx] = nil
        cellLoop[idx] = false
        cellWaveforms[idx] = nil
    end
end

local function captureScene(targetRow)
    for c = 1, numCols do
        local foundPlayingIdx = nil
        
        -- Find playing cell in this column
        for r = 1, numRows do
            local idx = (r - 1) * COLS_MAX + c
            if slotItem[idx] and #slotItem[idx] > 0 then
                foundPlayingIdx = idx
                break
            end
        end
        
        local targetIdx = (targetRow - 1) * COLS_MAX + c
        
        if foundPlayingIdx then
            local src = cellMemory[foundPlayingIdx]
            cellMemory[targetIdx] = {
                path = src.path,
                loop = src.loop,
                name = src.name,
                color = src.color,
                sourceGUID = src.sourceGUID,
                followAction = src.followAction
            }
            slotPath[targetIdx] = src.path
            slotName[targetIdx] = src.name
            cellLoop[targetIdx] = src.loop
            if show_waveforms then generateWaveform(targetIdx) end
            
            -- If we captured from the SAME row we are targeting, no change needed.
            -- If we captured from a different row, we successfully moved it.
        else
            -- Nothing playing in this track.
            -- PREVIOUSLY: We cleared the target slot (Snapshot mode).
            -- FIX: Do nothing. Keep existing content in the target slot (Merge mode).
            -- This prevents Accidental Deletion of stopped cells in the target row.
        end
    end
end

local function duplicateScene(r)
    if r >= numRows then return end
    for c = 1, numCols do
        local srcIdx = (r - 1) * COLS_MAX + c
        local dstIdx = r * COLS_MAX + c
        local src = cellMemory[srcIdx]
        cellMemory[dstIdx] = {
            path = src.path,
            loop = src.loop,
            name = src.name,
            color = src.color,
            sourceGUID = src.sourceGUID,
            followAction = src.followAction or "None"
        }
        slotPath[dstIdx] = src.path
        slotName[dstIdx] = src.name
        cellLoop[dstIdx] = src.loop
        if show_waveforms then generateWaveform(dstIdx) end
    end
end

-- NEW: Scene Batch Helpers
local function setSceneLoop(r, state)
    for c = 1, numCols do
        local i = (r - 1) * COLS_MAX + c
        if cellMemory[i] and slotPath[i] then -- Only affect populated cells
            cellMemory[i].loop = state
            cellLoop[i] = state
            -- Update runtime loop state if playing
            if (slotItem[i] and #slotItem[i] > 0) then
                updateLoopedCell(i)
            end
        end
    end
end

local function setSceneFollowAction(r, action)
    for c = 1, numCols do
        local i = (r - 1) * COLS_MAX + c
        if cellMemory[i] then
             cellMemory[i].followAction = action
        end
    end
end

-- NEW: Waveform State
local show_waveforms = false
local cellWaveforms = {} -- Cache: [i] = { peaks = {min, max, ...}, width = 90 }

local function generateWaveform(i)
    if not show_waveforms then return end
    
    local path = slotPath[i]
    if not path then return end
    
    -- Skip MIDI files check removed. Now we handle them!
    local isMidi = path:lower():match("%.mid$") or path:lower():match("%.midi$")
    
    -- Create temp item to read source? Or use existing slotItem if available?
    -- Better: create a temporary source/accessor if not playing to avoid glitching playback,
    -- But GetAudioAccessor requires a Take. 
    -- So we need a Take.
    
    local take = nil
    local item_to_delete = nil
    
    -- Check if we have a live item for this cell
    if slotItem[i] and slotItem[i][1] and reaper.ValidatePtr(slotItem[i][1], "MediaItem*") then
        take = reaper.GetActiveTake(slotItem[i][1])
    else
        -- Create a temporary item on the parent track just to read peaks
        -- This is heavy but necessary if we only have a file path
        if validTrack(parentTrack) then
             reaper.PreventUIRefresh(1)
             local item = reaper.AddMediaItemToTrack(parentTrack)
             take = reaper.AddTakeToMediaItem(item)
             local src = reaper.PCM_Source_CreateFromFile(path)
             if src then
                 reaper.SetMediaItemTake_Source(take, src)
                 reaper.SetMediaItemInfo_Value(item, "D_LENGTH", reaper.GetMediaSourceLength(src))
                 item_to_delete = item
             end
             reaper.PreventUIRefresh(-1)
        end
    end
    
    if not take or not reaper.ValidatePtr(take, "MediaItem_Take*") then return end
    
    -- MIDI PARSING
    if isMidi then
        local notes = {}
        local src = reaper.GetMediaItemTake_Source(take)
        local len = reaper.GetMediaSourceLength(src)
        if len <= 0.001 then len = 4.0 end -- Fallback length for empty MIDI
        
        -- Iterate notes
        local retval, notecnt, _, _ = reaper.MIDI_CountEvts(take)
        local minPitch = 127
        local maxPitch = 0
        local hasNotes = false
        
        -- Optimization: Limit to first 100 notes to save performance?
        local limit = math.min(notecnt, 200) 
        
        for n = 0, limit - 1 do
            local rv, sel, muted, startppq, endppq, chan, pitch, vel = reaper.MIDI_GetNote(take, n)
            if rv then
                hasNotes = true
                if pitch < minPitch then minPitch = pitch end
                if pitch > maxPitch then maxPitch = pitch end
                
                local start_sec = reaper.MIDI_GetProjTimeFromPPQPos(take, startppq)
                -- MIDI_GetProjTimeFromPPQPos returns Project Time. 
                -- We need relative time from item start? No, Take start is 0 in PPQ usually unless looped.
                -- Actually GetMediaItemTake_Source refers to the source.
                -- Let's use PPQ and convert to seconds relative to QN? 
                -- Simpler: MIDI_GetProjTimeFromPPQPos is affected by Project Tempo map.
                -- If we just created the item, it's at position 0?
                -- Wait, we added temp item at cursor or something?
                -- We added item to parentTrack. 
                
                -- Let's rely on basic PPQ to time linear assumption for preview or just use QN?
                -- Better: item start is wherever we placed it.
                -- Let's treat PPQ relative to start.
                
                local offset = reaper.GetMediaItemInfo_Value(reaper.GetMediaItemTake_Item(take), "D_POSITION")
                start_sec = start_sec - offset
                local end_sec = reaper.MIDI_GetProjTimeFromPPQPos(take, endppq) - offset
                
                table.insert(notes, {
                    s = start_sec / len, -- Start Pct
                    l = (end_sec - start_sec) / len, -- Length Pct
                    p = pitch -- Pitch (Raw)
                })
            end
        end
        
        -- Normalize Pitch
        if not hasNotes then minPitch = 0; maxPitch = 127 end
        local pitchRange = maxPitch - minPitch
        if pitchRange < 12 then 
            minPitch = minPitch - (12 - pitchRange)/2 
            maxPitch = maxPitch + (12 - pitchRange)/2
            pitchRange = 12 
        end
        
        for _, note in ipairs(notes) do
            note.np = (note.p - minPitch) / pitchRange -- Normalized Pitch (0 = Bottom/Low, 1 = Top/High)
        end
        
        cellWaveforms[i] = { type="midi", notes=notes }
        
        if item_to_delete then
            reaper.DeleteTrackMediaItem(reaper.GetMediaItemTrack(item_to_delete), item_to_delete)
        end
        return
    end

    local accessor = reaper.CreateTakeAudioAccessor(take)
    local src = reaper.GetMediaItemTake_Source(take)
    local len = reaper.GetMediaSourceLength(src)
    local sampleRate = reaper.GetMediaSourceSampleRate(src)
    if sampleRate == 0 then sampleRate = 44100 end
    local numChannels = 1 -- Peak read usually mono sum
    
    local width = 90 -- Pixel width
    local samples_per_pixel = math.floor((len * sampleRate) / width)
    if samples_per_pixel < 1 then samples_per_pixel = 1 end
    
    local peaks = {}
    local buf = reaper.new_array(samples_per_pixel * numChannels)
    
    for px = 0, width - 1 do
        local start_time = (px / width) * len
        local retval = reaper.GetAudioAccessorSamples(accessor, sampleRate, numChannels, start_time, samples_per_pixel, buf)
        
        -- Simple peak finding in this block
        local min_val = 0
        local max_val = 0
        
        -- Quick scan (downsample for speed if block is huge?)
        -- Lua loop is slow. Let's sample a few points or resize
        -- Actually, GetAllPeaks might be better if available, but manual is more robust for script.
        -- Optimize: Iterate with step if huge
        local step = 1
        if samples_per_pixel > 1000 then step = math.floor(samples_per_pixel / 100) end
        
        local table_buf = buf.table()
        for s = 1, #table_buf, step do
            local v = table_buf[s]
            if v < min_val then min_val = v end
            if v > max_val then max_val = v end
        end
        
        peaks[#peaks + 1] = min_val
        peaks[#peaks + 1] = max_val
    end
    
    reaper.DestroyAudioAccessor(accessor)
    if item_to_delete then
        reaper.DeleteTrackMediaItem(parentTrack, item_to_delete)
    end
    
    cellWaveforms[i] = peaks
end

-- ====== LIVE LOOPING LOGIC ======

local function recordCell(i)
    -- 1. Determine Timing (Next Bar Start)
    local playPos = ((reaper.GetPlayState() & 1) == 1) and reaper.GetPlayPosition() or reaper.GetCursorPosition()
    local qn = reaper.TimeMap2_timeToQN(0, playPos)
    
    -- Snap to next Bar (assuming 4/4 or whatever signature is active)
    local beatsPerBar = 4 
    local _, sigNum, _ = reaper.TimeMap_GetTimeSigAtTime(0, playPos)
    if sigNum then beatsPerBar = sigNum end
    
    local startQN = math.ceil(qn / beatsPerBar) * beatsPerBar
    -- If too close, jump to next
    if startQN - qn < 0.1 then startQN = startQN + beatsPerBar end
    
    local startTime = reaper.TimeMap2_QNToTime(0, startQN)
    
    -- Length: Use Quantize Setting
    local q = quantize_values[current_quantize_idx + 1]
    local recBeats = 4 -- Default fallback
    
    if q > 0 then
        recBeats = q
    else
        -- Default to 1 Bar if Quantize is None
        local beatsPerBar = 4 
        local _, sigNum = reaper.TimeMap_GetTimeSigAtTime(0, playPos)
        if sigNum then beatsPerBar = sigNum end
        recBeats = beatsPerBar
    end
    
    local endTime = reaper.TimeMap2_QNToTime(0, startQN + recBeats)
    
    -- 2. Validate Track
    local col = ((i - 1) % COLS_MAX) + 1
    local tr = getChildTracks()[col]
    if not validTrack(tr) then syncTCP(); tr = getChildTracks()[col] end
    if not validTrack(tr) then return end
    
    -- 3. Arm Track (Don't toggle global Record yet)
    reaper.SetMediaTrackInfo_Value(tr, "I_RECARM", 1)
    reaper.SetMediaTrackInfo_Value(tr, "I_RECMON", 1) -- Input Monitor ON
    reaper.SetMediaTrackInfo_Value(tr, "I_RECMODE", 0) -- Record Input
    
    -- 4. Set State
    cellRecording[i] = { state="WAIT", start=startTime, recEnd=endTime, track=tr }
    cellFlashTime[i] = reaper.time_precise()
end

local function updateRecording()
    local now = reaper.GetPlayPosition()
    if (reaper.GetPlayState() & 1) == 0 then now = reaper.GetCursorPosition() end
    
    local anyRecording = false
    local globalRec = (reaper.GetPlayState() & 4) == 4
    
    for i, state in pairs(cellRecording) do
        -- WAITING TO START
        if state.state == "WAIT" then
             if now >= state.start - 0.05 then -- Lookahead start
                 state.state = "REC"
                 cellFlashTime[i] = reaper.time_precise()
                 
                 -- Start Transport Recording if not active
                 if not globalRec then
                     reaper.Main_OnCommand(1013, 0) -- Transport: Record
                     globalRec = true
                 end
             end
             
        -- RECORDING
        elseif state.state == "REC" then
             if now >= state.recEnd - 0.1 then -- Lookahead end (stop slightly early to catch item?) or just wait
                 -- FINISH RECORDING
                 
                 -- 1. Disarm Track (so REAPER finishes this item?)
                 -- Actually, if we disarm, REAPER keeps recording to end of buffer usually.
                 -- Cleaner to just crop the result later.
                 reaper.SetMediaTrackInfo_Value(state.track, "I_RECARM", 0) 
                 
                 -- 2. Identify the new item
                 local itemCnt = reaper.CountTrackMediaItems(state.track)
                 local newItem = reaper.GetTrackMediaItem(state.track, itemCnt - 1)
                 
                 if newItem then
                     -- 3. Crop and Setup
                     reaper.SetMediaItemInfo_Value(newItem, "D_POSITION", state.start)
                     reaper.SetMediaItemInfo_Value(newItem, "D_LENGTH", state.recEnd - state.start)
                     reaper.SetMediaItemInfo_Value(newItem, "B_LOOPSRC", 1) -- Loop source
                     
                     -- 4. Register to Cell
                     local take = reaper.GetActiveTake(newItem)
                     if take then
                         local src = reaper.GetMediaItemTake_Source(take)
                         local filename = reaper.GetMediaSourceFileName(src, "")
                         
                         cellMemory[i].loop = true
                         cellMemory[i].path = filename
                         cellMemory[i].name = "Rec " .. os.date("%H:%M:%S")
                         
                         slotPath[i] = filename
                         slotName[i] = cellMemory[i].name
                         slotItem[i] = { newItem }
                         cellLoop[i] = true
                         
                         -- 5. Force Play
                         cellLoopLastEnd[i] = state.recEnd
                     end
                 end
                 
                 cellRecording[i] = nil -- Done
             end
        end
    end
    
    -- Check if we should stop Global Record (if no cells are REC or WAIT)
    -- Only stop if we are actually recording
    if globalRec then
        local activeRecs = 0
        for _, s in pairs(cellRecording) do
            if s.state == "REC" or s.state == "WAIT" then activeRecs = activeRecs + 1 end
        end
        if activeRecs == 0 then
             -- Stop Global Record but Keep Playing
             -- Action 40042 might toggle off? Or use specific "Stop Recording" action?
             -- 1013 is Record.
             reaper.Main_OnCommand(1013, 0) -- Toggle OFF
        end
    end
end

local function playSceneRow(r)

    sceneFlashTime[r] = reaper.time_precise()
    
    -- Track Active Scene for Follow Action
    activeSceneRow = r
    
    -- Calculate "Start Time" for Follow Action
    -- We use getQuantizedLaunchTime() logic, but simplified since playSample calculates it individually.
    -- Better to use current time + quantization delay.
    -- Or just use the time of the first triggered cell?
    -- Let's approximate: Launch is "Now" (quantized).
    -- If we use QN:
    local playPos = ((reaper.GetPlayState() & 1) == 1) and reaper.GetPlayPosition() or reaper.GetCursorPosition()
    local qn = reaper.TimeMap2_timeToQN(0, playPos)
    local q = quantize_values[current_quantize_idx + 1]
    if q > 0 then
        local quantizedQN = math.ceil(qn / q) * q
        if quantizedQN - qn < 0.01 then quantizedQN = quantizedQN + q end
        activeSceneStartTime = reaper.TimeMap2_QNToTime(0, quantizedQN)
    else
        activeSceneStartTime = playPos
    end
    
    for c = 1, numCols do
        local i = (r - 1) * COLS_MAX + c
        if slotPath[i] then
            playSample(i)
        else
            -- FIXED: Do NOT stop other cells if this slot is empty.
            -- This allows "Overdub" or "Mixing" scenes (e.g. Drums Sc1 + Bass Sc2).
            -- To stop a track, use the Column Stop button.
        end
    end
end

local function updatePlayback()
    -- Check Recordings
    updateRecording()
    
    local playState = reaper.GetPlayState()
    local isPlaying = (playState & 1) == 1
    
    -- 1. Auto-Stop Logic: If Transport Stops, Reset Session
    if not isPlaying then
        for i = 1, COLS_MAX * numRows do
             if slotItem[i] and #slotItem[i] > 0 then
                 stopCell(i)
             end
             -- Also clear stop pending
             cellStopPending[i] = nil
        end
        performanceRecordingItems = {} -- Release record items so they are safe
        return -- Exit early, no need to check progress
    end
    
    local now = reaper.GetPlayPosition()
    
    -- Update Performance Recording Items (Grow them)
    if global_performance_record then
        for col, itm in pairs(performanceRecordingItems) do
            if reaper.ValidatePtr(itm, "MediaItem*") then
                local startPos = reaper.GetMediaItemInfo_Value(itm, "D_POSITION")
                local newLen = now - startPos
                if newLen > 0 then
                    reaper.SetMediaItemInfo_Value(itm, "D_LENGTH", newLen)
                    reaper.UpdateItemInProject(itm)
                end
            else
                performanceRecordingItems[col] = nil 
            end
        end
    else
        performanceRecordingItems = {}
    end
    



    for i = 1, COLS_MAX * numRows do
        if cellStopPending[i] and now >= cellStopPending[i] - 0.05 then
            cellStopPending[i] = nil
            stopCell(i)
        end
    end
    for i = 1, COLS_MAX * numRows do
        if slotItem[i] and #slotItem[i] > 0 and not cellLoop[i] then
            local itm = slotItem[i][1]
            if reaper.ValidatePtr(itm, "MediaItem*") then
                local endPos = reaper.GetMediaItemInfo_Value(itm, "D_POSITION") + reaper.GetMediaItemInfo_Value(itm, "D_LENGTH")
                if now >= endPos - 0.05 then stopCell(i) end
            end
        end
        updateLoopedCell(i) 
    end
    
    -- SCENE FOLLOW ACTIONS (Global Check)
    if activeSceneRow > 0 and activeSceneRow <= numRows then
        local action = sceneFollowAction[activeSceneRow]
        local duration = sceneFollowDuration[activeSceneRow]
        
        if action and action ~= "None" and duration and duration > 0 then
            -- Calculate Bars Elapsed
            -- Convert StartTime to QN
            local startQN = reaper.TimeMap2_timeToQN(0, activeSceneStartTime)
            local currentQN = reaper.TimeMap2_timeToQN(0, now)
            
            local elapsedQN = currentQN - startQN
            local durationQN = duration * 4 -- Duration in Bars (4 beats)
            
            -- Pre-roll trigger (0.9 bars before end?)
            -- We want the Next Scene to LAUNCH at exactly Start + Duration.
            -- So we must TRIGGER it before that.
            -- Quantization is traditionally 1 Bar.
            -- So we should trigger it slightly before the last bar starts?
            -- E.g. at 3.9 bars?
            
            -- If we are within 1 beat of the transition point?
            -- Let's say we want to trigger it 0.5 beats before the Quantization Grid of the Target Time.
            -- Target Time = startQN + durationQN
            
            if elapsedQN >= (durationQN - 0.25) then
                 -- Trigger Action!
                 local target = -1
                 
                 if action == "Next" then
                     if activeSceneRow < numRows then target = activeSceneRow + 1 end
                 elseif action == "First" then
                     target = 1
                 elseif action == "Stop" then
                     target = 0 -- Special code for Stop
                 end
                 
                 if target ~= -1 then
                     if target == 0 then
                         stopSceneRow(activeSceneRow)
                     else
                         playSceneRow(target)
                     end
                     -- Reset activeSceneRow is handled by playSceneRow or stopSceneRow
                     -- BUT playSceneRow sets it to Target.
                     -- We must prevent re-triggering this frame?
                     -- activeSceneStartTime will be updated by playSceneRow, so elapsedQN will reset.
                 else
                     -- Invalid target (e.g. Next at last row), just clear active
                     activeSceneRow = -1
                 end
            end
        end
    end
end

-- ====== Function Row Implementation ======
local function F1_AddLastTouchedItem()
    local cell = selectedCell
    if cell == -1 then reaper.ShowMessageBox("Select a cell first.", "F1 - Add Item", 0) return end
    
    local item = reaper.GetSelectedMediaItem(0, 0)   
    if not item or not reaper.ValidatePtr(item, "MediaItem*") then
         reaper.ShowMessageBox("Touch/Select a media item in the arrange view first.", "F1 - Add Item", 0)
         return
    end
    local take = reaper.GetActiveTake(item)
    if not take or not reaper.ValidatePtr(take, "MediaItem_Take*") then return end
    local src = reaper.GetMediaItemTake_Source(take)
    if not src then return end
    local path = reaper.GetMediaSourceFileName(src, "")
    
    -- Special Handling for Internal MIDI (No File)
    if (not path or path == "") and reaper.TakeIsMIDI(take) then
         -- Check if project is saved
         local _, projFn = reaper.EnumProjects(-1)
         if projFn == "" then
             reaper.MB("Project must be saved before importing MIDI items.\n(Glue operation requires a valid project path to save the .mid file)", "Unsaved Project", 0)
             return
         end

         reaper.PreventUIRefresh(1)
         -- 1. Create Temp Track (Hidden logic optional, simply last track)
         reaper.InsertTrackAtIndex(reaper.CountTracks(0), false)
         local tempTrack = reaper.GetTrack(0, reaper.CountTracks(0)-1)
         
         -- 2. Copy Item via Chunk
         local retval, chunk = reaper.GetItemStateChunk(item, "", false)
         local tempItem = reaper.AddMediaItemToTrack(tempTrack)
         reaper.SetItemStateChunk(tempItem, chunk, false)
         
         -- 3. Select ONLY temp item
         reaper.SelectAllMediaItems(0, false)
         reaper.SetMediaItemSelected(tempItem, true)
         
         -- 4. Glue (Creates .mid file)
         reaper.Main_OnCommand(41588, 0) -- Item: Glue items (ignoring time selection)
         
         local gluedItem = reaper.GetTrackMediaItem(tempTrack, 0)
         if gluedItem then
             local gluedTake = reaper.GetActiveTake(gluedItem)
             if gluedTake then
                 local gluedSrc = reaper.GetMediaItemTake_Source(gluedTake)
                 path = reaper.GetMediaSourceFileName(gluedSrc, "")
                 
                 -- 5. Fallback: Convert to File if Glue returned empty (e.g. unsaved project)
                 if not path or path == "" then
                     -- Action: Convert active take MIDI to .mid file reference
                     reaper.Main_OnCommand(40685, 0) 
                     
                     -- Re-acquire source/path after conversion
                     gluedTake = reaper.GetActiveTake(gluedItem)
                     if gluedTake then
                         gluedSrc = reaper.GetMediaItemTake_Source(gluedTake)
                         path = reaper.GetMediaSourceFileName(gluedSrc, "")
                     end
                 end
             end
         end
         
         -- 6. Cleanup
         reaper.DeleteTrack(tempTrack)
         reaper.PreventUIRefresh(-1)
         
         -- Restore selection of original item
         reaper.SetMediaItemSelected(item, true)
    end
    
    if not path or path == "" then 
        reaper.MB("Could not retrieve file path from item.\nTry saving your project first or ensuring the item is glued to a file.", "F1 Error", 0)
        return 
    end



    cellMemory[cell].path = path
    cellMemory[cell].name = reaper.GetTakeName(take)
    
    -- Store GUID to allow F7 to find and delete it later
    local retval, guid = reaper.GetSetMediaItemInfo_String(item, "GUID", "", false)
    if retval then
        cellMemory[cell].sourceGUID = guid
    end
    
    slotPath[cell] = path
    slotName[cell] = cellMemory[cell].name
    
    cellWaveforms[cell] = nil -- Clear old waveform
    if show_waveforms then generateWaveform(cell) end
end

-- NEW: Delete Function
local function F2_ClearCell()
    if selectedCell ~= -1 then
        stopCell(selectedCell)
        cellMemory[selectedCell] = { path=nil, loop=false, name=nil, color=nil, sourceGUID=nil }
        slotPath[selectedCell] = nil
        slotName[selectedCell] = nil
        cellLoop[selectedCell] = false
        cellWaveforms[selectedCell] = nil -- Clear cached waveform
    end
end

-- NEW: Rename Function
local function F3_RenameCell()
    if selectedCell ~= -1 and slotPath[selectedCell] then
        local retval, name = reaper.GetUserInputs("Rename Slot", 1, "Name:", slotName[selectedCell] or "")
        if retval then
            slotName[selectedCell] = name
            cellMemory[selectedCell].name = name
        end
    end
end

-- NEW: Duplicate Function (F4)
local function F4_DuplicateCell()
    if selectedCell == -1 or not slotPath[selectedCell] then return end
    
    local targetCell = selectedCell + COLS_MAX
    if targetCell > COLS_MAX * numRows then return end -- Out of bounds
    
    -- Copy Data
    cellMemory[targetCell] = {
        path = cellMemory[selectedCell].path,
        loop = cellMemory[selectedCell].loop,
        name = cellMemory[selectedCell].name,
        color = cellMemory[selectedCell].color,
        sourceGUID = cellMemory[selectedCell].sourceGUID -- Copy source ref too? Probably yes.
    }
    slotPath[targetCell] = cellMemory[selectedCell].path
    slotName[targetCell] = cellMemory[selectedCell].name
    cellLoop[targetCell] = cellMemory[selectedCell].loop
    
    -- Copy Waveform or Generate
    if cellWaveforms[selectedCell] then
        cellWaveforms[targetCell] = cellWaveforms[selectedCell]
    elseif show_waveforms then
        generateWaveform(targetCell)
    end
end

-- NEW: Color Picker (F5)
local show_color_picker = false
local function F5_ColorCell()
    if selectedCell ~= -1 then
        show_color_picker = true
    end
end

-- NEW: FX Chain (F6)
local function F6_ShowFX()
    if selectedCell == -1 then return end
    local col = ((selectedCell - 1) % COLS_MAX) + 1
    local tr = getChildTracks()[col]
    if tr and validTrack(tr) then
        reaper.TrackFX_Show(tr, 0, 1) -- 1=show chain
    end
end

-- NEW: Remove Original Item (F7)
local function F7_StopCellFunc()
    if selectedCell == -1 then return end
    
    local guid = cellMemory[selectedCell].sourceGUID
    if not guid then
        reaper.MB("Cannot find original item record for this cell.\n(Maybe it was added before this update?)", "Delete Fail", 0)
        return
    end
    
    local cnt = reaper.CountMediaItems(0)
    local found = false
    for i = 0, cnt - 1 do
        local item = reaper.GetMediaItem(0, i)
        local retval, i_guid = reaper.GetSetMediaItemInfo_String(item, "GUID", "", false)
        if i_guid == guid then
            reaper.DeleteTrackMediaItem(reaper.GetMediaItem_Track(item), item)
            found = true
            -- Clear the reference as it's gone
            cellMemory[selectedCell].sourceGUID = nil
            break
        end
    end
    
    if not found then
        reaper.MB("Original item no longer exists on timeline.", "Info", 0)
    else
        reaper.UpdateArrange()
    end
end

-- NEW: Settings Window (F8)
-- (Existing F8 code...)

-- ====== Cell Clipboard Helpers ======
local cellClipboard = nil

local function copyCell(i)
    if not cellMemory[i].path then return end
    cellClipboard = {
        path = cellMemory[i].path,
        loop = cellMemory[i].loop,
        name = cellMemory[i].name,
        color = cellMemory[i].color,
        sourceGUID = cellMemory[i].sourceGUID,
        followAction = cellMemory[i].followAction or "None"
    }
end

local function cutCell(i)
    copyCell(i)
    -- Clear current cell (Logic from F2_ClearCell)
    stopCell(i)
    cellMemory[i] = { path=nil, loop=false, name=nil, color=nil, sourceGUID=nil, followAction="None" }
    slotPath[i] = nil
    slotName[i] = nil
    cellLoop[i] = false
    cellWaveforms[i] = nil
end

local function pasteCell(i)
    if not cellClipboard then return end
    -- Paste data
    cellMemory[i] = {
        path = cellClipboard.path,
        loop = cellClipboard.loop,
        name = cellClipboard.name,
        color = cellClipboard.color,
        sourceGUID = cellClipboard.sourceGUID,
        followAction = cellClipboard.followAction or "None"
    }
    slotPath[i] = cellClipboard.path
    slotName[i] = cellClipboard.name
    cellLoop[i] = cellClipboard.loop
    -- Note: We don't auto-play paste, just fill slot.
    cellWaveforms[i] = nil -- Clear old waveform
    if show_waveforms then generateWaveform(i) end
end

local function importFileToCell(i)
    local retval, filename = reaper.GetUserFileNameForRead("", "Import Audio/MIDI", "")
    if retval and filename then
        -- Stop cell if playing
        stopCell(i) 
        
        slotPath[i] = filename
        slotName[i] = filename:match("([^/\\]+)$")
        
        cellMemory[i] = {
            path = slotPath[i],
            loop = cellMemory[i].loop or false, -- Preserve loop setting if exists
            name = slotName[i],
            color = cellMemory[i].color,
            sourceGUID = nil, -- Imported file has no source GUID
            followAction = "None"
        }
        cellWaveforms[i] = nil -- Clear old waveform
        if show_waveforms then generateWaveform(i) end
    end
end
                    
-- NEW: Settings (F8)
local show_settings_window = false
local rec_length_mode = 0 -- 0 = Follow Quantize, 1 = Fixed
local function F8_ShowSettings()
    show_settings_window = not show_settings_window
end

-- ====== ImGui UI ======
-- Deleted themes from here to move to top

-- ====== GUI ======
local function gui()
    local window_flags = reaper.ImGui_WindowFlags_MenuBar()
    reaper.ImGui_SetNextWindowSize(ctx, 900, 600, reaper.ImGui_Cond_FirstUseEver())

    local thm = themes[current_theme_name] or themes["Modern Dark"]
    
    -- Apply Global Theme Colors
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(), thm.WinBg)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ChildBg(), thm.ChildBg)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBg(), thm.FrameBg)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), thm.Button)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), thm.ButtonHovered)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), thm.ButtonActive)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(), thm.Header)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), thm.Text)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(), thm.Border)

    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(), 8)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 6)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), 6, 4)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), 8, 8)
    -- REMOVED: reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(), 0x1E1E1EFF) -- Let ReaImGui use Native Theme
    
    local visible, open = reaper.ImGui_Begin(ctx, 'Session Player', true, window_flags)
    
    if visible then
        if reaper.ImGui_BeginMenuBar(ctx) then
            if reaper.ImGui_BeginMenu(ctx, 'Project') then
                if reaper.ImGui_MenuItem(ctx, 'Save State Now') then saveState() end
                if reaper.ImGui_MenuItem(ctx, 'Refresh Tracks') then syncTCP() end
                reaper.ImGui_EndMenu(ctx)
            end
            
             -- Theme Selector
            if reaper.ImGui_BeginMenu(ctx, 'Theme') then
                for _, name in ipairs(theme_names) do
                    if reaper.ImGui_MenuItem(ctx, name, nil, name == current_theme_name) then
                        current_theme_name = name
                    end
                end
                reaper.ImGui_EndMenu(ctx)
            end
            
            reaper.ImGui_SetNextItemWidth(ctx, 100)
            local changed
            changed, current_quantize_idx = reaper.ImGui_Combo(ctx, "Quantize", current_quantize_idx, table.concat(quantize_options, "\0").."\0")
            
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_SetCursorPosX(ctx, reaper.ImGui_GetCursorPosX(ctx) + 20)
            local rv_rec, new_rec = reaper.ImGui_Checkbox(ctx, "Global Record", global_performance_record)
            if rv_rec then global_performance_record = new_rec end
            
            if global_performance_record then
                 reaper.ImGui_SameLine(ctx)
                 if (reaper.time_precise() * 4) % 2 > 1 then
                     reaper.ImGui_TextColored(ctx, 0xFF0000FF, " REC")
                 else
                     reaper.ImGui_TextColored(ctx, 0x550000FF, " REC")
                 end
            end
            
            -- Donate Link (Right aligned)
            local avail_w = reaper.ImGui_GetContentRegionAvail(ctx)
            reaper.ImGui_SameLine(ctx, reaper.ImGui_GetWindowWidth(ctx) - 90)
            if reaper.ImGui_MenuItem(ctx, "☕ Donate") then
                reaper.CF_ShellExecute(DONATE_URL)
            end
            

            
            reaper.ImGui_EndMenuBar(ctx)
        end

        local cell_w = 90
        local cell_h = 50
        local footer_h = 47 
        
        if reaper.ImGui_BeginTable(ctx, 'SessionGrid', numCols + 1, reaper.ImGui_TableFlags_ScrollX() | reaper.ImGui_TableFlags_ScrollY() | reaper.ImGui_TableFlags_BordersInner(), 0, -footer_h * 2) then
            
            -- Setup Columns to Sync with Track Names
            local tracks = getChildTracks()
            for c = 1, numCols do
                local name = "Track " .. c
                if tracks[c] and validTrack(tracks[c]) then
                    name = getTrackName(tracks[c])
                end
                reaper.ImGui_TableSetupColumn(ctx, name, reaper.ImGui_TableColumnFlags_WidthFixed(), cell_w)
            end
            reaper.ImGui_TableSetupColumn(ctx, 'SCENE', reaper.ImGui_TableColumnFlags_WidthFixed(), 80)

            -- Custom Header Row for Renaming
            reaper.ImGui_TableNextRow(ctx, 0)
            for c = 1, numCols do
                reaper.ImGui_TableSetColumnIndex(ctx, c - 1)
                
                local name = "Track " .. c
                if tracks[c] and validTrack(tracks[c]) then name = getTrackName(tracks[c]) end
                
                -- Draw Header Background (using TableHeader with empty string to get style)
                local start_x = reaper.ImGui_GetCursorPosX(ctx)
                local start_y = reaper.ImGui_GetCursorPosY(ctx)
                local col_w, _ = reaper.ImGui_GetContentRegionAvail(ctx)
                
                -- Sync Color from Track
                local trackColor = nil
                if tracks[c] and validTrack(tracks[c]) then
                    local native = reaper.GetTrackColor(tracks[c])
                    trackColor = nativeColorToRgba(native)
                end
                
                -- Use Button for Header: Centers text automatically and handles background color reliably
                local bgColor = trackColor or themes[current_theme_name].Header
                
                -- Calculate Luminance to determine Text Color (Black or White)
                -- bgColor is 0xRRGGBBAA
                local r = (bgColor >> 24) & 0xFF
                local g = (bgColor >> 16) & 0xFF
                local b = (bgColor >> 8) & 0xFF
                local luma = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
                
                local textColor = 0xFFFFFFFF -- White default
                if luma > 0.5 then textColor = 0x000000FF end -- Black if background is bright
                
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), bgColor)
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), bgColor) 
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), bgColor)
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), textColor) -- Push Text Color
                
                -- Draw Button filling the cell width (-1)
                -- Label format: "Name##ID"
                if reaper.ImGui_Button(ctx, name .. "##header_" .. c, -1, 0) then
                    -- Optional: Left click selects the track in REAPER?
                    -- reaper.SetOnlyTrackSelected(tracks[c])
                end
                
                reaper.ImGui_PopStyleColor(ctx, 4) -- Pop 4 colors (Button*3 + Text)

                -- Context Menu (Renaming)
                if reaper.ImGui_BeginPopupContextItem(ctx) then
                    if reaper.ImGui_Selectable(ctx, "Rename Track") then
                        local retval, newName = reaper.GetUserInputs("Rename Track", 1, "New Name:", name)
                        if retval and tracks[c] then
                            setTrackName(tracks[c], newName)
                        end
                    end
                    reaper.ImGui_EndPopup(ctx)
                end
                
                -- Manual text drawing REMOVED (Button handles it)
            end
            
            -- Scene Header
            reaper.ImGui_TableSetColumnIndex(ctx, numCols)
            
            local name = "SCENE"
            local start_x = reaper.ImGui_GetCursorPosX(ctx)
            local start_y = reaper.ImGui_GetCursorPosY(ctx)
            local col_w, _ = reaper.ImGui_GetContentRegionAvail(ctx)
            
            reaper.ImGui_TableHeader(ctx, "##header_scene")
            
            local text_w, _ = reaper.ImGui_CalcTextSize(ctx, name)
            reaper.ImGui_SetCursorPosX(ctx, start_x + (col_w - text_w) * 0.5)
            reaper.ImGui_SetCursorPosY(ctx, start_y + ( reaper.ImGui_GetTextLineHeight(ctx) * 0.2 ))
            
            reaper.ImGui_Text(ctx, name)

            reaper.ImGui_TableNextRow(ctx, 0, 15) 

            for r = 1, numRows do
                reaper.ImGui_TableNextRow(ctx, 0, cell_h + 4)
                
                for c = 1, numCols do
                    reaper.ImGui_TableSetColumnIndex(ctx, c - 1) 
                    local i = (r - 1) * COLS_MAX + c
                    
                    reaper.ImGui_PushID(ctx, i)
                    
                    local isPlaying = slotItem[i] and #slotItem[i] > 0
                    local hasSample = slotPath[i] ~= nil
                    local isSelected = (selectedCell == i)
                    
                    -- THEME COLORS
                    -- Convert Theme Hex to RGBA floats
                    local rI, gI, bI, aI = hex2rgba(thm.CellIdle)
                    local rP, gP, bP, aP = hex2rgba(thm.CellPlay)
                    local rS, gS, bS, aS = hex2rgba(thm.CellActive) 
                    
                    local col_idle     = {rI, gI, bI, aI}
                    
                    -- Check for Custom User Color (F5)
                    local hasCustomColor = false
                    if cellMemory[i].color then
                        local r, g, b, a = reaper.ImGui_ColorConvertU32ToDouble4(cellMemory[i].color)
                        col_hasSample = {r, g, b, a}
                        hasCustomColor = true
                    else
                        col_hasSample = {rS, gS, bS, aS} -- Default Active color
                    end
                    
                    local col_playing   = {rP, gP, bP, aP}
                    local col_loop      = {0.9, 0.7, 0.2, 1.0} -- Amber for loop
                    
                    local finalCol = col_idle
                    
                    if isPlaying then
                        finalCol = col_playing
                         -- If custom color, maybe mix it? Or let Play override custom?
                         -- Let's let Play override custom color to show activity clearly,
                         -- OR pulse the custom color. For now, strict Play Color.
                         
                         local phase = (math.sin(reaper.time_precise() * 8) + 1) * 0.5
                         finalCol = {
                             finalCol[1] + 0.2 * phase,
                             finalCol[2] + 0.2 * phase,
                             finalCol[3] + 0.2 * phase,
                             1.0
                         }
                         if cellLoop[i] then
                            finalCol[1] = (finalCol[1] + col_loop[1]) * 0.5
                            finalCol[2] = (finalCol[2] + col_loop[2]) * 0.5
                            finalCol[3] = (finalCol[3] + col_loop[3]) * 0.5
                         end
                    elseif hasSample then
                        finalCol = col_hasSample
                        if cellLoop[i] then 
                            finalCol[1] = finalCol[1] * 0.7 + col_loop[1] * 0.3
                            finalCol[2] = finalCol[2] * 0.7 + col_loop[2] * 0.3
                            finalCol[3] = finalCol[3] * 0.7 + col_loop[3] * 0.3
                        end
                    elseif hasCustomColor then -- Empty but has color assignment
                        finalCol = col_hasSample
                    end
                    
                    if isSelected then
                         finalCol[1] = math.min(1, finalCol[1] + 0.15)
                         finalCol[2] = math.min(1, finalCol[2] + 0.15)
                         finalCol[3] = math.min(1, finalCol[3] + 0.15)
                    end
                    
                    local colorInt = reaper.ImGui_ColorConvertDouble4ToU32(finalCol[1], finalCol[2], finalCol[3], finalCol[4])
                    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), colorInt)
                    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), colorInt)
                    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), colorInt)
                    
                    local label = slotName[i] or ""
                    
                    if reaper.ImGui_Button(ctx, "##cell", cell_w - 4, cell_h - 4) then
                         selectedCell = i
                         if hasSample then 
                             if isPlaying then
                                 stopCell(i) -- Stop if already playing
                             else
                                 playSample(i) -- Play if stopped
                             end
                         else
                             -- Record Logic
                             if cellRecording[i] then
                                 -- User clicked while Valid/Recording -> CANCEL
                                 local st = cellRecording[i]
                                 if st.track and reaper.ValidatePtr(st.track, "MediaTrack*") then
                                     reaper.SetMediaTrackInfo_Value(st.track, "I_RECARM", 0)
                                 end
                                 cellRecording[i] = nil
                                 -- Global Stop will be handled by updateRecording in next frame
                             else
                                 recordCell(i) 
                             end
                         end
                    end
                    reaper.ImGui_PopStyleColor(ctx, 3)
                    
                    -- Overlay Text and Progress
                    local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
                    local min_x, min_y = reaper.ImGui_GetItemRectMin(ctx)
                    local max_x, max_y = reaper.ImGui_GetItemRectMax(ctx)

                    -- WAVEFORM PREVIEW
                    if show_waveforms and cellWaveforms[i] then
                         -- Optimization: Basic Window Intersection Check (Failsafe)
                         local win_x, win_y = reaper.ImGui_GetWindowPos(ctx)
                         local win_w, win_h = reaper.ImGui_GetWindowSize(ctx)
                         
                         -- Define conservative clip rect (entire window area)
                         local clip_x1 = win_x
                         local clip_y1 = win_y
                         local clip_x2 = win_x + win_w
                         local clip_y2 = win_y + win_h
                         
                         local visible = true
                         -- Check intersection
                         if max_x < clip_x1 or min_x > clip_x2 or max_y < clip_y1 or min_y > clip_y2 then
                             visible = false
                         end

                         if visible then
                             -- DETERMINE CONTENT COLOR (Notes / Waveform)
                             -- Priority: Custom Color > Track Color > Default White
                             local content_base_col = 0xFFFFFF00 -- Default Mask (White)
                             
                             if cellMemory[i].color then
                                 content_base_col = cellMemory[i].color
                             elseif tracks[c] then
                                 local tCol = reaper.GetTrackColor(tracks[c])
                                 if tCol ~= 0 then
                                     local r, g, b = reaper.ColorFromNative(tCol)
                                     content_base_col = reaper.ImGui_ColorConvertDouble4ToU32(r/255, g/255, b/255, 1.0)
                                 end
                             end
                             
                             -- Adjust Alpha/Brightness for Content
                             -- We want content to look "solid" or "bright" against the dimmed background
                             local cr, cg, cb, ca = reaper.ImGui_ColorConvertU32ToDouble4(content_base_col)
                             
                             -- Make it slightly brighter/lighter to pop against background
                             cr = math.min(1.0, cr * 1.5)
                             cg = math.min(1.0, cg * 1.5)
                             cb = math.min(1.0, cb * 1.5)
                             local alpha = 0.9 -- High visibility
                             
                             if isPlaying then
                                 -- If playing, maybe tint Green or just keep Bright?
                                 -- Let's mix slightly with Green to show activity
                                 cg = math.min(1.0, cg + 0.3)
                                 alpha = 1.0
                             end
                             
                             local content_color = reaper.ImGui_ColorConvertDouble4ToU32(cr, cg, cb, alpha)

                             if cellWaveforms[i].type == "midi" then
                                 -- DRAW MIDI
                                 local notes = cellWaveforms[i].notes
                                 if notes then
                                     local content_w = max_x - min_x
                                     local content_h = max_y - min_y
                                     -- Add some padding
                                     local pad = 2
                                     
                                     for _, n in ipairs(notes) do
                                         local nx = min_x + (n.s * content_w)
                                         local nw = math.max(1, n.l * content_w)
                                         -- Invert Pitch: High pitch = Low Y (Top), Low pitch = High Y (Bottom)
                                         -- 1.0 (High) -> min_y
                                         -- 0.0 (Low)  -> max_y
                                         local ny = max_y - (n.np * content_h) - pad
                                         local nh = 3 -- Note height
                                         
                                         if nx < max_x then
                                             -- Clip width
                                             if nx + nw > max_x then nw = max_x - nx end
                                             
                                             reaper.ImGui_DrawList_AddRectFilled(draw_list, nx, ny - nh/2, nx + nw, ny + nh/2, content_color)
                                         end
                                     end
                                 end
                             else
                                 -- DRAW AUDIO
                                 local peaks = cellWaveforms[i]
                                 local num_peaks = #peaks
                                 local center_y = min_y + cell_h * 0.5
                                 local scale = cell_h * 0.45 -- Leave some margin
                                 
                                 for px = 0, (num_peaks/2) - 1 do
                                     local min_v = peaks[px*2 + 1]
                                     local max_v = peaks[px*2 + 2]
                                     
                                     if min_v and max_v then
                                         local x = min_x + px
                                         -- Limit x to max_x
                                         if x < max_x then
                                             local y1 = center_y - (max_v * scale)
                                             local y2 = center_y - (min_v * scale)
                                             -- Ensure at least 1 pixel height
                                             if y2 - y1 < 1 then y2 = y1 + 1 end
                                             
                                             reaper.ImGui_DrawList_AddLine(draw_list, x, y1, x, y2, content_color, 1.0)
                                         end
                                     end
                                 end
                             end
                         end
                    end
                    
                    if isPlaying and slotItem[i][1] and reaper.ValidatePtr(slotItem[i][1], "MediaItem*") then
                        local itm = slotItem[i][1]
                        local start = reaper.GetMediaItemInfo_Value(itm, "D_POSITION")
                        local len = reaper.GetMediaItemInfo_Value(itm, "D_LENGTH")
                        local cur = reaper.GetPlayPosition()
                        local progress = math.max(0, math.min(1, (cur - start) / len))
                        reaper.ImGui_DrawList_AddRectFilled(draw_list, min_x, max_y - 6, min_x + (max_x - min_x) * progress, max_y, 0xFFFFFF66, 6, reaper.ImGui_DrawFlags_RoundCornersBottom())
                        
                        -- Stop Icon (Square)
                        local cx, cy = min_x + 15, min_y + cell_h/2
                        reaper.ImGui_DrawList_AddRectFilled(draw_list, cx - 5, cy - 5, cx + 5, cy + 5, 0xFFFFFFFF)
                    elseif hasSample then
                        -- Play Icon (Triangle)
                        local cx, cy = min_x + 15, min_y + cell_h/2
                        reaper.ImGui_DrawList_AddTriangleFilled(draw_list, cx - 4, cy - 6, cx - 4, cy + 6, cx + 6, cy, 0xFFFFFFFF)
                    else
                        -- Record States
                        local recState = cellRecording[i]
                        local cx, cy = min_x + cell_w/2, min_y + cell_h/2 
                        
                        if recState then
                             if recState.state == "WAIT" then
                                 -- Flash Red
                                 if (reaper.time_precise() * 8) % 2 > 1 then
                                     reaper.ImGui_DrawList_AddCircleFilled(draw_list, cx, cy, 6, 0xFF0000FF)
                                 else
                                     reaper.ImGui_DrawList_AddCircle(draw_list, cx, cy, 6, 0xFF0000FF)
                                 end
                             elseif recState.state == "REC" then
                                 -- Solid Red
                                 reaper.ImGui_DrawList_AddCircleFilled(draw_list, cx, cy, 8, 0xFF0000FF)
                             end
                        else
                             -- Empty Circle
                             reaper.ImGui_DrawList_AddCircle(draw_list, cx, cy, 6, 0x555555AA)
                        end
                    end
                    
                     reaper.ImGui_DrawList_AddText(draw_list, min_x + 6, min_y + 6, 0x000000AA, label)
                     reaper.ImGui_DrawList_AddText(draw_list, min_x + 5, min_y + 5, 0xFFFFFFFF, label)
                     
                     if cellLoop[i] then
                         reaper.ImGui_DrawList_AddCircleFilled(draw_list, max_x - 12, min_y + 12, 3, 0xFFFFFFFF)
                         reaper.ImGui_DrawList_AddCircleFilled(draw_list, max_x - 12, min_y + 12, 2, 0x000000FF)
                     end

                    if reaper.ImGui_BeginPopupContextItem(ctx) then
                        selectedCell = i
                        
                        local dispRow = math.floor((i - 1) / COLS_MAX) + 1
                        local dispCol = ((i - 1) % COLS_MAX) + 1
                        reaper.ImGui_TextDisabled(ctx, "Track " .. dispCol .. " • Scene " .. dispRow)

                        if reaper.ImGui_Selectable(ctx, "Loop", cellLoop[i]) then
                            cellLoop[i] = not cellLoop[i]
                            cellMemory[i].loop = cellLoop[i]
                            if isPlaying then updateLoopedCell(i) end
                        end
                        
                        if reaper.ImGui_BeginMenu(ctx, "Follow Action") then
                            local current = cellMemory[i].followAction or "None"
                            if reaper.ImGui_Selectable(ctx, "None", current == "None") then cellMemory[i].followAction = "None" end
                            if reaper.ImGui_Selectable(ctx, "Next", current == "Next") then cellMemory[i].followAction = "Next" end
                            if reaper.ImGui_Selectable(ctx, "Prev", current == "Prev") then cellMemory[i].followAction = "Prev" end
                            if reaper.ImGui_Selectable(ctx, "First", current == "First") then cellMemory[i].followAction = "First" end
                            if reaper.ImGui_Selectable(ctx, "Random", current == "Random") then cellMemory[i].followAction = "Random" end
                            if reaper.ImGui_Selectable(ctx, "Stop", current == "Stop") then cellMemory[i].followAction = "Stop" end
                            reaper.ImGui_EndMenu(ctx)
                        end
                        
                        reaper.ImGui_Separator(ctx)
                        if reaper.ImGui_Selectable(ctx, "Copy cell") then copyCell(i) end
                        if reaper.ImGui_Selectable(ctx, "Cut cell") then cutCell(i) end
                        
                        local pasteFlags = (cellClipboard == nil) and reaper.ImGui_SelectableFlags_Disabled() or 0
                        if reaper.ImGui_Selectable(ctx, "Paste cell", false, pasteFlags) then pasteCell(i) end
                        
                        reaper.ImGui_Separator(ctx)
                        if reaper.ImGui_Selectable(ctx, "Import File...") then importFileToCell(i) end
                        
                        if reaper.ImGui_Selectable(ctx, "Add Item (F1)") then F1_AddLastTouchedItem() end
                        if reaper.ImGui_Selectable(ctx, "Rename (F3)") then F3_RenameCell() end
                        if reaper.ImGui_Selectable(ctx, "Clear Slot (F2)") then F2_ClearCell() end
                        
                        reaper.ImGui_EndPopup(ctx)
                    end

                    -- DRAG SOURCE (Internal)
                    if reaper.ImGui_BeginDragDropSource(ctx, reaper.ImGui_DragDropFlags_None()) then
                        reaper.ImGui_SetDragDropPayload(ctx, "CELL", tostring(i))
                        reaper.ImGui_Text(ctx, "Move Cell " .. i .. "\n" .. label)
                        reaper.ImGui_EndDragDropSource(ctx)
                    end

                    if reaper.ImGui_BeginDragDropTarget(ctx) then
                        -- 1. Handle Internal Cell Drop
                        local payload_retval, payload_data = reaper.ImGui_AcceptDragDropPayload(ctx, "CELL")
                        if payload_retval then
                            local srcIdx = tonumber(payload_data)
                            if srcIdx and srcIdx ~= i then
                                -- Copy source to *this* target (i)
                                -- Copy logic similar to copyCell -> pasteCell but direct
                                cellMemory[i] = {
                                    path = cellMemory[srcIdx].path,
                                    loop = cellMemory[srcIdx].loop,
                                    name = cellMemory[srcIdx].name,
                                    color = cellMemory[srcIdx].color,
                                    sourceGUID = cellMemory[srcIdx].sourceGUID,
                                    followAction = cellMemory[srcIdx].followAction or "None"
                                }
                                slotPath[i] = cellMemory[srcIdx].path
                                slotName[i] = cellMemory[srcIdx].name
                                cellLoop[i] = cellMemory[srcIdx].loop
                                
                                -- Copy Waveform Cache
                                if cellWaveforms[srcIdx] then
                                    cellWaveforms[i] = cellWaveforms[srcIdx]
                                elseif show_waveforms then
                                    generateWaveform(i)
                                end
                            end
                        end
                        
                        -- 2. Handle External File Drop
                        local file_retval = reaper.ImGui_AcceptDragDropPayloadFiles(ctx)
                        if file_retval then
                            -- It seems retval is true/1. Now fetch the file.
                            local got_file, filename = reaper.ImGui_GetDragDropPayloadFile(ctx, 0)
                            
                            if got_file and filename then
                                file_data = filename
                                
                                -- File dropped!
                                stopCell(i) 
                                
                                slotPath[i] = file_data
                                slotName[i] = file_data:match("([^/\\]+)$")
                                
                                cellMemory[i] = {
                                    path = slotPath[i],
                                    loop = false,
                                    name = slotName[i],
                                    color = nil,
                                    sourceGUID = nil 
                                }
                                cellLoop[i] = false
                                cellWaveforms[i] = nil -- Clear old waveform
                                if show_waveforms then generateWaveform(i) end
                            end
                        end
                        
                        reaper.ImGui_EndDragDropTarget(ctx)
                    end
                    
                    reaper.ImGui_PopID(ctx)
                end
                
                -- Determine if this row is effectively "playing"
                local isRowPlaying = false
                for c_chk = 1, numCols do
                    local i_chk = (r - 1) * COLS_MAX + c_chk
                    if slotItem[i_chk] and #slotItem[i_chk] > 0 then
                        isRowPlaying = true
                        break
                    end
                end
                
                reaper.ImGui_TableSetColumnIndex(ctx, numCols)
                 
                
                if isRowPlaying then
                    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x00FF00AA) 
                else
                    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x66666655)
                end
                
                -- Use InvisibleButton to handle click, then draw items manually to customize layout
                reaper.ImGui_PushID(ctx, "SceneBtn" .. r)
                if reaper.ImGui_Button(ctx, "", 80, cell_h - 4) then
                    if isRowPlaying then
                        stopSceneRow(r)
                    else
                        playSceneRow(r)
                    end
                end
                reaper.ImGui_PopID(ctx)
                
                -- Overlay Text and Icon
                local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
                local min_x, min_y = reaper.ImGui_GetItemRectMin(ctx)
                local max_x, max_y = reaper.ImGui_GetItemRectMax(ctx)
                
                local cx, cy = min_x + 15, min_y + (max_y - min_y)/2
                
                -- Dynamic Color for Scene Button if Active
                if isRowPlaying then
                     reaper.ImGui_DrawList_AddRectFilled(draw_list, min_x, min_y, max_x, max_y, 0x00CC00AA) -- Active Green Overlay
                end

                if isRowPlaying then
                     -- Stop Icon (Square)
                     reaper.ImGui_DrawList_AddRectFilled(draw_list, cx - 5, cy - 5, cx + 5, cy + 5, 0xFFFFFFFF)
                else
                     -- Play Icon (Triangle)
                     reaper.ImGui_DrawList_AddTriangleFilled(draw_list, cx - 4, cy - 6, cx - 4, cy + 6, cx + 6, cy, 0xFFFFFFFF)
                end
                
                -- Centered Text "Scene X" (shifted right slightly due to icon)
                local label = sceneNames[r] or ("Scene " .. r)
                local text_w, text_h = reaper.ImGui_CalcTextSize(ctx, label)
                -- Center between icon end (cx+6) and right edge (max_x)
                local available_w = max_x - (cx + 10)
                local tx = (cx + 10) + (available_w - text_w)/2
                local ty = min_y + (max_y - min_y - text_h)/2
                
                reaper.ImGui_DrawList_AddText(draw_list, tx, ty, 0xFFFFFFFF, label)

                -- Follow Action Indicator
                local sfa = sceneFollowAction[r]
                if sfa and sfa ~= "None" then
                    local dur = sceneFollowDuration[r] or 4
                    local icon = ""
                    if sfa == "Next" then icon = "->"
                    elseif sfa == "First" then icon = "|<"
                    elseif sfa == "Stop" then icon = "[]" end
                    
                    local info = icon .. " " .. dur
                    reaper.ImGui_DrawList_AddText(draw_list, min_x + 4, max_y - 14, 0xAAAAAAFF, info)
                end

                -- Context Menu
                if reaper.ImGui_BeginPopupContextItem(ctx) then
                    reaper.ImGui_TextDisabled(ctx, "Scene " .. r)
                    reaper.ImGui_Separator(ctx)
                    
                    if reaper.ImGui_BeginMenu(ctx, "Batch Loop") then
                        if reaper.ImGui_MenuItem(ctx, "Loop On (All Cells)") then setSceneLoop(r, true) end
                        if reaper.ImGui_MenuItem(ctx, "Loop Off (All Cells)") then setSceneLoop(r, false) end
                        reaper.ImGui_EndMenu(ctx)
                    end
                    
                    reaper.ImGui_Separator(ctx)
                    
                    -- NEW: Scene Follow Actions
                    if reaper.ImGui_BeginMenu(ctx, "Follow Action") then
                         local curAct = sceneFollowAction[r] or "None"
                         if reaper.ImGui_MenuItem(ctx, "None", nil, curAct == "None") then sceneFollowAction[r] = "None" end
                         if reaper.ImGui_MenuItem(ctx, "Next", nil, curAct == "Next") then sceneFollowAction[r] = "Next" end
                         if reaper.ImGui_MenuItem(ctx, "First", nil, curAct == "First") then sceneFollowAction[r] = "First" end
                         if reaper.ImGui_MenuItem(ctx, "Stop", nil, curAct == "Stop") then sceneFollowAction[r] = "Stop" end
                         reaper.ImGui_EndMenu(ctx)
                    end
                    
                    if reaper.ImGui_BeginMenu(ctx, "Follow Duration") then
                         local curDur = sceneFollowDuration[r] or 4
                         local durs = {1, 2, 4, 8, 16, 32}
                         for _, d in ipairs(durs) do
                             if reaper.ImGui_MenuItem(ctx, d .. " Bars", nil, curDur == d) then sceneFollowDuration[r] = d end
                         end
                         -- Custom Input? Maybe later.
                         reaper.ImGui_EndMenu(ctx)
                    end
                    
                    reaper.ImGui_Separator(ctx)
                    
                    if reaper.ImGui_Selectable(ctx, "Rename row...") then
                        local retval, newName = reaper.GetUserInputs("Rename Scene", 1, "Name:", sceneNames[r])
                        if retval then sceneNames[r] = newName end
                    end
                    
                    if reaper.ImGui_Selectable(ctx, "Build scene from currently playing clips") then
                        captureScene(r)
                    end
                    
                    reaper.ImGui_Separator(ctx)
                    
                    if reaper.ImGui_Selectable(ctx, "Copy row") then copyScene(r) end
                    
                    local pasteFlags = (sceneClipboard == nil) and reaper.ImGui_SelectableFlags_Disabled() or 0
                    if reaper.ImGui_Selectable(ctx, "Paste row", false, pasteFlags) then pasteScene(r) end
                    
                    reaper.ImGui_Separator(ctx)
                    
                    if reaper.ImGui_Selectable(ctx, "Duplicate row") then duplicateScene(r) end
                    if reaper.ImGui_Selectable(ctx, "Clear row") then clearScene(r) end

                    reaper.ImGui_EndPopup(ctx)
                end
                

                reaper.ImGui_PopStyleColor(ctx)
                
            end

                         -- Stop Buttons Row
            reaper.ImGui_TableNextRow(ctx, 0, 30)
            local anyTrackPlaying = false
            
            for c = 1, numCols do
                 reaper.ImGui_TableSetColumnIndex(ctx, c - 1)
                 reaper.ImGui_PushID(ctx, "StopBtns"..c)
                 
                 local trackPlaying = false
                 for r=1,numRows do 
                     if slotItem[(r-1)*COLS_MAX+c] and #slotItem[(r-1)*COLS_MAX+c]>0 then 
                         trackPlaying = true
                         break 
                     end 
                 end
                 
                 if trackPlaying then
                     anyTrackPlaying = true
                     if reaper.ImGui_Button(ctx, "Stop", cell_w - 4, 25) then
                         local stopTime = atNextStopGrid(STOP_DELAY_BARS)
                         for r=1,numRows do 
                            local i = (r-1)*COLS_MAX + c
                            if slotItem[i] and #slotItem[i] > 0 then
                                cellStopPending[i] = stopTime
                                cellFlashTime[i] = reaper.time_precise()
                            end
                         end
                     end
                 end
                 reaper.ImGui_PopID(ctx)
            end
            
            -- Stop All Button (Conditional)
            if anyTrackPlaying then
                reaper.ImGui_TableSetColumnIndex(ctx, numCols)
                if reaper.ImGui_Button(ctx, "Stop All", 60, 25) then
                     local stopTime = atNextStopGrid(SCENE_STOP_DELAY_BARS)
                     for i=1,COLS_MAX*numRows do
                        if slotItem[i] and #slotItem[i] > 0 then
                            cellStopPending[i] = stopTime
                            cellFlashTime[i] = reaper.time_precise()
                        end
                     end
                     for r=1,numRows do scenePlaying[r] = false end
                end
            end
            
            reaper.ImGui_EndTable(ctx)
        end
        
        reaper.ImGui_Separator(ctx)
        
        -- Function Buttons Row
        if reaper.ImGui_BeginTable(ctx, 'Functions', 8) then
            for i = 1, 8 do
                reaper.ImGui_TableSetupColumn(ctx, "F"..i)
            end
            reaper.ImGui_TableNextRow(ctx)
            
            -- F1: Add Item
            reaper.ImGui_TableSetColumnIndex(ctx, 0)
            if reaper.ImGui_Button(ctx, "F1: Add Item", -1, 30) or (reaper.ImGui_IsWindowFocused(ctx) and reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_F1())) then 
                F1_AddLastTouchedItem() 
            end
            if reaper.ImGui_IsItemHovered(ctx) then reaper.ImGui_SetTooltip(ctx, "Assign selected arrange item to selected cell") end

            -- F2: Clear
            reaper.ImGui_TableSetColumnIndex(ctx, 1)
            if reaper.ImGui_Button(ctx, "F2: Clear", -1, 30) or (reaper.ImGui_IsWindowFocused(ctx) and reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_F2())) then 
                F2_ClearCell() 
            end
            if reaper.ImGui_IsItemHovered(ctx) then reaper.ImGui_SetTooltip(ctx, "Clear selected cell") end

            -- F3: Rename
            reaper.ImGui_TableSetColumnIndex(ctx, 2)
            if reaper.ImGui_Button(ctx, "F3: Rename", -1, 30) or (reaper.ImGui_IsWindowFocused(ctx) and reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_F3())) then 
                F3_RenameCell() 
            end
            if reaper.ImGui_IsItemHovered(ctx) then reaper.ImGui_SetTooltip(ctx, "Rename selected cell") end

            -- F4: Duplicate
            reaper.ImGui_TableSetColumnIndex(ctx, 3)
            if reaper.ImGui_Button(ctx, "F4: Duplicate", -1, 30) or (reaper.ImGui_IsWindowFocused(ctx) and reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_F4())) then 
                F4_DuplicateCell() 
            end
            if reaper.ImGui_IsItemHovered(ctx) then reaper.ImGui_SetTooltip(ctx, "Duplicate selected cell to the slot below") end

            -- F5: Color
            reaper.ImGui_TableSetColumnIndex(ctx, 4)
            if reaper.ImGui_Button(ctx, "F5: Color", -1, 30) or (reaper.ImGui_IsWindowFocused(ctx) and reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_F5())) then 
                F5_ColorCell() 
            end
            if reaper.ImGui_IsItemHovered(ctx) then reaper.ImGui_SetTooltip(ctx, "Set custom color for selected cell") end

            -- F6: FX Chain
            reaper.ImGui_TableSetColumnIndex(ctx, 5)
            if reaper.ImGui_Button(ctx, "F6: FX Chain", -1, 30) or (reaper.ImGui_IsWindowFocused(ctx) and reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_F6())) then 
                F6_ShowFX() 
            end
            if reaper.ImGui_IsItemHovered(ctx) then reaper.ImGui_SetTooltip(ctx, "Open FX Chain for this track") end
            
            -- F7: Remove Item
            reaper.ImGui_TableSetColumnIndex(ctx, 6)
            if reaper.ImGui_Button(ctx, "F7: Remove", -1, 30) or (reaper.ImGui_IsWindowFocused(ctx) and reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_F7())) then 
                F7_StopCellFunc() 
            end
            if reaper.ImGui_IsItemHovered(ctx) then reaper.ImGui_SetTooltip(ctx, "Stop and remove item from timeline (keeps cell)") end

            -- F8: Settings
            reaper.ImGui_TableSetColumnIndex(ctx, 7)
            if reaper.ImGui_Button(ctx, "F8: Settings", -1, 30) or (reaper.ImGui_IsWindowFocused(ctx) and reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_F8())) then 
                F8_ShowSettings() 
            end
            
            reaper.ImGui_EndTable(ctx)
        end
        
        -- Color Picker Popup
        if show_color_picker then
            reaper.ImGui_OpenPopup(ctx, 'Color Picker')
            show_color_picker = false
        end
        
        if reaper.ImGui_BeginPopupModal(ctx, 'Color Picker', true, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
            if selectedCell ~= -1 then
                -- CELL MODE
                local current_col = cellMemory[selectedCell].color or 0xAAAAAAFF
                local input_col = reaper.ImGui_ColorConvertNative(current_col)
                
                local retval, new_col = reaper.ImGui_ColorPicker4(ctx, "##cp", input_col, reaper.ImGui_ColorEditFlags_NoAlpha() | reaper.ImGui_ColorEditFlags_PickerHueBar())
                
                if retval then
                     cellMemory[selectedCell].color = reaper.ImGui_ColorConvertNative(new_col)
                end
                
                if reaper.ImGui_Button(ctx, "Reset Color") then
                    cellMemory[selectedCell].color = nil
                end
                reaper.ImGui_SameLine(ctx)
                if reaper.ImGui_Button(ctx, "Close") then
                    reaper.ImGui_CloseCurrentPopup(ctx)
                end
            else
                reaper.ImGui_Text(ctx, "No selection.")
                if reaper.ImGui_Button(ctx, "Close") then reaper.ImGui_CloseCurrentPopup(ctx) end
            end
            reaper.ImGui_EndPopup(ctx)
        end

        -- Settings Window
        if show_settings_window then
            local s_visible, s_open = reaper.ImGui_Begin(ctx, 'Settings', true, reaper.ImGui_WindowFlags_AlwaysAutoResize())
            if s_visible then
                reaper.ImGui_Text(ctx, "Recording Settings")
                if reaper.ImGui_RadioButton(ctx, "Follow Quantize", rec_length_mode == 0) then rec_length_mode = 0 end
                reaper.ImGui_SameLine(ctx)
                reaper.ImGui_TextDisabled(ctx, "(Record length matches Quantize)")
                
                if reaper.ImGui_RadioButton(ctx, "Fixed 1 Bar", rec_length_mode == 1) then rec_length_mode = 1 end
                reaper.ImGui_SameLine(ctx)
                reaper.ImGui_TextDisabled(ctx, "(Always 1 Bar)")
                
                reaper.ImGui_Separator(ctx)
                reaper.ImGui_Text(ctx, "Default Startup")
                -- Add more settings here later

                reaper.ImGui_Separator(ctx)
                reaper.ImGui_Text(ctx, "Visuals")
                local rv, new_val = reaper.ImGui_Checkbox(ctx, "Show Waveforms (Experimental)", show_waveforms)
                if rv then
                    show_waveforms = new_val
                    if show_waveforms then
                        -- Generate for all existing cells
                        for i = 1, numRows * COLS_MAX do
                            if slotPath[i] then generateWaveform(i) end
                        end
                    else
                        -- Clear cache to free memory? Optional.
                        cellWaveforms = {}
                    end
                end
                
                reaper.ImGui_End(ctx)
            end
            
            if not s_open then
                 show_settings_window = false
            end
        end
        
        reaper.ImGui_Separator(ctx)
        if reaper.ImGui_Button(ctx, "+ Add Track") then
            numCols = numCols + 1
            syncTCP()
        end
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, "- Remove Track") then
            if numCols > 1 then
                numCols = numCols - 1
                syncTCP()
            end
        end
        
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_SameLine(ctx)
        
        if reaper.ImGui_Button(ctx, "+ Add Scene") then
            resizeScenes(numRows + 1)
        end
        if reaper.ImGui_IsItemHovered(ctx) then reaper.ImGui_SetTooltip(ctx, "Add a new Scene row") end
        
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, "- Remove Scene") then
            if numRows > 1 then
                resizeScenes(numRows - 1)
            end
        end
        if reaper.ImGui_IsItemHovered(ctx) then reaper.ImGui_SetTooltip(ctx, "Remove the last Scene row") end

        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_Separator(ctx)
        
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, "Mixer") then
            local base = reaper.GetResourcePath() .. "/Scripts/Hosi/"
            local scriptName = "Hosi Mini Track Mixer - ReaImGui.lua"
            local fullPath = base .. scriptName
            
            -- Check existence, fallback to Dev
            if not reaper.file_exists(fullPath) then
                scriptName = "Hosi Mini Track Mixer - ReaImGui - Dev.lua"
                fullPath = base .. scriptName
            end
            
            if reaper.file_exists(fullPath) then
                 local cmdId = reaper.AddRemoveReaScript(true, 0, fullPath, true)
                 if cmdId ~= 0 then
                     reaper.Main_OnCommand(cmdId, 0)
                 else
                     reaper.MB("Failed to register Mixer script.", "Error", 0)
                 end
            else
                 reaper.MB("Could not find 'Hosi Mini Track Mixer - ReaImGui.lua' in Scripts/Hosi folder.", "Script Not Found", 0)
            end
        end
        
        reaper.ImGui_End(ctx)
    end
    
    reaper.ImGui_PopStyleVar(ctx, 4)
    reaper.ImGui_PopStyleColor(ctx, 9) -- Pop 9 global colors

    if open then
        reaper.defer(function()
            updatePlayback()
            gui()
        end)
    end
end

-- Main Entry

loadState()
findOrCreateParent()
syncTCP()
updatePlayback()
gui()