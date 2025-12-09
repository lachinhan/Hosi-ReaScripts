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
local cfg_random_colors = true
local cfg_snap_grid = false
local cfg_trim_item = false -- New option
local cfg_split_items = false -- New option
local cfg_auto_fades = false -- New option
local cfg_strip_silence = false -- New option

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
        loops = GetItemSpectralData(item, cfg_threshold_db, cfg_min_silence, cfg_min_loop_len)
    end
    
    -- CLEAR EXISTING MARKERS/REGIONS IN RANGE
    local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local item_end = item_start + item_len
    
    local num_markers = reaper.CountProjectMarkers(0)
    for i = num_markers - 1, 0, -1 do
        local retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(i)
        if pos >= item_start and pos <= item_end then
            -- ONLY delete if it looks like an auto-generated loop/section
            -- Pattern: "Loop <number>" or "Section <number>"
            if name:match("^Loop %d+$") or name:match("^Section %d+$") then
                 reaper.DeleteProjectMarker(0, markrgnindexnumber, isrgn)
            end
        end
    end
    
    if loops and #loops > 0 then
        local min_start = math.huge
        local max_end = 0

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
             local m_idx = reaper.AddProjectMarker(0, false, start_pos, 0, "Loop " .. i, -1)
             -- 2. Create Region
             local r_idx = reaper.AddProjectMarker(0, true, start_pos, end_pos, "Section " .. i, -1)
             
             if cfg_random_colors then
                 local color = reaper.ColorToNative(math.random(50,255), math.random(50,255), math.random(50,255))|0x1000000
                 reaper.SetProjectMarker3(0, m_idx, false, start_pos, 0, "Loop " .. i, color)
                 reaper.SetProjectMarker3(0, r_idx, true, start_pos, end_pos, "Section " .. i, color)
             end
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

function ExportLoops()
    -- Configure Render Settings for Region Export
    -- RENDER_BOUNDSFLAG: 3 = Project Regions
    reaper.GetSetProjectInfo(0, "RENDER_BOUNDSFLAG", 3, true)
    
    -- Set Filename Pattern to "$region" (to use region names like "Section 1")
    reaper.GetSetProjectInfo_String(0, "RENDER_PATTERN", "$region", true)
    
    -- Open Render Dialog
    reaper.Main_OnCommand(40015, 0) -- File: Render project to disk...
end

--------------------------------------------------------------------------------
-- USER PRESETS PERSISTENCE
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
-- DRAW GUI
--------------------------------------------------------------------------------
function DrawGUI()
    local count_c, count_v = PushTheme(ctx)
    local flags = reaper.ImGui_WindowFlags_NoCollapse()
    reaper.ImGui_SetNextWindowSize(ctx, 320, 290, reaper.ImGui_Cond_FirstUseEver())
    
    local visible, open = reaper.ImGui_Begin(ctx, "Auto Loop Detector", true, flags)
    if visible then
        -- Title
        reaper.ImGui_TextColored(ctx, UI.Info, "RMS DETECTION")
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_TextDisabled(ctx, "(Mini)")
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_Dummy(ctx, 0, 5) 
        
        -- PARAMETERS PANEL
        if reaper.ImGui_BeginChild(ctx, "ConfigPanel", 0, 195, 1) then
            
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
            local changed_c, new_c = reaper.ImGui_Checkbox(ctx, "Random Colors", cfg_random_colors)
            if changed_c then cfg_random_colors = new_c end
            
            reaper.ImGui_SameLine(ctx, 160)
            local changed_g, new_g = reaper.ImGui_Checkbox(ctx, "Snap to Grid", cfg_snap_grid)
            if changed_g then cfg_snap_grid = new_g end

            -- Trim Option
            local changed_tr, new_tr = reaper.ImGui_Checkbox(ctx, "Trim Excess", cfg_trim_item)
            if changed_tr then cfg_trim_item = new_tr end

            reaper.ImGui_SameLine(ctx, 160)
            local changed_sp, new_sp = reaper.ImGui_Checkbox(ctx, "Split Items", cfg_split_items)
            if changed_sp then cfg_split_items = new_sp end

            -- Advanced Row
            local changed_af, new_af = reaper.ImGui_Checkbox(ctx, "Auto Fades", cfg_auto_fades)
            if changed_af then cfg_auto_fades = new_af end

            reaper.ImGui_SameLine(ctx, 160)
            local changed_ss, new_ss = reaper.ImGui_Checkbox(ctx, "Strip Silence", cfg_strip_silence)
            if changed_ss then cfg_strip_silence = new_ss end

            reaper.ImGui_EndChild(ctx)
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
        if reaper.ImGui_Button(ctx, "Export (Render)...", btn_w, 24) then
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
