-- @description Auto Loop Detector
-- @author Hosi
-- @version 1.0
-- @about
--   GUI tool to scan media items for loop points based on RMS energy.
--   Features: High Precision (5ms), Transient Protection, Grid Snap, and Presets.
--   
--   Requires: ReaImGui API
-- @provides [main] .
-- @changelog
--   + Initial release

local ctx = reaper.ImGui_CreateContext('Hosi_Auto_Loop_Detector')
local font_size = 14
local window_open = true

-- CONFIG VARIABLES
local cfg_threshold_db = -30.0
local cfg_min_silence = 2.0
local cfg_min_loop_len = 4.0
local cfg_color_mode = 2 -- 0=None, 1=Random, 2=Track Color, 3=Item Color
local cfg_snap_grid = false
local cfg_trim_item = false 
local cfg_split_items = false 
local cfg_auto_fades = false 
local cfg_strip_silence = false -- New option
local cfg_render_bounds = 3 -- 3 = Project Regions (Default), 2 = Time Selection
local cfg_naming_scheme = 2 -- 1=Simple, 2=Track Name, 3=Item Name
local cfg_detection_mode = 1 -- 1=RMS (Default), 2=Transient (Peak)
local cfg_append_bpm = false -- New option
local cfg_append_key = false -- New option
local cfg_user_key_root = 0 -- 0=C, 1=C#, etc.
local cfg_user_key_minor = false -- New option for Minor key (m)
local KEY_NAMES = {"C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"}

-- PRESETS DEFINITION
local PRESETS = {
    { name = "General (Default)",     thresh = -30.0, sil = 2.0, len = 4.0 },
    { name = "Drums / Loud Synth",    thresh = -20.0, sil = 1.0, len = 2.0 },
    { name = "Percussion (High Dyn)", thresh = -15.0, sil = 0.5, len = 1.0 },
    { name = "Bass / Low End",        thresh = -25.0, sil = 1.5, len = 2.0 },
    { name = "Vocals / Soft Gtr",     thresh = -45.0, sil = 2.5, len = 3.0 },
    { name = "Staccato / Plucks",     thresh = -28.0, sil = 0.3, len = 0.5 },
    { name = "Long Texture/Pad",      thresh = -35.0, sil = 4.0, len = 8.0 },
    { name = "Ambient / Drone",       thresh = -40.0, sil = 5.0, len = 10.0 },
    { name = "Field Rec / Atmos",     thresh = -50.0, sil = 3.0, len = 5.0 },
    { name = "Aggressive Chop",       thresh = -12.0, sil = 0.2, len = 1.0 }
}
local current_preset_idx = 0 -- 0-indexed for ImGui

local scan_result_msg = ""
local scan_msg_color = 0xFFFFFFFF

--------------------------------------------------------------------------------
-- UI DESIGN SYSTEM (JJazzLab Style)
--------------------------------------------------------------------------------
local UI = {
    WindowBg      = 0x1E1E24FF, -- Very Dark Blue-Grey
    ChildBg       = 0x25252DFF,
    PopupBg       = 0x25252DFF,
    Text          = 0xE0E0E0FF,
    TextDisabled  = 0x808080FF,
    Border        = 0x44444CFF,
    FrameBg       = 0x363640FF,
    FrameBgHover  = 0x4A4A55FF,
    FrameBgActive = 0x5A5A65FF,
    TitleBg       = 0x15151AFF,
    Button        = 0x5C6BC0AA, -- Indigo 400
    ButtonHover   = 0x5C6BC0FF,
    ButtonActive  = 0x3F51B5FF,
    Header        = 0x363640FF,
    HeaderHover   = 0x4A4A55FF,
    HeaderActive  = 0x5A5A65FF,
    ResizeGrip    = 0x5C6BC044,
    CheckMark     = 0x8C9EFFFF,
    Separator     = 0x44444CFF,
    Success       = 0x66BB6AFF, 
    Error         = 0xEF5350FF, 
    Warning       = 0xFFA726FF, 
    Info          = 0x29B6F6FF  
}

local STYLE = {
    WindowRounding    = 10.0, -- Increased for smoother look
    FrameRounding     = 5.0,
    GrabRounding      = 5.0,
    PopupRounding     = 5.0,
    ScrollbarRounding = 12.0,
    TabRounding       = 6.0,
    
    ItemSpacingX      = 4.0, -- Ultra compact
    ItemSpacingY      = 3.0,
    FramePaddingX     = 4.0, 
    FramePaddingY     = 2.0,
    WindowPaddingX    = 6.0, 
    WindowPaddingY    = 6.0 
}

function PushTheme(ctx)
    local count_c = 0
    local count_v = 0
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(),       UI.WindowBg); count_c = count_c + 1
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ChildBg(),        UI.ChildBg); count_c = count_c + 1
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_PopupBg(),        UI.PopupBg); count_c = count_c + 1
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(),           UI.Text); count_c = count_c + 1
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TextDisabled(),   UI.TextDisabled); count_c = count_c + 1
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(),         UI.Border); count_c = count_c + 1
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBg(),        UI.FrameBg); count_c = count_c + 1
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgHovered(), UI.FrameBgHover); count_c = count_c + 1
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgActive(),  UI.FrameBgActive); count_c = count_c + 1
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBg(),        UI.TitleBg); count_c = count_c + 1
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),         UI.Button); count_c = count_c + 1
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(),  UI.ButtonHover); count_c = count_c + 1
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),   UI.ButtonActive); count_c = count_c + 1
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(),         UI.Header); count_c = count_c + 1
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderHovered(),  UI.HeaderHover); count_c = count_c + 1
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderActive(),   UI.HeaderActive); count_c = count_c + 1
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Separator(),      UI.Separator); count_c = count_c + 1
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ResizeGrip(),     UI.ResizeGrip); count_c = count_c + 1
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_CheckMark(),      UI.CheckMark); count_c = count_c + 1

    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(),    STYLE.WindowRounding); count_v = count_v + 1
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(),     STYLE.FrameRounding); count_v = count_v + 1
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_PopupRounding(),     STYLE.PopupRounding); count_v = count_v + 1
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_GrabRounding(),      STYLE.GrabRounding); count_v = count_v + 1
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_TabRounding(),       STYLE.TabRounding); count_v = count_v + 1
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(),       STYLE.ItemSpacingX, STYLE.ItemSpacingY); count_v = count_v + 1
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(),      STYLE.FramePaddingX, STYLE.FramePaddingY); count_v = count_v + 1
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(),     STYLE.WindowPaddingX, STYLE.WindowPaddingY); count_v = count_v + 1
    
    return count_c, count_v
end

--------------------------------------------------------------------------------
-- CORE LOGIC
--------------------------------------------------------------------------------
local function DB2Val(db) return 10 ^ (db / 20) end

function GetItemSpectralData(item, threshold_db, min_silence_sec, min_loop_len)
    local take = reaper.GetActiveTake(item)
    if not take or reaper.TakeIsMIDI(take) then return nil end

    local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local source = reaper.GetMediaItemTake_Source(take)
    local samplerate = reaper.GetMediaSourceSampleRate(source)
    local num_channels = reaper.GetMediaSourceNumChannels(source)
    
    local accessor = reaper.CreateTakeAudioAccessor(take)
    local window_size = 0.005 -- 5ms PRECISION
    local samples_per_window = math.floor(samplerate * window_size)
    local buffer = reaper.new_array(samples_per_window * num_channels)
    
    local threshold_val = DB2Val(threshold_db)
    
    local is_in_loop = false
    local silence_duration = 0
    local loop_start_time = 0
    local detected_loops = {}

    local pos = 0
    while pos < item_len do
        local retval = reaper.GetAudioAccessorSamples(accessor, samplerate, num_channels, pos, samples_per_window, buffer)
        if retval <= 0 then break end
        
        local sum_sq = 0
        local sample_count = 0
        local tbl = buffer.table()
        
        for i = 1, #tbl do
            sum_sq = sum_sq + (tbl[i] * tbl[i])
            sample_count = sample_count + 1
        end
        
        local rms = (sample_count > 0) and math.sqrt(sum_sq / sample_count) or 0

        if rms > threshold_val then
            silence_duration = 0
            if not is_in_loop then
                is_in_loop = true
                -- TRANSIENT PROTECTION: Backtrack 10ms
                loop_start_time = math.max(0, pos - 0.010) 
            end
        else
            silence_duration = silence_duration + window_size
            if is_in_loop and silence_duration >= min_silence_sec then
                local loop_end_time = pos - silence_duration
                local loop_duration = loop_end_time - loop_start_time
                if loop_duration >= min_loop_len then
                     table.insert(detected_loops, {start = item_start + loop_start_time, ending = item_start + loop_end_time})
                end
                is_in_loop = false
            end
        end
        pos = pos + window_size
    end
    
    if is_in_loop then
         table.insert(detected_loops, {start = item_start + loop_start_time, ending = item_start + item_len})
    end

    reaper.DestroyAudioAccessor(accessor)
    return detected_loops
end

function GetItemPeakData(item, threshold_db, min_silence_sec, min_loop_len)
    local take = reaper.GetActiveTake(item)
    if not take or reaper.TakeIsMIDI(take) then return nil end

    local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local source = reaper.GetMediaItemTake_Source(take)
    local samplerate = reaper.GetMediaSourceSampleRate(source)
    local num_channels = reaper.GetMediaSourceNumChannels(source)
    
    local accessor = reaper.CreateTakeAudioAccessor(take)
    local window_size = 0.002 -- 2ms PRECISION (Tighter for transients)
    local samples_per_window = math.floor(samplerate * window_size)
    local buffer = reaper.new_array(samples_per_window * num_channels)
    
    local threshold_val = DB2Val(threshold_db)
    
    local is_in_loop = false
    local silence_duration = 0
    local loop_start_time = 0
    local detected_loops = {}

    local pos = 0
    while pos < item_len do
        local retval = reaper.GetAudioAccessorSamples(accessor, samplerate, num_channels, pos, samples_per_window, buffer)
        if retval <= 0 then break end
        
        local max_peak = 0
        local tbl = buffer.table()
        
        for i = 1, #tbl do
            local abs_val = math.abs(tbl[i])
            if abs_val > max_peak then max_peak = abs_val end
        end

        if max_peak > threshold_val then
            silence_duration = 0
            if not is_in_loop then
                is_in_loop = true
                -- TRANSIENT PROTECTION: Backtrack 10ms to catch attack
                loop_start_time = math.max(0, pos - 0.010) 
            end
        else
            silence_duration = silence_duration + window_size
            if is_in_loop and silence_duration >= min_silence_sec then
                local loop_end_time = pos - silence_duration
                local loop_duration = loop_end_time - loop_start_time
                if loop_duration >= min_loop_len then
                     table.insert(detected_loops, {start = item_start + loop_start_time, ending = item_start + loop_end_time})
                end
                is_in_loop = false
            end
        end
        pos = pos + window_size
    end
    
    if is_in_loop then
         table.insert(detected_loops, {start = item_start + loop_start_time, ending = item_start + item_len})
    end

    reaper.DestroyAudioAccessor(accessor)
    return detected_loops
end

function GetMidiData(item, min_silence_sec, min_loop_len)
    local take = reaper.GetActiveTake(item)
    if not take or not reaper.TakeIsMIDI(take) then return nil end

    local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    
    -- 1. Collect all notes
    local notes = {}
    local retval, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(take)
    for i = 0, notecnt - 1 do
        local _, selected, muted, startppq, endppq, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
        local start_sec = reaper.MIDI_GetProjTimeFromPPQPos(take, startppq) - item_start
        local end_sec = reaper.MIDI_GetProjTimeFromPPQPos(take, endppq) - item_start
        if not muted then
            table.insert(notes, {s = start_sec, e = end_sec})
        end
    end
    
    if #notes == 0 then return {} end

    -- 2. Sort by start time
    table.sort(notes, function(a, b) return a.s < b.s end)

    -- 3. Merge overlapping/adjacent notes into "Sound Blocks"
    local blocks = {}
    if #notes > 0 then
        local current_block = {s = notes[1].s, e = notes[1].e}
        for i = 2, #notes do
            local note = notes[i]
            -- If note starts before (or barely after) current block ends, merge it
            -- We add a tiny tolerance (0.01s) for "tight" playing
            if note.s <= (current_block.e + 0.01) then
                current_block.e = math.max(current_block.e, note.e)
            else
                -- Gap found! Push current block and start new one
                table.insert(blocks, current_block)
                current_block = {s = note.s, e = note.e}
            end
        end
        table.insert(blocks, current_block)
    end

    -- 4. Calculate Loops based on Silence Gaps between Blocks
    local detected_loops = {}
    -- If only one big block, check if it fits criteria
    if #blocks == 1 then
        if (blocks[1].e - blocks[1].s) >= min_loop_len then
             table.insert(detected_loops, {start = item_start + blocks[1].s, ending = item_start + blocks[1].e})
        end
        return detected_loops
    end

    local current_loop_start = blocks[1].s
    local current_loop_end = blocks[1].e

    for i = 2, #blocks do
        local gap = blocks[i].s - current_loop_end
        
        if gap >= min_silence_sec then
            -- Gap is big enough -> End of current loop
            local duration = current_loop_end - current_loop_start
            if duration >= min_loop_len then
                table.insert(detected_loops, {start = item_start + current_loop_start, ending = item_start + current_loop_end})
            end
            -- Start new loop
            current_loop_start = blocks[i].s
            current_loop_end = blocks[i].e
        else
            -- Gap too small -> Continue current loop
            current_loop_end = blocks[i].e
        end
    end
    
    -- Check buffer
    local duration = current_loop_end - current_loop_start
    if duration >= min_loop_len then
         table.insert(detected_loops, {start = item_start + current_loop_start, ending = item_start + current_loop_end})
    end

    return detected_loops
end

function ProcessSingleItem(item)
    local take = reaper.GetActiveTake(item)
    local loops = nil
    
    if take and reaper.TakeIsMIDI(take) then
        loops = GetMidiData(item, cfg_min_silence, cfg_min_loop_len)
    else
        if cfg_detection_mode == 2 then
             loops = GetItemPeakData(item, cfg_threshold_db, cfg_min_silence, cfg_min_loop_len)
        else
             loops = GetItemSpectralData(item, cfg_threshold_db, cfg_min_silence, cfg_min_loop_len)
        end
    end
    
    -- DETERMINE NAMING BASE
    local base_name_r = "Section"
    local base_name_m = "Loop"
    
    if cfg_naming_scheme == 2 then -- Track Name
        local track = reaper.GetMediaItem_Track(item)
        local _, name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
        if name ~= "" then 
            base_name_r = name
            base_name_m = name
        end
    elseif cfg_naming_scheme == 3 then -- Item Name
        local take = reaper.GetActiveTake(item)
        if take then
            local name = reaper.GetTakeName(take)
            if name ~= "" then
                base_name_r = name
                base_name_m = name
            end
        end
    end

    -- APPEND SMART INFO (BPM / KEY)
    local smart_suffix = ""
    if cfg_append_bpm then
        smart_suffix = smart_suffix .. "_" .. GetFormattedBPM() .. "bpm"
    end
    if cfg_append_key then
        smart_suffix = smart_suffix .. "_" .. GetProjectKeyString()
    end
    
    -- Update Base Name
    if smart_suffix ~= "" then
        base_name_r = base_name_r .. smart_suffix
        base_name_m = base_name_m .. smart_suffix
    end


    -- Helper to escape pattern
    local function escape_pattern(text)
        return text:gsub("([^%w])", "%%%1")
    end
    
    local pat_r = "^" .. escape_pattern(base_name_r) .. " %d+$"
    local pat_m = "^" .. escape_pattern(base_name_m) .. " %d+$"
    
    -- CLEAR EXISTING MARKERS/REGIONS IN RANGE
    local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local item_end = item_start + item_len
    
    local num_markers = reaper.CountProjectMarkers(0)
    for i = num_markers - 1, 0, -1 do
        local retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(i)
        if pos >= item_start and pos <= item_end then
            -- Delete if matches current scheme OR default scheme (cleanup old runs)
            if name:match(pat_r) or name:match(pat_m) or 
               name:match("^Section %d+$") or name:match("^Loop %d+$") then
                 reaper.DeleteProjectMarker(0, markrgnindexnumber, isrgn)
            end
        end
    end
    
    if loops and #loops > 0 then
        local min_start = math.huge
        local max_end = 0
        local count = 1

        for i, loop in ipairs(loops) do
             local start_pos = loop.start
             local end_pos = loop.ending
             
             if cfg_snap_grid then
                 start_pos = reaper.SnapToGrid(0, start_pos)
                 end_pos = reaper.SnapToGrid(0, end_pos)
             end

             -- Track bounds for trimming
             if start_pos < min_start then min_start = start_pos end
             if end_pos > max_end then max_end = end_pos end

             -- 1. Create Marker
             local m_name = base_name_m .. " " .. count
             local m_idx = reaper.AddProjectMarker(0, false, start_pos, 0, m_name, -1)
             -- 2. Create Region
             local r_name = base_name_r .. " " .. count
             local r_idx = reaper.AddProjectMarker(0, true, start_pos, end_pos, r_name, -1)
             
             local color = 0
             if cfg_color_mode == 1 then -- Random
                 color = reaper.ColorToNative(math.random(50,255), math.random(50,255), math.random(50,255))|0x1000000
             elseif cfg_color_mode == 2 then -- Track Color
                 local track = reaper.GetMediaItem_Track(item)
                 color = reaper.GetTrackColor(track)
             elseif cfg_color_mode == 3 then -- Item Color
                 color = reaper.GetMediaItemInfo_Value(item, "I_CUSTOMCOLOR")
                 if color == 0 then -- Fallback to track if item has no color
                     local track = reaper.GetMediaItem_Track(item)
                     color = reaper.GetTrackColor(track) 
                 end
             end
             
             if cfg_color_mode > 0 and color ~= 0 then
                 reaper.SetProjectMarker3(0, m_idx, false, start_pos, 0, m_name, color)
                 reaper.SetProjectMarker3(0, r_idx, true, start_pos, end_pos, r_name, color)
             end
             count = count + 1
        end

        -- TRIM ITEM LOGIC
        if cfg_trim_item and min_start < max_end then
            local take = reaper.GetActiveTake(item)
            if take then
                -- Calculate offset adjustment
                local current_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                local current_offs = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
                local playrate = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
                
                local diff = min_start - current_pos
                local new_offs = current_offs + (diff * playrate)
                
                reaper.SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", new_offs)
                reaper.SetMediaItemInfo_Value(item, "D_POSITION", min_start)
                reaper.SetMediaItemInfo_Value(item, "D_LENGTH", max_end - min_start)
            end
        end

        -- SPLIT ITEMS LOGIC
        if cfg_split_items then
            local split_points = {}
            for _, loop in ipairs(loops) do
                local s = loop.start
                local e = loop.ending
                if cfg_snap_grid then
                    s = reaper.SnapToGrid(0, s)
                    e = reaper.SnapToGrid(0, e)
                end
                table.insert(split_points, s)
                table.insert(split_points, e)
            end
            
            -- Sort descending to split from right to left
            table.sort(split_points, function(a,b) return a > b end)
            
            -- Remove duplicates and split
            local last_point = -1
            for _, point in ipairs(split_points) do
                if point ~= last_point then
                    local cur_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                    local cur_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
                    if point > cur_start and point < (cur_start + cur_len) then
                        reaper.SplitMediaItem(item, point)
                    end
                    last_point = point
                end
            end
            
            -- POST-SPLIT PROCESSING: FADES & STRIP SILENCE
            -- Check bounds again simply to be safe
            local track = reaper.GetMediaItem_Track(item)
            local item_count = reaper.CountTrackMediaItems(track)
            
            -- We loop backwards to safely delete items if needed
            for i = item_count - 1, 0, -1 do
                local it = reaper.GetTrackMediaItem(track, i)
                local pos = reaper.GetMediaItemInfo_Value(it, "D_POSITION")
                local len = reaper.GetMediaItemInfo_Value(it, "D_LENGTH")
                local end_p = pos + len
                local center = pos + (len / 2)
                
                -- SAFETY: Only process items within the original item's range
                if pos >= item_start - 0.001 and end_p <= item_end + 0.001 then
                
                    -- Check if this item is inside ANY detected loop
                    local is_loop_item = false
                    
                    for _, loop in ipairs(loops) do
                        -- Be generous with the check
                        if center >= loop.start and center <= loop.ending then
                            is_loop_item = true
                            break
                        end
                    end
                    
                    local deleted = false
                    if not is_loop_item and cfg_strip_silence then
                         reaper.DeleteTrackMediaItem(track, it)
                         deleted = true
                    end
                    
                    if not deleted then
                        if cfg_auto_fades then
                            reaper.SetMediaItemInfo_Value(it, "D_FADEINLEN", 0.010)
                            reaper.SetMediaItemInfo_Value(it, "D_FADEOUTLEN", 0.010)
                        else
                            -- Force remove default fades for ALL items (Loops & Silence)
                            reaper.SetMediaItemInfo_Value(it, "D_FADEINLEN", 0.0)
                            reaper.SetMediaItemInfo_Value(it, "D_FADEOUTLEN", 0.0)
                        end
                    end
                end 
            end
        end

        return #loops
    else
        return 0
    end
end

function PerformScan()
    local item_count = reaper.CountSelectedMediaItems(0)
    if item_count == 0 then
        scan_result_msg = "Please select audio/MIDI items first."
        scan_msg_color = UI.Error
        return
    end

    reaper.Undo_BeginBlock()
    
    local total_loops = 0
    for i = 0, item_count - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local loops_found = ProcessSingleItem(item)
        total_loops = total_loops + loops_found
    end

    reaper.UpdateArrange()
    
    if total_loops > 0 then
        scan_result_msg = "Found " .. total_loops .. " loops across " .. item_count .. " items!"
        scan_msg_color = UI.Success
    else
        scan_result_msg = "No loops found."
        scan_msg_color = UI.Warning
    end
    
    reaper.Undo_EndBlock("Auto Detect Loop Points (Batch)", -1)
end

--------------------------------------------------------------------------------
-- RENDER PRESETS LOGIC (Ported/Adapted from cfillion_Apply render preset.lua)
--------------------------------------------------------------------------------
local RENDER_PRESETS = {}
local RENDER_PRESET_NAMES = {"(Current Settings)"}
local cfg_render_preset_idx = 0 -- 0 = Current Settings

-- Helper: Base64 Decode
local function decodeBase64(data)
    if reaper.NF_Base64_Decode then
        return select(2, reaper.NF_Base64_Decode(data))
    end
    local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    data = data:gsub('[^'..b..'=]', '')
    return data:gsub('.', function(x)
        if x == '=' then return '' end
        local r, f = '', b:find(x) - 1
        for i = 6, 1, -1 do
            r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and '1' or '0')
        end
        return r
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if #x ~= 8 then return '' end
        local c = 0
        for i = 1, 8 do
            c = c + (x:sub(i, i) == '1' and 2 ^ (8 - i) or 0)
        end
        return string.char(c)
    end)
end

-- Helper: Tokenizer
local function tokenize(line)
    local pos, tokens = 1, {}
    while pos do
        local tail, eat = nil, 1
        local quote = line:sub(pos, pos)
        if quote == '"' or quote == "'" or quote == '`' then
            pos = pos + 1
            tail = line:find(quote .. '%s', pos)
            eat = 2
            if not tail then
                if line:sub(-1) == quote then tail = line:len() else tail = nil end -- permissive
            end
        else
            tail = line:find('%s', pos)
        end
        if pos <= line:len() then
            table.insert(tokens, line:sub(pos, tail and tail - 1))
        end
        pos = tail and tail + eat
    end
    return tokens
end

-- Helpers: Parser State
local function insertPreset(presets, name)
    local preset = presets[name]
    if not preset then preset = {}; presets[name] = preset end
    return preset
end

local function addPresetSettings(preset, mask, value)
    preset.RENDER_SETTINGS = (value & mask) | (preset.RENDER_SETTINGS or 0)
    preset._render_settings_mask = mask | (preset._render_settings_mask or 0)
end

local function propertyExtractor(preset, key)
    return function(file, line)
        preset[key] = (preset[key] or '') .. line
        return true
    end
end

local function parseNodeContents(extractor, defaultParser)
    local function parser(presets, file, line)
        line = line:match('^%s*(.*)$')
        if line:sub(1, 1) == '>' then return defaultParser end
        local ok = extractor(file, line)
        if ok then return parser end
        return nil -- error
    end
    return parser
end

-- Forward declaration
local parseDefault 

function parseFormatPreset(presets, file, tokens)
    if #tokens < 8 then return parseDefault end
    local preset = insertPreset(presets, tokens[2])
    preset.RENDER_SRATE           = tonumber(tokens[3])
    preset.RENDER_CHANNELS        = tonumber(tokens[4])
    preset.projrenderlimit        = tonumber(tokens[5])
    preset.projrenderrateinternal = tonumber(tokens[6])
    preset.projrenderrateinternal = tonumber(tokens[6])
    preset.projrenderresample     = tonumber(tokens[7])
    preset.RENDER_DITHER          = tonumber(tokens[8])
    preset.RENDER_FORMAT          = '' 
    if tokens[9] then
        addPresetSettings(preset, 0x6F14, tonumber(tokens[9]))
    end
    return parseNodeContents(propertyExtractor(preset, 'RENDER_FORMAT'), parseDefault)
end

function parseOutputPreset(presets, file, tokens)
    if #tokens < 9 then return parseDefault end
    local preset = insertPreset(presets, tokens[2])
    -- We skip BOUNDS and PATTERN intentionally if we want to override them, 
    -- BUT the user might want the preset's pattern. 
    -- For this integration, we will apply everything, then override Bounds/Pattern explicitly in ExportLoops.
    
    preset.RENDER_BOUNDSFLAG = tonumber(tokens[3])
    preset.RENDER_STARTPOS   = tonumber(tokens[4])
    preset.RENDER_ENDPOS     = tonumber(tokens[5])
    
    local settingsMask = 0x10EB | 0x6F14 -- Combined mask
    addPresetSettings(preset, settingsMask, tonumber(tokens[6]))
    
    preset.RENDER_PATTERN    = tostring(tokens[8])
    preset.RENDER_TAILFLAG   = tonumber(tokens[9]) == 0 and 0 or 0xFF
    -- Handle directory v6.43+
    if tokens[10] and tokens[10] ~= "" then preset.RENDER_FILE = tokens[10] end
    if tokens[11] then preset.RENDER_TAILMS = tonumber(tokens[11]) end
    return parseDefault
end

parseDefault = function(presets, file, line)
    local tokens = tokenize(line)
    if not tokens[1] then return parseDefault end
    
    if tokens[1] == '<RENDERPRESET' then return parseFormatPreset(presets, file, tokens)
    elseif tokens[1] == 'RENDERPRESET_OUTPUT' then return parseOutputPreset(presets, file, tokens)
    end
    return parseDefault
end

local function LoadRenderPresets()
    local filename = 'reaper-render.ini'
    local path = reaper.GetResourcePath() .. '/' .. filename
    if not reaper.file_exists(path) then return end
    
    local file = io.open(path, 'r')
    if not file then return end
    
    local parser = parseDefault
    for line in file:lines() do
        line = line:match('^(.-)\r*$')
        local next_parser = parser(RENDER_PRESETS, filename, line)
        if next_parser then parser = next_parser end
    end
    file:close()

    -- Populate Names List
    for name, _ in pairs(RENDER_PRESETS) do
        table.insert(RENDER_PRESET_NAMES, name)
    end
    table.sort(RENDER_PRESET_NAMES, function(a,b) 
        if a == "(Current Settings)" then return true end
        if b == "(Current Settings)" then return false end
        return a:lower() < b:lower() 
    end)
end

local function ApplyRenderPreset(preset_name)
    local preset = RENDER_PRESETS[preset_name]
    if not preset then return end
    
    local project = 0
    for key, value in pairs(preset) do
        if key == 'RENDER_FORMAT' then
             -- Handled specially at end
        elseif key:match('^_') then 
             -- internal
        elseif type(value) == 'string' then
            reaper.GetSetProjectInfo_String(project, key, value, true)
        elseif key:match('^[a-z]') then -- lowercase config vars
            reaper.SNM_SetIntConfigVar(key, value)
        else
            -- Apply with mask if exists
            local mask = preset[('_%s_mask'):format(key:lower())]
            if mask then
                local cur = reaper.GetSetProjectInfo(project, key, 0, false)
                value = (value & mask) | (cur & ~mask)
            end
            reaper.GetSetProjectInfo(project, key, value, true)
        end
    end
    
    if preset.RENDER_FORMAT then
        reaper.GetSetProjectInfo_String(project, 'RENDER_FORMAT', preset.RENDER_FORMAT, true)
    end
end

-- INIT PRESETS
LoadRenderPresets()

function ExportLoops()
    -- 1. Apply Preset if selected
    if cfg_render_preset_idx > 0 then
        local name = RENDER_PRESET_NAMES[cfg_render_preset_idx + 1]
        ApplyRenderPreset(name)
    end

    -- 2. Configure Render Settings for Region Export (Overrides Preset)
    -- RENDER_BOUNDSFLAG: 3 = Project Regions, 2 = Time Selection
    if cfg_render_bounds ~= -1 then
        reaper.GetSetProjectInfo(0, "RENDER_BOUNDSFLAG", cfg_render_bounds, true)
        
        -- Set Filename Pattern
        if cfg_render_bounds == 3 then
            -- Regions -> Use region name
            reaper.GetSetProjectInfo_String(0, "RENDER_PATTERN", "$region", true)
        else
            -- Time Selection -> Use project name
            reaper.GetSetProjectInfo_String(0, "RENDER_PATTERN", "$project", true)
        end
    end
    
    -- Open Render Dialog
    reaper.Main_OnCommand(40015, 0) -- File: Render project to disk...
end

--------------------------------------------------------------------------------
-- USER PRESETS PERSISTENCE (Existing)
--------------------------------------------------------------------------------
function UpdateExtState()
    local str = ""
    -- User presets start at index 11 (Lua 1-based, 10 factory presets)
    for i = 11, #PRESETS do
        local p = PRESETS[i]
        local entry = string.format("%s:%s:%s:%s", p.name, p.thresh, p.sil, p.len)
        if str == "" then str = entry else str = str .. "|" .. entry end
    end
    reaper.SetExtState("Hosi_LoopDetector", "UserPresets", str, true)
end

function LoadUserPresets()
    local saved = reaper.GetExtState("Hosi_LoopDetector", "UserPresets")
    if saved and saved ~= "" then
        for entry in saved:gmatch("([^|]+)") do
            -- Format: "Name:Thresh:Sil:Len"
            local name, thresh, sil, len = entry:match("^(.-):([%d.-]+):([%d.-]+):([%d.-]+)$")
            if name and thresh then
                table.insert(PRESETS, {
                    name = name,
                    thresh = tonumber(thresh),
                    sil = tonumber(sil),
                    len = tonumber(len)
                })
            end
        end
    end
end

function SaveUserPreset()
    local retval, name = reaper.GetUserInputs("Save Preset", 1, "Preset Name:", "My Preset")
    if retval and name ~= "" then
        -- Add to current table
        table.insert(PRESETS, {
             name = name,
             thresh = cfg_threshold_db,
             sil = cfg_min_silence,
             len = cfg_min_loop_len
        })
        
        UpdateExtState()
        
        -- Select the new preset
        current_preset_idx = #PRESETS - 1
    end
end

function RenameUserPreset()
    local idx = current_preset_idx + 1
    if idx <= 10 then return end -- Safety check
    
    local old_name = PRESETS[idx].name
    local retval, name = reaper.GetUserInputs("Rename Preset", 1, "New Name:", old_name)
    if retval and name ~= "" then
        PRESETS[idx].name = name
        UpdateExtState()
    end
end

function DeleteUserPreset()
    local idx = current_preset_idx + 1
    if idx <= 10 then return end -- Safety check
    
    table.remove(PRESETS, idx)
    UpdateExtState()
    
    -- Reset selection to Default
    current_preset_idx = 0
    -- Apply Default values
    cfg_threshold_db = PRESETS[1].thresh
    cfg_min_silence = PRESETS[1].sil
    cfg_min_loop_len = PRESETS[1].len
end

LoadUserPresets() -- Init load

--------------------------------------------------------------------------------
-- UTILITY FUNCTIONS
--------------------------------------------------------------------------------

function GetProjectKeyString()
    -- Use user selected key
    local key_str = KEY_NAMES[cfg_user_key_root + 1]
    if cfg_user_key_minor then
        key_str = key_str .. "m"
    end
    return key_str
end

function GetFormattedBPM()
    local bpm = reaper.Master_GetTempo()
    -- Format as integer for cleaner filename
    return string.format("%d", math.floor(bpm + 0.5))
end

function SetTrackSelected(track, selected)
    reaper.SetTrackSelected(track, selected)
end

function Transport_Stop()
    reaper.Main_OnCommand(1016, 0) -- Transport: Stop
end

function Transport_Pause()
    reaper.Main_OnCommand(1008, 0) -- Transport: Pause
end

function PreviewCurrentLoop()
    local cursor_pos = reaper.GetCursorPosition()
    
    -- 1. Get All Regions
    local regions = {}
    local i = 0
    repeat
        local retval, isrgn, pos, rgnend, name, idx = reaper.EnumProjectMarkers(i)
        if retval > 0 and isrgn then
            table.insert(regions, {pos=pos, rgnend=rgnend})
        end
        i = i + 1
    until retval == 0
    
    if #regions == 0 then
        reaper.ShowMessageBox("No Regions detected in project.", "Preview Loop", 0)
        return
    end

    -- 2. Sort Regions
    table.sort(regions, function(a,b) return a.pos < b.pos end)
    
    -- 3. Determine Target Region
    local target_r = nil
    
    -- Check if inside a region
    for _, r in ipairs(regions) do
        if cursor_pos >= r.pos and cursor_pos < r.rgnend then
            target_r = r
            break
        end
    end
    
    -- If not inside, find the next closest region
    if not target_r then
        for _, r in ipairs(regions) do
            if r.pos > cursor_pos then
                target_r = r
                break
            end
        end
    end
     
    -- If still not found (cursor after last region), wrap to first? or just take last?
    -- Let's take the first usage case: user likely wants to start from beginning if at end.
    if not target_r and #regions > 0 then
        target_r = regions[1]
    end
    
    -- 4. Execute Play
    if target_r then
        -- Always ensure loop points are set correctly for the target region
        reaper.GetSet_LoopTimeRange(true, true, target_r.pos, target_r.rgnend, false)
        reaper.GetSetRepeat(1) -- Enable Repeat
        
        -- Check Play State
        local play_state = reaper.GetPlayState()
        local is_paused = (play_state & 2 == 2)
        local cursor_inside = (cursor_pos >= target_r.pos and cursor_pos < target_r.rgnend)
        
        if is_paused and cursor_inside then
            -- If Paused and inside region, just Resume (don't move cursor)
            reaper.Main_OnCommand(1007, 0) -- Transport: Play
        else
            -- Otherwise (Stopped, Playing elsewhere, or Force Restart), Start from beginning
            reaper.SetEditCurPos(target_r.pos, true, false) -- Move cursor to start
            reaper.Main_OnCommand(1007, 0) -- Transport: Play
        end
    end
end

function Transport_Nav(dir)
    local cursor_pos = reaper.GetCursorPosition()
    local regions = {}
    local i = 0
    repeat
        local retval, isrgn, pos, rgnend, name, idx = reaper.EnumProjectMarkers(i)
        if retval > 0 and isrgn then
            table.insert(regions, {pos=pos, rgnend=rgnend})
        end
        i = i + 1
    until retval == 0
    
    if #regions == 0 then return end
    
    -- Sort regions by position to ensure logical navigation
    table.sort(regions, function(a,b) return a.pos < b.pos end)
    
    local target_idx = -1
    local cur_idx = -1
    
    -- Check if we are currently inside a region
    for k, r in ipairs(regions) do
        if cursor_pos >= r.pos and cursor_pos < r.rgnend then
            cur_idx = k
            break
        end
    end
    
    if cur_idx ~= -1 then
        -- We are in a region, go safely to prev/next
        target_idx = cur_idx + dir
    else
        -- Not in a region, find closest
        if dir > 0 then
             -- Find first region starting after cursor
             for k, r in ipairs(regions) do
                 if r.pos > cursor_pos then target_idx = k; break end
             end
             -- If none found (end of project), maybe wrap to 1? Or stop.
             if target_idx == -1 and #regions > 0 then target_idx = 1 end -- Wrap to start
        else
             -- Find first region ending before cursor (loop backwards)
             for k = #regions, 1, -1 do
                 local r = regions[k]
                 if r.rgnend <= cursor_pos then target_idx = k; break end
             end
             -- If none found (start of project), maybe wrap to last?
             if target_idx == -1 and #regions > 0 then target_idx = #regions end -- Wrap to end
        end
    end
    
    -- Bounds check
    if target_idx < 1 then target_idx = #regions end
    if target_idx > #regions then target_idx = 1 end
    
    -- Execute Jump
    local t = regions[target_idx]
    if t then
        reaper.SetEditCurPos(t.pos, true, false)
        PreviewCurrentLoop()
    end
end

--------------------------------------------------------------------------------
-- DRAW GUI
--------------------------------------------------------------------------------
function DrawGUI()
    local count_c, count_v = PushTheme(ctx)
    local flags = reaper.ImGui_WindowFlags_NoCollapse()
    reaper.ImGui_SetNextWindowSize(ctx, 320, 290, reaper.ImGui_Cond_FirstUseEver())
    
    local visible, open = reaper.ImGui_Begin(ctx, "Auto Loop Detector", true, flags)
    if visible then
        -- Title
        -- Title / Detection Mode Selector
        reaper.ImGui_SetNextItemWidth(ctx, 150)
        local mode_preview = (cfg_detection_mode == 1) and "RMS (Default)" or "Transient (Peak)"
        
        if reaper.ImGui_BeginCombo(ctx, "##detectmode", mode_preview) then
            if reaper.ImGui_Selectable(ctx, "RMS (Default)", cfg_detection_mode == 1) then cfg_detection_mode = 1 end
            if reaper.ImGui_Selectable(ctx, "Transient (Peak)", cfg_detection_mode == 2) then cfg_detection_mode = 2 end
            reaper.ImGui_EndCombo(ctx)
        end
        if reaper.ImGui_IsItemHovered(ctx) then
             reaper.ImGui_SetTooltip(ctx, "Detection Algorithm:\n- RMS: Average energy (Vocals, Pads)\n- Transient: Peak levels (Drums, Percussion)")
        end
        
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_TextDisabled(ctx, "(Mode)")
        
        -- Settings Button (Gear)
        reaper.ImGui_SameLine(ctx, reaper.ImGui_GetContentRegionAvail(ctx) - 26)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x00000000)
        reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 12) -- Rounded
        if reaper.ImGui_Button(ctx, "⚙") then 
             reaper.ImGui_OpenPopup(ctx, "SettingsMenu")
        end
        reaper.ImGui_PopStyleVar(ctx)
        reaper.ImGui_PopStyleColor(ctx)
        if reaper.ImGui_IsItemHovered(ctx) then reaper.ImGui_SetTooltip(ctx, "Settings (Naming, Coloring...)") end
        
        -- SETTINGS POPUP
        if reaper.ImGui_BeginPopup(ctx, "SettingsMenu") then
             reaper.ImGui_TextColored(ctx, UI.Info, "Configuration")
             reaper.ImGui_Separator(ctx)
             
             -- Naming Scheme
             reaper.ImGui_Text(ctx, "Name Mode")
             reaper.ImGui_SetNextItemWidth(ctx, 150)
             if reaper.ImGui_BeginCombo(ctx, "##naming_pop", cfg_naming_scheme == 1 and "Simple" or (cfg_naming_scheme == 2 and "Track Name" or "Item Name")) then
                if reaper.ImGui_Selectable(ctx, "Simple (Section X)", cfg_naming_scheme == 1) then cfg_naming_scheme = 1 end
                if reaper.ImGui_Selectable(ctx, "Track Name (Guitar 1, 2...)", cfg_naming_scheme == 2) then cfg_naming_scheme = 2 end
                if reaper.ImGui_Selectable(ctx, "Item Name (File 1, 2...)", cfg_naming_scheme == 3) then cfg_naming_scheme = 3 end
                reaper.ImGui_EndCombo(ctx)
             end
             
             -- Smart Naming Options
             reaper.ImGui_Dummy(ctx, 0, 2)
             local changed_bpm, new_bpm = reaper.ImGui_Checkbox(ctx, "Attach BPM (_120bpm)", cfg_append_bpm)
             if changed_bpm then cfg_append_bpm = new_bpm end
             
             local changed_key, new_key = reaper.ImGui_Checkbox(ctx, "Attach Key", cfg_append_key)
             if changed_key then cfg_append_key = new_key end
             
             if cfg_append_key then
                 reaper.ImGui_SameLine(ctx)
                 reaper.ImGui_SetNextItemWidth(ctx, 45)
                 if reaper.ImGui_BeginCombo(ctx, "##keyroot", KEY_NAMES[cfg_user_key_root + 1]) then
                     for i, k in ipairs(KEY_NAMES) do
                         local is_sel = (cfg_user_key_root == i - 1)
                         if reaper.ImGui_Selectable(ctx, k, is_sel) then
                             cfg_user_key_root = i - 1
                         end
                         if is_sel then reaper.ImGui_SetItemDefaultFocus(ctx) end
                     end
                     reaper.ImGui_EndCombo(ctx)
                 end
                 
                 reaper.ImGui_SameLine(ctx)
                 local changed_min, new_min = reaper.ImGui_Checkbox(ctx, "m", cfg_user_key_minor)
                 if changed_min then cfg_user_key_minor = new_min end
             end
             
             reaper.ImGui_Dummy(ctx, 0, 5)
             
             -- Color Mode
             reaper.ImGui_Text(ctx, "Color Mode")
             reaper.ImGui_SetNextItemWidth(ctx, 150)
             local c_preview = "Color"
            if cfg_color_mode == 1 then c_preview = "Random"
            elseif cfg_color_mode == 2 then c_preview = "Track Color"
            elseif cfg_color_mode == 3 then c_preview = "Item Color"
            elseif cfg_color_mode == 0 then c_preview = "No Color"
            end
            
            if reaper.ImGui_BeginCombo(ctx, "##coloring_pop", c_preview) then
                if reaper.ImGui_Selectable(ctx, "Track Color (Match Track)", cfg_color_mode == 2) then cfg_color_mode = 2 end
                if reaper.ImGui_Selectable(ctx, "Item Color (Match Clip)", cfg_color_mode == 3) then cfg_color_mode = 3 end
                if reaper.ImGui_Selectable(ctx, "Random Colors", cfg_color_mode == 1) then cfg_color_mode = 1 end
                if reaper.ImGui_Selectable(ctx, "No Color (Default)", cfg_color_mode == 0) then cfg_color_mode = 0 end
                reaper.ImGui_EndCombo(ctx)
            end
             
             reaper.ImGui_EndPopup(ctx)
        end
        
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_Dummy(ctx, 0, 5) 
         
        
        -- PARAMETERS PANEL
        if true then

            
            -- Detect Item Type for UI Feedback
            local is_midi_target = false
            local item = reaper.GetSelectedMediaItem(0, 0)
            if item then
                local take = reaper.GetActiveTake(item)
                if take and reaper.TakeIsMIDI(take) then
                    is_midi_target = true
                end
            end

            -- PRESETS COMBO
            local combo_w = 133
            if current_preset_idx >= 10 then combo_w = 85 end -- Shrink if showing extra buttons
            
            reaper.ImGui_PushItemWidth(ctx, combo_w)
            if reaper.ImGui_BeginCombo(ctx, "##presets", PRESETS[current_preset_idx + 1].name) then
                for i, p in ipairs(PRESETS) do
                    local is_selected = (current_preset_idx == i - 1)
                    if reaper.ImGui_Selectable(ctx, p.name, is_selected) then
                        current_preset_idx = i - 1
                        -- Apply Preset
                        cfg_threshold_db = p.thresh
                        cfg_min_silence = p.sil
                        cfg_min_loop_len = p.len
                    end
                    if is_selected then reaper.ImGui_SetItemDefaultFocus(ctx) end
                end
                reaper.ImGui_EndCombo(ctx)
            end
            reaper.ImGui_PopItemWidth(ctx)
            
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "+") then
                SaveUserPreset()
            end
            if reaper.ImGui_IsItemHovered(ctx) then
                reaper.ImGui_SetTooltip(ctx, "Save current settings as User Preset")
            end
            
            -- Rename / Delete buttons for User Presets (Index >= 10, i.e., 11th entry)
            if current_preset_idx >= 10 then
                reaper.ImGui_SameLine(ctx)
                if reaper.ImGui_Button(ctx, "R") then
                    RenameUserPreset()
                end
                if reaper.ImGui_IsItemHovered(ctx) then
                    reaper.ImGui_SetTooltip(ctx, "Rename Preset")
                end
                
                reaper.ImGui_SameLine(ctx)
                if reaper.ImGui_Button(ctx, "-") then
                    DeleteUserPreset()
                end
                if reaper.ImGui_IsItemHovered(ctx) then
                    reaper.ImGui_SetTooltip(ctx, "Delete Preset")
                end
            end

            -- TRANSPORT BAR (Play/Pause/Stop)
            reaper.ImGui_SameLine(ctx, 0, 15) -- Spacing
            
            -- Prev (Blue)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x1E90FFFF)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x00BFFFFF)
            if reaper.ImGui_Button(ctx, "⏮") then Transport_Nav(-1) end
            reaper.ImGui_PopStyleColor(ctx, 2)
            if reaper.ImGui_IsItemHovered(ctx) then reaper.ImGui_SetTooltip(ctx, "Previous Loop") end

            reaper.ImGui_SameLine(ctx)

            -- Play (Green)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x228B22FF)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x2E8B57FF)
            if reaper.ImGui_Button(ctx, "▶") then PreviewCurrentLoop() end
            reaper.ImGui_PopStyleColor(ctx, 2)
            if reaper.ImGui_IsItemHovered(ctx) then reaper.ImGui_SetTooltip(ctx, "Preview Loop (Play)") end
            
            reaper.ImGui_SameLine(ctx)
            
            -- Pause (Orange/Yellow)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0xDAA520FF)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0xFFD700FF)
            if reaper.ImGui_Button(ctx, "⏸") then Transport_Pause() end
            reaper.ImGui_PopStyleColor(ctx, 2)
            if reaper.ImGui_IsItemHovered(ctx) then reaper.ImGui_SetTooltip(ctx, "Pause") end
            
            reaper.ImGui_SameLine(ctx)
            
            -- Stop (Red)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0xB22222FF)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0xDC143CFF)
            if reaper.ImGui_Button(ctx, "■") then Transport_Stop() end
            reaper.ImGui_PopStyleColor(ctx, 2)
            if reaper.ImGui_IsItemHovered(ctx) then reaper.ImGui_SetTooltip(ctx, "Stop") end

            reaper.ImGui_SameLine(ctx)

            -- Next (Blue)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x1E90FFFF)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x00BFFFFF)
            if reaper.ImGui_Button(ctx, "⏭") then Transport_Nav(1) end
            reaper.ImGui_PopStyleColor(ctx, 2)
            if reaper.ImGui_IsItemHovered(ctx) then reaper.ImGui_SetTooltip(ctx, "Next Loop") end
            
            
            reaper.ImGui_Dummy(ctx, 0, 3)

            -- Threshold (Disabled for MIDI)
            reaper.ImGui_AlignTextToFramePadding(ctx)
            reaper.ImGui_Text(ctx, "Threshold")
            reaper.ImGui_SameLine(ctx, 80)
            reaper.ImGui_SetNextItemWidth(ctx, -1)
            
            if is_midi_target then
                reaper.ImGui_BeginDisabled(ctx)
            end
            local changed_t, new_t = reaper.ImGui_SliderDouble(ctx, "##threshold", cfg_threshold_db, -60.0, 0.0, "%.1f dB")
            if changed_t then cfg_threshold_db = new_t end
            if is_midi_target then
                reaper.ImGui_EndDisabled(ctx)
                -- Tooltip explanation
                if reaper.ImGui_IsItemHovered(ctx) then -- Tooltip on the disabled slider
                     reaper.ImGui_SetTooltip(ctx, "Not used for MIDI (Note-based detection)")
                end
            end
            
            -- Naming and Coloring moved to Settings Menu
             
            
            -- Min Silence
            reaper.ImGui_AlignTextToFramePadding(ctx)
            reaper.ImGui_Text(ctx, "Silence")
            reaper.ImGui_SameLine(ctx, 80)
            reaper.ImGui_SetNextItemWidth(ctx, -1)
            local changed_s, new_s = reaper.ImGui_SliderDouble(ctx, "##silence", cfg_min_silence, 0.1, 10.0, "%.1f s")
            if changed_s then cfg_min_silence = new_s end
            
            -- Min Loop Length
            reaper.ImGui_AlignTextToFramePadding(ctx)
            reaper.ImGui_Text(ctx, "Min Loop")
            reaper.ImGui_SameLine(ctx, 80)
            reaper.ImGui_SetNextItemWidth(ctx, -1)
            local changed_l, new_l = reaper.ImGui_SliderDouble(ctx, "##length", cfg_min_loop_len, 0.5, 20.0, "%.1f s")
            if changed_l then cfg_min_loop_len = new_l end
            
            reaper.ImGui_Dummy(ctx, 0, 2)
            
            -- OPTIONS
            -- Row 1
            local changed_tr, new_tr = reaper.ImGui_Checkbox(ctx, "Trim Excess", cfg_trim_item)
            if changed_tr then cfg_trim_item = new_tr end

            reaper.ImGui_SameLine(ctx, 160)
            local changed_g, new_g = reaper.ImGui_Checkbox(ctx, "Snap to Grid", cfg_snap_grid)
            if changed_g then cfg_snap_grid = new_g end

            -- Row 2
            local changed_af, new_af = reaper.ImGui_Checkbox(ctx, "Auto Fades", cfg_auto_fades)
            if changed_af then cfg_auto_fades = new_af end

            reaper.ImGui_SameLine(ctx, 160)
            local changed_sp, new_sp = reaper.ImGui_Checkbox(ctx, "Split Items", cfg_split_items)
            if changed_sp then cfg_split_items = new_sp end

            -- Row 3
            local changed_ss, new_ss = reaper.ImGui_Checkbox(ctx, "Strip Silence", cfg_strip_silence)
            if changed_ss then cfg_strip_silence = new_ss end

            -- reaper.ImGui_EndChild(ctx)

        end

        reaper.ImGui_Dummy(ctx, 0, 5)
        
        -- ACTION BUTTON
        local btn_w = reaper.ImGui_GetContentRegionAvail(ctx)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), UI.Button)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), UI.ButtonHover)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), UI.ButtonActive)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0xFFFFFFFF) 
        
        if reaper.ImGui_Button(ctx, "SCAN", btn_w, 28) then
            PerformScan()
        end
        
        reaper.ImGui_Dummy(ctx, 0, 2)
        
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), UI.FrameBg)
        -- Render Preset Selector
        reaper.ImGui_SetNextItemWidth(ctx, 110)
        local current_p_name = RENDER_PRESET_NAMES[cfg_render_preset_idx + 1] or ""
        if reaper.ImGui_BeginCombo(ctx, "##renderpreset", current_p_name) then
            for i, name in ipairs(RENDER_PRESET_NAMES) do
                local is_selected = (cfg_render_preset_idx == i - 1)
                if reaper.ImGui_Selectable(ctx, name, is_selected) then
                    cfg_render_preset_idx = i - 1
                end
                if is_selected then reaper.ImGui_SetItemDefaultFocus(ctx) end
            end
            reaper.ImGui_EndCombo(ctx)
        end
        if reaper.ImGui_IsItemHovered(ctx) then
             reaper.ImGui_SetTooltip(ctx, "Select Render Preset (Output Format, etc.)")
        end

        reaper.ImGui_SameLine(ctx)
        
        -- Render Bounds Selector
        reaper.ImGui_SetNextItemWidth(ctx, 110)
        local bound_preview = "Default"
        if cfg_render_bounds == 3 then bound_preview = "Regions"
        elseif cfg_render_bounds == 2 then bound_preview = "Time Sel"
        end
        
        if reaper.ImGui_BeginCombo(ctx, "##renderbound", bound_preview) then
            if reaper.ImGui_Selectable(ctx, "Default (Preset)", cfg_render_bounds == -1) then cfg_render_bounds = -1 end
            if reaper.ImGui_Selectable(ctx, "Project Regions", cfg_render_bounds == 3) then cfg_render_bounds = 3 end
            if reaper.ImGui_Selectable(ctx, "Time Selection", cfg_render_bounds == 2) then cfg_render_bounds = 2 end
            reaper.ImGui_EndCombo(ctx)
        end
        if reaper.ImGui_IsItemHovered(ctx) then
             reaper.ImGui_SetTooltip(ctx, "Select Render Bounds:\n- Default: Use bounds from the selected Preset\n- Regions: Force Project Regions\n- Time Sel: Force Time Selection")
        end
        
        reaper.ImGui_SameLine(ctx)
        
        if reaper.ImGui_Button(ctx, "Export...", -1, 24) then
            ExportLoops()
        end
        reaper.ImGui_PopStyleColor(ctx, 1)
        
        reaper.ImGui_PopStyleColor(ctx, 4)
        
        -- STATUS MESSAGE
        if scan_result_msg ~= "" then
            reaper.ImGui_Dummy(ctx, 0, 1)
            local win_w = reaper.ImGui_GetWindowWidth(ctx)
            local txt_w = reaper.ImGui_CalcTextSize(ctx, scan_result_msg)
            local pad_x = (win_w - txt_w) * 0.5
            if pad_x > 0 then reaper.ImGui_SetCursorPosX(ctx, pad_x) end
            reaper.ImGui_TextColored(ctx, scan_msg_color, scan_result_msg)
        end

        reaper.ImGui_End(ctx)
    end

    if count_c then reaper.ImGui_PopStyleColor(ctx, count_c) end
    if count_v then reaper.ImGui_PopStyleVar(ctx, count_v) end

    if not open then
        window_open = false
    end
end

function MainLoop()
    if window_open then
        DrawGUI()
        reaper.defer(MainLoop)
    end
end

MainLoop()
