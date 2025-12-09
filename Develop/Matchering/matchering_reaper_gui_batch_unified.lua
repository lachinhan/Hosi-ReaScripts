--[[
@description    Matchering 2.0 GUI (Unified Batch Processor)
@author         Hosi
@version        1.1
@reaper_version 6.0+
@extensions     ReaImGui, SWS/ReaPack (for Python worker)
@provides
  [main] . > Hosi_Matchering 2.0 GUI (Unified Batch).lua

@about
  # Matchering 2.0 Unified Batch Processor

  A comprehensive graphical user interface (GUI) to manage and run Matchering 2.0
  in two distinct batch modes (Multi-Target or Multi-Reference).

  ## Modes:
  1. **Multi-Target (N:1):** Apply one single Reference file to multiple Target files.
  2. **Multi-Reference (1:N):** Apply multiple Reference files to one single Target file.

  ## Requirements:
  - ReaImGui (v0.10+) installed via ReaPack.
  - The Python worker script (`matchering_worker.py`) must be saved in the same directory.
  - Python environment setup for Matchering 2.0 CLI.
  
  ## Instructions:
  1. Select the desired batch mode.
  2. Load your Target(s) and Reference(s) from selected Media Items.
  3. Click 'Run Batch'.

@changelog
  + v1.0 (2025-Nov-12) - Initial Unified Batch release with Multi-Target and Multi-Reference modes.
  + v1.1 (2025-Dec-09) - Modern GUI 
--]]

-- REAPER SCRIPT: Matchering 2.0 GUI (Unified Batch)
-- DESCRIPTION: Lua GUI (using ReaImGui) to run Matchering 2.0
-- Handles both Multi-Target and Multi-Reference batch modes.
-- INSTRUCTIONS:
-- 1. Ensure you have 'ReaImGui' installed via ReaPack.
-- 2. Save this file and 'matchering_worker.py' in the same Scripts folder.
-- 3. Run this .lua file from the Action List.

-- --- REAIMGUI INITIALIZATION ---
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local imgui = require('imgui')('0.10')

if not imgui or type(imgui) ~= "table" then
  reaper.ShowMessageBox("Could not initialize ReaImGui library.\nPlease install 'ReaImGui' (v0.10+) via ReaPack.", "ReaImGui Error", 0)
  return
end
-- ---------------------------------------------------

-- --- Variable Declarations ---
local script_title = "Matchering 2.0 GUI (Unified Batch)"

-- *** NEW: Unified Batch Logic ***
local batch_mode = 1 -- 1 = Multi-Target, 2 = Multi-Reference

-- Data for Mode 1 (N-Targets -> 1-Ref)
local multi_target_queue = {} -- Stores tables: {item, path, name}
local single_ref_item, single_ref_path, single_ref_name = nil, nil, "None"

-- Data for Mode 2 (1-Target -> N-Refs)
local multi_ref_queue = {} -- Stores tables: {item, path, name}
local single_target_item, single_target_path, single_target_name = nil, nil, "None"

-- Universal Job Queue (built at runtime)
local job_queue = {} -- Stores final pairs: {target = {item, path, name}, ref = {item, path, name}}
local total_jobs = 0
local current_job_target_item = nil -- Item being processed (for muting)
local current_job_ref_item = nil -- Item being processed (for muting)

local status_text = "Idle. Select a mode and add items."
local last_error = ""
local is_running = false
local run_start_time = 0 

local ctx = imgui.CreateContext(script_title)
local is_open = true 

-- --- Settings (Load and Save) ---
local settings = {
    cmd_id = reaper.GetExtState("MatcheringGUI", "CommandID", "_RSda7da6ca31d1042f5346f01affaf25c592d81dc1"),
    bit_depth_options = {"-b16", "-b24", "-b32"},
    bit_depth_index = 2,
    -- *** NEW: Idea 2 (Continue on Error) ***
    continue_on_error = reaper.GetExtState("MatcheringGUI", "ContinueOnError", "false") == "true"
}
local saved_bit_depth = reaper.GetExtState("MatcheringGUI", "BitDepth", "-b24")
for i, v in ipairs(settings.bit_depth_options) do
    if v == saved_bit_depth then
        settings.bit_depth_index = i
        break
    end
end
function SaveSettings()
    reaper.SetExtState("MatcheringGUI", "CommandID", settings.cmd_id, true)
    reaper.SetExtState("MatcheringGUI", "BitDepth", settings.bit_depth_options[settings.bit_depth_index], true)
    -- *** NEW: Idea 2 (Continue on Error) ***
    reaper.SetExtState("MatcheringGUI", "ContinueOnError", settings.continue_on_error and "true" or "false", true)
end
-- --- End Settings ---


-- --- Helper Functions ---
function GetItemPath(item)
    if not item then return nil end
    local take = reaper.GetActiveTake(item)
    if not take then return nil end
    local source = reaper.GetMediaItemTake_Source(take)
    if not source then return nil end
    local path = reaper.GetMediaSourceFileName(source, "", 4096)
    if path and type(path) == "string" and #path > 0 and path:match("[/\\]") then 
        return path
    end
    return nil
end

function GetBasename(path)
    if not path or #path == 0 then return "None" end
    local basename = path:match("([^/\\]+)$")
    if not basename then return "None" end
    return basename
end


-- --- THEME & STYLES (JJazzLab Style) ---
local UI = {
    WindowBg      = 0x1E1E24FF,
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
    WindowRounding    = 10.0,
    FrameRounding     = 5.0,
    GrabRounding      = 5.0,
    PopupRounding     = 5.0,
    ScrollbarRounding = 12.0,
    TabRounding       = 6.0,
    ItemSpacingX      = 4.0,
    ItemSpacingY      = 3.0,
    FramePaddingX     = 4.0, 
    FramePaddingY     = 2.0,
    WindowPaddingX    = 6.0, 
    WindowPaddingY    = 6.0 
}

function PushTheme(ctx)
    local count_c = 0
    local count_v = 0
    imgui.PushStyleColor(ctx, imgui.Col_WindowBg,       UI.WindowBg); count_c = count_c + 1
    imgui.PushStyleColor(ctx, imgui.Col_ChildBg,        UI.ChildBg); count_c = count_c + 1
    imgui.PushStyleColor(ctx, imgui.Col_PopupBg,        UI.PopupBg); count_c = count_c + 1
    imgui.PushStyleColor(ctx, imgui.Col_Text,           UI.Text); count_c = count_c + 1
    imgui.PushStyleColor(ctx, imgui.Col_TextDisabled,   UI.TextDisabled); count_c = count_c + 1
    imgui.PushStyleColor(ctx, imgui.Col_Border,         UI.Border); count_c = count_c + 1
    imgui.PushStyleColor(ctx, imgui.Col_FrameBg,        UI.FrameBg); count_c = count_c + 1
    imgui.PushStyleColor(ctx, imgui.Col_FrameBgHovered, UI.FrameBgHover); count_c = count_c + 1
    imgui.PushStyleColor(ctx, imgui.Col_FrameBgActive,  UI.FrameBgActive); count_c = count_c + 1
    imgui.PushStyleColor(ctx, imgui.Col_TitleBg,        UI.TitleBg); count_c = count_c + 1
    imgui.PushStyleColor(ctx, imgui.Col_Button,         UI.Button); count_c = count_c + 1
    imgui.PushStyleColor(ctx, imgui.Col_ButtonHovered,  UI.ButtonHover); count_c = count_c + 1
    imgui.PushStyleColor(ctx, imgui.Col_ButtonActive,   UI.ButtonActive); count_c = count_c + 1
    imgui.PushStyleColor(ctx, imgui.Col_Header,         UI.Header); count_c = count_c + 1
    imgui.PushStyleColor(ctx, imgui.Col_HeaderHovered,  UI.HeaderHover); count_c = count_c + 1
    imgui.PushStyleColor(ctx, imgui.Col_HeaderActive,   UI.HeaderActive); count_c = count_c + 1
    imgui.PushStyleColor(ctx, imgui.Col_Separator,      UI.Separator); count_c = count_c + 1
    imgui.PushStyleColor(ctx, imgui.Col_ResizeGrip,     UI.ResizeGrip); count_c = count_c + 1
    imgui.PushStyleColor(ctx, imgui.Col_CheckMark,      UI.CheckMark); count_c = count_c + 1

    imgui.PushStyleVar(ctx, imgui.StyleVar_WindowRounding,    STYLE.WindowRounding); count_v = count_v + 1
    imgui.PushStyleVar(ctx, imgui.StyleVar_FrameRounding,     STYLE.FrameRounding); count_v = count_v + 1
    imgui.PushStyleVar(ctx, imgui.StyleVar_PopupRounding,     STYLE.PopupRounding); count_v = count_v + 1
    imgui.PushStyleVar(ctx, imgui.StyleVar_GrabRounding,      STYLE.GrabRounding); count_v = count_v + 1
    imgui.PushStyleVar(ctx, imgui.StyleVar_TabRounding,       STYLE.TabRounding); count_v = count_v + 1
    imgui.PushStyleVar(ctx, imgui.StyleVar_ItemSpacing,       STYLE.ItemSpacingX, STYLE.ItemSpacingY); count_v = count_v + 1
    imgui.PushStyleVar(ctx, imgui.StyleVar_FramePadding,      STYLE.FramePaddingX, STYLE.FramePaddingY); count_v = count_v + 1
    imgui.PushStyleVar(ctx, imgui.StyleVar_WindowPadding,     STYLE.WindowPaddingX, STYLE.WindowPaddingY); count_v = count_v + 1
    
    return count_c, count_v
end


-- *** NEW: Clear all data when switching modes ***
function ClearAllQueues()
    multi_target_queue = {}
    single_ref_item, single_ref_path, single_ref_name = nil, nil, "None"
    multi_ref_queue = {}
    single_target_item, single_target_path, single_target_name = nil, nil, "None"
    job_queue = {}
    total_jobs = 0
    status_text = "Mode switched. Please add items."
    last_error = ""
    is_running = false -- Safety
end

-- *** Functions for Mode 1 (N-Targets -> 1-Ref) ***
function SetMultiTargets()
    if is_running then return end
    multi_target_queue = {}
    total_jobs = 0
    
    local sel_count = reaper.CountSelectedMediaItems(0)
    if sel_count == 0 then
        status_text = "Error: No items selected to set as targets."
        return
    end
    
    local items_added = 0
    for i = 0, sel_count - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        if item ~= single_ref_item then
            local path = GetItemPath(item)
            if path then
                table.insert(multi_target_queue, { item = item, path = path, name = GetBasename(path) })
                items_added = items_added + 1
            end
        end
    end
    
    if items_added > 0 then
        status_text = string.format("Loaded %d target(s). Ready.", items_added)
        total_jobs = items_added
    else
        status_text = "Error: Could not read paths from selected targets."
    end
end

function SetSingleReference()
    if is_running then return end
    local sel_count = reaper.CountSelectedMediaItems(0)
    if sel_count ~= 1 then
        status_text = "Error: Please select exactly ONE item to be the reference."
        return
    end
    
    local item = reaper.GetSelectedMediaItem(0, 0)
    local path = GetItemPath(item)
    
    if path then
        single_ref_item = item
        single_ref_path = path
        single_ref_name = GetBasename(path)
        status_text = "Reference set. Ready."
        
        for i = #multi_target_queue, 1, -1 do
            if multi_target_queue[i].item == single_ref_item then
                table.remove(multi_target_queue, i)
                total_jobs = #multi_target_queue
                status_text = "Reference set. (Removed from targets)."
            end
        end
    else
        status_text = "Error: Could not read path from selected reference."
    end
end

-- *** Functions for Mode 2 (1-Target -> N-Refs) ***
function SetSingleTarget()
    if is_running then return end
    local sel_count = reaper.CountSelectedMediaItems(0)
    if sel_count ~= 1 then
        status_text = "Error: Please select exactly ONE item to be the TARGET."
        return
    end
    
    local item = reaper.GetSelectedMediaItem(0, 0)
    local path = GetItemPath(item)
    
    if path then
        single_target_item = item
        single_target_path = path
        single_target_name = GetBasename(path)
        status_text = "Target set. Now set References."
        
        for i = #multi_ref_queue, 1, -1 do
            if multi_ref_queue[i].item == single_target_item then
                table.remove(multi_ref_queue, i)
                total_jobs = #multi_ref_queue
                status_text = "Target set. (Removed from references)."
            end
        end
    else
        status_text = "Error: Could not read path from selected target."
    end
end

function SetMultiReferences()
    if is_running then return end
    multi_ref_queue = {}
    total_jobs = 0
    
    local sel_count = reaper.CountSelectedMediaItems(0)
    if sel_count == 0 then
        status_text = "Error: No items selected to set as references."
        return
    end
    
    local items_added = 0
    for i = 0, sel_count - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        if item ~= single_target_item then
            local path = GetItemPath(item)
            if path then
                table.insert(multi_ref_queue, { item = item, path = path, name = GetBasename(path) })
                items_added = items_added + 1
            end
        end
    end
    
    if items_added > 0 then
        status_text = string.format("Loaded %d reference(s). Ready.", items_added)
        total_jobs = items_added
    else
        status_text = "Error: Could not read paths from selected references."
    end
end

-- *** NEW: Unified Batch Logic ***
function StartNextJob()
    if #job_queue == 0 then
        is_running = false
        run_start_time = 0
        status_text = string.format("Batch complete! %d job(s) finished.", total_jobs)
        total_jobs = 0
        if batch_mode == 2 and single_target_item then
            reaper.SetMediaItemInfo_Value(single_target_item, "B_MUTE", 1.0)
            reaper.UpdateArrange()
        end
        return
    end

    local job = table.remove(job_queue, 1)
    current_job_target_item = job.target.item
    current_job_ref_item = job.ref.item
    
    if job.target.path:lower():match("%.mp3$") or job.ref.path:lower():match("%.mp3$") then
        last_error = "Error: .mp3 files not supported. Skipping job."
        reaper.defer(StartNextJob)
        return
    end

    local cmd_id = reaper.NamedCommandLookup(settings.cmd_id)
    if cmd_id == 0 then
        status_text = "Error: Batch stopped."
        last_error = "Could not find worker script Command ID. Check Settings."
        is_running = false
        job_queue = {} 
        return
    end
    
    reaper.SetExtState("MatcheringWorker", "Target", job.target.path, false)
    reaper.SetExtState("MatcheringWorker", "Reference", job.ref.path, false)
    reaper.SetExtState("MatcheringWorker", "ReferenceName", job.ref.name, false)
    reaper.SetExtState("MatcheringWorker", "BitDepth", settings.bit_depth_options[settings.bit_depth_index], false)
    reaper.SetExtState("MatcheringWorker", "Command", "", false) 
    
    reaper.Main_OnCommand(cmd_id, 0)
    
    local job_name = ""
    if batch_mode == 1 then
        job_name = "T: " .. job.target.name
    else
        job_name = "R: " .. job.ref.name
    end
    status_text = string.format("Running (%d/%d): %s", total_jobs - #job_queue, total_jobs, job_name)
    last_error = ""
    is_running = true
    run_start_time = reaper.time_precise()
end

function StartBatch()
    if is_running then return end
    
    job_queue = {}
    
    if batch_mode == 1 then
        if #multi_target_queue == 0 then
            status_text = "Error"; last_error = "No target items in queue."
            return
        end
        if not single_ref_item then
            status_text = "Error"; last_error = "No reference item set."
            return
        end
        local R = { item = single_ref_item, path = single_ref_path, name = single_ref_name }
        for _, T in ipairs(multi_target_queue) do
            table.insert(job_queue, { target = T, ref = R })
        end
    else
        if not single_target_item then
            status_text = "Error"; last_error = "No target item set."
            return
        end
        if #multi_ref_queue == 0 then
            status_text = "Error"; last_error = "No reference items in queue."
            return
        end
        local T = { item = single_target_item, path = single_target_path, name = single_target_name }
        for _, R in ipairs(multi_ref_queue) do
            table.insert(job_queue, { target = T, ref = R })
        end
    end
    
    total_jobs = #job_queue
    if total_jobs == 0 then
        status_text = "Error"; last_error = "No valid jobs to run."
        return
    end
    
    StartNextJob()
end

-- --- GUI LOOP (ReaImGui) ---
function main_loop()
    -- Status check logic (Unchanged Logic, just checking status)
    if is_running then
        local worker_status = reaper.GetExtState("MatcheringWorker", "Status")
        if worker_status and #worker_status > 0 then
            if worker_status == "Done" then
                reaper.SetExtState("MatcheringWorker", "Status", "", false) 
                if batch_mode == 1 then
                    if current_job_target_item then reaper.SetMediaItemInfo_Value(current_job_target_item, "B_MUTE", 1.0) end
                    if current_job_ref_item then reaper.SetMediaItemInfo_Value(current_job_ref_item, "B_MUTE", 1.0) end
                else
                    if current_job_ref_item then reaper.SetMediaItemInfo_Value(current_job_ref_item, "B_MUTE", 1.0) end
                end
                reaper.UpdateArrange() 
                reaper.defer(StartNextJob) 
            elseif worker_status:match("^Error:") then
                last_error = worker_status:gsub("^Error: ", "") 
                reaper.SetExtState("MatcheringWorker", "Status", "", false) 
                if settings.continue_on_error then
                    status_text = "Error! Skipping job..."
                    if current_job_target_item then reaper.SetMediaItemInfo_Value(current_job_target_item, "B_MUTE", 1.0) end
                    if current_job_ref_item then reaper.SetMediaItemInfo_Value(current_job_ref_item, "B_MUTE", 1.0) end
                    reaper.UpdateArrange()
                    reaper.defer(StartNextJob)
                else
                    is_running = false
                    run_start_time = 0 
                    job_queue = {}; multi_target_queue = {}; multi_ref_queue = {}; total_jobs = 0
                    status_text = "Error! Batch stopped."
                end
            elseif status_text ~= worker_status then
                 status_text = worker_status
                 last_error = ""
            end
        end
        local gui_command = reaper.GetExtState("MatcheringWorker", "Command")
        if gui_command == "Cancel" then
             is_running = false; run_start_time = 0
             job_queue = {}; multi_target_queue = {}; multi_ref_queue = {}; total_jobs = 0
             status_text = "Cancelling... waiting for worker."
        end
    end

    -- --- Draw GUI ---
    local count_c, count_v = PushTheme(ctx) -- Apply Theme
    
    -- Ensure a minimum reasonable width AND Fixed Max Width to prevent drift
    -- (360 min, 360 max) -> Compact Fixed Width. Height is auto.
    imgui.SetNextWindowSizeConstraints(ctx, 360, -1, 360, 16384)
    
    -- Use AlwaysAutoResize to fit content (height will collapse/expand)
    local visible, is_open_ret = imgui.Begin(ctx, script_title, is_open, imgui.WindowFlags_AlwaysAutoResize)
    is_open = is_open_ret

    if visible then
        -- Header
        imgui.TextColored(ctx, UI.Info, "MATCHERING BATCH")
        imgui.SameLine(ctx); imgui.TextDisabled(ctx, "(Unified)")
        imgui.Separator(ctx)
        imgui.Dummy(ctx, 0, 5)

        -- 1. Mode Selection (Styled)
        imgui.BeginDisabled(ctx, is_running)
        if imgui.BeginChild(ctx, "ModeSelect", 0, 35, 1) then
            imgui.PushStyleVar(ctx, imgui.StyleVar_ItemSpacing, 15, 0) -- Spacing between radios
            if imgui.RadioButton(ctx, "Multi-Target (N:1)", batch_mode == 1) then
                if batch_mode ~= 1 then ClearAllQueues() end; batch_mode = 1
            end
            imgui.SameLine(ctx)
            if imgui.RadioButton(ctx, "Multi-Reference (1:N)", batch_mode == 2) then
                if batch_mode ~= 2 then ClearAllQueues() end; batch_mode = 2
            end
            imgui.PopStyleVar(ctx)
            imgui.EndChild(ctx)
        end
        imgui.EndDisabled(ctx)
        
        imgui.Dummy(ctx, 0, 5)

        -- 2. Main Content Area
        if imgui.BeginChild(ctx, "MainContent", 0, 160, 1) then
            if batch_mode == 1 then
                -- Mode 1 GUI
                imgui.TextColored(ctx, UI.CheckMark, "MODE 1: Apply 1 Reference to multiple Targets")
                imgui.Separator(ctx)
                
                imgui.BeginDisabled(ctx, is_running)
                -- Targets Row
                if imgui.Button(ctx, "Set Selected as TARGETS", 200, 25) then SetMultiTargets() end
                imgui.SameLine(ctx); imgui.TextWrapped(ctx, string.format("%d items in queue", #multi_target_queue))
                
                -- Reference Row
                if imgui.Button(ctx, "Set Selected as REFERENCE", 200, 25) then SetSingleReference() end
                imgui.SameLine(ctx); imgui.TextWrapped(ctx, single_ref_name)
                imgui.EndDisabled(ctx)
            else
                -- Mode 2 GUI
                imgui.TextColored(ctx, UI.CheckMark, "MODE 2: Test multiple References on 1 Target")
                imgui.Separator(ctx)
                
                imgui.BeginDisabled(ctx, is_running)
                -- Target Row
                if imgui.Button(ctx, "Set Selected as TARGET", 200, 25) then SetSingleTarget() end
                imgui.SameLine(ctx); imgui.TextWrapped(ctx, single_target_name)
                
                -- References Row
                if imgui.Button(ctx, "Set Selected as REFERENCES", 200, 25) then SetMultiReferences() end
                imgui.SameLine(ctx); imgui.TextWrapped(ctx, string.format("%d items in queue", #multi_ref_queue))
                imgui.EndDisabled(ctx)
            end
            
            imgui.Dummy(ctx, 0, 10)
            imgui.Separator(ctx)
            
            -- Action Button (Centered-ish)
            local btn_w = imgui.GetContentRegionAvail(ctx)
            if is_running then
                imgui.PushStyleColor(ctx, imgui.Col_Button, 0xEF5350AA) -- Red
                imgui.PushStyleColor(ctx, imgui.Col_ButtonHovered, 0xEF5350FF) 
                if imgui.Button(ctx, "STOP / CANCEL", btn_w, 35) then
                    reaper.SetExtState("MatcheringWorker", "Command", "Cancel", false)
                    status_text = "Cancelling..."
                end
                imgui.PopStyleColor(ctx, 2)
            else
                imgui.PushStyleColor(ctx, imgui.Col_Button, UI.Success) -- Green-ish
                imgui.PushStyleColor(ctx, imgui.Col_ButtonHovered, 0x66BB6AFF)
                if imgui.Button(ctx, "RUN BATCH", btn_w, 35) then StartBatch() end
                imgui.PopStyleColor(ctx, 2)
            end
            
            imgui.EndChild(ctx)
        end

        -- 3. Status Panel
        imgui.Dummy(ctx, 0, 5)
        if imgui.BeginChild(ctx, "StatusPanel", 0, 50, 1) then
            imgui.TextColored(ctx, UI.TextDisabled, "Status:")
            imgui.SameLine(ctx)
            if is_running then
                 imgui.TextColored(ctx, UI.CheckMark, status_text)
            elseif last_error ~= "" then
                 imgui.TextColored(ctx, UI.Error, last_error)
            else
                 imgui.Text(ctx, status_text)
            end
            
            if is_running and run_start_time > 0 then
                local t = reaper.time_precise() - run_start_time
                imgui.TextDisabled(ctx, string.format("Elapsed: %.1fs", t))
            end
            imgui.EndChild(ctx)
        end
        
        -- 4. Settings (Collapsible)
        imgui.Dummy(ctx, 0, 5)
        imgui.BeginDisabled(ctx, is_running)
        if imgui.CollapsingHeader(ctx, "Settings") then
            -- Checkbox
            local c_err, n_err = imgui.Checkbox(ctx, "Continue on Error", settings.continue_on_error)
            if c_err then settings.continue_on_error = n_err; SaveSettings() end
            
            imgui.Dummy(ctx, 0, 2)
            
            -- Manual ID Input (Constrain Width)
            imgui.TextWrapped(ctx, "Paste Command ID for 'matchering_worker.py':")
            
            -- 1. Input ID (Flexible width - Optimal)
            imgui.PushItemWidth(ctx, 235) 
            local c_id, n_id = imgui.InputText(ctx, "##cmd_id", settings.cmd_id, 128)
            if c_id then settings.cmd_id = n_id; SaveSettings() end
            imgui.PopItemWidth(ctx)
            
            -- 2. Paste Button
            imgui.SameLine(ctx)
            if imgui.Button(ctx, "Paste") then
                local clip = imgui.GetClipboardText(ctx)
                if clip and #clip > 0 then
                    settings.cmd_id = clip
                    SaveSettings()
                end
            end
            
            -- 3. Bit Depth (Compact - Expanded)
            imgui.SameLine(ctx)
            local opts = table.concat(settings.bit_depth_options, "\0") .. "\0"
            imgui.PushItemWidth(ctx, 68)
            local c_bd, n_bd = imgui.Combo(ctx, "##BitDepth", settings.bit_depth_index - 1, opts)
            if c_bd then settings.bit_depth_index = n_bd + 1; SaveSettings() end
            imgui.PopItemWidth(ctx)
        end
        imgui.EndDisabled(ctx)

        imgui.End(ctx)
    end
    
    if count_c then imgui.PopStyleColor(ctx, count_c) end
    if count_v then imgui.PopStyleVar(ctx, count_v) end
    
    if is_open then reaper.defer(main_loop) end
end

-- --- Start ---
main_loop()