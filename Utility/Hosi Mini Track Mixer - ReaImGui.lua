--[[
@description    Hosi Mini Track Mixer (ReaImGui Version)
@author         Hosi
@version        1.9.3
@reaper_version 6.0
@provides
  [main] . > Hosi_Mini Track Mixer (ReaImGui).lua

@about
  # Hosi Mini Track Mixer (ReaImGui Version)

  A small GUI workflow for mixing track volume, pan, width, sends, receives, and FX.

  ## Requirements:
  - REAPER 6.0+
  - ReaImGui library
  - SWS/S&M Extension (optional, for better track selection focus)

@changelog
  v1.9.3 (2025-Dec-10)
  - Modern GUI
  - Vertical Mixer
  - Run Auto-Color & Icons
  - Smart Gain Staging
  - Group Tracks
  - Send Matrix
  - Vertical FX Rack  
  v1.9.2 (2025-11-01)
  - Fixed: Lua error related to missing 'nil' argument in InputText for rename popup.
  v1.9.1 (2025-11-01)
  - Added: "Rename" button for items in the "Configure Custom Menu" window.
  v1.9 (2025-10-21)
  - Added: Super Advanced Search with logical operators (AND, OR, NOT).
  - Added: New search keys: 'fx:none', 'sends:none', 'solo:yes', 'parent:"name"'.
  - Added: Parameter-based search for 'vol', 'pan', and 'width' (e.g., 'vol:>-6', 'pan:=0').
  - Added: Drag & Drop to create sends. Drag one track onto another to create a send.
  - Added: Advanced Search. Use 'fx:name' to find tracks with a specific plugin, and 'sends:>N', 'sends:<N', or 'sends:=N' to filter by send count.
  - Added: Direct Value Input. Double-click on most numerical displays (Volume, Pan, Width, etc.) to open a popup and type in the exact value.
  v1.8 (2025-10-20)
  - Added: "Show All" and "Has Sends" filter buttons in the SENDS mode view for quicker list filtering.
  - Added: "Add New Send" button in SENDS mode to create new sends from the selected track.
  - Added: "Delete" button (X) for each send and receive, allowing for direct routing management.
  - Improved: Added a right-click context menu to the "EDITING" button for direct mode selection, while preserving the left-click cycle functionality.
  v1.7 (2025-10-17)
  - Added: Drag & Drop functionality to reorder items in the "Configure Menu" window.
  - Improved: Menu configuration window now uses icons for better visual distinction of item types.
  v1.6 (2025-10-16)
  - Added: A customizable user menu (⚙️ icon) to run any REAPER action or script from the toolbar.
  - Added: Configuration window to add/remove custom menu items. Settings are saved globally.
  v1.5 (2025-10-15)
  - Added: A vertical stereo peak meter is now displayed next to the fader in the Channel Strip view for real-time visual feedback.
  - Added: Detailed tooltips for most UI elements to improve user guidance and clarity.
  - Added: Quick Comp controls in the Channel Strip view.
  v1.4 (2025-10-14)
  - Added: Channel Strip View
  - Added: A horizontal stereo VU meter is now displayed for each track, providing real-time visual feedback on audio levels.
  - Added: "Sync View" checkbox to synchronize the script's track filter with REAPER's main track view (TCP/Mixer).
  - Added: When Sync View is active, changing the view mode dropdown will automatically show/hide tracks in the project.
  - Added: Disabling Sync View will reset and show all tracks in the project.
  - Added: Display of the formatted parameter value (e.g., "-12.5 dB") next to each slider in FX PARAMS mode for precise control.
  - Improved: Replaced the static "VIEW" button in SENDS, RECEIVES, and FX PARAMS modes with the persistent View Mode dropdown filter.
  - Improved: The View Mode filter now applies to all editing modes for a more consistent workflow.
  - Added: FX Parameter Control mode. Users can now pin specific plugin parameters to the mixer for direct control.
  - Added: "Pin" button on each track to open a parameter selection window.
  - Added: Track Receives control mode, allowing users to view and manage all incoming signals for a selected track.
  - Added: Track Sends control mode. In this mode, the mixer displays tracks with sends, allowing detailed control over each send's volume, pan, and mute.
  v1.3 (2025-10-13)
  - Added: New View Modes: "SELECTED & CHILDREN", "ARMED", "HAS FX", "HAS ITEMS", "MUTED".
  - Added: Stereo Width control. The mode button now cycles through PAN, VOL, and WIDTH.
  - Added: Phase Invert button (ø) for each track.
  - Improved: Replaced "Gang" checkbox with selection-based ganging.
  - Added: Track visibility control and toolbar buttons.
  v1.2 (2025-09-23)
  - Added: Right-click context menu.
  v1.1 (2025-09-23)
  - Added: Double-click to collapse/expand folders.
  v1.0 (2025-09-23)
  - Initial release.
--]]

-- --- USER CONFIGURATION ---
local config = {
    win_title = "Hosi Mini Track Mixer v1.9.3",
    refresh_interval = 0.05,
    indent_size = 15.0
}


-- --- THEME DEFINITIONS ---
local themes = {
    ["Modern Dark"] = {
        WinBg = 0x121212FF,
        ChildBg = 0x1E1E1EFF,
        PopupBg = 0x1E1E1EFF,
        FrameBg = 0x2C2C3EFF,
        FrameBgHovered = 0x3D3D55FF,
        FrameBgActive = 0x4A90E2FF,
        TitleBg = 0x121212FF,
        TitleBgActive = 0x121212FF,
        MenuBarBg = 0x1E1E1EFF,
        CheckMark = 0x4A90E2FF,
        SliderGrab = 0x4A90E2CC,
        SliderGrabActive = 0x4A90E2FF,
        Button = 0x2C2C3EFF,
        ButtonHovered = 0x3D3D55FF,
        ButtonActive = 0x4A90E2FF,
        Header = 0x2C2C3EFF,
        HeaderHovered = 0x3D3D55FF,
        HeaderActive = 0x4A90E2FF,
        Text = 0xE0E0E0FF,
        TextDisabled = 0x808080FF,
        Border = 0x40404077,
        Separator = 0x404040FF,
        ResizeGrip = 0x4A90E255,
        ResizeGripHovered = 0x4A90E2AA,
        ResizeGripActive = 0x4A90E2FF,
        -- Vars
        WindowRounding = 10.0,
        ChildRounding = 8.0,
        FrameRounding = 12.0, -- More rounded "pill" look
        PopupRounding = 8.0,
        ScrollbarSize = 12.0,
        ScrollbarRounding = 9.0,
        GrabRounding = 12.0,
        FramePadding = {8, 4},
        ItemSpacing = {8, 6}
    },
    ["Midnight Blue"] = {
        WinBg = 0x0F111AFF,
        ChildBg = 0x161925FF,
        PopupBg = 0x161925FF,
        FrameBg = 0x202436FF,
        FrameBgHovered = 0x2E344EFF,
        FrameBgActive = 0x00D9D9FF, -- Cyan accent
        TitleBg = 0x0F111AFF,
        TitleBgActive = 0x0F111AFF,
        MenuBarBg = 0x161925FF,
        CheckMark = 0x00D9D9FF,
        SliderGrab = 0x00D9D9CC,
        SliderGrabActive = 0x00D9D9FF,
        Button = 0x202436FF,
        ButtonHovered = 0x2E344EFF,
        ButtonActive = 0x00D9D9FF,
        Header = 0x202436FF,
        HeaderHovered = 0x2E344EFF,
        HeaderActive = 0x00D9D9FF,
        Text = 0xDDE6FFFF,
        TextDisabled = 0x6B7A99FF,
        Border = 0x30365077,
        Separator = 0x303650FF,
        ResizeGrip = 0x00D9D955,
        ResizeGripHovered = 0x00D9D9AA,
        ResizeGripActive = 0x00D9D9FF,
        -- Vars
        WindowRounding = 8.0,
        ChildRounding = 6.0,
        FrameRounding = 10.0,
        PopupRounding = 6.0,
        ScrollbarSize = 12.0,
        ScrollbarRounding = 6.0,
        GrabRounding = 6.0,
        FramePadding = {6, 4},
        ItemSpacing = {6, 4}
    },
    ["Classic"] = {
         -- Simplified Classic REAPER/ImGui look (mostly default colors but cleaned up)
        WinBg = 0x333333FF,
        ChildBg = 0x282828FF,
        PopupBg = 0x282828FF,
        FrameBg = 0x454545FF,
        FrameBgHovered = 0x555555FF,
        FrameBgActive = 0x777777FF,
        TitleBg = 0x333333FF,
        TitleBgActive = 0x3E3E3EFF,
        MenuBarBg = 0x333333FF,
        CheckMark = 0x999999FF,
        SliderGrab = 0x999999FF,
        SliderGrabActive = 0xCCCCCCFF,
        Button = 0x454545FF,
        ButtonHovered = 0x555555FF,
        ButtonActive = 0x777777FF,
        Header = 0x454545FF,
        HeaderHovered = 0x555555FF,
        HeaderActive = 0x777777FF,
        Text = 0xDDDDDDFF,
        TextDisabled = 0x888888FF,
        Border = 0x00000077,
        Separator = 0x555555FF,
        ResizeGrip = 0x99999955,
        ResizeGripHovered = 0x999999AA,
        ResizeGripActive = 0x999999FF,
        -- Vars
        WindowRounding = 0.0,
        ChildRounding = 0.0,
        FrameRounding = 0.0,
        PopupRounding = 0.0,
        ScrollbarSize = 14.0,
        ScrollbarRounding = 9.0,
        GrabRounding = 0.0,
        FramePadding = {4, 3},
        ItemSpacing = {8, 4}
    }
}

-- --- INITIALIZE REAIM GUI ---
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local imgui = require('imgui')('0.10')

if not imgui or type(imgui) ~= "table" then
  reaper.ShowMessageBox("Could not initialize ReaImGui library.\n\nPlease install it (v0.10+) via ReaPack.", "ReaImGui Error", 0)
  return
end

local ctx = imgui.CreateContext(config.win_title)

-- Check for optional dependencies
local has_sws_set_last_touched = type(reaper.SetLastTouchedTrack) == 'function'

-- --- STATE VARIABLES ---
local new_view_modes = { "ALL", "FOLDERS", "FOLDERS & CHILDREN", "SELECTED", "SELECTED & CHILDREN", "ARMED", "HAS FX", "HAS ITEMS", "MUTED" }
local state = {
    is_open = true,
    edit_mode = "PAN", -- PAN, VOL, WIDTH, FX RACK, SENDS, RECEIVES, FX PARAMS, CHAN STRIP
    edit_modes = { "PAN", "VOL", "WIDTH", "FX RACK", "SENDS", "RECEIVES", "FX PARAMS", "CHAN STRIP" },
    view_mode = 1,
    view_mode_names = new_view_modes,
    view_mode_names_str = table.concat(new_view_modes, "\0") .. "\0",
    filter_text = "",
    sync_view = false,
    sends_list_filter = "ALL", -- ALL, HAS_SENDS
    -- Meter Options
    meter_options = {
        mode = "PEAK", -- PEAK, RMS (Visual Smoothing)
        scale = "DIGITAL", -- DIGITAL (0dB Max), EBU (-18dB Ref)
        show_ticks = true
    },
    -- Mix Snapshots
    mix_snapshots = {
        A = nil,
        B = nil,
        current_active = nil -- 'A' or 'B' or nil
    },
    -- Auto-Color Rules
    auto_color_rules = {
        -- Drums (Red/Orange)
        { pattern = "kick", color = 0xFF0000, icon = "🥁" },
        { pattern = "snare", color = 0xFF4400, icon = "🥁" },
        { pattern = "hat", color = 0xFF8800, icon = "🎩" },
        { pattern = "cymbal", color = 0xFFAA00, icon = "📀" },
        { pattern = "drum", color = 0xAA0000, icon = "🥁" },
        { pattern = "tom", color = 0xDD5500, icon = "🥁" },
        
        -- Bass (Dark Blue/Purple)
        { pattern = "bass", color = 0x0000FF, icon = "🎸" },
        { pattern = "sub", color = 0x000088, icon = "🔉" },
        
        -- Guitars (Green)
        { pattern = "gtr", color = 0x00FF00, icon = "🎸" },
        { pattern = "guitar", color = 0x00FF00, icon = "🎸" },
        { pattern = "acous", color = 0x88FF00, icon = "🎸" },
        
        -- Keys/Synth (Teal/Cyan)
        { pattern = "key", color = 0x00FFFF, icon = "🎹" },
        { pattern = "piano", color = 0x00FFFF, icon = "🎹" },
        { pattern = "synth", color = 0x00AAAA, icon = "🎹" },
        { pattern = "pad", color = 0x008888, icon = "🌌" },
        
        -- Vocals (Pink/Magenta)
        { pattern = "vox", color = 0xFF00FF, icon = "🎤" },
        { pattern = "vocal", color = 0xFF00FF, icon = "🎤" },
        { pattern = "bgv", color = 0xFF55FF, icon = "🎤" },
        { pattern = "choir", color = 0xAA00AA, icon = "🗣️" },
        
        -- FX/Buss (Yellow/Gold)
        { pattern = "fx", color = 0xFFFF00, icon = "✨" },
        { pattern = "verb", color = 0xFFAA00, icon = "🌫️" },
        { pattern = "delay", color = 0xFFAA00, icon = "🔁" },
        { pattern = "bus", color = 0xAAAA00, icon = "🚌" },
        { pattern = "master", color = 0xFFFFFF, icon = "🎚️" }
    },
    -- Focus Folder State
    focus_folder_guid = nil,
    focus_folder_depth = -1,
    focus_folder_idx = -1, -- Track index of the focused folder
    
    -- Mixer Layout ("LIST" or "STRIP")
    mixer_layout = "LIST",
    
    -- Track Groups (VCA Style)
    track_groups = {}, -- Key: GUID, Value: Group Index (1-8)
    group_names = {}, -- Key: Group Index (1-8), Value: Name String
    -- SEND MATRIX STATE
    matrix_pinned_tracks = {}, -- Array of GUID strings
    show_matrix_view = false,  -- Toggle for Matrix View
    group_colors = {
        [0] = 0x00000000, -- None
        [1] = 0xFF0000FF, -- Red
        [2] = 0x00FF00FF, -- Green
        [3] = 0x0000FFFF, -- Blue
        [4] = 0xFFFF00FF, -- Yellow
        [5] = 0x00FFFFFF, -- Cyan
        [6] = 0xFF00FFFF, -- Magenta
        [7] = 0xFF8800FF, -- Orange
        [8] = 0x8800FFFF  -- Purple
    },

    -- Track data
    tracks = {},
    tracksPan = {},
    tracksVol = {},
    tracksWidth = {},
    tracksSel = {},
    tracksMut = {},
    tracksSol = {},
    tracksFX = {},
    tracksFXCount = {},
    tracksArmed = {},
    tracksHasItems = {},
    tracksDepth = {},
    isFolder = {},
    folderCollapsed = {},
    tracksVisible = {},
    tracksPhase = {},
    tracksSends = {},
    tracksReceives = {},
    tracksPeakL = {},
    tracksPeakR = {},
    tracksPeakHoldL = {},
    tracksPeakR = {},
    tracksPeakHoldL = {},
    tracksPeakHoldR = {},
    tracksFXList = {}, -- New table for FX Rack data
    last_selected_track_idx = nil,
    sends_view_track_idx = nil,
    receives_view_track_idx = nil,
    pinnedParams = {},
    popup_pin_track_idx = nil,
    open_pin_popup = false,
    open_add_send_popup = false,
    last_update_time = 0,
    -- Quick Controls State
    quickControls = {
        reaComp_idx = nil,
        reaComp_params = {}
    },
    -- Presets
    preset1 = { track = {} },
    preset2 = { track = {} },
    preset3 = { track = {} },
    preset4 = { track = {} },
    preset5 = { track = {} },
    -- Custom Menu
    customMenu = {},
    open_custom_menu_config = false,
    new_menu_item_name = "",
    new_menu_item_id = "",
    new_menu_item_type_idx = 0,
    menu_config_target_table = nil,
    -- Drag & Drop state for menu config
    dnd_source_path = nil,
    dnd_target_path = nil,
    dnd_drop_type = nil, -- 'before', 'into'
    item_to_delete_path = nil,
    -- NEW STATE FOR VALUE INPUT POPUP
    open_value_input_popup = false,
    value_input_info = {},
    value_input_text = "",
    -- NEW STATE FOR RENAME MENU ITEM POPUP
    open_rename_popup = false,
    rename_item_path = nil,
    rename_item_new_name = "",
    -- GROUP RENAME POPUP
    open_group_rename_popup = false,
    -- THEME STATE
    current_theme = "Modern Dark"
}

-- --- UTILITY AND LOGIC FUNCTIONS ---

-- Track Grouping Helpers
function LoadProjectGroups()
    -- Load Assignments
    local retval, str = reaper.GetProjExtState(0, "HosiMixer", "TrackGroups")
    if retval == 1 and str ~= "" then
        for part in str:gmatch("[^,]+") do
            local guid, grp = part:match("([^:]+):(%d+)")
            if guid and grp then
                state.track_groups[guid] = tonumber(grp)
            end
        end
    end
    
    -- Load Names
    local retval_n, str_n = reaper.GetProjExtState(0, "HosiMixer", "GroupNames")
    if retval_n == 1 and str_n ~= "" then
        for part in str_n:gmatch("[^,]+") do
            local grp, name = part:match("(%d+):([^:]+)")
            if grp and name then
                state.group_names[tonumber(grp)] = name
            end
        end
    end
    -- Ensure defaults
    for i=1, 8 do
        if not state.group_names[i] then state.group_names[i] = "Group "..i end
    end
end

function SaveProjectGroups()
    local parts = {}
    for guid, grp in pairs(state.track_groups) do
        table.insert(parts, guid .. ":" .. grp)
    end
    reaper.SetProjExtState(0, "HosiMixer", "TrackGroups", table.concat(parts, ","))
    
    local name_parts = {}
    for i=1, 8 do
        if state.group_names[i] then
            table.insert(name_parts, i .. ":" .. state.group_names[i])
        end
    end
    reaper.SetProjExtState(0, "HosiMixer", "GroupNames", table.concat(name_parts, ","))
end

-- Matrix Persistence
function LoadMatrixPins()
    local retval, str = reaper.GetProjExtState(0, "HosiMixer", "MatrixPins")
    if retval == 1 and str ~= "" then
        state.matrix_pinned_tracks = {}
        for part in str:gmatch("[^,]+") do
            table.insert(state.matrix_pinned_tracks, part)
        end
    end
end

function SaveMatrixPins()
    if #state.matrix_pinned_tracks > 0 then
        local str = table.concat(state.matrix_pinned_tracks, ",")
        reaper.SetProjExtState(0, "HosiMixer", "MatrixPins", str)
    else
        reaper.SetProjExtState(0, "HosiMixer", "MatrixPins", "")
    end
end

function SetTrackGroup(track, group_idx)
    local guid = reaper.GetTrackGUID(track)
    if group_idx == 0 then state.track_groups[guid] = nil
    else state.track_groups[guid] = group_idx end
    SaveProjectGroups()
end

function GetTrackGroup(track)
    if not track then return 0 end
    local guid = reaper.GetTrackGUID(track)
    return state.track_groups[guid] or 0
end

local is_group_adjusting = false

function SyncGroupVolume(leader_track, ratio, skip_selected)
    if is_group_adjusting then return end
    local group = GetTrackGroup(leader_track)
    if group == 0 then return end
    
    is_group_adjusting = true
    reaper.PreventUIRefresh(1)
    
    local leader_guid = reaper.GetTrackGUID(leader_track)
    for i = 1, #state.tracks do
        local t = state.tracks[i]
        -- If skip_selected is true and track is selected, skip it (handled by selection loop)
        if skip_selected and state.tracksSel[i] then goto continue_sync_vol end
        
        if t ~= leader_track and GetTrackGroup(t) == group then
            local current_vol = reaper.GetMediaTrackInfo_Value(t, "D_VOL")
            reaper.SetMediaTrackInfo_Value(t, "D_VOL", current_vol * ratio)
        end
        ::continue_sync_vol::
    end
    
    reaper.PreventUIRefresh(-1)
    is_group_adjusting = false
end

function SyncGroupPan(leader_track, delta, skip_selected)
    if is_group_adjusting then return end
    local group = GetTrackGroup(leader_track)
    if group == 0 then return end
    
    is_group_adjusting = true
    reaper.PreventUIRefresh(1)

    local leader_guid = reaper.GetTrackGUID(leader_track)
    for i = 1, #state.tracks do
        local t = state.tracks[i]
        -- If skip_selected is true and track is selected, skip it
        if skip_selected and state.tracksSel[i] then goto continue_sync_pan end
        
        if t ~= leader_track and GetTrackGroup(t) == group then
            local current_pan = reaper.GetMediaTrackInfo_Value(t, "D_PAN")
            local new_pan = current_pan + delta
            if new_pan > 1.0 then new_pan = 1.0 elseif new_pan < -1.0 then new_pan = -1.0 end
            reaper.SetMediaTrackInfo_Value(t, "D_PAN", new_pan)
        end
        ::continue_sync_pan::
    end

    reaper.PreventUIRefresh(-1)
    is_group_adjusting = false
end

-- Load Groups on Startup
LoadProjectGroups()
LoadMatrixPins()

function DrawTrackContextMenuOptions(ctx, track, i, guid_str, name)
    imgui.Text(ctx, "Track: " .. name)
    imgui.Separator(ctx)
    
    -- Grouping Submenu
    if imgui.BeginMenu(ctx, "Pooling / Grouping 🔗") then
         if imgui.MenuItem(ctx, "No Group", nil, GetTrackGroup(track)==0) then SetTrackGroup(track, 0) end
         imgui.Separator(ctx)
         for g=1, 8 do
             imgui.PushStyleColor(ctx, imgui.Col_Text, state.group_colors[g])
             local g_name = state.group_names[g] or ("Group "..g)
             if imgui.MenuItem(ctx, g_name, nil, GetTrackGroup(track)==g) then SetTrackGroup(track, g) end
             imgui.PopStyleColor(ctx)
         end
         imgui.Separator(ctx)
         if imgui.MenuItem(ctx, "✏️ Edit Group Names...") then state.open_group_rename_popup = true end
         
         imgui.EndMenu(ctx)
    end
    
    imgui.Separator(ctx)
    
    -- Matrix Pinning
    local is_pinned = false
    for _, pinned_guid in ipairs(state.matrix_pinned_tracks) do
        if pinned_guid == guid_str then is_pinned = true; break end
    end
    if imgui.MenuItem(ctx, is_pinned and "📌 Unpin from Matrix" or "📌 Pin to Matrix") then
        if is_pinned then
            -- Remove
            for k, v in ipairs(state.matrix_pinned_tracks) do
                if v == guid_str then table.remove(state.matrix_pinned_tracks, k); break end
            end
        else
            -- Add
            table.insert(state.matrix_pinned_tracks, guid_str)
        end
        SaveMatrixPins()
    end
    imgui.Separator(ctx)
    
    if state.isFolder[i] then
        if imgui.MenuItem(ctx, "🔍 Focus on this Folder") then
            state.focus_folder_guid = guid_str
            state.focus_folder_depth = state.tracksDepth[i] -- state.tracksDepth is available
            state.focus_folder_idx = i
        end
        imgui.Separator(ctx)
    end
    
    if imgui.MenuItem(ctx, "Rename...") then
        state.rename_item_path = track 
        state.rename_item_new_name = name
        state.open_rename_popup = true 
    end
    
    if imgui.MenuItem(ctx, 'Insert New Track') then reaper.defer(function() reaper.Main_OnCommand(40001, 0) end) end
    if imgui.MenuItem(ctx, 'Delete Track') then reaper.defer(function() reaper.DeleteTrack(track) end) end
end

function SetTheme(theme_name)
    local theme = themes[theme_name] or themes["Modern Dark"]
    state.current_theme = theme_name
    
    -- Colors
    imgui.PushStyleColor(ctx, imgui.Col_WindowBg, theme.WinBg)
    imgui.PushStyleColor(ctx, imgui.Col_ChildBg, theme.ChildBg)
    imgui.PushStyleColor(ctx, imgui.Col_PopupBg, theme.PopupBg)
    imgui.PushStyleColor(ctx, imgui.Col_FrameBg, theme.FrameBg)
    imgui.PushStyleColor(ctx, imgui.Col_FrameBgHovered, theme.FrameBgHovered)
    imgui.PushStyleColor(ctx, imgui.Col_FrameBgActive, theme.FrameBgActive)
    imgui.PushStyleColor(ctx, imgui.Col_TitleBg, theme.TitleBg)
    imgui.PushStyleColor(ctx, imgui.Col_TitleBgActive, theme.TitleBgActive)
    imgui.PushStyleColor(ctx, imgui.Col_TitleBgCollapsed, theme.TitleBg)
    imgui.PushStyleColor(ctx, imgui.Col_MenuBarBg, theme.MenuBarBg)
    imgui.PushStyleColor(ctx, imgui.Col_CheckMark, theme.CheckMark)
    imgui.PushStyleColor(ctx, imgui.Col_SliderGrab, theme.SliderGrab)
    imgui.PushStyleColor(ctx, imgui.Col_SliderGrabActive, theme.SliderGrabActive)
    imgui.PushStyleColor(ctx, imgui.Col_Button, theme.Button)
    imgui.PushStyleColor(ctx, imgui.Col_ButtonHovered, theme.ButtonHovered)
    imgui.PushStyleColor(ctx, imgui.Col_ButtonActive, theme.ButtonActive)
    imgui.PushStyleColor(ctx, imgui.Col_Header, theme.Header)
    imgui.PushStyleColor(ctx, imgui.Col_HeaderHovered, theme.HeaderHovered)
    imgui.PushStyleColor(ctx, imgui.Col_HeaderActive, theme.HeaderActive)
    imgui.PushStyleColor(ctx, imgui.Col_Text, theme.Text)
    imgui.PushStyleColor(ctx, imgui.Col_TextDisabled, theme.TextDisabled)
    imgui.PushStyleColor(ctx, imgui.Col_Border, theme.Border)
    imgui.PushStyleColor(ctx, imgui.Col_Separator, theme.Separator)
    imgui.PushStyleColor(ctx, imgui.Col_ResizeGrip, theme.ResizeGrip)
    imgui.PushStyleColor(ctx, imgui.Col_ResizeGripHovered, theme.ResizeGripHovered)
    imgui.PushStyleColor(ctx, imgui.Col_ResizeGripActive, theme.ResizeGripActive)

    -- Vars
    imgui.PushStyleVar(ctx, imgui.StyleVar_WindowRounding, theme.WindowRounding)
    imgui.PushStyleVar(ctx, imgui.StyleVar_ChildRounding, theme.ChildRounding)
    imgui.PushStyleVar(ctx, imgui.StyleVar_FrameRounding, theme.FrameRounding)
    imgui.PushStyleVar(ctx, imgui.StyleVar_PopupRounding, theme.PopupRounding)
    imgui.PushStyleVar(ctx, imgui.StyleVar_ScrollbarSize, theme.ScrollbarSize)
    imgui.PushStyleVar(ctx, imgui.StyleVar_ScrollbarRounding, theme.ScrollbarRounding)
    imgui.PushStyleVar(ctx, imgui.StyleVar_GrabRounding, theme.GrabRounding)
    imgui.PushStyleVar(ctx, imgui.StyleVar_FramePadding, theme.FramePadding[1], theme.FramePadding[2])
    imgui.PushStyleVar(ctx, imgui.StyleVar_ItemSpacing, theme.ItemSpacing[1], theme.ItemSpacing[2])
    
    -- Save to ExtState
    reaper.SetExtState("Hosi.MiniTrackMixer", "Theme", theme_name, true)
end

function PopTheme()
    -- Pop all pushed colors (26) and vars (9)
    imgui.PopStyleColor(ctx, 26)
    imgui.PopStyleVar(ctx, 9)
end

function load_theme_setting()
    local saved_theme = reaper.GetExtState("Hosi.MiniTrackMixer", "Theme")
    if saved_theme and themes[saved_theme] then
        state.current_theme = saved_theme
    end
end

function PackColor(r, g, b, a)
    local r_int = math.floor(r * 255 + 0.5)
    local g_int = math.floor(g * 255 + 0.5)
    local b_int = math.floor(b * 255 + 0.5)
    local a_int = math.floor(a * 255 + 0.5)
    -- Fixed: Combine as R G B A (ReaImGui ColorConvertDouble4ToU32 equivalent)
    -- Shift: R<<24, G<<16, B<<8, A
    return (r_int << 24) | (g_int << 16) | (b_int << 8) | a_int
end

function GainToDB(gain)
    if not gain then return -144.0 end
    if gain < 0.0000000298 then return -144.0 end
    return 20 * (math.log(gain) / math.log(10))
end

function DBToGain(db)
    return 10 ^ (db / 20)
end

function ShowTooltip(text)
    if imgui.IsItemHovered(ctx) then
        imgui.BeginTooltip(ctx)
        imgui.Text(ctx, text)
        imgui.EndTooltip(ctx)
    end
end

function ForceUIRefresh()
    reaper.TrackList_AdjustWindows(false)
    reaper.UpdateArrange()
end

function DrawVUMeter(ctx, height, peakL_gain, peakR_gain, peakHoldL_gain, peakHoldR_gain, track_idx)
    local draw_list = imgui.GetWindowDrawList(ctx)
    local screen_px, screen_py = imgui.GetCursorScreenPos(ctx)

    local meter_w, meter_spacing = 25, 4
    local total_w = meter_w * 2 + meter_spacing
    local text_height = 20

    -- Invisible Button for Interaction (Reset / Context Menu)
    -- Changed ID to be unique per track to avoid conflicts
    imgui.InvisibleButton(ctx, "##vu_area_"..track_idx, total_w, height + text_height)
    
    -- Context Menu
    if imgui.BeginPopupContextItem(ctx, "MeterSettings"..track_idx) then
        imgui.TextDisabled(ctx, "Meter Settings")
        imgui.Separator(ctx)
        
        if imgui.BeginMenu(ctx, "Scale") then
            if imgui.MenuItem(ctx, "Digital (0dB Max)", "", state.meter_options.scale == "DIGITAL") then state.meter_options.scale = "DIGITAL" end
            -- Adjusted EBU label for clarity
            if imgui.MenuItem(ctx, "EBU Style (Ref -18dB)", "", state.meter_options.scale == "EBU") then state.meter_options.scale = "EBU" end
            imgui.EndMenu(ctx)
        end
        
        if imgui.MenuItem(ctx, "Show Ticks", "", state.meter_options.show_ticks) then state.meter_options.show_ticks = not state.meter_options.show_ticks end
        imgui.Separator(ctx)
        if imgui.MenuItem(ctx, "Reset All Peaks") then
            for i=1, #state.tracks do state.tracksPeakHoldL[i] = 0; state.tracksPeakHoldR[i] = 0 end
        end
        imgui.EndPopup(ctx)
    elseif imgui.IsItemClicked(ctx, 0) then
        state.tracksPeakHoldL[track_idx] = 0
        state.tracksPeakHoldR[track_idx] = 0
    end
    
    if imgui.IsItemHovered(ctx) then
         ShowTooltip("L-Click: Reset Peak\nR-Click: Meter Settings")
    end

    -- Helper to map Gain to 0-1 based on scale
    local function GetPulse(val_gain)
        local db = GainToDB(val_gain)
        local min_db = -60
        local max_db = 0
        
        if db < min_db then return 0 end
        if db > max_db then return 1 end
        return (db - min_db) / (max_db - min_db)
    end

    for ch = 0, 1 do
        local gain = (ch == 0) and peakL_gain or peakR_gain
        local hold_gain = (ch == 0) and peakHoldL_gain or peakHoldR_gain
        local x = screen_px + (ch * (meter_w + meter_spacing))
        
        -- Background Meter Track
        imgui.DrawList_AddRectFilled(draw_list, x, screen_py, x + meter_w, screen_py + height, 0x111111FF) 

        -- Calculate Height
        local fill_pct = GetPulse(gain)
        local fill_h = math.floor(fill_pct * height)
        local y_top = screen_py + (height - fill_h)
        
        -- Draw Gradient Bar
        if fill_h > 0 then
            local col_bot, col_mid, col_top
            
            if state.meter_options.scale == "EBU" then
                 -- EBU Colors: Gradient attempt
                 col_bot = 0x00AA00FF
                 col_top = 0xFFCC00FF 
                 if fill_pct > 0.8 then col_top = 0xFF0000FF end 
            else
                 -- Digital: Green -> Red
                 col_bot = 0x00FF00FF
                 col_top = 0xFF0000FF
            end
            
            -- Use MultiColor for Gradient
            imgui.DrawList_AddRectFilledMultiColor(draw_list, x, y_top, x + meter_w, screen_py + height, 
                    col_top, col_top, col_bot, col_bot) 
        end

        -- Hold Line
        local hold_pct = GetPulse(hold_gain)
        if hold_pct > 0 then
            local y_hold = screen_py + (height - math.floor(hold_pct * height))
            imgui.DrawList_AddLine(draw_list, x, y_hold, x + meter_w, y_hold, 0xFFFFFFFF, 1)
        end
    end

    -- Draw Ticks
    if state.meter_options.show_ticks then
        local dbs = {-6, -12, -18, -24, -40}
        local min_db, max_db = -60, 0
        local x_start = screen_px
        local x_end = screen_px + total_w
        
        for _, db in ipairs(dbs) do
            if db >= min_db then
               local pct = (db - min_db) / (max_db - min_db)
               local y = screen_py + (height - math.floor(pct * height))
               imgui.DrawList_AddLine(draw_list, x_start, y, x_end, y, 0x66666655, 1)
            end
        end
    end

    -- Draw Peak Hold Text
    local peak_hold_db_l = GainToDB(peakHoldL_gain)
    local peak_hold_db_r = GainToDB(peakHoldR_gain)
    
    local text_l = (peak_hold_db_l < -99) and "-inf" or string.format("%.1f", peak_hold_db_l)
    local text_r = (peak_hold_db_r < -99) and "-inf" or string.format("%.1f", peak_hold_db_r)
    
    local text_w_l = imgui.CalcTextSize(ctx, text_l)
    local text_w_r = imgui.CalcTextSize(ctx, text_r)
    
    local text_y_pos = screen_py + height + 3

    imgui.DrawList_AddText(draw_list, screen_px + (meter_w - text_w_l) / 2, text_y_pos, PackColor(0.8,0.8,0.8,1), text_l)
    imgui.DrawList_AddText(draw_list, screen_px + meter_w + meter_spacing + (meter_w - text_w_r) / 2, text_y_pos, PackColor(0.8,0.8,0.8,1), text_r)
end

-- OLD FUNCTION (Kept to ensure clean replacement flow, but disabled by rename)
function DrawVUMeter_OLD(ctx, height, peakL_gain, peakR_gain, peakHoldL_gain, peakHoldR_gain, track_idx)
    local draw_list = imgui.GetWindowDrawList(ctx)
    local screen_px, screen_py = imgui.GetCursorScreenPos(ctx)

    local meter_w, meter_spacing = 25, 4
    local total_w = meter_w * 2 + meter_spacing
    local text_height = 20

    -- Invisible Button for Interaction (Reset / Context Menu)
    imgui.InvisibleButton(ctx, "##vu_area_"..track_idx, total_w, height + text_height)
    
    -- Context Menu
    if imgui.BeginPopupContextItem(ctx, "MeterSettings"..track_idx) then
        imgui.TextDisabled(ctx, "Meter Settings")
        imgui.Separator(ctx)
        
        if imgui.BeginMenu(ctx, "Scale") then
            if imgui.MenuItem(ctx, "Digital (0dB Max)", "", state.meter_options.scale == "DIGITAL") then state.meter_options.scale = "DIGITAL" end
            -- Adjusted EBU label for clarity
            if imgui.MenuItem(ctx, "EBU Style (Ref -18dB)", "", state.meter_options.scale == "EBU") then state.meter_options.scale = "EBU" end
            imgui.EndMenu(ctx)
        end
        
        if imgui.MenuItem(ctx, "Show Ticks", "", state.meter_options.show_ticks) then state.meter_options.show_ticks = not state.meter_options.show_ticks end
        imgui.Separator(ctx)
        if imgui.MenuItem(ctx, "Reset All Peaks") then
            for i=1, #state.tracks do state.tracksPeakHoldL[i] = 0; state.tracksPeakHoldR[i] = 0 end
        end
        imgui.EndPopup(ctx)
    elseif imgui.IsItemClicked(ctx, 0) then
        state.tracksPeakHoldL[track_idx] = 0
        state.tracksPeakHoldR[track_idx] = 0
    end
    
    if imgui.IsItemHovered(ctx) then
         ShowTooltip("L-Click: Reset Peak\nR-Click: Meter Settings")
    end

    local col_bg = 0x00000044 -- Transparent/Darker background for meter
    local col_green = 0x22DD22FF
    local col_yellow = 0xEEEE22FF
    local col_red = 0xFF2222FF
    local col_peak_hold = 0xFFFFFFFF

    local function DrawBar(x_offset, peak_gain, peak_hold_gain)
        local db = GainToDB(peak_gain)
        local meter_range_db = 60 -- from -60dB to 0dB
        local meter_headroom_db = 6 -- from 0dB to +6dB

        local bar_h = 0
        if db >= -meter_range_db then
            bar_h = (db + meter_range_db) / (meter_range_db + meter_headroom_db) * height
            bar_h = math.min(bar_h, height)
        end

        -- Background
        imgui.DrawList_AddRectFilled(draw_list, screen_px + x_offset, screen_py, screen_px + x_offset + meter_w, screen_py + height, col_bg)

        -- Meter bar
        if bar_h > 0 then
            local yellow_thresh = height * (meter_range_db - 9) / (meter_range_db + meter_headroom_db)
            local red_thresh = height * meter_range_db / (meter_range_db + meter_headroom_db)

            -- Green part
            local green_h = math.min(bar_h, yellow_thresh)
            imgui.DrawList_AddRectFilled(draw_list, screen_px + x_offset, screen_py + height - green_h, screen_px + x_offset + meter_w, screen_py + height, col_green)

            -- Yellow part
            if bar_h > yellow_thresh then
                local yellow_h = math.min(bar_h, red_thresh) - yellow_thresh
                imgui.DrawList_AddRectFilled(draw_list, screen_px + x_offset, screen_py + height - yellow_thresh - yellow_h, screen_px + x_offset + meter_w, screen_py + height - yellow_thresh, col_yellow)
            end

            -- Red part
            if bar_h > red_thresh then
                local red_h = bar_h - red_thresh
                imgui.DrawList_AddRectFilled(draw_list, screen_px + x_offset, screen_py + height - red_thresh - red_h, screen_px + x_offset + meter_w, screen_py + height - red_thresh, col_red)
            end
        end

        -- Peak Hold Line
        local peak_hold_db = GainToDB(peak_hold_gain)
        if peak_hold_db > -meter_range_db then
            local peak_y_pos_h = (peak_hold_db + meter_range_db) / (meter_range_db + meter_headroom_db) * height
            local peak_y_pos = screen_py + height - math.min(peak_y_pos_h, height)
            imgui.DrawList_AddLine(draw_list, screen_px + x_offset, peak_y_pos, screen_px + x_offset + meter_w, peak_y_pos, col_peak_hold, 1.5)
        end
    end

    DrawBar(0, peakL_gain, peakHoldL_gain)
    DrawBar(meter_w + meter_spacing, peakR_gain, peakHoldR_gain)
    
    -- Draw Peak Hold Text
    local peak_hold_db_l = GainToDB(peakHoldL_gain)
    local peak_hold_db_r = GainToDB(peakHoldR_gain)
    
    local text_l = (peak_hold_db_l < -99) and "-inf" or string.format("%.1f", peak_hold_db_l)
    local text_r = (peak_hold_db_r < -99) and "-inf" or string.format("%.1f", peak_hold_db_r)
    
    local text_w_l = imgui.CalcTextSize(ctx, text_l)
    local text_w_r = imgui.CalcTextSize(ctx, text_r)
    
    local text_y_pos = screen_py + height + 3

    imgui.DrawList_AddText(draw_list, screen_px + (meter_w - text_w_l) / 2, text_y_pos, PackColor(0.8,0.8,0.8,1), text_l)
    imgui.DrawList_AddText(draw_list, screen_px + meter_w + meter_spacing + (meter_w - text_w_r) / 2, text_y_pos, PackColor(0.8,0.8,0.8,1), text_r)
end

function save_pinned_params()
    local data_parts = {}
    for guid, pins in pairs(state.pinnedParams) do
        if pins and #pins > 0 then
            local pin_parts = {}
            for _, pin in ipairs(pins) do
                table.insert(pin_parts, pin.fx_idx .. "," .. pin.param_idx)
            end
            table.insert(data_parts, guid .. ":" .. table.concat(pin_parts, ";"))
        end
    end
    local data_string = table.concat(data_parts, "|")
    reaper.SetProjExtState(0, "Hosi.MiniTrackMixer", "Pins", data_string)
end

function load_pinned_params()
    local _, data_string = reaper.GetProjExtState(0, "Hosi.MiniTrackMixer", "Pins")
    state.pinnedParams = {}
    if data_string and data_string ~= "" then
        for track_data in string.gmatch(data_string, "([^|]+)") do
            local guid, pins_str = string.match(track_data, "([^:]+):([^:]+)")
            if guid and pins_str then
                state.pinnedParams[guid] = {}
                for pin_data in string.gmatch(pins_str, "([^;]+)") do
                    local fx_idx, param_idx = string.match(pin_data, "([^,]+),([^,]+)")
                    if fx_idx and param_idx then
                        table.insert(state.pinnedParams[guid], {
                            fx_idx = tonumber(fx_idx),
                            param_idx = tonumber(param_idx)
                        })
                    end
                end
            end
        end
    end
end

-- A simple serializer for a Lua table.
function serialize_table(val)
    if type(val) == "string" then
        return string.format("%q", val)
    elseif type(val) == "number" or type(val) == "boolean" then
        return tostring(val)
    elseif type(val) == "table" then
        local parts = {}
        -- Check if it's an array or a map
        local is_array = true
        local n = 0
        for k, _ in pairs(val) do
            n = n + 1
            if type(k) ~= "number" or k ~= n then
                is_array = false
            end
        end
        if n ~= #val then is_array = false end

        for k, v in ipairs(val) do
            table.insert(parts, serialize_table(v))
        end
        if not is_array then
            for k, v in pairs(val) do
                if type(k) == "number" and k > 0 and k <= #val and val[k] == v then
                    -- already handled
                else
                    table.insert(parts, string.format("[%s]=%s", serialize_table(k), serialize_table(v)))
                end
            end
        end
        return "{" .. table.concat(parts, ",") .. "}"
    else
        return "nil"
    end
end

function save_custom_menu()
    local data_string = serialize_table(state.customMenu)
    reaper.SetExtState("Hosi.MiniTrackMixer", "CustomMenu", data_string, true)
end

function load_custom_menu()
    local data_string = reaper.GetExtState("Hosi.MiniTrackMixer", "CustomMenu")
    if data_string and data_string ~= "" then
        local success, result = pcall(load("return " .. data_string))
        if success and type(result) == "table" then
            state.customMenu = result
        else
            state.customMenu = {} -- Reset if data is corrupted
        end
    else
        state.customMenu = {}
    end
end

-- Helper to split string by a delimiter
function split(s, delimiter)
    local result = {};
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match);
    end
    return result;
end

-- Evaluates a single condition (e.g., 'fx:reacomp', 'NOT solo:yes')
function EvaluateSingleCondition(i, condition)
    local track = state.tracks[i]
    condition = condition:gsub("^%s*(.-)%s*$", "%1") -- trim

    local is_not = false
    if condition:upper():sub(1, 4) == "NOT " then
        is_not = true
        condition = condition:sub(5):gsub("^%s*(.-)%s*$", "%1")
    end

    local result = false
    
    -- Correctly parse key-value pairs, handling quotes
    local key, quoted_value, regular_value
    key, quoted_value = condition:match('^([%w_]+):"([^"]+)"$')
    if not key then
        key, regular_value = condition:match('^([%w_]+):([^%s]+)$')
    end
    
    local value = quoted_value or regular_value

    if key and value then
        key = key:lower()
        -- value is handled case-by-case below

        if key == 'fx' then
            if value:lower() == 'none' then
                result = (reaper.TrackFX_GetCount(track) == 0)
            else
                local fx_count = reaper.TrackFX_GetCount(track)
                for fx_idx = 0, fx_count - 1 do
                    local _, fx_name = reaper.TrackFX_GetFXName(track, fx_idx, "")
                    if fx_name and fx_name:lower():find(value:lower(), 1, true) then
                        result = true
                        break
                    end
                end
            end
        elseif key == 'sends' then
            if value:lower() == 'none' then
                 result = (#state.tracksSends[i] == 0)
            else
                local op, num_str = value:match("([<>=])%s*(%d+)")
                if not op then op = "="; num_str = value:match("%s*(%d+)%s*") end
                
                if num_str then
                    local num = tonumber(num_str)
                    local num_sends = #state.tracksSends[i]
                    if op == '>' then result = num_sends > num
                    elseif op == '<' then result = num_sends < num
                    elseif op == '=' then result = num_sends == num end
                end
            end
        elseif key == 'solo' then
            if value:lower() == 'yes' then result = (state.tracksSol[i] > 0) end
        elseif key == 'parent' then
            local parent = reaper.GetParentTrack(track)
            if parent then
                local _, parent_name = reaper.GetTrackName(parent)
                if parent_name:lower() == value:lower() then result = true end
            end
        elseif key == 'vol' or key == 'pan' or key == 'width' then
            local op, num_val_str = value:match("([<>=])(-?%d+[.]?%d*)")
            if not op then op = "="; num_val_str = value:match("(-?%d+[.]?%d*)") end

            if num_val_str then
                local num_val = tonumber(num_val_str)
                local track_val
                if key == 'vol' then track_val = GainToDB(state.tracksVol[i])
                elseif key == 'pan' then track_val = state.tracksPan[i] * 100
                elseif key == 'width' then track_val = state.tracksWidth[i] * 100 end

                if op == '>' then result = track_val > num_val
                elseif op == '<' then result = track_val < num_val
                elseif op == '=' then result = math.abs(track_val - num_val) < 0.1 -- Epsilon for float comparison
                end
            end
        end
    else
        -- No key found, do a simple name search
        local _, name = reaper.GetTrackName(track)
        result = name:lower():find(condition:lower(), 1, true)
    end

    -- If is_not is true, return not result. Otherwise, return result.
    return (is_not and not result) or (not is_not and result)
end

-- Main filter function with logical operators
function ApplyAdvancedFilter(i, filter_text)
    filter_text = filter_text:gsub("^%s*(.-)%s*$", "%1") -- trim
    if filter_text == "" then return true end

    -- Normalize logical operators to handle case-insensitivity
    local query = filter_text:gsub(" and ", " AND "):gsub(" or ", " OR "):gsub(" not ", " NOT ")
    query = query:gsub(" AND ", " AND "):gsub(" OR ", " OR "):gsub(" NOT ", " NOT ")

    -- This parser respects OR as the lowest precedence operator, and AND as higher.
    -- It splits the entire query by " OR " first. If any of these parts are true, the whole expression is true.
    -- Each of these parts is then split by " AND ". All of these smaller parts must be true for the AND-group to be true.
    
    local or_parts = split(query, " OR ")
    for _, or_part in ipairs(or_parts) do
        or_part = or_part:gsub("^%s*(.-)%s*$", "%1")
        if or_part ~= "" then
            local and_parts = split(or_part, " AND ")
            local is_and_group_true = true
            for _, and_part in ipairs(and_parts) do
                and_part = and_part:gsub("^%s*(.-)%s*$", "%1")
                if and_part ~= "" then
                    if not EvaluateSingleCondition(i, and_part) then
                        is_and_group_true = false
                        break
                    end
                end
            end

            if is_and_group_true then
                return true -- One of the OR-groups is true, so the whole expression is true
            end
        end
    end
    
    return false -- None of the OR-groups were true
end


function ApplyViewFilter(i)
    local track = state.tracks[i]
    local show_track = true
    
    local current_view_mode = state.view_mode_names[state.view_mode]
    if current_view_mode == "FOLDERS" then
        if not state.isFolder[i] then show_track = false end
    elseif current_view_mode == "FOLDERS & CHILDREN" then
        if not state.isFolder[i] and state.tracksDepth[i] == 0 then
            show_track = false
        end
    elseif current_view_mode == "SELECTED" then
        if not state.tracksSel[i] then show_track = false end
    elseif current_view_mode == "SELECTED & CHILDREN" then
        local is_visible = state.tracksSel[i]
        if not is_visible then
            local parent = reaper.GetParentTrack(track)
            while parent do
                if reaper.IsTrackSelected(parent) then
                    is_visible = true
                    break
                end
                parent = reaper.GetParentTrack(parent)
            end
        end
        if not is_visible then show_track = false end
    elseif current_view_mode == "ARMED" then
        if not state.tracksArmed[i] then show_track = false end
    elseif current_view_mode == "HAS FX" then
        if state.tracksFXCount[i] < 1 then show_track = false end
    elseif current_view_mode == "HAS ITEMS" then
        if not state.tracksHasItems[i] then show_track = false end
    elseif current_view_mode == "MUTED" then
        if state.tracksMut[i] ~= 1 then show_track = false end
    end
    
    return show_track
end

function SyncTrackVisibility()
    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)
    
    for i = 1, #state.tracks do
        local guid_str = reaper.GetTrackGUID(state.tracks[i])
        local should_show = ApplyViewFilter(i) and ApplyAdvancedFilter(i, state.filter_text)
        
        if state.edit_mode == "SENDS" and #state.tracksSends[i] == 0 then
            should_show = false
        elseif state.edit_mode == "RECEIVES" and #state.tracksReceives[i] == 0 then
            should_show = false
        elseif state.edit_mode == "FX PARAMS" and (not state.pinnedParams[guid_str] or #state.pinnedParams[guid_str] == 0) then
            should_show = false
        end

        local new_vis_state = should_show and 1 or 0
        reaper.SetMediaTrackInfo_Value(state.tracks[i], "B_SHOWINTCP", new_vis_state)
        reaper.SetMediaTrackInfo_Value(state.tracks[i], "B_SHOWINMIXER", new_vis_state)
    end
    
    reaper.PreventUIRefresh(-1)
    reaper.Undo_EndBlock("Sync Track Visibility", -1)
    ForceUIRefresh()
end

-- --- MIX SNAPSHOT LOGIC ---
function StoreSnapshot(slot)
    local snapshot = {}
    for i = 1, #state.tracks do
        local track = state.tracks[i]
        if reaper.ValidatePtr(track, "MediaTrack*") then
             local guid = reaper.GetTrackGUID(track)
             snapshot[guid] = {
                 vol = reaper.GetMediaTrackInfo_Value(track, "D_VOL"),
                 pan = reaper.GetMediaTrackInfo_Value(track, "D_PAN"),
                 width = reaper.GetMediaTrackInfo_Value(track, "D_WIDTH"),
                 mute = reaper.GetMediaTrackInfo_Value(track, "B_MUTE"),
                 solo = reaper.GetMediaTrackInfo_Value(track, "I_SOLO"),
                 phase = reaper.GetMediaTrackInfo_Value(track, "B_PHASE")
             }
        end
    end
    state.mix_snapshots[slot] = snapshot
    state.mix_snapshots.current_active = slot
end

function RecallSnapshot(slot)
    local snapshot = state.mix_snapshots[slot]
    if not snapshot then return end
    
    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)
    
    for i = 1, #state.tracks do
        local track = state.tracks[i]
        if reaper.ValidatePtr(track, "MediaTrack*") then
            local guid = reaper.GetTrackGUID(track)
            local data = snapshot[guid]
            
            if data then
                reaper.SetMediaTrackInfo_Value(track, "D_VOL", data.vol)
                reaper.SetMediaTrackInfo_Value(track, "D_PAN", data.pan)
                reaper.SetMediaTrackInfo_Value(track, "D_WIDTH", data.width)
                reaper.SetMediaTrackInfo_Value(track, "B_MUTE", data.mute)
                reaper.SetMediaTrackInfo_Value(track, "I_SOLO", data.solo)
                reaper.SetMediaTrackInfo_Value(track, "B_PHASE", data.phase)
            end
        end
    end
    
    reaper.PreventUIRefresh(-1)
    reaper.Undo_EndBlock("Recall Mix Snapshot " .. slot, -1)
    state.mix_snapshots.current_active = slot
    ForceUIRefresh()
end

-- --- AUTO-COLOR LOGIC ---
function RunAutoColor()
    reaper.Undo_BeginBlock()
    local change_count = 0
    
    for i = 1, #state.tracks do
        local track = state.tracks[i]
        if reaper.ValidatePtr(track, "MediaTrack*") then
             local _, current_name = reaper.GetTrackName(track)
             local name_lower = current_name:lower()
             
             -- Find matching rule
             for _, rule in ipairs(state.auto_color_rules) do
                 if name_lower:find(rule.pattern, 1, true) then
                     -- Apply Color
                     local r = (rule.color >> 16) & 0xFF
                     local g = (rule.color >> 8) & 0xFF
                     local b = rule.color & 0xFF
                     local native_color = reaper.ColorToNative(r, g, b)
                     reaper.SetTrackColor(track, native_color)
                     
                     -- Apply Icon (Rename)
                     -- Check if icon already starts the name to avoid duplication
                     if not current_name:find(rule.icon, 1, true) then
                         local new_name = rule.icon .. " " .. current_name
                         reaper.GetSetMediaTrackInfo_String(track, "P_NAME", new_name, true)
                     end
                     
                     change_count = change_count + 1
                     break -- Stop after first match (priority based on order in table)
                 end
             end
        end
    end
    
    reaper.Undo_EndBlock("Auto Color & Icon " .. change_count .. " Tracks", -1)
    ForceUIRefresh()
end

-- Smart Gain Staging
function RunGainStaging(target_db)
    reaper.Undo_BeginBlock()
    local track_count = #state.tracks
    local any_changed = false
    
    -- Check if we should only process selected tracks
    local process_selected_only = false
    for i = 1, track_count do
        if state.tracksSel[i] then process_selected_only = true; break end
    end
    
    for i = 1, track_count do
        if not process_selected_only or state.tracksSel[i] then
            -- Get highest peak seen so far (stored as Linear Gain in state)
            local peak_l_gain = state.tracksPeakHoldL[i] or 0
            local peak_r_gain = state.tracksPeakHoldR[i] or 0
            
            local peak_l_db = GainToDB(peak_l_gain)
            local peak_r_db = GainToDB(peak_r_gain)
            
            local max_peak_db = math.max(peak_l_db, peak_r_db)
            
            -- Sanity check: Signal must be somewhat audible to gain stage (> -60dB)
            if max_peak_db > -60 then
                local delta_db = target_db - max_peak_db
                
                -- Safety Limiter: Don't boost more than 24dB
                if delta_db > 24 then delta_db = 24 end
                
                local current_vol = reaper.GetMediaTrackInfo_Value(state.tracks[i], "D_VOL")
                local new_vol = current_vol * DBToGain(delta_db)
                
                reaper.SetMediaTrackInfo_Value(state.tracks[i], "D_VOL", new_vol)
                any_changed = true
            end
        end
    end
    
    local msg = any_changed and ("Smart Gain Stage to " .. target_db .. "dB") or "Smart Gain Stage (No Change)"
    reaper.Undo_EndBlock(msg, -1)
end

-- Helper to reset all peaks
local function ResetAllPeaks()
    for i = 1, #state.tracks do
        state.tracksPeakHoldL[i] = 0
        state.tracksPeakHoldR[i] = 0
    end
end

function DrawVerticalStrip(ctx, i, track, strip_width, strip_height)
    local width = strip_width
    local p = imgui.GetCursorScreenPos(ctx)
    local draw_list = imgui.GetWindowDrawList(ctx)
    
    imgui.BeginGroup(ctx)
    
    -- Header: Name & Color
    local r, g, b = reaper.ColorFromNative(reaper.GetTrackColor(track))
    local header_col = PackColor(r/255, g/255, b/255, 0.4)
    imgui.PushStyleColor(ctx, imgui.Col_Button, header_col)
    
    -- Track ID & NameButton (Click to Select)
    local _, name = reaper.GetTrackName(track)
    
    -- Badge Logic
    local grp = GetTrackGroup(track)
    local prefix = (grp > 0) and string.format("G%d", grp) or tostring(i)
    local display_name = string.format("%s: %s", prefix, name)
    
    if imgui.Button(ctx, display_name.."##vname"..i, width, 20) then
         if imgui.IsKeyDown(ctx, imgui.Mod_Ctrl) then
            reaper.SetTrackSelected(track, not reaper.IsTrackSelected(track))
         else
            reaper.SetOnlyTrackSelected(track)
         end
         state.last_selected_track_idx = i
    end
    
    -- Context Menu
    if imgui.BeginPopupContextItem(ctx, "TrackContextMenuVM"..i) then
        DrawTrackContextMenuOptions(ctx, track, i, reaper.GetTrackGUID(track), name)
        imgui.EndPopup(ctx)
    end

    if state.tracksSel[i] then
        -- Highlight selected
        local min_x, min_y = imgui.GetItemRectMin(ctx)
        local max_x, max_y = imgui.GetItemRectMax(ctx)
        imgui.DrawList_AddRect(imgui.GetWindowDrawList(ctx), min_x, min_y, max_x, max_y, 0xFFFFFFFF, 0, 0, 2)
    end
    
    -- Group Color Indicator (Corner Triangle)
    if grp > 0 then
        local min_x, min_y = imgui.GetItemRectMin(ctx)
        local grp_col = state.group_colors[grp]
        local dl = imgui.GetWindowDrawList(ctx)
        imgui.DrawList_AddTriangleFilled(dl, min_x, min_y, min_x + 10, min_y, min_x, min_y + 10, grp_col)
    end
    
    imgui.PopStyleColor(ctx)
    
    -- Controls
    -- Mute/Solo/Rec Row
    local btn_sz = (width - 6) / 3
    if state.tracksMut[i]==1 then imgui.PushStyleColor(ctx,imgui.Col_Button,PackColor(1,0,0,0.5)) end; if imgui.Button(ctx,"M##vm"..i,btn_sz,18) then reaper.SetMediaTrackInfo_Value(track,"B_MUTE",1-state.tracksMut[i]) end; if state.tracksMut[i]==1 then imgui.PopStyleColor(ctx) end; imgui.SameLine(ctx,0,3)
    if state.tracksSol[i]>0 then imgui.PushStyleColor(ctx,imgui.Col_Button,PackColor(1,1,0,0.5)) end; if imgui.Button(ctx,"S##vs"..i,btn_sz,18) then reaper.SetMediaTrackInfo_Value(track,"I_SOLO",state.tracksSol[i]>0 and 0 or 1) end; if state.tracksSol[i]>0 then imgui.PopStyleColor(ctx) end; imgui.SameLine(ctx,0,3)
    if state.tracksArmed[i] then imgui.PushStyleColor(ctx,imgui.Col_Button,PackColor(1,0,0,0.8)) end; if imgui.Button(ctx,"R##vr"..i,btn_sz,18) then reaper.SetMediaTrackInfo_Value(track,"I_RECARM",state.tracksArmed[i] and 0 or 1) end; if state.tracksArmed[i] then imgui.PopStyleColor(ctx) end
    
    -- Pan
    imgui.PushItemWidth(ctx, width)
    local pan_val = math.floor(state.tracksPan[i]*100+0.5)
    local pan_changed, new_pan = imgui.SliderInt(ctx, "##vpan"..i, pan_val, -100, 100, "Pan: %d")
    if pan_changed then
        local new_pan_norm = new_pan/100
        local old_pan = state.tracksPan[i]
        local delta = new_pan_norm - old_pan
        
        SyncGroupPan(track, delta, state.tracksSel[i])
        state.tracksPan[i] = new_pan_norm -- Drift Fix
        
        if state.tracksSel[i] then
            for j=1,#state.tracks do
                if state.tracksSel[j] then
                    local t = state.tracks[j]
                    local p = reaper.GetMediaTrackInfo_Value(t,"D_PAN") + delta
                    local p_clamped = math.max(-1,math.min(1,p))
                    reaper.SetMediaTrackInfo_Value(t,"D_PAN",p_clamped)
                    if state.tracks[j] then state.tracksPan[j] = p_clamped end
                end
            end
        else
            reaper.SetMediaTrackInfo_Value(track, "D_PAN", new_pan_norm)
        end
    end
    if imgui.IsItemHovered(ctx) and imgui.IsMouseDoubleClicked(ctx,0) then
        local old_pan = state.tracksPan[i]
        local delta = 0 - old_pan
        SyncGroupPan(track, delta, state.tracksSel[i])
        
        if state.tracksSel[i] then
             for j=1,#state.tracks do if state.tracksSel[j] then reaper.SetMediaTrackInfo_Value(state.tracks[j],"D_PAN",0) end end
        else
             reaper.SetMediaTrackInfo_Value(track, "D_PAN", 0)
        end
    end
    imgui.PopItemWidth(ctx)
    
    -- Fader & Meter Area
    local used_h = 75 
    local fader_h = strip_height - used_h - 60 
    
    if fader_h > 300 then fader_h = 300 end
    if fader_h < 50 then fader_h = 50 end
    
    -- FIXED WIDTHS (Applied from User's preference)
    local fader_w = 35 -- User set 35
    local meter_w = 35 -- User set 35
    local spacing = 4
    local total_group_w = fader_w + meter_w + spacing
    
    -- Center
    local start_x = imgui.GetCursorPosX(ctx)
    local side_padding = (width - total_group_w) / 2
    if side_padding > 0 then 
        start_x = start_x + side_padding
        imgui.SetCursorPosX(ctx, start_x) 
    end
    
    -- 1. FADER
    local vol = state.tracksVol[i]
    local db = GainToDB(vol)
    local slider_val = (db < -60) and -60 or db
    if slider_val > 12 then slider_val = 12 end
    
    local f_changed, f_val = imgui.VSliderDouble(ctx, "##vvol"..i, fader_w, fader_h, slider_val, -60, 12, "")
    if f_changed then
        local new_gain = DBToGain(f_val)
        local old_gain = state.tracksVol[i]
        local ratio = (old_gain > 0.0000001) and (new_gain / old_gain) or 1.0
        SyncGroupVolume(track, ratio, state.tracksSel[i])
        state.tracksVol[i] = new_gain
        if state.tracksSel[i] then
            for j=1,#state.tracks do
                if state.tracksSel[j] then
                     local t = state.tracks[j]
                     local current_gain = reaper.GetMediaTrackInfo_Value(t, "D_VOL")
                     reaper.SetMediaTrackInfo_Value(t, "D_VOL", current_gain * ratio)
                     if state.tracks[j] then state.tracksVol[j] = current_gain * ratio end
                end
            end
        else
            reaper.SetMediaTrackInfo_Value(track, "D_VOL", new_gain)
        end
    end
    if imgui.IsItemHovered(ctx) and imgui.IsMouseDoubleClicked(ctx,0) then
         SyncGroupVolume(track, (state.tracksVol[i] > 0.0000001) and (1.0 / state.tracksVol[i]) or 1.0, state.tracksSel[i])
         if state.tracksSel[i] then
             for j=1,#state.tracks do if state.tracksSel[j] then reaper.SetMediaTrackInfo_Value(state.tracks[j],"D_VOL",1.0) end end
         else
             reaper.SetMediaTrackInfo_Value(track, "D_VOL", 1.0)
         end
    end
    
    imgui.SameLine(ctx, 0, spacing)
    
    -- 2. STEREO METER (Matching Channel Strip Style)
    -- Reserve space
    imgui.InvisibleButton(ctx, "##vmeter"..i, meter_w, fader_h)
    

    if imgui.IsItemHovered(ctx) then
        -- Shift + Click
        if imgui.IsMouseClicked(ctx, 0) and (imgui.IsKeyDown(ctx, imgui.Mod_Shift) or imgui.IsKeyDown(ctx, imgui.Mod_Ctrl)) then
            ResetAllPeaks()
        -- Double Click
        elseif imgui.IsMouseDoubleClicked(ctx, 0) then
            state.tracksPeakHoldL[i] = 0
            state.tracksPeakHoldR[i] = 0
        end
        ShowTooltip("Shift+Click: Reset ALL Peaks\nDouble-Click Left: Reset Peak Hold")
    end
    
    local m_min_x, m_min_y = imgui.GetItemRectMin(ctx)
    local m_max_x, m_max_y = imgui.GetItemRectMax(ctx)
    
    -- Helper for Gradient Pulse
    local function GetPulse(val_gain)
        local db = GainToDB(val_gain)
        local min_db, max_db = -60, 0
        if db < min_db then return 0 end
        if db > max_db then return 1 end
        return (db - min_db) / (max_db - min_db)
    end
    
    local sub_meter_w = (meter_w - 2) / 2
    if sub_meter_w < 2 then sub_meter_w = 2 end
    
    for ch = 0, 1 do
        local gain = (ch == 0) and (state.tracksPeakL[i] or -150) or (state.tracksPeakR[i] or -150)
        local hold_gain = (ch == 0) and (state.tracksPeakHoldL[i] or 0) or (state.tracksPeakHoldR[i] or 0)
        
        local x = m_min_x + (ch * (sub_meter_w + 2))
        
        -- Background
        imgui.DrawList_AddRectFilled(draw_list, x, m_min_y, x + sub_meter_w, m_max_y, 0xFF111111)
        
        -- Fill
        local fill_pct = GetPulse(gain)
        local fill_h = math.floor(fill_pct * fader_h)
        if fill_h > 0 then
            local y_top = m_max_y - fill_h
            -- Gradient Colors (Green -> Red)
            local col_bot = 0x00FF00FF
            local col_top = 0xFF0000FF
            imgui.DrawList_AddRectFilledMultiColor(draw_list, x, y_top, x + sub_meter_w, m_max_y, col_top, col_top, col_bot, col_bot)
        end
        
        -- Hold Line
        local hold_pct = GetPulse(hold_gain)
        if hold_pct > 0 then
            local y_hold = m_max_y - math.floor(hold_pct * fader_h)
            imgui.DrawList_AddLine(draw_list, x, y_hold, x + sub_meter_w, y_hold, 0xFFFFFFFF, 1)
        end
    end

    -- 3. TEXT VALUES (Centered under respective columns)
    -- Volume under Fader
    local vol_str = (db < -90) and "-inf" or string.format("%.1f", db)
    local v_w = imgui.CalcTextSize(ctx, vol_str)
    
    imgui.SetCursorPosX(ctx, start_x + (fader_w - v_w)/2)
    imgui.Text(ctx, vol_str)
    
    imgui.SameLine(ctx, 0, 0)
    
    -- Peak Readout (Max Peak because stereo text won't fit effectively in 35px)
    local peak_max = math.max(state.tracksPeakHoldL[i] or 0, state.tracksPeakHoldR[i] or 0)
    local peak_db = GainToDB(peak_max)
    
    local p_str
    local p_col = 0xAAAAAAFF
    if peak_db < -90 then
        p_str = "-inf"
        p_col = 0x666666FF
    else
        p_str = string.format("%.1f", peak_db)
        if peak_db > -1 then p_col = 0xFF0000FF 
        elseif peak_db > -6 then p_col = 0xFFFF00FF
        else p_col = 0x00FF00FF end
    end
    
    local p_w = imgui.CalcTextSize(ctx, p_str)
    local meter_start_x = start_x + fader_w + spacing
    imgui.SetCursorPosX(ctx, meter_start_x + (meter_w - p_w)/2)
    imgui.TextColored(ctx, p_col, p_str)
    
    -- FX RACK (Vertical Scrollable Area)
    local track = state.tracks[i]
    local fx_count = reaper.TrackFX_GetCount(track)
    
    imgui.Dummy(ctx, 1, 4) -- Spacer
    
    -- Calculate remaining height for FX list
    -- We are inside VerticalMixerArea (Horizontal Scroll).
    -- GetContentRegionAvail(ctx).y returns remaining height in the Parent Child.
    local avail_w, avail_h = imgui.GetContentRegionAvail(ctx)
    -- Ensure minimal height
    if avail_h < 50 then avail_h = 50 end
    
    -- FX Child Window
    -- Use a unique ID for each track's FX rack
    -- Using 0 flags for Auto Scrollbar. 
    -- If user wants "Always", we could add WindowFlags_AlwaysVerticalScrollbar
    if imgui.BeginChild(ctx, "FXRack"..i, total_group_w, avail_h, 0) then 
        if fx_count > 0 then
            imgui.SetCursorPosX(ctx, 0) 
            imgui.TextDisabled(ctx, "FX")
            
            -- Dynamic Width check (accounts for Scrollbar if visible)
            local fx_content_w = imgui.GetContentRegionAvail(ctx)
            
            for fx_idx = 0, fx_count - 1 do
                local retval, buf = reaper.TrackFX_GetFXName(track, fx_idx, "")
                local is_enabled = reaper.TrackFX_GetEnabled(track, fx_idx)
                local fx_name = buf:gsub("VST: ", ""):gsub("VST3: ", ""):gsub("JS: ", ""):gsub("AU: ", "")
                -- Adjust truncate based on actual width?
                -- If scrollbar is present, width is smaller (e.g. 80 -> 60).
                -- 12 chars might be too much.
                local text_limit = (fx_content_w > 70) and 12 or 9
                if #fx_name > text_limit then fx_name = string.sub(fx_name, 1, text_limit)..".." end
                
                -- Dynamic Button Width
                local btn_col = is_enabled and 0x224422FF or 0x333333FF
                imgui.PushStyleColor(ctx, imgui.Col_Button, btn_col)
                imgui.PushStyleVar(ctx, imgui.StyleVar_ButtonTextAlign, 0.5, 0.5) -- Center Text
                
                if imgui.Button(ctx, fx_name.."##vfx"..i.."_"..fx_idx, fx_content_w, 18) then
                    reaper.TrackFX_Show(track, fx_idx, 3) 
                end
                
                imgui.PopStyleVar(ctx) -- Pop Align
                
                if imgui.IsItemClicked(ctx, 1) then
                    reaper.TrackFX_SetEnabled(track, fx_idx, not is_enabled)
                end
                imgui.PopStyleColor(ctx)
            end
        else
            imgui.TextDisabled(ctx, "-")
        end
        imgui.EndChild(ctx)
    end
    
    imgui.EndGroup(ctx)
end

function DrawVerticalMixerArea(ctx, height)
    -- Horizontal Scroll Child
    if imgui.BeginChild(ctx, "VerticalMixerArea", 0, height, 0, imgui.WindowFlags_HorizontalScrollbar + imgui.WindowFlags_AlwaysHorizontalScrollbar) then
        local hide_children_of_collapsed_folder, collapsed_folder_depth = false, -1
        local is_focus_active = state.focus_folder_guid ~= nil
        local is_in_focus_scope = false
        
        -- Calculate Heights once
        local avail = imgui.GetContentRegionAvail(ctx)
        local strip_h = (type(avail)=='table' and avail.y or avail)
        local strip_w = 80

        for i = 1, #state.tracks do
            -- Filtering Logic (Duplicated from List View for consistency)
            if is_focus_active then
                 if i == state.focus_folder_idx then is_in_focus_scope = true; goto v_continue end
                 if is_in_focus_scope then
                     if state.tracksDepth[i] <= state.focus_folder_depth then is_in_focus_scope = false end
                 end
                 if not is_in_focus_scope then goto v_continue end
            end

            local track = state.tracks[i]
            if reaper.ValidatePtr(track, "MediaTrack*") then
                local current_depth = state.tracksDepth[i]
                if hide_children_of_collapsed_folder and current_depth > collapsed_folder_depth then goto v_continue
                elseif hide_children_of_collapsed_folder and current_depth <= collapsed_folder_depth then hide_children_of_collapsed_folder, collapsed_folder_depth = false, -1 end
                
                local show_track = ApplyAdvancedFilter(i, state.filter_text)
                if show_track and not ApplyViewFilter(i) then show_track = false end
                
                -- Extra Filters matching List View
                local guid_str = reaper.GetTrackGUID(track)
                if show_track and state.edit_mode == "FX PARAMS" and (not state.pinnedParams[guid_str] or #state.pinnedParams[guid_str] == 0) then show_track = false end
                if show_track and not state.tracksVisible[i] then show_track = false end

                if show_track then
                    DrawVerticalStrip(ctx, i, track, strip_w, strip_h)
                    imgui.SameLine(ctx)
                end
                
                if state.isFolder[i] and state.folderCollapsed[i] then hide_children_of_collapsed_folder, collapsed_folder_depth = true, current_depth end
            end
            ::v_continue::
        end
        imgui.EndChild(ctx)
    end
end

function ResetAllTracksVisibility()
    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)
    for i = 1, #state.tracks do
        reaper.SetMediaTrackInfo_Value(state.tracks[i], "B_SHOWINTCP", 1)
        reaper.SetMediaTrackInfo_Value(state.tracks[i], "B_SHOWINMIXER", 1)
    end
    reaper.PreventUIRefresh(-1)
    reaper.Undo_EndBlock("Show All Tracks", -1)
    ForceUIRefresh()
end

function update_quick_controls(track)
    -- Reset state
    state.quickControls = { reaComp_idx = nil, reaComp_params = {} }

    if not track then return end

    local fx_count = reaper.TrackFX_GetCount(track)
    for i = 0, fx_count - 1 do
        local _, fx_name = reaper.TrackFX_GetFXName(track, i, "")
        if fx_name then
            -- Find ReaComp
            if not state.quickControls.reaComp_idx and fx_name:find("ReaComp", 1, true) then
                state.quickControls.reaComp_idx = i
                state.quickControls.reaComp_params.bypass = reaper.TrackFX_GetEnabled(track, i)
                break -- Stop searching once ReaComp is found
            end
        end
    end
end

function update_and_check_tracks()
    local new_track_count = reaper.CountTracks(0)
    local last_track_count = #state.tracks

    if last_track_count ~= new_track_count then
        state.tracks, state.tracksPan, state.tracksVol, state.tracksWidth, state.tracksSel, 
        state.tracksDepth, state.isFolder, state.folderCollapsed, state.tracksVisible, 
        state.tracksPhase, state.tracksArmed, state.tracksHasItems, state.tracksFXCount,
        state.tracksSends, state.tracksReceives, state.tracksPeakL, state.tracksPeakR,
        state.tracksPeakHoldL, state.tracksPeakHoldR =
        {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}
    end
    
    state.last_selected_track_idx = nil
    local last_sel_track = reaper.GetLastTouchedTrack()

    -- First pass: gather basic info for all tracks
    for i = 1, new_track_count do
        local track = reaper.GetTrack(0, i - 1)
        
        state.tracks[i] = track
        state.tracksPan[i] = reaper.GetMediaTrackInfo_Value(track, "D_PAN")
        state.tracksVol[i] = reaper.GetMediaTrackInfo_Value(track, "D_VOL")
        state.tracksWidth[i] = reaper.GetMediaTrackInfo_Value(track, "D_WIDTH")
        state.tracksMut[i] = reaper.GetMediaTrackInfo_Value(track, "B_MUTE")
        state.tracksSol[i] = reaper.GetMediaTrackInfo_Value(track, "I_SOLO")
        state.tracksFX[i] = reaper.TrackFX_GetChainVisible(track)
        state.tracksDepth[i] = reaper.GetTrackDepth(track)
        state.isFolder[i] = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1
        state.tracksVisible[i] = reaper.GetMediaTrackInfo_Value(track, "B_SHOWINTCP") == 1
        state.tracksSel[i] = reaper.IsTrackSelected(track)
        state.tracksPhase[i] = reaper.GetMediaTrackInfo_Value(track, "B_PHASE")
        state.tracksArmed[i] = reaper.GetMediaTrackInfo_Value(track, "I_RECARM") == 1
        state.tracksHasItems[i] = reaper.CountTrackMediaItems(track) > 0
        state.tracksFXCount[i] = reaper.TrackFX_GetCount(track)
        
        state.tracksHasItems[i] = reaper.CountTrackMediaItems(track) > 0
        state.tracksFXCount[i] = reaper.TrackFX_GetCount(track)
        
        -- Gather FX List for Rack
        state.tracksFXList[i] = {}
        for fx = 0, state.tracksFXCount[i] - 1 do
            local _, fx_name = reaper.TrackFX_GetFXName(track, fx, "")
            -- Simplify name: Remove 'VST: ', 'VST3: ', 'JS: ', etc. and keep it short
            -- Logic to clean up name could be complex, for now store raw or simple cleanup
            fx_name = fx_name:gsub("^%w+: ", ""):gsub(" %(.+%)", "")
            
            local is_enabled = reaper.TrackFX_GetEnabled(track, fx)
            local is_offline = reaper.TrackFX_GetOffline(track, fx)
            table.insert(state.tracksFXList[i], { name = fx_name, enabled = is_enabled, offline = is_offline })
        end

        -- Peak Info
        local currentPeakL_gain = reaper.Track_GetPeakInfo(track, 0)
        local currentPeakR_gain = reaper.Track_GetPeakInfo(track, 1)
        
        -- Apply Smoothing / Decay for visual stability
        local decay = 0.85
        local old_peakL = state.tracksPeakL[i] or 0
        local old_peakR = state.tracksPeakR[i] or 0
        
        state.tracksPeakL[i] = math.max(currentPeakL_gain, old_peakL * decay)
        state.tracksPeakR[i] = math.max(currentPeakR_gain, old_peakR * decay)
        
        -- Hard reset if very low to allow reaching silence
        if state.tracksPeakL[i] < 0.0000001 then state.tracksPeakL[i] = 0 end
        if state.tracksPeakR[i] < 0.0000001 then state.tracksPeakR[i] = 0 end
        
        -- Determine visibility (moved out of loop optimization if possible, but fine here)
        -- state.is_visible = {} -- Don't reset this inside the loop! It clears previous iterations!
        -- Wait, state.is_visible is indexed by [i]. But initializing it {} inside loop is wrong if it wipes others?
        -- Actually `state.is_visible` should be initialized ONCE before loop.
        -- In step 1449 I put it here?
        -- Let's check where it was.
        -- Original code (Step 266 in Clean 1448) had `state.is_visible = {}` at line 278 (Init func).
        -- In 1449 I replaced `smoothed_meters = ...` with `state.is_visible = {}`.
        -- If I put `state.is_visible = {}` inside the track loop, it resets every track!
        -- That explains why filtering might be broken or flickering?
        -- I should REMOVE `state.is_visible = {}` from here. It is already checked in main loop or initialized elsewhere?
        -- I'll check Init section later. For now, remove it from here.
    
    -- Initialize Peak Hold values if they don't exist
        state.tracksPeakHoldL[i] = state.tracksPeakHoldL[i] or 0
        state.tracksPeakHoldR[i] = state.tracksPeakHoldR[i] or 0

        -- Update peak hold only if current peak is higher
        if currentPeakL_gain > state.tracksPeakHoldL[i] then
            state.tracksPeakHoldL[i] = currentPeakL_gain
        end
        
        if currentPeakR_gain > state.tracksPeakHoldR[i] then
            state.tracksPeakHoldR[i] = currentPeakR_gain
        end
        
        -- Note: User requested Infinite Hold.
        -- Values will only reset if manually cleared (logic to be added if needed) or on script restart.
        -- To reset: we need a UI trigger. For now, this satisfies "Never jump down".

        state.tracksSends[i] = {}
        state.tracksReceives[i] = {}
        if state.folderCollapsed[i] == nil then state.folderCollapsed[i] = false end

        if last_sel_track and track == last_sel_track then
            state.last_selected_track_idx = i
        end
    end

    -- Update quick controls for the selected track
    if state.last_selected_track_idx then
        update_quick_controls(state.tracks[state.last_selected_track_idx])
    else
        update_quick_controls(nil)
    end


    -- Second pass: build both sends and receives tables
    for i = 1, new_track_count do
        local src_track = state.tracks[i]
        local _, src_name = reaper.GetTrackName(src_track)
        
        local send_count = reaper.GetTrackNumSends(src_track, 0)
        for j = 0, send_count - 1 do
            local dest_track_ptr = reaper.GetTrackSendInfo_Value(src_track, 0, j, "P_DESTTRACK")
            if dest_track_ptr and reaper.ValidatePtr(dest_track_ptr, "MediaTrack*") then
                local send_vol = reaper.GetTrackSendInfo_Value(src_track, 0, j, "D_VOL")
                local send_pan = reaper.GetTrackSendInfo_Value(src_track, 0, j, "D_PAN")
                local send_mute = reaper.GetTrackSendInfo_Value(src_track, 0, j, "B_MUTE")

                local _, dest_name = reaper.GetTrackName(dest_track_ptr)
                table.insert(state.tracksSends[i], { vol = send_vol, pan = send_pan, mute = send_mute, dest_track_name = dest_name })

                for k = 1, new_track_count do
                    if state.tracks[k] == dest_track_ptr then
                        table.insert(state.tracksReceives[k], {
                            src_track = src_track, src_track_name = src_name, send_idx = j,
                            vol = send_vol, pan = send_pan, mute = send_mute
                        })
                        break
                    end
                end
            end
        end
    end
end

function save_preset(preset_num)
    local preset_table = state["preset" .. preset_num]
    if not preset_table then return end

    preset_table.track, preset_table.pan, preset_table.vol,
    preset_table.mute, preset_table.solo = {}, {}, {}, {}, {}
    
    for i = 1, #state.tracks do
        preset_table.track[i] = state.tracks[i]
        preset_table.pan[i] = state.tracksPan[i]
        preset_table.vol[i] = state.tracksVol[i]
        preset_table.mute[i] = state.tracksMut[i]
        preset_table.solo[i] = state.tracksSol[i]
    end
    reaper.ShowMessageBox("Preset " .. preset_num .. " saved.", "Notification", 0)
end

function load_preset(preset_num)
    local preset_table = state["preset" .. preset_num]
    if not preset_table or #preset_table.track == 0 then
        reaper.ShowMessageBox("Preset " .. preset_num .. " is empty.", "Notification", 0)
        return
    end

    for i = 1, #preset_table.track do
        local track = state.tracks[i]
        if track and reaper.ValidatePtr(track, "MediaTrack*") then
            reaper.SetMediaTrackInfo_Value(track, "D_VOL", preset_table.vol[i])
            reaper.SetMediaTrackInfo_Value(track, "D_PAN", preset_table.pan[i])
            reaper.SetMediaTrackInfo_Value(track, "B_MUTE", preset_table.mute[i])
            reaper.SetMediaTrackInfo_Value(track, "I_SOLO", preset_table.solo[i])
        end
    end
    reaper.ShowMessageBox("Preset " .. preset_num .. " loaded.", "Notification", 0)
end

function CycleEditMode()
    if state.edit_mode == "PAN" then state.edit_mode = "VOL"
    elseif state.edit_mode == "VOL" then state.edit_mode = "WIDTH"
    elseif state.edit_mode == "WIDTH" then state.edit_mode = "FX RACK"
    elseif state.edit_mode == "FX RACK" then state.edit_mode = "SENDS"
    elseif state.edit_mode == "SENDS" then state.edit_mode = "RECEIVES"
    elseif state.edit_mode == "RECEIVES" then state.edit_mode = "FX PARAMS"
    elseif state.edit_mode == "FX PARAMS" then state.edit_mode = "CHAN STRIP"
    else state.edit_mode = "PAN" end
    
    if state.sync_view then SyncTrackVisibility() end
end

-- Recursively draws the custom menu
function DrawRecursiveMenu(menu_table)
    for _, item in ipairs(menu_table) do
        if item.type == "item" then
            if imgui.MenuItem(ctx, item.name) then
                local num_cmd = tonumber(item.commandId)
                if num_cmd then
                    reaper.Main_OnCommand(num_cmd, 0)
                else
                    reaper.Main_OnCommand(reaper.NamedCommandLookup(item.commandId), 0)
                end
            end
        elseif item.type == "menu" then
            if imgui.BeginMenu(ctx, item.name) then
                DrawRecursiveMenu(item.items)
                imgui.EndMenu(ctx)
            end
        elseif item.type == "separator" then
            imgui.Separator(ctx)
        end
    end
end

-- --- Custom Menu Drag & Drop Logic ---
function get_parent_table_and_index(path_str)
    local path = {}
    for part in string.gmatch(path_str, "[^%.]+") do table.insert(path, tonumber(part)) end
    if #path == 0 then return nil, nil end

    local parent = { items = state.customMenu } -- Dummy parent for root
    local current_table = state.customMenu

    for i = 1, #path - 1 do
        local idx = path[i]
        local item = current_table[idx]
        if item and item.type == 'menu' and item.items then
            parent = item
            current_table = item.items
        else
            return nil, nil -- Invalid path
        end
    end
    return parent.items, path[#path]
end

function execute_menu_move(source_path, target_path, drop_type)
    -- 1. Remove source item
    local source_parent, source_idx = get_parent_table_and_index(source_path)
    if not source_parent then return end
    local item_to_move = table.remove(source_parent, source_idx)
    if not item_to_move then return end

    -- 2. Find target location and insert
    if drop_type == 'into' then
        local target_parent_table, target_idx = get_parent_table_and_index(target_path)
        -- Ensure we are not dropping a parent into its own child
        if string.find(target_path, source_path .. ".", 1, true) then
            table.insert(source_parent, source_idx, item_to_move) -- Put it back, invalid move
            return
        end
        if target_parent_table and target_parent_table[target_idx] and target_parent_table[target_idx].type == 'menu' then
            local target_item = target_parent_table[target_idx]
            table.insert(target_item.items, item_to_move)
        else
            table.insert(source_parent, source_idx, item_to_move) -- Put it back if target invalid
        end
    else -- 'before'
        local target_parent, target_idx = get_parent_table_and_index(target_path)
        if not target_parent then
             table.insert(source_parent, source_idx, item_to_move) -- Put it back
             return
        end
        -- Adjust index if moving within the same list
        if source_parent == target_parent and source_idx < target_idx then
            target_idx = target_idx - 1
        end
        table.insert(target_parent, target_idx, item_to_move)
    end
    save_custom_menu()
end

function execute_menu_delete(path_to_delete)
    local parent_table, idx = get_parent_table_and_index(path_to_delete)
    if parent_table and idx then
        table.remove(parent_table, idx)
        save_custom_menu()
    end
end

function execute_menu_rename(path_to_rename, new_name)
    local parent_table, idx = get_parent_table_and_index(path_to_rename)
    if parent_table and idx and parent_table[idx] and new_name ~= "" then
        parent_table[idx].name = new_name
        save_custom_menu()
    end
end

-- Recursively draws the menu configuration tree with Drag & Drop
function DrawMenuConfiguration(menu_table, path_prefix)
    for i, item in ipairs(menu_table) do
        local current_path = path_prefix .. i
        local id_str = tostring(item) -- Unique ID for this item

        -- Drop Target for placing items *BEFORE* the current one
        imgui.InvisibleButton(ctx, "drop_target_before##" .. current_path, -1, 4)
        if imgui.BeginDragDropTarget(ctx) then
            local success, payload_str = imgui.AcceptDragDropPayload(ctx, "CUSTOM_MENU_ITEM")
            if success and payload_str ~= current_path then
                state.dnd_source_path = payload_str
                state.dnd_target_path = current_path
                state.dnd_drop_type = 'before'
            end
            imgui.EndDragDropTarget(ctx)
        end

        -- Main Item Display and Drag/Drop Source/Target
        local node_open = false
        local item_label
        if item.type == "menu" then item_label = "📁 " .. item.name .. " (Sub-menu)"
        elseif item.type == "item" then item_label = "📄 " .. item.name .. " (Action)"
        elseif item.type == "separator" then item_label = "--- Separator ---" end

        if item.type == "menu" then
            node_open = imgui.TreeNode(ctx, item_label .. "##" .. id_str)
        else
            imgui.Selectable(ctx, item_label .. "##" .. id_str, false)
        end

        -- DRAG SOURCE (applies to the last item drawn)
        if imgui.BeginDragDropSource(ctx) then
            imgui.SetDragDropPayload(ctx, "CUSTOM_MENU_ITEM", current_path)
            imgui.Text(ctx, "Moving: " .. item.name)
            imgui.EndDragDropSource(ctx)
        end

        -- DROP TARGET (for dropping *INTO* a sub-menu)
        if item.type == 'menu' then
            if imgui.BeginDragDropTarget(ctx) then
                local success, payload_str = imgui.AcceptDragDropPayload(ctx, "CUSTOM_MENU_ITEM")
                if success and payload_str ~= current_path then
                    state.dnd_source_path = payload_str
                    state.dnd_target_path = current_path
                    state.dnd_drop_type = 'into'
                end
                imgui.EndDragDropTarget(ctx)
            end
        end

        -- Context/Selection logic
        if imgui.IsItemClicked(ctx, 0) and item.type == "menu" then
            state.menu_config_target_table = item.items
        end

        -- Action buttons (Rename, Delete)
        imgui.SameLine(ctx)
        if item.type ~= "separator" then
            if imgui.SmallButton(ctx, "Rename##" .. id_str) then
                state.rename_item_path = current_path
                state.rename_item_new_name = item.name
                state.open_rename_popup = true
            end
            imgui.SameLine(ctx)
        end
        
        if imgui.SmallButton(ctx, "Delete##" .. id_str) then
            state.item_to_delete_path = current_path
        end

        if node_open then
            DrawMenuConfiguration(item.items, current_path .. ".")
            imgui.TreePop(ctx)
        end
    end
    
    -- Drop Target for placing item at the END of the current list
    imgui.InvisibleButton(ctx, "drop_target_end##" .. path_prefix, -1, 4)
    if imgui.BeginDragDropTarget(ctx) then
        local success, payload_str = imgui.AcceptDragDropPayload(ctx, "CUSTOM_MENU_ITEM")
        if success then
            local target_path = path_prefix .. (#menu_table + 1)
            state.dnd_source_path = payload_str
            state.dnd_target_path = target_path
            state.dnd_drop_type = 'before'
        end
        imgui.EndDragDropTarget(ctx)
    end
end

-- --- MAIN GUI LOOP ---
function loop()
    local current_time = reaper.time_precise()
    if current_time - state.last_update_time > config.refresh_interval then
        update_and_check_tracks()
        state.last_update_time = current_time
    end

    -- Apply Theme (Before Begin to affect Window TitleBar/Frame)
    SetTheme(state.current_theme)

    local visible, is_open_ret = imgui.Begin(ctx, config.win_title, state.is_open, imgui.WindowFlags_NoScrollbar)
    state.is_open = is_open_ret
    
    if visible then
        -- Toolbar (Theme already applied)
        local content_avail = imgui.GetContentRegionAvail(ctx)
        local available_w = type(content_avail) == 'table' and content_avail.x or content_avail
        
        local preset_btn_w, preset_spacing = 25, 2
        local custom_menu_w = 24
        local presets_width = (preset_btn_w * 5) + (preset_spacing * 4)
        local snapshots_w = (25 * 2) + 1 + 2 -- A/B buttons + spacing + padding approx
        -- Reduced widths to fit new buttons
        local toggle_btn_w, view_combo_w, sync_check_w, group_spacing = 100, 120, 80, 10
        local layout_icon_w = 35
        
        -- Added snapshots_w and increased spacing multiplier to 6
        local buttons_total_w = presets_width + snapshots_w + toggle_btn_w + layout_icon_w + view_combo_w + sync_check_w + custom_menu_w + (group_spacing * 7)
        local search_width = available_w - buttons_total_w - 15
        if search_width < 50 then search_width = 50 end
        
        imgui.PushItemWidth(ctx, search_width)
        local filter_changed, new_filter_text = imgui.InputText(ctx, "##Search", state.filter_text, 256)
        if filter_changed then state.filter_text = new_filter_text end
        if state.filter_text == "" then
            local min_x, min_y = imgui.GetItemRectMin(ctx); local max_x, max_y = imgui.GetItemRectMax(ctx)
            local draw_list = imgui.GetWindowDrawList(ctx)
            imgui.DrawList_AddText(draw_list, min_x + 5, min_y + ((max_y - min_y) - 16) / 2, PackColor(0.5, 0.5, 0.5, 1.0), "Search...")
        end
        ShowTooltip("Search tracks by name and advanced query...")
        imgui.PopItemWidth(ctx)
        
        imgui.SameLine(ctx, 0, group_spacing)
        -- Shortened label to save space
        if imgui.Button(ctx, state.edit_mode, toggle_btn_w, 25) then
            CycleEditMode() -- Left-click action
        end
        
        -- Attach a context menu to the button above
        if imgui.BeginPopupContextItem(ctx, "EditModeContextPopup") then
            for _, mode in ipairs(state.edit_modes) do
                if imgui.MenuItem(ctx, mode, "", state.edit_mode == mode) then
                    state.edit_mode = mode
                    if state.sync_view then SyncTrackVisibility() end
                end
            end
            imgui.EndPopup(ctx)
        end
        ShowTooltip("Left-click to cycle through modes.\nRight-click for direct selection.")
        
        imgui.SameLine(ctx, 0, group_spacing)
        
        -- MIXER LAYOUT TOGGLE
        local icon_layout = state.mixer_layout == "LIST" and "📜" or "🎚️"
        if imgui.Button(ctx, icon_layout .. "##layout_toggle", 30, 25) then
            state.mixer_layout = state.mixer_layout == "LIST" and "STRIP" or "LIST"
        end
        if imgui.IsItemHovered(ctx) then ShowTooltip("Toggle View: List / Vertical Mixer") end
        
        imgui.SameLine(ctx, 0, group_spacing)
        -- MATRIX TOGGLE
        local icon_matrix = state.show_matrix_view and "⚪" or "🕸️" 
        local btn_col = state.show_matrix_view and PackColor(0.2, 0.6, 1, 1) or imgui.GetStyleColor(ctx, imgui.Col_Button)
        imgui.PushStyleColor(ctx, imgui.Col_Button, btn_col)
        if imgui.Button(ctx, icon_matrix .. "##matrix_toggle", 30, 25) then
             state.show_matrix_view = not state.show_matrix_view
        end
        imgui.PopStyleColor(ctx)
        if imgui.IsItemHovered(ctx) then ShowTooltip("Toggle Send Matrix View") end

        imgui.SameLine(ctx, 0, group_spacing)
        imgui.PushItemWidth(ctx, view_combo_w)
        local combo_changed, new_view_mode = imgui.Combo(ctx, "##ViewMode", state.view_mode - 1, state.view_mode_names_str)
        if combo_changed then 
            state.view_mode = new_view_mode + 1
            if state.sync_view then SyncTrackVisibility() end
        end
        ShowTooltip("Filter the track list by criteria.")
        imgui.PopItemWidth(ctx)

        imgui.SameLine(ctx, 0, group_spacing)
        local sync_changed, new_sync_state = imgui.Checkbox(ctx, "Sync View", state.sync_view)
        if sync_changed then
            state.sync_view = new_sync_state
            if state.sync_view then
                SyncTrackVisibility() -- Sync immediately when turned on
            else
                ResetAllTracksVisibility() -- Reset when turned off
            end
        end
        ShowTooltip("When checked, hides/shows tracks in REAPER\nto match the current filter applied in the script.")
        
        imgui.SameLine(ctx, 0, group_spacing)
        imgui.SameLine(ctx, 0, group_spacing)
        
        -- PRESETS (Grouped)
        imgui.BeginGroup(ctx)
            imgui.PushStyleVar(ctx, imgui.StyleVar_ItemSpacing, 1, 0)
            imgui.PushStyleVar(ctx, imgui.StyleVar_FrameRounding, 0)
            for i=1, 5 do
                local btn_label = tostring(i)
                -- Apply rounded corners to first and last button only
                if i == 1 then imgui.PushStyleVar(ctx, imgui.StyleVar_FrameRounding, 4)
                elseif i == 5 then imgui.PushStyleVar(ctx, imgui.StyleVar_FrameRounding, 4) end
                
                -- Highlight if likely active (logic omitted for simplicity, just style)
                if imgui.Button(ctx, btn_label.."##preset"..i, 20, 25) then load_preset(i) end
                if imgui.IsItemClicked(ctx, 1) then save_preset(i) end
                ShowTooltip("Preset "..i.."\nL-Click: Load\nR-Click: Save")
                
                if i == 1 or i == 5 then imgui.PopStyleVar(ctx) end -- Pop individual rounding
                if i < 5 then imgui.SameLine(ctx) end
            end
            imgui.PopStyleVar(ctx, 2)
        imgui.EndGroup(ctx)

        imgui.SameLine(ctx, 0, group_spacing)
        


        imgui.SameLine(ctx, 0, group_spacing)
        
        imgui.SameLine(ctx, 0, group_spacing)
        
        -- MIX SNAPSHOTS (A/B)
        imgui.BeginGroup(ctx)
            imgui.PushStyleVar(ctx, imgui.StyleVar_ItemSpacing, 1, 0)
            imgui.PushStyleVar(ctx, imgui.StyleVar_FrameRounding, 4) -- Rounded pills
            
            -- Slot A
            local is_A_active = state.mix_snapshots.current_active == "A"
            if is_A_active then imgui.PushStyleColor(ctx, imgui.Col_Button, 0x4A90E2FF) end -- Blue for active
            if imgui.Button(ctx, "A##snapA", 25, 25) then RecallSnapshot("A") end
            if is_A_active then imgui.PopStyleColor(ctx) end
            if imgui.IsItemClicked(ctx, 1) then StoreSnapshot("A"); ShowTooltip("Stored Snapshot A") end
            ShowTooltip("Snapshot A\nL-Click: Recall\nR-Click: Store")
            
            imgui.SameLine(ctx)
            
            -- Slot B
            local is_B_active = state.mix_snapshots.current_active == "B"
            if is_B_active then imgui.PushStyleColor(ctx, imgui.Col_Button, 0x4A90E2FF) end -- Blue for active
            if imgui.Button(ctx, "B##snapB", 25, 25) then RecallSnapshot("B") end
            if is_B_active then imgui.PopStyleColor(ctx) end
            if imgui.IsItemClicked(ctx, 1) then StoreSnapshot("B"); ShowTooltip("Stored Snapshot B") end
            ShowTooltip("Snapshot B\nL-Click: Recall\nR-Click: Store")

            imgui.PopStyleVar(ctx, 2)
        imgui.EndGroup(ctx)
        
        imgui.SameLine(ctx, 0, group_spacing)
        
        -- Default to standard button but Transparent as requested to hide alignment offsets
        imgui.PushStyleColor(ctx, imgui.Col_Button, 0) -- Transparent background
        -- Still try to center reasonable well
        imgui.PushStyleVar(ctx, imgui.StyleVar_FramePadding, 0, 0)
        imgui.PushStyleVar(ctx, imgui.StyleVar_ButtonTextAlign, 0.5, 0.5) 

        if imgui.Button(ctx, " ⚙️##customMenu", 21, 21) then
            imgui.OpenPopup(ctx, "CustomMenuPopup")
        end
        
        imgui.PopStyleVar(ctx, 2)
        imgui.PopStyleColor(ctx)
        
        ShowTooltip("Open the custom menu.")

        if imgui.BeginPopup(ctx, "CustomMenuPopup") then
            if #state.customMenu > 0 then
                DrawRecursiveMenu(state.customMenu)
                imgui.Separator(ctx)
            else
                imgui.TextDisabled(ctx, "(Menu is empty)")
            end
            if imgui.MenuItem(ctx, "Configure Menu...") then
                state.open_custom_menu_config = true
                state.menu_config_target_table = state.customMenu -- Default to root
            end
            
            imgui.Separator(ctx)
            if imgui.MenuItem(ctx, "🎨 Run Auto-Color & Icons") then
                RunAutoColor()
            end
            
            if imgui.BeginMenu(ctx, "⚖️ Smart Gain Staging") then
                imgui.TextDisabled(ctx, "(Requires Playback First)")
                imgui.Separator(ctx)
                if imgui.MenuItem(ctx, "Target -12dB (Safe)") then RunGainStaging(-12) end
                if imgui.MenuItem(ctx, "Target -18dB (Analog)") then RunGainStaging(-18) end
                if imgui.MenuItem(ctx, "Target -6dB (Hot)") then RunGainStaging(-6) end
                imgui.EndMenu(ctx)
            end
            
            imgui.Separator(ctx)
            if imgui.BeginMenu(ctx, "Theme") then
                 for name, _ in pairs(themes) do
                     if imgui.MenuItem(ctx, name, "", state.current_theme == name) then
                         state.current_theme = name
                         reaper.SetExtState("Hosi.MiniTrackMixer", "Theme", name, true)
                     end
                 end
                 imgui.EndMenu(ctx)
            end
            
            imgui.Separator(ctx)
            if imgui.MenuItem(ctx, "☕ Donate (PayPal)") then
                reaper.CF_ShellExecute("https://paypal.me/nkstudio")
            end
            imgui.EndPopup(ctx)
        end

        imgui.Separator(ctx)

        imgui.Separator(ctx)
        
        local status_bar_h = 30
        local main_area_h = -status_bar_h
        
        -- Main Area Content
        if state.edit_mode == "SENDS" then
            -- SENDS MODE LAYOUT
            if imgui.BeginTable(ctx, 'SendsLayout', 2, imgui.TableFlags_BordersInnerV + imgui.TableFlags_Resizable) then
                imgui.TableSetupColumn(ctx, "Tracks", imgui.TableColumnFlags_WidthFixed, 280)
                imgui.TableSetupColumn(ctx, "Send Controls", imgui.TableColumnFlags_WidthStretch)

                imgui.TableNextColumn(ctx)
                if imgui.BeginChild(ctx, "TrackListChildSends", 0, main_area_h) then
                    for i = 1, #state.tracks do
                        if reaper.ValidatePtr(state.tracks[i], "MediaTrack*") then
                            local show_in_list = true
                            if state.sends_list_filter == "HAS_SENDS" and #state.tracksSends[i] == 0 then
                                show_in_list = false
                            end

                            if show_in_list and ApplyViewFilter(i) and ApplyAdvancedFilter(i, state.filter_text) then
                                local _, name = reaper.GetTrackName(state.tracks[i])
                                local r, g, b = reaper.ColorFromNative(reaper.GetTrackColor(state.tracks[i]))
                                imgui.PushStyleColor(ctx, imgui.Col_Header, PackColor(r/255, g/255, b/255, 0.3)); imgui.PushStyleColor(ctx, imgui.Col_HeaderHovered, PackColor(r/255, g/255, b/255, 0.5)); imgui.PushStyleColor(ctx, imgui.Col_HeaderActive, PackColor(r/255, g/255, b/255, 0.7))
                                
                                local has_sends = #state.tracksSends[i] > 0
                                if has_sends then imgui.PushStyleColor(ctx, imgui.Col_Text, PackColor(1.0, 0.85, 0.4, 1.0)) end -- Gold/Yellow for tracks with sends
                                
                                -- Table Row for Sends List (Left Side)
                                -- Note: This is inside 'TrackListChildSends' which is likely just a Child window, not the main table. 
                                -- Ah, line 1083 is BeginTable 'send_track_line'..i which is nested.
                                -- To stripe the *list*, we should draw a rect behind the text, or use a table for the list itself if it isn't one.
                                -- The code structure: Child -> Loop -> BeginTable(per item). 
                                -- Can't easy stripe nested tables. 
                                -- Better strategy: Draw a Child Window BG rect manually or just accept loose layout?
                                -- Let's stick to simple text for now or simple separators.
                                
                                if i % 2 == 0 then
                                   -- Draw a subtle background for this "Item" block
                                   local cursor_p_x, cursor_p_y = imgui.GetCursorScreenPos(ctx)
                                   local avail_w = imgui.GetContentRegionAvail(ctx)
                                   -- We need to know height. approximate.
                                   imgui.DrawList_AddRectFilled(imgui.GetWindowDrawList(ctx), cursor_p_x, cursor_p_y, cursor_p_x + avail_w, cursor_p_y + 20, 0xFFFFFF07)
                                end

                                if imgui.BeginTable(ctx, 'send_track_line'..i, 2, 0) then
                                    imgui.TableSetupColumn(ctx, 'drag', imgui.TableColumnFlags_WidthFixed, 20)
                                    imgui.TableSetupColumn(ctx, 'name', imgui.TableColumnFlags_WidthStretch)
                                    
                                    imgui.TableNextColumn(ctx) -- Drag handle column
                                    imgui.Button(ctx, "::##drag_sends"..i)
                                    ShowTooltip("Drag to another track to create a send.")
                                    if imgui.BeginDragDropSource(ctx) then
                                        imgui.SetDragDropPayload(ctx, "TRACK_ITEM_SEND", tostring(i))
                                        imgui.Text(ctx, "Send from: " .. name)
                                        imgui.EndDragDropSource(ctx)
                                    end
                                    
                                    imgui.TableNextColumn(ctx) -- Name column
                                    if imgui.Selectable(ctx, string.format("%02d: %s (%d sends)", i, name, #state.tracksSends[i]), state.sends_view_track_idx == i, imgui.SelectableFlags_SpanAllColumns) then state.sends_view_track_idx = i end
                                    if imgui.BeginDragDropTarget(ctx) then
                                        local success, payload_str = imgui.AcceptDragDropPayload(ctx, "TRACK_ITEM_SEND")
                                        if success then
                                            local src_idx = tonumber(payload_str)
                                            if src_idx and i and src_idx ~= i then
                                                local src_track = state.tracks[src_idx]
                                                local dest_track = state.tracks[i]
                                                if src_track and dest_track then
                                                    reaper.Undo_BeginBlock()
                                                    reaper.CreateTrackSend(src_track, dest_track)
                                                    reaper.Undo_EndBlock("Create Send via Drag & Drop", -1)
                                                end
                                            end
                                        end
                                        imgui.EndDragDropTarget(ctx)
                                    end
                                    imgui.EndTable(ctx)
                                end
                                
                                if has_sends then imgui.PopStyleColor(ctx) end
                                
                                imgui.PopStyleColor(ctx, 3)
                            end
                        end
                    end
                end
                imgui.EndChild(ctx)

                imgui.TableNextColumn(ctx)
                
                -- Filter buttons and track-specific controls
                local content_avail_table = imgui.GetContentRegionAvail(ctx)
                local content_w = type(content_avail_table) == 'table' and content_avail_table.x or content_avail_table
                local btn_w = 90
                
                if state.sends_view_track_idx and state.tracks[state.sends_view_track_idx] then
                    local track_idx, track = state.sends_view_track_idx, state.tracks[state.sends_view_track_idx]
                    local _, name = reaper.GetTrackName(track)
                    imgui.Text(ctx, "Editing Sends for: " .. name)
                    imgui.SameLine(ctx)
                    if imgui.Button(ctx, "Add Send") then state.open_add_send_popup = true end
                    ShowTooltip("Add a new send from this track to another track.")
                    
                    imgui.SameLine(ctx, content_w - (btn_w * 2 + 5))

                else
                    imgui.Text(ctx, "Select a track on the left to manage sends.")
                    imgui.SameLine(ctx, content_w - (btn_w * 2 + 5))
                end

                -- "Has Sends" button
                local has_sends_active = state.sends_list_filter == "HAS_SENDS"
                if has_sends_active then imgui.PushStyleColor(ctx, imgui.Col_Button, PackColor(0.2, 0.6, 0.2, 1.0)) end
                if imgui.Button(ctx, "Has Sends", btn_w, 0) then state.sends_list_filter = "HAS_SENDS" end
                if has_sends_active then imgui.PopStyleColor(ctx) end
                ShowTooltip("Show only tracks that have sends.")

                imgui.SameLine(ctx)

                -- "Show All" button
                local all_active = state.sends_list_filter == "ALL"
                if all_active then imgui.PushStyleColor(ctx, imgui.Col_Button, PackColor(0.2, 0.6, 0.2, 1.0)) end
                if imgui.Button(ctx, "Show All", btn_w, 0) then state.sends_list_filter = "ALL" end
                if all_active then imgui.PopStyleColor(ctx) end
                ShowTooltip("Show all tracks in the list.")
                
                imgui.Separator(ctx)

                if state.sends_view_track_idx and state.tracks[state.sends_view_track_idx] then
                    local track_idx, track = state.sends_view_track_idx, state.tracks[state.sends_view_track_idx]
                    if imgui.BeginChild(ctx, "SendControlsChild", 0, -2) then
                        for j, send_info in ipairs(state.tracksSends[track_idx]) do
                            local send_api_idx = j - 1
                            imgui.Text(ctx, "Send " .. j .. ": -> " .. send_info.dest_track_name)
                            
                            if imgui.Button(ctx, "X##del_send"..j..track_idx, 20, 20) then
                                reaper.Undo_BeginBlock()
                                reaper.RemoveTrackSend(track, 0, send_api_idx)
                                reaper.Undo_EndBlock("Delete Send", -1)
                                goto continue_send_loop -- Skip the rest of the loop for this deleted item
                            end
                            ShowTooltip("Delete this send.")
                            imgui.SameLine(ctx)
                            
                            if send_info.mute == 1 then imgui.PushStyleColor(ctx, imgui.Col_Button, PackColor(1,0,0,0.5)) end
                            if imgui.Button(ctx, "Mute##send"..j..track_idx, 50, 0) then reaper.SetTrackSendInfo_Value(track, 0, send_api_idx, "B_MUTE", 1-send_info.mute); reaper.Undo_BeginBlock(); reaper.Undo_EndBlock("Toggle Send Mute", -1) end
                            if send_info.mute == 1 then imgui.PopStyleColor(ctx) end
                            ShowTooltip("Mute/Unmute this send.")
                            imgui.SameLine(ctx, 0, 10); imgui.PushItemWidth(ctx, -125)
                            local db, db_int_val = GainToDB(send_info.vol), math.floor(GainToDB(send_info.vol) + 0.5)
                            local vol_changed, new_db_int = imgui.SliderInt(ctx, "##vol_send"..j..track_idx, db_int_val, -100, 12, "")
                            ShowTooltip(string.format("Volume: %.2f dB\nDouble-click value to type.\nRight-click slider to reset to 0dB.", db))
                            if imgui.IsItemClicked(ctx, 1) then reaper.SetTrackSendInfo_Value(track, 0, send_api_idx, "D_VOL", 1)
                            elseif vol_changed then reaper.SetTrackSendInfo_Value(track, 0, send_api_idx, "D_VOL", DBToGain(new_db_int)); reaper.Undo_BeginBlock(); reaper.Undo_EndBlock("Adjust Send Volume", -1) end
                            imgui.PopItemWidth(ctx); imgui.SameLine(ctx, 0, 5)
                            local db_text = string.format("Vol: %.1f dB", db)
                            imgui.Text(ctx, db_text)
                            if imgui.IsItemHovered(ctx) and imgui.IsMouseDoubleClicked(ctx, 0) then
                                state.value_input_info = { track_idx = track_idx, param_type = 'SEND_VOL', send_idx = send_api_idx, current_value_str = string.format("%.2f dB", db) }
                                state.value_input_text = string.format("%.2f", db)
                                state.open_value_input_popup = true
                            end

                            imgui.PushItemWidth(ctx, -120)
                            local pan_val = math.floor(send_info.pan * 100 + 0.5)
                            local pan_changed, new_pan_int = imgui.SliderInt(ctx, "##pan_send"..j..track_idx, pan_val, -100, 100, "")
                            imgui.SameLine(ctx)
                            local pan_text = string.format("Pan: %d", pan_val)
                            imgui.Text(ctx, pan_text)
                            if imgui.IsItemHovered(ctx) and imgui.IsMouseDoubleClicked(ctx, 0) then
                                state.value_input_info = { track_idx = track_idx, param_type = 'SEND_PAN', send_idx = send_api_idx, current_value_str = pan_text }
                                state.value_input_text = tostring(pan_val)
                                state.open_value_input_popup = true
                            end
                            ShowTooltip("Pan Value\nDouble-click value to type.\nRight-click slider to reset to center.")
                            if imgui.IsItemClicked(ctx, 1) then reaper.SetTrackSendInfo_Value(track, 0, send_api_idx, "D_PAN", 0)
                            elseif pan_changed then reaper.SetTrackSendInfo_Value(track, 0, send_api_idx, "D_PAN", new_pan_int / 100); reaper.Undo_BeginBlock(); reaper.Undo_EndBlock("Adjust Send Pan", -1) end
                            imgui.PopItemWidth(ctx); imgui.Separator(ctx)
                            ::continue_send_loop::
                        end
                    end
                    imgui.EndChild(ctx)
                end
                imgui.EndTable(ctx)
            end
        elseif state.edit_mode == "RECEIVES" then
            -- RECEIVES MODE LAYOUT
            if imgui.BeginTable(ctx, 'ReceivesLayout', 2, imgui.TableFlags_BordersInnerV + imgui.TableFlags_Resizable) then
                imgui.TableSetupColumn(ctx, "Tracks", imgui.TableColumnFlags_WidthFixed, 280)
                imgui.TableSetupColumn(ctx, "Receive Controls", imgui.TableColumnFlags_WidthStretch)
                imgui.TableNextColumn(ctx)
                if imgui.BeginChild(ctx, "TrackListChildReceives", 0, -2) then
                    for i = 1, #state.tracks do
                        if reaper.ValidatePtr(state.tracks[i], "MediaTrack*") and #state.tracksReceives[i] > 0 then
                            if ApplyViewFilter(i) and ApplyAdvancedFilter(i, state.filter_text) then
                                local _, name = reaper.GetTrackName(state.tracks[i])
                                local r, g, b = reaper.ColorFromNative(reaper.GetTrackColor(state.tracks[i]))
                                imgui.PushStyleColor(ctx, imgui.Col_Header, PackColor(r/255, g/255, b/255, 0.3)); imgui.PushStyleColor(ctx, imgui.Col_HeaderHovered, PackColor(r/255, g/255, b/255, 0.5)); imgui.PushStyleColor(ctx, imgui.Col_HeaderActive, PackColor(r/255, g/255, b/255, 0.7))
                                
                                if i % 2 == 0 then
                                   local cursor_p_x, cursor_p_y = imgui.GetCursorScreenPos(ctx)
                                   local avail_w = imgui.GetContentRegionAvail(ctx)
                                   imgui.DrawList_AddRectFilled(imgui.GetWindowDrawList(ctx), cursor_p_x, cursor_p_y, cursor_p_x + avail_w, cursor_p_y + 20, 0xFFFFFF07)
                                end
                                
                                if imgui.BeginTable(ctx, 'receive_track_line'..i, 2, 0) then
                                    imgui.TableSetupColumn(ctx, 'drag', imgui.TableColumnFlags_WidthFixed, 20)
                                    imgui.TableSetupColumn(ctx, 'name', imgui.TableColumnFlags_WidthStretch)

                                    imgui.TableNextColumn(ctx) -- Drag handle column
                                    imgui.Button(ctx, "::##drag_receives"..i)
                                    ShowTooltip("Drag to another track to create a send.")
                                    if imgui.BeginDragDropSource(ctx) then
                                        imgui.SetDragDropPayload(ctx, "TRACK_ITEM_SEND", tostring(i))
                                        imgui.Text(ctx, "Send from: " .. name)
                                        imgui.EndDragDropSource(ctx)
                                    end

                                    imgui.TableNextColumn(ctx) -- Name column
                                    if imgui.Selectable(ctx, string.format("%02d: %s (%d receives)", i, name, #state.tracksReceives[i]), state.receives_view_track_idx == i, imgui.SelectableFlags_SpanAllColumns) then state.receives_view_track_idx = i end
                                    if imgui.BeginDragDropTarget(ctx) then
                                        local success, payload_str = imgui.AcceptDragDropPayload(ctx, "TRACK_ITEM_SEND")
                                        if success then
                                            local src_idx = tonumber(payload_str)
                                            if src_idx and i and src_idx ~= i then
                                                local src_track = state.tracks[src_idx]
                                                local dest_track = state.tracks[i]
                                                if src_track and dest_track then
                                                    reaper.Undo_BeginBlock()
                                                    reaper.CreateTrackSend(src_track, dest_track)
                                                    reaper.Undo_EndBlock("Create Send via Drag & Drop", -1)
                                                end
                                            end
                                        end
                                        imgui.EndDragDropTarget(ctx)
                                    end
                                    imgui.EndTable(ctx)
                                end
                                
                                imgui.PopStyleColor(ctx, 3)
                            end
                        end
                    end
                end
                imgui.EndChild(ctx)
                imgui.TableNextColumn(ctx)
                if state.receives_view_track_idx and state.tracks[state.receives_view_track_idx] then
                    local track_idx, track = state.receives_view_track_idx, state.tracks[state.receives_view_track_idx]
                    local _, name = reaper.GetTrackName(track)
                    imgui.Text(ctx, "Editing Receives for: " .. name); imgui.Separator(ctx)
                    if imgui.BeginChild(ctx, "ReceiveControlsChild", 0, -2) then
                        for j, receive_info in ipairs(state.tracksReceives[track_idx]) do
                            imgui.Text(ctx, "Receive " .. j .. ": <- From " .. receive_info.src_track_name)
                            
                            if imgui.Button(ctx, "X##del_receive"..j..track_idx, 20, 20) then
                                reaper.Undo_BeginBlock()
                                reaper.RemoveTrackSend(receive_info.src_track, 0, receive_info.send_idx)
                                reaper.Undo_EndBlock("Delete Receive", -1)
                                goto continue_receive_loop -- Skip the rest of the loop for this deleted item
                            end
                            ShowTooltip("Delete this receive.")
                            imgui.SameLine(ctx)
                            
                            if receive_info.mute == 1 then imgui.PushStyleColor(ctx, imgui.Col_Button, PackColor(1,0,0,0.5)) end
                            if imgui.Button(ctx, "Mute##receive"..j..track_idx, 50, 0) then reaper.SetTrackSendInfo_Value(receive_info.src_track, 0, receive_info.send_idx, "B_MUTE", 1-receive_info.mute); reaper.Undo_BeginBlock(); reaper.Undo_EndBlock("Toggle Receive Mute", -1) end
                            if receive_info.mute == 1 then imgui.PopStyleColor(ctx) end
                            ShowTooltip("Mute/Unmute this receive.")
                            imgui.SameLine(ctx, 0, 10); imgui.PushItemWidth(ctx, -125)
                            local db, db_int_val = GainToDB(receive_info.vol), math.floor(GainToDB(receive_info.vol) + 0.5)
                            local vol_changed, new_db_int = imgui.SliderInt(ctx, "##vol_receive"..j..track_idx, db_int_val, -100, 12, "")
                            ShowTooltip(string.format("Volume: %.2f dB\nDouble-click value to type.\nRight-click slider to reset to 0dB.", db))
                            if imgui.IsItemClicked(ctx, 1) then reaper.SetTrackSendInfo_Value(receive_info.src_track, 0, receive_info.send_idx, "D_VOL", 1)
                            elseif vol_changed then reaper.SetTrackSendInfo_Value(receive_info.src_track, 0, receive_info.send_idx, "D_VOL", DBToGain(new_db_int)); reaper.Undo_BeginBlock(); reaper.Undo_EndBlock("Adjust Receive Volume", -1) end
                            imgui.PopItemWidth(ctx); imgui.SameLine(ctx, 0, 5)
                            local db_text = string.format("Vol: %.1f dB", db)
                            imgui.Text(ctx, db_text)
                            if imgui.IsItemHovered(ctx) and imgui.IsMouseDoubleClicked(ctx, 0) then
                                state.value_input_info = { track_idx = track_idx, param_type = 'RECEIVE_VOL', receive_info = receive_info, current_value_str = string.format("%.2f dB", db) }
                                state.value_input_text = string.format("%.2f", db)
                                state.open_value_input_popup = true
                            end

                            imgui.PushItemWidth(ctx, -120)
                            local pan_val = math.floor(receive_info.pan * 100 + 0.5)
                            local pan_changed, new_pan_int = imgui.SliderInt(ctx, "##pan_receive"..j..track_idx, pan_val, -100, 100, "")
                            imgui.SameLine(ctx)
                            local pan_text = string.format("Pan: %d", pan_val)
                            imgui.Text(ctx, pan_text)
                            if imgui.IsItemHovered(ctx) and imgui.IsMouseDoubleClicked(ctx, 0) then
                                state.value_input_info = { track_idx = track_idx, param_type = 'RECEIVE_PAN', receive_info = receive_info, current_value_str = pan_text }
                                state.value_input_text = tostring(pan_val)
                                state.open_value_input_popup = true
                            end
                            ShowTooltip("Pan Value\nDouble-click value to type.\nRight-click slider to reset to center.")
                            if imgui.IsItemClicked(ctx, 1) then reaper.SetTrackSendInfo_Value(receive_info.src_track, 0, receive_info.send_idx, "D_PAN", 0)
                            elseif pan_changed then reaper.SetTrackSendInfo_Value(receive_info.src_track, 0, receive_info.send_idx, "D_PAN", new_pan_int / 100); reaper.Undo_BeginBlock(); reaper.Undo_EndBlock("Adjust Receive Pan", -1) end
                            imgui.PopItemWidth(ctx); imgui.Separator(ctx)
                            ::continue_receive_loop::
                        end
                    end
                    imgui.EndChild(ctx)
                else
                    imgui.Text(ctx, "Select a track from the list on the left to manage its receives.")
                end
                imgui.EndTable(ctx)
            end
        elseif state.edit_mode == "CHAN STRIP" then
            local track_idx = state.last_selected_track_idx
            if track_idx and state.tracks[track_idx] then
                local track = state.tracks[track_idx]
                local guid_str = reaper.GetTrackGUID(track)
                local _, name = reaper.GetTrackName(track)
                local r, g, b = reaper.ColorFromNative(reaper.GetTrackColor(track))

                -- Main Layout
                if imgui.BeginTable(ctx, "ChannelStripLayout", 2, 0) then
                    imgui.TableSetupColumn(ctx, "Controls", imgui.TableColumnFlags_WidthStretch)
                    imgui.TableSetupColumn(ctx, "FaderMeter", imgui.TableColumnFlags_WidthFixed, 120)
                    
                    -- Left Column: Controls
                    imgui.TableNextColumn(ctx)
                    local left_col_start_y = imgui.GetCursorPosY(ctx) -- Store Y pos before drawing

                    -- Header and Buttons on one line
                    imgui.PushStyleColor(ctx, imgui.Col_Text, PackColor(r/255, g/255, b/255, 1.0))
                    imgui.Text(ctx, string.format("CHANNEL: %02d: %s", track_idx, name))
                    imgui.PopStyleColor(ctx)
                    
                    local content_avail = imgui.GetContentRegionAvail(ctx)
                    local content_w = type(content_avail) == 'table' and content_avail.x or content_avail

                    local btn_w = 25
                    local btn_h = 25
                    local btn_spacing = 8 -- Fallback value for compatibility
                    local total_btns_w = (btn_w * 4) + (btn_spacing * 3)
                    imgui.SameLine(ctx, content_w - total_btns_w - 5) -- -5 for some padding

                    imgui.BeginGroup(ctx)
                    if state.tracksPhase[track_idx]==1 then imgui.PushStyleColor(ctx,imgui.Col_Button,PackColor(1,0.5,0,0.5)) end; if imgui.Button(ctx,"ø##phase_cs",btn_w,btn_h) then reaper.SetMediaTrackInfo_Value(track,"B_PHASE",1-state.tracksPhase[track_idx]) end; if state.tracksPhase[track_idx]==1 then imgui.PopStyleColor(ctx) end; ShowTooltip("Invert Phase"); imgui.SameLine(ctx)
                    if state.tracksMut[track_idx]==1 then imgui.PushStyleColor(ctx,imgui.Col_Button,PackColor(1,0,0,0.5)) end; if imgui.Button(ctx,"M##mute_cs",btn_w,btn_h) then reaper.SetMediaTrackInfo_Value(track,"B_MUTE",1-state.tracksMut[track_idx]) end; if state.tracksMut[track_idx]==1 then imgui.PopStyleColor(ctx) end; ShowTooltip("Mute"); imgui.SameLine(ctx)
                    if state.tracksSol[track_idx]>0 then imgui.PushStyleColor(ctx,imgui.Col_Button,PackColor(1,1,0,0.5)) end; if imgui.Button(ctx,"S##solo_cs",btn_w,btn_h) then reaper.SetMediaTrackInfo_Value(track,"I_SOLO",state.tracksSol[track_idx]>0 and 0 or 1) end; if state.tracksSol[track_idx]>0 then imgui.PopStyleColor(ctx) end; ShowTooltip("Solo"); imgui.SameLine(ctx)
                    if state.tracksFX[track_idx]~=-1 then imgui.PushStyleColor(ctx,imgui.Col_Button,PackColor(0,1,0,0.5)) end; if imgui.Button(ctx,"FX##fx_cs",btn_w,btn_h) then reaper.TrackFX_Show(track,0,state.tracksFX[track_idx]==-1 and 1 or -1) end; if state.tracksFX[track_idx]~=-1 then imgui.PopStyleColor(ctx) end; ShowTooltip("Open FX Chain window")
                    imgui.EndGroup(ctx)
                    
                    imgui.Separator(ctx)

                    imgui.Text(ctx, "Pan"); imgui.SameLine(ctx, 40); imgui.PushItemWidth(ctx, -70)
                    local pan_val = math.floor(state.tracksPan[track_idx]*100+0.5)
                    local pan_changed, new_pan = imgui.SliderInt(ctx, "##Pan_cs", pan_val, -100, 100, "")
                    if pan_changed then reaper.SetMediaTrackInfo_Value(track, "D_PAN", new_pan/100); reaper.Undo_BeginBlock(); reaper.Undo_EndBlock("Adjust Pan", -1) end
                    if imgui.IsItemClicked(ctx,1) then reaper.SetMediaTrackInfo_Value(track,"D_PAN",0) end
                    imgui.PopItemWidth(ctx); imgui.SameLine(ctx, 0, 5)
                    local pan_text = string.format("%d", pan_val)
                    imgui.Text(ctx, pan_text)
                    if imgui.IsItemHovered(ctx) and imgui.IsMouseDoubleClicked(ctx, 0) then
                        state.value_input_info = { track_idx = track_idx, param_type = 'PAN', current_value_str = pan_text }
                        state.value_input_text = tostring(pan_val)
                        state.open_value_input_popup = true
                    end
                    ShowTooltip("Pan (Left/Right Balance)\nDouble-click value to type.\nRight-click slider to reset.")

                    imgui.Text(ctx, "Width"); imgui.SameLine(ctx, 40); imgui.PushItemWidth(ctx, -70)
                    local width_val = math.floor(state.tracksWidth[track_idx]*100+0.5)
                    local width_changed, new_width = imgui.SliderInt(ctx, "##Width_cs", width_val, -100, 100, "")
                    if width_changed then reaper.SetMediaTrackInfo_Value(track, "D_WIDTH", new_width/100); reaper.Undo_BeginBlock(); reaper.Undo_EndBlock("Adjust Width", -1) end
                    if imgui.IsItemClicked(ctx,1) then reaper.SetMediaTrackInfo_Value(track,"D_WIDTH",1) end
                    imgui.PopItemWidth(ctx); imgui.SameLine(ctx, 0, 5)
                    local width_text = string.format("%d%%", width_val)
                    imgui.Text(ctx, width_text)
                    if imgui.IsItemHovered(ctx) and imgui.IsMouseDoubleClicked(ctx, 0) then
                        state.value_input_info = { track_idx = track_idx, param_type = 'WIDTH', current_value_str = width_text }
                        state.value_input_text = tostring(width_val)
                        state.open_value_input_popup = true
                    end
                    ShowTooltip("Stereo Width\nDouble-click value to type.\nDouble-click or right-click slider to reset.")
                    
                    imgui.Separator(ctx)
                    
                    -- QUICK COMP
                    imgui.Text(ctx, "QUICK COMP")
                    if state.quickControls.reaComp_idx then
                        local comp_fx = state.quickControls.reaComp_idx
                        if imgui.Button(ctx, (state.quickControls.reaComp_params.bypass and "Bypassed" or "Bypass") .. "##Comp_Bypass") then
                             reaper.TrackFX_SetEnabled(track, comp_fx, not state.quickControls.reaComp_params.bypass)
                        end
                        ShowTooltip("Enable/Disable ReaComp.")
                        
                        -- Helper function for Comp sliders
                        local function CompSlider(label, param_idx, slider_min, slider_max, format)
                            local norm_val = reaper.TrackFX_GetParam(track, comp_fx, param_idx)
                            local _, formatted_val = reaper.TrackFX_GetFormattedParamValue(track, comp_fx, param_idx, norm_val, "")

                            local slider_val = math.floor(norm_val * (slider_max - slider_min) + slider_min + 0.5)

                            imgui.Text(ctx, label .. ": "); imgui.SameLine(ctx); imgui.Text(ctx, formatted_val); imgui.SameLine(ctx); imgui.PushItemWidth(ctx, -1)
                            local changed, new_slider_val = imgui.SliderInt(ctx, "##"..label, slider_val, slider_min, slider_max, "")
                            ShowTooltip(label .. " - ReaComp")
                            if changed then
                                local new_norm_val = (new_slider_val - slider_min) / (slider_max - slider_min)
                                reaper.TrackFX_SetParam(track, comp_fx, param_idx, new_norm_val)
                            end
                            imgui.PopItemWidth(ctx)
                        end
                        
                        -- Corrected parameter mapping based on user feedback.
                        -- ReaComp Param Indices: 0=Threshold, 1=Ratio, 2=Attack, 3=Release, 4=Pre-comp
                        CompSlider("Threshold", 0, 0, 1000)
                        CompSlider("Ratio", 1, 0, 1000)
                        CompSlider("Pre-comp", 4, 0, 1000)
                        CompSlider("Attack", 2, 0, 1000)
                        CompSlider("Release", 3, 0, 1000)

                    else
                         imgui.Text(ctx, "ReaComp not found on this track.")
                    end
                    imgui.Separator(ctx)

                    imgui.Text(ctx, "Sends")
                    if #state.tracksSends[track_idx] > 0 then
                        for j = 1, math.min(4, #state.tracksSends[track_idx]) do
                            local send_info = state.tracksSends[track_idx][j]
                            local send_api_idx = j - 1
                            imgui.Text(ctx, "S" .. j .. " -> " .. send_info.dest_track_name)
                            imgui.PushItemWidth(ctx, -70)
                            local db, db_int_val = GainToDB(send_info.vol), math.floor(GainToDB(send_info.vol) + 0.5)
                            local vol_changed, new_db_int = imgui.SliderInt(ctx, "##vol_send_cs"..j, db_int_val, -100, 12, "")
                            ShowTooltip(string.format("Send Volume: %.2f dB\nDouble-click value to type.\nRight-click slider to reset.", db))
                            if imgui.IsItemClicked(ctx, 1) then reaper.SetTrackSendInfo_Value(track, 0, send_api_idx, "D_VOL", 1)
                            elseif vol_changed then reaper.SetTrackSendInfo_Value(track, 0, send_api_idx, "D_VOL", DBToGain(new_db_int)); reaper.Undo_BeginBlock(); reaper.Undo_EndBlock("Adjust Send Volume", -1) end
                            imgui.PopItemWidth(ctx); imgui.SameLine(ctx)
                            local db_text = string.format("%.1f dB", db)
                            imgui.Text(ctx, db_text)
                            if imgui.IsItemHovered(ctx) and imgui.IsMouseDoubleClicked(ctx, 0) then
                                state.value_input_info = { track_idx = track_idx, param_type = 'SEND_VOL', send_idx = send_api_idx, current_value_str = db_text }
                                state.value_input_text = string.format("%.2f", db)
                                state.open_value_input_popup = true
                            end
                        end
                    else
                        imgui.Text(ctx, "No Sends on this track.")
                    end
                    
                    imgui.Separator(ctx)
                    
                    imgui.Text(ctx, "Pinned FX Parameters")
                    if state.pinnedParams[guid_str] and #state.pinnedParams[guid_str] > 0 then
                        for p_idx, param_info in ipairs(state.pinnedParams[guid_str]) do
                            local norm_val = reaper.TrackFX_GetParam(track, param_info.fx_idx, param_info.param_idx)
                            local _, param_name = reaper.TrackFX_GetParamName(track, param_info.fx_idx, param_info.param_idx, "")
                            local _, formatted_val = reaper.TrackFX_GetFormattedParamValue(track, param_info.fx_idx, param_info.param_idx, norm_val, "")
                            imgui.PushItemWidth(ctx, -65)
                            local slider_val = math.floor(norm_val * 1000 + 0.5)
                            local changed, new_slider_val = imgui.SliderInt(ctx, "##fxparam_cs"..p_idx, slider_val, 0, 1000, param_name)
                            ShowTooltip(param_name .. "\nDouble-click value to type.")
                            if changed then reaper.TrackFX_SetParam(track, param_info.fx_idx, param_info.param_idx, new_slider_val / 1000.0); reaper.Undo_BeginBlock(); reaper.Undo_EndBlock("Adjust FX Parameter", -1) end
                            imgui.PopItemWidth(ctx)
                            imgui.SameLine(ctx, 0, 5)
                            imgui.Text(ctx, formatted_val)
                            if imgui.IsItemHovered(ctx) and imgui.IsMouseDoubleClicked(ctx, 0) then
                                state.value_input_info = { track_idx = track_idx, param_type = 'FX_PARAM', fx_info = { fx_idx = param_info.fx_idx, param_idx = param_info.param_idx }, current_value_str = formatted_val }
                                state.value_input_text = tostring(slider_val)
                                state.open_value_input_popup = true
                            end
                        end
                    else
                        imgui.Text(ctx, "No Pinned FX on this track.")
                    end

                    local left_col_end_y = imgui.GetCursorPosY(ctx) -- Store Y pos after drawing
                    local left_col_height = left_col_end_y - left_col_start_y

                    -- Right Column: Fader & Meter
                    imgui.TableNextColumn(ctx)

                    local text_height = 22 -- Reserve space for text below elements
                    local element_height = left_col_height - text_height
                    if element_height < 50 then element_height = 50 end
                    
                    -- Fader Group (now on the left)
                    imgui.BeginGroup(ctx)
                    
                    local db = GainToDB(state.tracksVol[track_idx])
                    local s_val
                    if db >= 0 then s_val = (db / 12) * 100
                    else s_val = (db / 60) * 100 end
                    s_val = math.floor(s_val + 0.5)

                    local fader_changed, new_s = imgui.VSliderInt(ctx, "##Vol_cs", 40, element_height, s_val, -100, 100, "")
                    ShowTooltip(string.format("Volume: %.2f dB\nDouble-click value to type.\nRight-click slider to reset to 0dB.", db))
                    if imgui.IsItemClicked(ctx,1) then reaper.SetMediaTrackInfo_Value(track,"D_VOL",1); fader_changed = false end
                    
                    if fader_changed then 
                        local new_db
                        if new_s >= 0 then new_db = (new_s / 100) * 12
                        else new_db = (new_s / 100) * 60 end
                        reaper.SetMediaTrackInfo_Value(track,"D_VOL",DBToGain(new_db))
                        reaper.Undo_BeginBlock(); reaper.Undo_EndBlock("Adjust Vol", -1)
                    end
                    
                    local db_text = string.format("%.1f dB", db)
                    local text_w = imgui.CalcTextSize(ctx, db_text)
                    imgui.SetCursorPosX(ctx, imgui.GetCursorPosX(ctx) + (40 - text_w) / 2)
                    imgui.Text(ctx, db_text)
                    if imgui.IsItemHovered(ctx) and imgui.IsMouseDoubleClicked(ctx, 0) then
                        state.value_input_info = { track_idx = track_idx, param_type = 'VOL', current_value_str = db_text }
                        state.value_input_text = string.format("%.2f", db)
                        state.open_value_input_popup = true
                    end

                    imgui.EndGroup(ctx) -- End fader group
                    
                    imgui.SameLine(ctx, 0, 5)
                    
                    -- VU Meter (now on the right)
                    DrawVUMeter(ctx, element_height, state.tracksPeakL[track_idx], state.tracksPeakR[track_idx], state.tracksPeakHoldL[track_idx], state.tracksPeakHoldR[track_idx], track_idx)

                    imgui.EndTable(ctx)
                end

            else
                imgui.Text(ctx, "Please select a track in REAPER to use Channel Strip View.")
            end

        else
            -- PAN/VOL/WIDTH/FX PARAMS MODE LAYOUT
            
            -- Focus Folder Exit Button
            if state.focus_folder_guid then
                 local folder_name = "Folder"
                 -- Try to get folder name from idx if valid, else generic
                 if state.tracks[state.focus_folder_idx] and reaper.ValidatePtr(state.tracks[state.focus_folder_idx], "MediaTrack*") then
                     _, folder_name = reaper.GetTrackName(state.tracks[state.focus_folder_idx])
                 end
                 
                 imgui.PushStyleColor(ctx, imgui.Col_Button, 0x333333FF)
                 if imgui.Button(ctx, "🔙 EXIT FOCUS: " .. folder_name, -1, 30) then
                     state.focus_folder_guid = nil
                     state.focus_folder_idx = -1
                     state.focus_folder_depth = -1
                 end
                 imgui.PopStyleColor(ctx)
            end

            if state.show_matrix_view then
                DrawSendMatrix(ctx)
                goto skip_list_view
            end

            if state.mixer_layout == "STRIP" then
                DrawVerticalMixerArea(ctx, main_area_h)
                goto skip_list_view
            end

            if imgui.BeginChild(ctx, "TrackListScope", 0, main_area_h) then
                if imgui.BeginTable(ctx, 'MainMixerArea', 2, imgui.TableFlags_BordersInnerV + imgui.TableFlags_Resizable) then
                imgui.TableSetupColumn(ctx, "Tracks", imgui.TableColumnFlags_WidthFixed, 260)
                imgui.TableSetupColumn(ctx, "Controls", imgui.TableColumnFlags_WidthStretch)
                local hide_children_of_collapsed_folder, collapsed_folder_depth = false, -1
                
                -- Focus Folder Scope Latch
                local is_focus_active = state.focus_folder_guid ~= nil
                local is_in_focus_scope = false

                for i = 1, #state.tracks do
                    -- FOCUS FOLDER FILTER
                    if is_focus_active then
                         -- If we hit the focused folder, activate scope (but don't show the folder itself, we want to see inside)
                         if i == state.focus_folder_idx then
                             is_in_focus_scope = true
                             goto continue_loop -- Hide header
                         end
                         
                         if is_in_focus_scope then
                             -- Check if we exited the folder
                             if state.tracksDepth[i] <= state.focus_folder_depth then
                                 is_in_focus_scope = false
                             end
                         end
                         
                         -- If not in scope, hide
                         if not is_in_focus_scope then goto continue_loop end
                    end

                    local track = state.tracks[i]
                    if reaper.ValidatePtr(track, "MediaTrack*") then
                        local current_depth = state.tracksDepth[i]
                        if hide_children_of_collapsed_folder and current_depth > collapsed_folder_depth then goto continue_loop
                        elseif hide_children_of_collapsed_folder and current_depth <= collapsed_folder_depth then hide_children_of_collapsed_folder, collapsed_folder_depth = false, -1 end
                        
                        
                        local show_track = ApplyAdvancedFilter(i, state.filter_text)
                        
                        if show_track and not ApplyViewFilter(i) then show_track = false end

                        local guid_str = reaper.GetTrackGUID(track)
                        if show_track and state.edit_mode == "FX PARAMS" and (not state.pinnedParams[guid_str] or #state.pinnedParams[guid_str] == 0) then show_track = false end
                        
                        if show_track then
                            local _, name = reaper.GetTrackName(track)
                            
                            -- MAIN TABLE ROW
                            imgui.TableNextRow(ctx)
                            -- Alternating row color
                            if i % 2 == 0 then
                                -- Use a subtle overlay based on theme brightness 
                                -- (Since we don't have per-theme row vars yet, use a generic safe low-alpha white or black)
                                -- For modern dark, a slight lighten is nice.
                                imgui.TableSetBgColor(ctx, imgui.TableBgTarget_RowBg0, 0xFFFFFF07) -- Very faint white overlay
                            end

                            imgui.TableNextColumn(ctx)
                            if current_depth > 0 then imgui.Indent(ctx, current_depth * config.indent_size) end
                            if imgui.BeginTable(ctx, 'track_line'..i, 4, 0) then
                                imgui.TableSetupColumn(ctx, 'drag'..i, imgui.TableColumnFlags_WidthFixed, 20)
                                imgui.TableSetupColumn(ctx, 'vis'..i, imgui.TableColumnFlags_WidthFixed, 25)
                                imgui.TableSetupColumn(ctx, 'name'..i, imgui.TableColumnFlags_WidthStretch)
                                imgui.TableSetupColumn(ctx, 'buttons'..i, imgui.TableColumnFlags_WidthFixed, 140)

                                imgui.TableNextColumn(ctx) -- Drag Handle
                                imgui.Button(ctx, "::##drag_main"..i)
                                ShowTooltip("Drag to another track to create a send.")
                                if imgui.BeginDragDropSource(ctx) then
                                    imgui.SetDragDropPayload(ctx, "TRACK_ITEM_SEND", tostring(i))
                                    imgui.Text(ctx, "Send from: " .. name)
                                    imgui.EndDragDropSource(ctx)
                                end

                                imgui.TableNextColumn(ctx) -- Visibility
                                -- Center Eye Icon
                                imgui.PushStyleVar(ctx, imgui.StyleVar_FramePadding, 0, 0)
                                
                                -- Visual Feedback: Bright if visible, Dim if hidden
                                local eye_col = state.tracksVisible[i] and 0xFFFFFFFF or 0xFFFFFF40
                                imgui.PushStyleColor(ctx, imgui.Col_Text, eye_col)
                                
                                if imgui.Button(ctx, "👁##vis"..i, 22, 18) then 
                                    local new_vis_state = state.tracksVisible[i] and 0 or 1
                                    reaper.SetMediaTrackInfo_Value(track, "B_SHOWINTCP", new_vis_state)
                                    reaper.SetMediaTrackInfo_Value(track, "B_SHOWINMIXER", new_vis_state)
                                    ForceUIRefresh()
                                end
                                
                                imgui.PopStyleColor(ctx)
                                imgui.PopStyleVar(ctx)
                                ShowTooltip("Show/Hide this track in TCP and Mixer.")
                                
                                imgui.TableNextColumn(ctx) -- Track Name
                                local display_name = string.format("%02d: %s", i, name)
                                if state.isFolder[i] then display_name = (state.folderCollapsed[i] and "📂 " or "📁 ") .. display_name end
                                local r, g, b = reaper.ColorFromNative(reaper.GetTrackColor(track))
                                imgui.PushStyleColor(ctx, imgui.Col_Header, PackColor(r/255, g/255, b/255, 0.3)); imgui.PushStyleColor(ctx, imgui.Col_HeaderHovered, PackColor(r/255, g/255, b/255, 0.5)); imgui.PushStyleColor(ctx, imgui.Col_HeaderActive, PackColor(r/255, g/255, b/255, 0.7))
                                
                                if imgui.Selectable(ctx, display_name.."##track"..i, state.tracksSel[i], imgui.SelectableFlags_SpanAllColumns) then
                                    state.last_selected_track_idx = i
                                    
                                    -- Restore selection logic
                                    if imgui.IsKeyDown(ctx, imgui.Mod_Ctrl) then
                                        -- Multi-select / Toggle
                                        reaper.SetTrackSelected(track, not reaper.IsTrackSelected(track))
                                    else
                                        -- Exclusive Select
                                        reaper.SetOnlyTrackSelected(track)
                                    end
                                    
                                    if has_sws_set_last_touched then reaper.SetLastTouchedTrack(track) end
                                end
                                
                                -- Robust Double-Click to Toggle Folder Collapse (Check Hover + DoubleClick)
                                if state.isFolder[i] and imgui.IsItemHovered(ctx) and imgui.IsMouseDoubleClicked(ctx, 0) then
                                    local new_compact = state.folderCollapsed[i] and 0 or 2 -- 0=normal, 2=collapsed (small)
                                    reaper.SetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT", new_compact)
                                    -- Manually flip state for immediate visual feedback before next API update
                                    state.folderCollapsed[i] = not state.folderCollapsed[i]
                                    ForceUIRefresh()
                                end
                                
                                -- Right Click Context Menu for Focus
                                if imgui.BeginPopupContextItem(ctx, "TrackContextMenu"..i) then
                                    DrawTrackContextMenuOptions(ctx, track, i, guid_str, name)
                                    imgui.EndPopup(ctx)
                                end
                                
                                if state.isFolder[i] and imgui.IsItemHovered(ctx) then ShowTooltip("Double-click to Collapse/Expand.\nRight-click for Opts.") end
                                
                                imgui.PopStyleColor(ctx, 3)
                                
                                -- Drop Target for creating sends
                                if imgui.BeginDragDropTarget(ctx) then
                                    local success, payload_str = imgui.AcceptDragDropPayload(ctx, "TRACK_ITEM_SEND")
                                    if success then
                                        local src_idx = tonumber(payload_str)
                                        if src_idx and i and src_idx ~= i then
                                            local src_track = state.tracks[src_idx]
                                            local dest_track = state.tracks[i]
                                            if src_track and dest_track then
                                                reaper.Undo_BeginBlock()
                                                reaper.CreateTrackSend(src_track, dest_track)
                                                reaper.Undo_EndBlock("Create Send via Drag & Drop", -1)
                                            end
                                        end
                                    end
                                    imgui.EndDragDropTarget(ctx)
                                end
                                
                                imgui.TableNextColumn(ctx) -- Buttons
                                -- Reduce padding for small buttons to center text
                                imgui.PushStyleVar(ctx, imgui.StyleVar_FramePadding, 0, 4)
                                
                                if state.tracksMut[i]==1 then imgui.PushStyleColor(ctx,imgui.Col_Button,PackColor(1,0,0,0.5)) end; if imgui.Button(ctx,"M##"..i,25,0) then reaper.SetMediaTrackInfo_Value(track,"B_MUTE",1-state.tracksMut[i]) end; if state.tracksMut[i]==1 then imgui.PopStyleColor(ctx) end; ShowTooltip("Mute"); imgui.SameLine(ctx,0,2)
                                if state.tracksSol[i]>0 then imgui.PushStyleColor(ctx,imgui.Col_Button,PackColor(1,1,0,0.5)) end; if imgui.Button(ctx,"S##"..i,25,0) then reaper.SetMediaTrackInfo_Value(track,"I_SOLO",state.tracksSol[i]>0 and 0 or 1) end; if state.tracksSol[i]>0 then imgui.PopStyleColor(ctx) end; ShowTooltip("Solo"); imgui.SameLine(ctx,0,2)
                                if state.tracksFX[i]~=-1 then imgui.PushStyleColor(ctx,imgui.Col_Button,PackColor(0,1,0,0.5)) end; if imgui.Button(ctx,"FX##"..i,25,0) then reaper.TrackFX_Show(track,0,state.tracksFX[i]==-1 and 1 or -1) end; if state.tracksFX[i]~=-1 then imgui.PopStyleColor(ctx) end; ShowTooltip("Open FX Chain window"); imgui.SameLine(ctx,0,2)
                                if state.tracksPhase[i]==1 then imgui.PushStyleColor(ctx,imgui.Col_Button,PackColor(1,0.5,0,0.5)) end; if imgui.Button(ctx,"ø##"..i,25,0) then reaper.SetMediaTrackInfo_Value(track,"B_PHASE",1-state.tracksPhase[i]) end; if state.tracksPhase[i]==1 then imgui.PopStyleColor(ctx) end; ShowTooltip("Invert Phase"); imgui.SameLine(ctx,0,2)
                                local has_pins = state.pinnedParams[guid_str] and #state.pinnedParams[guid_str] > 0
                                if has_pins then imgui.PushStyleColor(ctx, imgui.Col_Button, PackColor(0.2, 0.6, 1.0, 0.7)) end
                                if imgui.Button(ctx, "Pin##pin"..i, 28, 0) then state.popup_pin_track_idx = i; state.open_pin_popup = true end
                                ShowTooltip("Pin an FX parameter from this track\nfor quick control in 'FX PARAMS' mode.")
                                if has_pins then imgui.PopStyleColor(ctx) end
                                
                                imgui.PopStyleVar(ctx) -- Pop FramePadding

                                imgui.EndTable(ctx)
                            end
                            if current_depth > 0 then imgui.Unindent(ctx, current_depth * config.indent_size) end
                            imgui.TableNextColumn(ctx)
                            -- Reduce gap on the right by pushing wider width
                            local slider_w_offset = -5
                            if state.edit_mode == "PAN" then
                                local pan_val = math.floor(state.tracksPan[i]*100+0.5)
                                -- New Pan Slider Logic
                                imgui.PushItemWidth(ctx, -1)
                                local changed,new_pan=imgui.SliderInt(ctx,"##Pan"..i,pan_val,-100,100,"%d")
                                imgui.PopItemWidth(ctx)
                                
                                if imgui.IsItemHovered(ctx) and imgui.IsMouseDoubleClicked(ctx, 0) then
                                    state.value_input_info = { track_idx = i, param_type = 'PAN', current_value_str = tostring(pan_val) }
                                    state.value_input_text = tostring(pan_val)
                                    state.open_value_input_popup = true
                                end
                                ShowTooltip("Pan Value\nDouble-click value to type.\nRight-click slider to reset to center.")
                                if changed then 
                                    reaper.Undo_BeginBlock()
                                    local new_pan_norm = new_pan/100
                                    local d = new_pan_norm - state.tracksPan[i]
                                    
                                    -- Group Sync
                                    SyncGroupPan(track, d, state.tracksSel[i])
                                    
                                    -- IMMEDIATE STATE UPDATE TO PREVENT DRIFT
                                    state.tracksPan[i] = new_pan_norm

                                    if state.tracksSel[i] then 
                                        for j=1,#state.tracks do 
                                            if state.tracksSel[j] then 
                                                local t=state.tracks[j]
                                                local p=reaper.GetMediaTrackInfo_Value(t,"D_PAN")+d
                                                local p_clamped = math.max(-1,math.min(1,p))
                                                reaper.SetMediaTrackInfo_Value(t,"D_PAN",p_clamped) 
                                                if state.tracks[j] then state.tracksPan[j] = p_clamped end -- Update state for others too? Ideally yes, but main drift comes from leader.
                                            end 
                                        end 
                                    else 
                                        reaper.SetMediaTrackInfo_Value(track,"D_PAN",new_pan_norm) 
                                    end
                                    reaper.Undo_EndBlock("Adjust Pan",-1) 
                                end
                                if imgui.IsItemClicked(ctx,1) then 
                                    local d = 0 - state.tracksPan[i]
                                    SyncGroupPan(track, d, state.tracksSel[i])
                                    if state.tracksSel[i] then
                                        for j=1,#state.tracks do if state.tracksSel[j] then reaper.SetMediaTrackInfo_Value(state.tracks[j],"D_PAN",0) end end
                                    else
                                        reaper.SetMediaTrackInfo_Value(track,"D_PAN",0) 
                                    end
                                end

                            elseif state.edit_mode == "VOL" then
                                local db = GainToDB(state.tracksVol[i])
                                local s_val
                                if db >= 0 then s_val = (db / 12) * 100
                                else s_val = (db / 60) * 100 end
                                s_val = math.floor(s_val + 0.5)

                                -- 1. Reduce Slider Width to make room for Peak
                                local avail_w = imgui.GetContentRegionAvail(ctx)
                                local peak_reserved_w = 40 -- Enough for "-XX.X"
                                local slider_w = avail_w - peak_reserved_w - 8 -- spacing
                                if slider_w < 10 then slider_w = 10 end -- minimal visibility
                                
                                imgui.PushItemWidth(ctx, slider_w)
                                local db_str = string.format("%.1f dB", db)
                                local ch,new_s=imgui.SliderInt(ctx,"##Vol"..i,s_val,-100,100,"")
                                
                                -- Volume Input & Tooltip
                                local slider_hovered = imgui.IsItemHovered(ctx)
                                if slider_hovered then
                                     ShowTooltip(string.format("Volume: %.2f dB\nDouble-click to type value.\nRight-click to reset to 0dB.", db))
                                     
                                     -- Right-Click Reset
                                     if imgui.IsItemClicked(ctx, 1) then
                                         reaper.Undo_BeginBlock()
                                         SyncGroupVolume(track, (state.tracksVol[i] > 0.0000001) and (1.0 / state.tracksVol[i]) or 1.0, state.tracksSel[i])
                                         if state.tracksSel[i] then
                                             for j=1,#state.tracks do if state.tracksSel[j] then reaper.SetMediaTrackInfo_Value(state.tracks[j],"D_VOL",1.0) end end
                                         else
                                             reaper.SetMediaTrackInfo_Value(track, "D_VOL", 1.0)
                                         end
                                         reaper.Undo_EndBlock("Reset Volume", -1)
                                     end

                                     if imgui.IsMouseDoubleClicked(ctx, 0) then
                                        state.value_input_info = { track_idx = i, param_type = 'VOL', current_value_str = db_str }
                                        state.value_input_text = string.format("%.2f", db)
                                        state.open_value_input_popup = true
                                        
                                        -- Prevent standard reset or drag from applying during double-click
                                        ch = false 
                                     end
                                end
                                
                                -- Draw text over slider manually
                                local center_x, center_y = imgui.GetItemRectMin(ctx)
                                local size_x, size_y = imgui.GetItemRectSize(ctx)
                                local text_sz_x, text_sz_y = imgui.CalcTextSize(ctx, db_str)
                                imgui.DrawList_AddText(imgui.GetWindowDrawList(ctx), center_x + (size_x/2 - text_sz_x/2), center_y + (size_y/2 - text_sz_y/2), 0xFFFFFFFF, db_str)
                                
                                imgui.PopItemWidth(ctx)
                                
                                -- 2. Draw Peak Value
                                imgui.SameLine(ctx, 0, 10)
                                
                                -- Capture Peak Position
                                local p_pos_x, p_pos_y = imgui.GetCursorScreenPos(ctx)
                                
                                local peakL = state.tracksPeakHoldL[i] or 0
                                local peakR = state.tracksPeakHoldR[i] or 0
                                local max_peak = math.max(peakL, peakR)
                                local peak_db = GainToDB(max_peak)
                                
                                local peak_col = 0x00FF00FF 
                                if peak_db > -1.0 then peak_col = 0xFF0000FF 
                                elseif peak_db > -6.0 then peak_col = 0xFFFF00FF end 
                                
                                local peak_str
                                if peak_db < -90 then 
                                    peak_str = "-inf"
                                    peak_col = 0x666666FF 
                                else 
                                    peak_str = string.format("%.1f", peak_db)
                                end
                                
                                imgui.PushStyleColor(ctx, imgui.Col_Text, peak_col)
                                imgui.Text(ctx, peak_str)
                                imgui.PopStyleColor(ctx)
                                
                                -- RESET PEAK INTERACTION (INVISIBLE BUTTON OVERLAY)
                                local p_rect_w, p_rect_h = imgui.GetItemRectSize(ctx)
                                -- Ensure overlay covers the text fully
                                imgui.SetCursorScreenPos(ctx, p_pos_x, p_pos_y)
                                imgui.InvisibleButton(ctx, "##peak_reset_ovrl"..i, p_rect_w, p_rect_h)
                                
                                if imgui.IsItemHovered(ctx) then
                                    if imgui.IsMouseClicked(ctx, 0) and (imgui.IsKeyDown(ctx, imgui.Mod_Shift) or imgui.IsKeyDown(ctx, imgui.Mod_Ctrl)) then
                                        ResetAllPeaks()
                                    elseif imgui.IsMouseDoubleClicked(ctx, 0) then
                                        state.tracksPeakHoldL[i] = 0
                                        state.tracksPeakHoldR[i] = 0
                                    end
                                    ShowTooltip("Shift+Click: Reset ALL Peaks\nDouble-Click Left: Reset Peak Hold")
                                end
                                
                                -- Apply Volume Change (if not suppressed by Double Click)
                                if ch then 
                                    reaper.Undo_BeginBlock()
                                    local new_db
                                    if new_s >= 0 then new_db = (new_s / 100) * 12
                                    else new_db = (new_s / 100) * 60 end

                                    local old_gain = state.tracksVol[i]
                                    local new_gain = DBToGain(new_db)
                                    local ratio = (old_gain > 0.000001) and (new_gain / old_gain) or 1
                                    
                                    -- Group Sync
                                    SyncGroupVolume(track, ratio, state.tracksSel[i])
                                    
                                    -- IMMEDIATE STATE UPDATE TO PREVENT DRIFT
                                    state.tracksVol[i] = new_gain

                                    if state.tracksSel[i] then
                                        for j=1, #state.tracks do 
                                            if state.tracksSel[j] then 
                                                local t = state.tracks[j]
                                                local current_gain = reaper.GetMediaTrackInfo_Value(t, "D_VOL")
                                                reaper.SetMediaTrackInfo_Value(t, "D_VOL", current_gain * ratio)
                                                if state.tracks[j] then state.tracksVol[j] = current_gain * ratio end
                                            end 
                                        end 
                                    else 
                                        reaper.SetMediaTrackInfo_Value(track,"D_VOL",new_gain) 
                                    end
                                    reaper.Undo_EndBlock("Adjust Vol", -1) 
                                end
                            elseif state.edit_mode == "FX RACK" then
                                -- FX RACK DRAWING
                                local fx_list = state.tracksFXList[i]
                                if fx_list and #fx_list > 0 then
                                    -- Calculate button size to fit available width or scroll?
                                    -- For now, fixed width "chiclets" wrapping or scrolling horizontally?
                                    -- Let's try simple left-to-right flow with SameLine, maybe wrapping if too many.
                                    -- Or maybe a scrollable child? No, space is tight directly in table.
                                    -- Just Draw them buttons!
                                    
                                    for fx_idx, fx_data in ipairs(fx_list) do
                                        local api_fx_idx = fx_idx - 1
                                        if fx_idx > 1 then imgui.SameLine(ctx, 0, 2) end
                                        
                                        local col_btn
                                        if fx_data.offline then col_btn = PackColor(0.5, 0, 0, 1) -- Reddish for offline
                                        elseif fx_data.enabled then col_btn = PackColor(0.2, 0.8, 0.4, 0.8) -- Green for Active
                                        else col_btn = PackColor(0.3, 0.3, 0.3, 0.8) end -- Gray for Bypassed
                                        
                                        imgui.PushStyleColor(ctx, imgui.Col_Button, col_btn)
                                        imgui.PushStyleColor(ctx, imgui.Col_ButtonHovered, PackColor(0.4, 0.9, 0.5, 1.0))
                                        imgui.PushStyleColor(ctx, imgui.Col_ButtonActive, PackColor(1, 1, 1, 1.0))
                                        
                                        -- Shorten name for tiny button? Or just empty small square with Tooltip?
                                        -- "Chiclet" style usually implies no text or very short text.
                                        -- Let's try small width (e.g. 15px) vertical bar or box.
                                        -- User said "square represent FX1, FX2".
                                        if imgui.Button(ctx, "##fx"..i.."_"..fx_idx, 12, 18) then
                                            -- Toggle Enable/Bypass
                                            reaper.Undo_BeginBlock()
                                            reaper.TrackFX_SetEnabled(track, api_fx_idx, not fx_data.enabled)
                                            reaper.Undo_EndBlock("Toggle FX Bypass", -1)
                                        end
                                        imgui.PopStyleColor(ctx, 3)
                                        
                                        -- Right Click to Float
                                        if imgui.IsItemClicked(ctx, 1) then
                                            reaper.TrackFX_Show(track, api_fx_idx, 3) -- 3 = float window
                                        end
                                        
                                        -- Tooltip with Name and Status
                                        local status_txt = fx_data.enabled and "Active" or (fx_data.offline and "Offline" or "Bypassed")
                                        ShowTooltip(string.format("%d: %s\n(%s)\nL-Click: Toggle | R-Click: Float", fx_idx, fx_data.name, status_txt))
                                    end
                                else
                                    imgui.TextDisabled(ctx, "-")
                                end
                            elseif state.edit_mode == "WIDTH" then
                                local width_val = math.floor(state.tracksWidth[i]*100+0.5)
                                imgui.PushItemWidth(ctx, -1)
                                local changed,new_width_int=imgui.SliderInt(ctx,"##Width"..i,width_val,-100,100,"%d%%")
                                imgui.PopItemWidth(ctx)
                                
                                if imgui.IsItemHovered(ctx) and imgui.IsMouseDoubleClicked(ctx, 0) then
                                    state.value_input_info = { track_idx = i, param_type = 'WIDTH', current_value_str = tostring(width_val) }
                                    state.value_input_text = tostring(width_val)
                                    state.open_value_input_popup = true
                                end
                                ShowTooltip("Stereo Width\nDouble-click value to type.\nRight-click slider to reset to 100%.")
                                if changed then reaper.Undo_BeginBlock();local new_width = new_width_int/100.0;local d=new_width-state.tracksWidth[i];if state.tracksSel[i] then for j=1,#state.tracks do if state.tracksSel[j] then local t=state.tracks[j];local w=reaper.GetMediaTrackInfo_Value(t,"D_WIDTH")+d;reaper.SetMediaTrackInfo_Value(t,"D_WIDTH",math.max(-1,math.min(1,w))) end end else reaper.SetMediaTrackInfo_Value(track,"D_WIDTH",new_width) end; reaper.Undo_EndBlock("Adjust Width",-1) end
                                if imgui.IsItemClicked(ctx,1) then reaper.SetMediaTrackInfo_Value(track,"D_WIDTH",1) end
                            elseif state.edit_mode == "FX PARAMS" then
                                if state.pinnedParams[guid_str] then
                                    for p_idx, param_info in ipairs(state.pinnedParams[guid_str]) do
                                        if imgui.Button(ctx, "X##unpin"..i..p_idx, 20, 0) then table.remove(state.pinnedParams[guid_str], p_idx); save_pinned_params(); goto continue_fx_loop end
                                        ShowTooltip("Unpin this parameter.")
                                        imgui.SameLine(ctx)
                                        local norm_val = reaper.TrackFX_GetParam(track, param_info.fx_idx, param_info.param_idx)
                                        local _, param_name = reaper.TrackFX_GetParamName(track, param_info.fx_idx, param_info.param_idx, "")
                                        local _, formatted_val = reaper.TrackFX_GetFormattedParamValue(track, param_info.fx_idx, param_info.param_idx, norm_val, "")
                                        imgui.PushItemWidth(ctx, -65)
                                        local slider_val = math.floor(norm_val * 1000 + 0.5)
                                        local changed, new_slider_val = imgui.SliderInt(ctx, "##fxparam"..i..p_idx, slider_val, 0, 1000, param_name)
                                        ShowTooltip(param_name .. "\nDouble-click value to type.")
                                        if changed then reaper.TrackFX_SetParam(track, param_info.fx_idx, param_info.param_idx, new_slider_val / 1000.0); reaper.Undo_BeginBlock(); reaper.Undo_EndBlock("Adjust FX Parameter", -1) end
                                        imgui.PopItemWidth(ctx)
                                        imgui.SameLine(ctx, 0, 5)
                                        imgui.Text(ctx, formatted_val)
                                        if imgui.IsItemHovered(ctx) and imgui.IsMouseDoubleClicked(ctx, 0) then
                                            state.value_input_info = { track_idx = i, param_type = 'FX_PARAM', fx_info = { fx_idx = param_info.fx_idx, param_idx = param_info.param_idx }, current_value_str = formatted_val }
                                            state.value_input_text = tostring(slider_val)
                                            state.open_value_input_popup = true
                                        end
                                        ::continue_fx_loop::
                                    end
                                end
                            end
                            if state.isFolder[i] and state.folderCollapsed[i] then hide_children_of_collapsed_folder, collapsed_folder_depth = true, current_depth end
                        end
                    end
                    ::continue_loop::
                end
                imgui.EndTable(ctx)
            end
            imgui.EndChild(ctx)
            end
            ::skip_list_view::
        end
        
        DrawStatusBar(ctx, status_bar_h)

        -- Popup for pinning FX parameters
        if state.open_pin_popup then
            imgui.OpenPopup(ctx, "PinFXParamPopup")
            state.open_pin_popup = false
        end
        if imgui.BeginPopup(ctx, "PinFXParamPopup") then
            if state.popup_pin_track_idx then
                local track = state.tracks[state.popup_pin_track_idx]
                local _, track_name = reaper.GetTrackName(track)
                imgui.Text(ctx, "Pin Parameter for: " .. track_name); imgui.Separator(ctx)
                local fx_count = reaper.TrackFX_GetCount(track)
                if fx_count > 0 then
                    for fx = 0, fx_count - 1 do
                        local _, fx_name = reaper.TrackFX_GetFXName(track, fx, "")
                        if imgui.TreeNode(ctx, fx_name .. "##fxnode" .. fx) then
                            local param_count = reaper.TrackFX_GetNumParams(track, fx)
                            for p = 0, param_count - 1 do
                                local _, param_name = reaper.TrackFX_GetParamName(track, fx, p, "")
                                if imgui.Selectable(ctx, param_name .. "##param"..p) then
                                    local guid_str = reaper.GetTrackGUID(track)
                                    local new_pin = {fx_idx = fx, param_idx = p}
                                    if not state.pinnedParams[guid_str] then state.pinnedParams[guid_str] = {} end
                                    local exists = false
                                    for _, pin in ipairs(state.pinnedParams[guid_str]) do if pin.fx_idx == new_pin.fx_idx and pin.param_idx == new_pin.param_idx then exists = true; break end end
                                    if not exists then 
                                        table.insert(state.pinnedParams[guid_str], new_pin)
                                        save_pinned_params()
                                    end
                                    state.popup_pin_track_idx = nil
                                    imgui.CloseCurrentPopup(ctx)
                                end
                            end
                            imgui.TreePop(ctx)
                        end
                    end
                else
                    imgui.Text(ctx, "No FX on this track.")
                end
                imgui.Separator(ctx)
                if imgui.Button(ctx, "Close") then
                    state.popup_pin_track_idx = nil
                    imgui.CloseCurrentPopup(ctx)
                end
            end
            imgui.EndPopup(ctx)
        end
        
        -- Popup for adding a new Send
        if state.open_add_send_popup then
            imgui.OpenPopup(ctx, "AddSendPopup")
            state.open_add_send_popup = false
        end
    
        imgui.SetNextWindowSize(ctx, 350, 400, imgui.Cond_FirstUseEver)
        if imgui.BeginPopupModal(ctx, "AddSendPopup") then
            local src_track_idx = state.sends_view_track_idx
            if src_track_idx and state.tracks[src_track_idx] then
                local src_track = state.tracks[src_track_idx]
                local _, src_name = reaper.GetTrackName(src_track)
                imgui.Text(ctx, "Add Send From: " .. src_name)
                imgui.Text(ctx, "Select Destination Track:")
                imgui.Separator(ctx)
    
                if imgui.BeginChild(ctx, "DestTrackList", 0, -40) then
                    for i = 1, #state.tracks do
                        local dest_track = state.tracks[i]
                        if dest_track ~= src_track then -- Don't allow sending to self
                            local _, dest_name = reaper.GetTrackName(dest_track)
                            if imgui.Selectable(ctx, string.format("%02d: %s", i, dest_name)) then
                                reaper.Undo_BeginBlock()
                                reaper.CreateTrackSend(src_track, dest_track)
                                reaper.Undo_EndBlock("Add Send", -1)
                                imgui.CloseCurrentPopup(ctx)
                            end
                        end
                    end
                end
                imgui.EndChild(ctx)
    
                imgui.Separator(ctx)
                if imgui.Button(ctx, "Cancel", -1, 0) then
                    imgui.CloseCurrentPopup(ctx)
                end
            else
                imgui.Text(ctx, "Error: No source track selected.")
                if imgui.Button(ctx, "Close") then imgui.CloseCurrentPopup(ctx) end
            end
    
            imgui.EndPopup(ctx)
        end

        -- Popup for configuring Custom Menu
        if state.open_custom_menu_config then
            imgui.OpenPopup(ctx, "Configure Custom Menu")
            state.open_custom_menu_config = false -- Reset trigger
        end

        imgui.SetNextWindowSize(ctx, 500, 450, imgui.Cond_FirstUseEver)
        if imgui.BeginPopupModal(ctx, "Configure Custom Menu") then
            imgui.Text(ctx, "Manage Custom Menu (Drag & drop to reorder)"); imgui.Separator(ctx)

            if imgui.Button(ctx, "Add to Root") then state.menu_config_target_table = state.customMenu end
            imgui.SameLine(ctx)
            imgui.TextDisabled(ctx, "(Click a sub-menu in the tree to select it as the target)")

            if imgui.BeginChild(ctx, "MenuTree", 0, -150) then
                DrawMenuConfiguration(state.customMenu, "")
            end
            imgui.EndChild(ctx)
            
            -- Execute deferred actions (move or delete)
            if state.dnd_source_path and state.dnd_target_path then
                execute_menu_move(state.dnd_source_path, state.dnd_target_path, state.dnd_drop_type)
                state.dnd_source_path, state.dnd_target_path, state.dnd_drop_type = nil, nil, nil -- Reset after action
            elseif state.item_to_delete_path then
                execute_menu_delete(state.item_to_delete_path)
                state.item_to_delete_path = nil -- Reset after action
            end

            imgui.Separator(ctx)
            imgui.Text(ctx, "Add New Item")

            local label_col_width = 150

            -- Item Type
            imgui.Text(ctx, "Type")
            imgui.SameLine(ctx, label_col_width)
            imgui.PushItemWidth(ctx, -1)
            local item_types = "Action\0Sub-menu\0Separator\0"
            local type_changed, new_type = imgui.Combo(ctx, "##ItemType", state.new_menu_item_type_idx, item_types)
            if type_changed then 
                state.new_menu_item_type_idx = new_type
                state.new_menu_item_name = ""
                state.new_menu_item_id = ""
            end
            imgui.PopItemWidth(ctx)

            -- Display Name (for Action and Sub-menu)
            if state.new_menu_item_type_idx ~= 2 then -- Not a separator
                imgui.Text(ctx, "Display Name")
                imgui.SameLine(ctx, label_col_width)
                imgui.PushItemWidth(ctx, -1)
                local name_changed, new_name = imgui.InputText(ctx, "##DisplayName", state.new_menu_item_name, 128)
                if name_changed then state.new_menu_item_name = new_name end
                imgui.PopItemWidth(ctx)
            end

            -- Command ID (for Action only)
            if state.new_menu_item_type_idx == 0 then -- Action
                imgui.Text(ctx, "Command ID / Script ID")
                imgui.SameLine(ctx, label_col_width)
                imgui.PushItemWidth(ctx, -1)
                local id_changed, new_id = imgui.InputText(ctx, "##CommandID", state.new_menu_item_id, 256)
                if id_changed then state.new_menu_item_id = new_id end
                imgui.PopItemWidth(ctx)
                ShowTooltip("Enter the Action ID (e.g., 40001) or the script/extension ID (e.g., _RS123abc...).")
            end

            if imgui.Button(ctx, "Add Item", 120, 0) then
                local target = state.menu_config_target_table or state.customMenu
                local changed = false
                if state.new_menu_item_type_idx == 0 then -- Action
                    if state.new_menu_item_name ~= "" and state.new_menu_item_id ~= "" then
                        table.insert(target, { type = "item", name = state.new_menu_item_name, commandId = state.new_menu_item_id })
                        changed = true
                    end
                elseif state.new_menu_item_type_idx == 1 then -- Sub-menu
                    if state.new_menu_item_name ~= "" then
                        table.insert(target, { type = "menu", name = state.new_menu_item_name, items = {} })
                        changed = true
                    end
                elseif state.new_menu_item_type_idx == 2 then -- Separator
                    table.insert(target, { type = "separator", name = "---" })
                    changed = true
                end
                if changed then
                    save_custom_menu()
                    state.new_menu_item_name = ""
                    state.new_menu_item_id = ""
                end
            end
            imgui.SameLine(ctx, imgui.GetWindowWidth(ctx) - 110)
            if imgui.Button(ctx, "Close", 100, 0) then
                imgui.CloseCurrentPopup(ctx)
            end
            imgui.EndPopup(ctx)
        end
        
        -- Popup for direct value input
        if state.open_value_input_popup then
            imgui.OpenPopup(ctx, "ValueInputPopup")
            state.open_value_input_popup = false
        end

        imgui.SetNextWindowSize(ctx, 300, 120, imgui.Cond_Appearing)
        if imgui.BeginPopupModal(ctx, "ValueInputPopup") then
            local info = state.value_input_info
            local title = "Enter Value"
            if info.param_type == 'VOL' or (info.param_type and info.param_type:find("SEND_VOL")) or (info.param_type and info.param_type:find("RECEIVE_VOL")) then
                title = "Enter Volume (dB)"
            elseif info.param_type == 'PAN' or (info.param_type and info.param_type:find("SEND_PAN")) or (info.param_type and info.param_type:find("RECEIVE_PAN")) then
                title = "Enter Pan (-100 to 100)"
            elseif info.param_type == 'WIDTH' then
                title = "Enter Width (%)"
            elseif info.param_type == 'FX_PARAM' then
                title = "Enter FX Value (0-1000)"
            end
            imgui.Text(ctx, title)
            imgui.TextDisabled(ctx, "Current: " .. (info.current_value_str or ""))
            imgui.Separator(ctx)
            
            imgui.Text(ctx, "Value:")
            imgui.SameLine(ctx)
            imgui.PushItemWidth(ctx, -1)
            local value_changed, new_value_str = imgui.InputText(ctx, "##ValueInput", state.value_input_text, 128, imgui.InputTextFlags_EnterReturnsTrue + imgui.InputTextFlags_CharsDecimal, nil)
            
            -- Continuously update state to reflect what's in the box
            state.value_input_text = new_value_str
            
            if imgui.IsWindowAppearing(ctx) then imgui.SetKeyboardFocusHere(ctx, -1) end -- Focus the input field on open
            imgui.PopItemWidth(ctx)

            if imgui.Button(ctx, "OK", 120, 0) or value_changed then
                local num_val = tonumber(state.value_input_text)
                if num_val ~= nil and info.track_idx and state.tracks[info.track_idx] then
                    local track = state.tracks[info.track_idx]
                    reaper.Undo_BeginBlock()
                    
                    if info.param_type == 'VOL' then
                        local new_gain = DBToGain(num_val)
                        if state.tracksSel[info.track_idx] then
                            local old_gain = reaper.GetMediaTrackInfo_Value(track, "D_VOL")
                            local ratio = (old_gain > 0.000001) and (new_gain / old_gain) or 1
                            for j=1, #state.tracks do
                                if state.tracksSel[j] then
                                    local t = state.tracks[j]
                                    local current_gain = reaper.GetMediaTrackInfo_Value(t, "D_VOL")
                                    reaper.SetMediaTrackInfo_Value(t, "D_VOL", current_gain * ratio)
                                end
                            end
                        else
                            reaper.SetMediaTrackInfo_Value(track, "D_VOL", new_gain)
                        end
                        reaper.Undo_EndBlock("Set Volume", -1)
                    elseif info.param_type == 'PAN' then
                        local new_pan = math.max(-100, math.min(100, num_val)) / 100.0
                        if state.tracksSel[info.track_idx] then
                            local old_pan = reaper.GetMediaTrackInfo_Value(track, "D_PAN")
                            local delta = new_pan - old_pan
                            for j=1, #state.tracks do
                                if state.tracksSel[j] then
                                    local t = state.tracks[j]
                                    local current_pan = reaper.GetMediaTrackInfo_Value(t, "D_PAN")
                                    reaper.SetMediaTrackInfo_Value(t, "D_PAN", math.max(-1, math.min(1, current_pan + delta)))
                                end
                            end
                        else
                            reaper.SetMediaTrackInfo_Value(track, "D_PAN", new_pan)
                        end
                        reaper.Undo_EndBlock("Set Pan", -1)
                    elseif info.param_type == 'WIDTH' then
                         local new_width = math.max(-100, math.min(100, num_val)) / 100.0
                         if state.tracksSel[info.track_idx] then
                             local old_width = reaper.GetMediaTrackInfo_Value(track, "D_WIDTH")
                             local delta = new_width - old_width
                             for j=1, #state.tracks do
                                 if state.tracksSel[j] then
                                    local t = state.tracks[j]
                                    local current_width = reaper.GetMediaTrackInfo_Value(t, "D_WIDTH")
                                    reaper.SetMediaTrackInfo_Value(t, "D_WIDTH", math.max(-1, math.min(1, current_width + delta)))
                                 end
                             end
                         else
                            reaper.SetMediaTrackInfo_Value(track, "D_WIDTH", new_width)
                         end
                         reaper.Undo_EndBlock("Set Width", -1)
                    elseif info.param_type == 'SEND_VOL' then
                        reaper.SetTrackSendInfo_Value(track, 0, info.send_idx, "D_VOL", DBToGain(num_val))
                        reaper.Undo_EndBlock("Set Send Volume", -1)
                    elseif info.param_type == 'SEND_PAN' then
                        reaper.SetTrackSendInfo_Value(track, 0, info.send_idx, "D_PAN", math.max(-100, math.min(100, num_val)) / 100.0)
                        reaper.Undo_EndBlock("Set Send Pan", -1)
                    elseif info.param_type == 'RECEIVE_VOL' then
                        reaper.SetTrackSendInfo_Value(info.receive_info.src_track, 0, info.receive_info.send_idx, "D_VOL", DBToGain(num_val))
                        reaper.Undo_EndBlock("Set Receive Volume", -1)
                    elseif info.param_type == 'RECEIVE_PAN' then
                        reaper.SetTrackSendInfo_Value(info.receive_info.src_track, 0, info.receive_info.send_idx, "D_PAN", math.max(-100, math.min(100, num_val)) / 100.0)
                        reaper.Undo_EndBlock("Set Receive Pan", -1)
                    elseif info.param_type == 'FX_PARAM' then
                        local new_norm_val = math.max(0, math.min(1000, num_val)) / 1000.0
                        reaper.TrackFX_SetParam(track, info.fx_info.fx_idx, info.fx_info.param_idx, new_norm_val)
                        reaper.Undo_EndBlock("Set FX Parameter", -1)
                    else
                        reaper.Undo_EndBlock("", -1) -- Cancel block if type not matched
                    end
                end
                imgui.CloseCurrentPopup(ctx)
            end
            imgui.SameLine(ctx)
            if imgui.Button(ctx, "Cancel", 120, 0) then
                imgui.CloseCurrentPopup(ctx)
            end

            imgui.EndPopup(ctx)
        end

        -- NEW POPUP for Renaming a Custom Menu Item
        if state.open_rename_popup then
            imgui.OpenPopup(ctx, "RenameMenuItemPopup")
            state.open_rename_popup = false -- Reset trigger
        end

        imgui.SetNextWindowSize(ctx, 300, 120, imgui.Cond_Appearing)
        if imgui.BeginPopupModal(ctx, "RenameMenuItemPopup") then
            imgui.Text(ctx, "Rename Menu Item")
            imgui.Separator(ctx)
            
            imgui.Text(ctx, "New Name:")
            imgui.SameLine(ctx)
            imgui.PushItemWidth(ctx, -1)
            -- *** THIS IS THE FIX ***
            -- Added 'nil' as the 6th argument
            local name_changed, new_name_str = imgui.InputText(ctx, "##RenameInput", state.rename_item_new_name, 128, imgui.InputTextFlags_EnterReturnsTrue, nil)
            
            -- Continuously update state
            state.rename_item_new_name = new_name_str
            
            if imgui.IsWindowAppearing(ctx) then imgui.SetKeyboardFocusHere(ctx, -1) end -- Focus input on open
            imgui.PopItemWidth(ctx)

            if imgui.Button(ctx, "OK", 120, 0) or name_changed then
                if state.rename_item_path and state.rename_item_new_name ~= "" then
                    execute_menu_rename(state.rename_item_path, state.rename_item_new_name)
                end
                state.rename_item_path = nil -- Reset path
                imgui.CloseCurrentPopup(ctx)
            end
            imgui.SameLine(ctx)
            if imgui.Button(ctx, "Cancel", 120, 0) then
                state.rename_item_path = nil -- Reset path
                imgui.CloseCurrentPopup(ctx)
            end

            imgui.EndPopup(ctx)
        end
        
        -- EDIT GROUP NAMES POPUP
        if state.open_group_rename_popup then 
            imgui.OpenPopup(ctx, "EditGroupNamesPopup")
            state.open_group_rename_popup = false 
        end
        
        imgui.SetNextWindowSize(ctx, 260, 330, imgui.Cond_Appearing)
        if imgui.BeginPopupModal(ctx, "EditGroupNamesPopup", true, imgui.WindowFlags_NoResize) then
            imgui.Text(ctx, "Rename Groups")
            imgui.Separator(ctx)
            
            for i=1, 8 do
                imgui.PushID(ctx, i)
                imgui.AlignTextToFramePadding(ctx)
                imgui.PushStyleColor(ctx, imgui.Col_Text, state.group_colors[i])
                imgui.Text(ctx, "Group "..i)
                imgui.PopStyleColor(ctx)
                imgui.SameLine(ctx, 70)
                imgui.PushItemWidth(ctx, -1)
                
                local name_val = state.group_names[i] or ""
                local changed, new_name = imgui.InputText(ctx, "##grpname", name_val, 32)
                if changed then state.group_names[i] = new_name end
                
                imgui.PopItemWidth(ctx)
                imgui.PopID(ctx)
            end
            
            imgui.Separator(ctx)
            if imgui.Button(ctx, "Save & Close", 120, 0) then
                SaveProjectGroups()
                imgui.CloseCurrentPopup(ctx)
            end
            imgui.SameLine(ctx)
            if imgui.Button(ctx, "Cancel", 120, 0) then
                -- Reload to discard changes? 
                LoadProjectGroups() -- Simple revert
                imgui.CloseCurrentPopup(ctx)
            end
            
            imgui.EndPopup(ctx)
        end

        imgui.End(ctx)
    end
    
    PopTheme() -- Pop styles for the window (must match SetTheme)

    if state.is_open then reaper.defer(loop) end
end

-- SEND MATRIX DRAWING
function DrawSendMatrix(ctx)
    -- Calculate available space
    local content_avail = imgui.GetContentRegionAvail(ctx)
    local width = type(content_avail) == 'table' and content_avail.x or content_avail
    local height = type(content_avail) == 'table' and content_avail.y or content_avail
    
    -- Filter Pinned Tracks
    local col_tracks = {}
    for _, guid in ipairs(state.matrix_pinned_tracks) do
        local track = reaper.BR_GetMediaTrackByGUID(0, guid)
        if track then table.insert(col_tracks, track) end
    end
    
    if #col_tracks == 0 then
        imgui.PushStyleColor(ctx, imgui.Col_Text, PackColor(1, 1, 0, 1))
        imgui.Text(ctx, "Send Matrix: No tracks pinned as Destinations.")
        imgui.PopStyleColor(ctx)
        imgui.Text(ctx, "Usage: Right-click a Reverb/Aux track > 'Pooling / Grouping' > '📌 Pin to Matrix'")
        return
    end
    
    local cell_w = 60
    local row_header_w = 150
    
    -- Use 0 for border (false) if integer is required, or simpler signature.
    -- Most ReaImGui examples use: BeginChild(ctx, id, w, h, border_flags?)
    -- Let's try skipping the border arg if it's optional, or pass 0.
    -- Error said "number expected, got boolean". So arg 5 is a number. 
    -- Arg 5 is likely 'border' as int (0 or 1), or it is 'flags' directly if border is omitted?
    -- If flags is 6th... 
    -- Let's assume arg 5 is border(int) then 6 is flags.
    -- Or signature is BeginChild(ctx, id, w, h, flags). (Count: 5 args total).
    -- User passed 6 args.
    -- Let's match the other usage: imgui.BeginChild(ctx, "TrackListChildSends", 0, -2) -> 4 args.
    -- So flags is likely 5th arg.
    -- Correct Signature: BeginChild(ctx, id, width, height, child_flags, window_flags)
    -- We pass 0 for child_flags (No Border, No Resize)
    -- We pass WindowFlags_HorizontalScrollbar as window_flags
    imgui.BeginChild(ctx, "MatrixRegion", width, height, 0, imgui.WindowFlags_HorizontalScrollbar)
    
    -- Header Row
    imgui.SetCursorPosX(ctx, row_header_w) 
    for _, dest_track in ipairs(col_tracks) do
        local _, name = reaper.GetTrackName(dest_track)
        imgui.PushItemWidth(ctx, cell_w)
        if imgui.Button(ctx, name, cell_w - 4, 0) then
            -- Click header?
        end
        imgui.SameLine(ctx)
        imgui.PopItemWidth(ctx)
    end
    imgui.NewLine(ctx)
    
    -- Rows
    for i, track in ipairs(state.tracks) do
        -- Safety check for is_visible
        local is_vis = true
        if state.is_visible and state.is_visible[i] ~= nil then
            is_vis = state.is_visible[i]
        end
        
        if is_vis then
             local _, name = reaper.GetTrackName(track)
             
             -- Row Header
             imgui.PushItemWidth(ctx, row_header_w)
             if imgui.Selectable(ctx, name .. "##Row"..i, state.tracksSel[i], 0, row_header_w - 10, 0) then
                 local is_ctrl = imgui.IsKeyDown(ctx, 4096) or imgui.IsKeyDown(ctx, 1)
                 SetTrackSelected(track, not state.tracksSel[i], is_ctrl)
             end
             imgui.PopItemWidth(ctx)
             imgui.SameLine(ctx, row_header_w)
             
             -- Cells
             for c_idx, dest_track in ipairs(col_tracks) do
                 if track == dest_track then
                     imgui.PushStyleColor(ctx, imgui.Col_Border, PackColor(0.2,0.2,0.2,0.5))
                     imgui.Dummy(ctx, cell_w, 20)
                     imgui.PopStyleColor(ctx)
                 else
                     local send_idx = nil
                     local send_vol = 0
                     local cnt = reaper.GetTrackNumSends(track, 0)
                     for s=0, cnt-1 do
                         local dest = reaper.GetTrackSendInfo_Value(track, 0, s, "P_DESTTRACK")
                         if dest == dest_track then 
                            send_idx = s 
                            send_vol = reaper.GetTrackSendInfo_Value(track, 0, s, "D_VOL")
                            break 
                         end
                     end
                     
                     if send_idx then
                         local active_col = PackColor(0.2, 0.8, 1, 1)
                         imgui.PushStyleColor(ctx, imgui.Col_Button, active_col)
                         local db_val = GainToDB(send_vol)
                         local display = string.format("%.0f", db_val)
                         
                        imgui.Button(ctx, display.."##Send"..i.."_"..c_idx, cell_w - 4, 18)
                         
                         if imgui.IsItemActive(ctx) and imgui.IsMouseDragging(ctx, 0) then
                             local delta_x, delta_y = imgui.GetMouseDragDelta(ctx, 0)
                             local sensitivity = 0.5
                             local new_db = db_val + (-delta_y * sensitivity)
                             if new_db > 12 then new_db = 12 end
                             reaper.SetTrackSendInfo_Value(track, 0, send_idx, "D_VOL", DBToGain(new_db))
                             imgui.ResetMouseDragDelta(ctx, 0)
                         end
                         
                         if imgui.IsItemClicked(ctx, 1) then
                             reaper.RemoveTrackSend(track, 0, send_idx)
                         end
                         ShowTooltip("Drag: Adjust Volume\nRight-Click: Delete Send")
                         imgui.PopStyleColor(ctx)
                     else
                         imgui.PushStyleColor(ctx, imgui.Col_Button, PackColor(0.15,0.15,0.15,1))
                         if imgui.Button(ctx, "+##Create"..i.."_"..c_idx, cell_w - 4, 18) then
                             reaper.CreateTrackSend(track, dest_track)
                         end
                         ShowTooltip("Click to Create Send to " .. select(2, reaper.GetTrackName(dest_track)))
                         imgui.PopStyleColor(ctx)
                     end
                 end
                 imgui.SameLine(ctx)
             end
             imgui.NewLine(ctx)
        end
    end
    imgui.EndChild(ctx)
end

-- MASTER LOUDNESS FUNCTIONS
function GetMasterLoudnessMeter()
    local master = reaper.GetMasterTrack(0)
    local cnt = reaper.TrackFX_GetCount(master)
    for i=0, cnt-1 do
        local _, name = reaper.TrackFX_GetFXName(master, i, "")
        if name:match("Loudness Meter") and name:match("LUFS") then
            return i
        end
    end
    return nil
end

function EnsureMasterLoudnessMeter()
    local master = reaper.GetMasterTrack(0)
    local idx = GetMasterLoudnessMeter()
    if not idx then
        idx = reaper.TrackFX_AddByName(master, "analysis/loudness_meter", false, -1)
    end
    return idx
end

function GetMasterLoudnessData()
    local master = reaper.GetMasterTrack(0)
    local idx = GetMasterLoudnessMeter()
    
    if not idx then return { status = "MISSING" } end
    
    local is_enabled = reaper.TrackFX_GetEnabled(master, idx)
    local is_offline = reaper.TrackFX_GetOffline(master, idx)
    
    if not is_enabled or is_offline then
        return { status = "OFFLINE", fx_idx = idx }
    end
    
    local lufs_m, lufs_s, lufs_i = -144, -144, -144
    local rms_m, rms_i, peak_db, lra = -144, -144, -144, 0
    local num_params = reaper.TrackFX_GetNumParams(master, idx)
    
    for p=0, num_params-1 do
        local _, p_name = reaper.TrackFX_GetParamName(master, idx, p, "")
        local val = reaper.TrackFX_GetParam(master, idx, p)
        
        -- Match "output" parameters specifically
        if p_name:match("LUFS%-M.*output") then lufs_m = val end
        if p_name:match("LUFS%-S.*output") then lufs_s = val end
        if p_name:match("LUFS%-I.*output") then lufs_i = val end
        if p_name:match("RMS%-M.*output") then rms_m = val end
        if p_name:match("RMS%-I.*output") then rms_i = val end
        if p_name:match("Peak.*output") then peak_db = val end
        if p_name:match("Loudness Range output") or p_name:match("LRA.*output") then lra = val end
    end
    
    -- Fallback strategy: If names didn't match (maybe locale?), try fixed indices for standard plugin
    if not debug_found and num_params > 8 then
       -- Standard "analysis/loudness_meter" structure guess?
       -- Actually, let's just stick to name matching but match looser.
    end
    

    
    return { status = "ACTIVE", m = lufs_m, s = lufs_s, i = lufs_i, rms_m = rms_m, rms_i = rms_i, peak = peak_db, fx_idx = idx, lra = lra }
end

function DrawMasterLoudness(ctx)
    local data = GetMasterLoudnessData()
    
    imgui.BeginGroup(ctx)
    imgui.PushStyleVar(ctx, imgui.StyleVar_FramePadding, 4, 2)
    imgui.Text(ctx, "MASTER LUFS")
    imgui.SameLine(ctx)
    
    if data.status == "MISSING" then
        imgui.PushStyleColor(ctx, imgui.Col_Button, PackColor(0.2, 0.2, 0.2, 1))
        if imgui.Button(ctx, "ADD METER") then EnsureMasterLoudnessMeter() end
        imgui.PopStyleColor(ctx)
    elseif data.status == "OFFLINE" then
        imgui.PushStyleColor(ctx, imgui.Col_Button, PackColor(0.8, 0, 0, 1))
        if imgui.Button(ctx, "⏻ POWER ON") then
             reaper.TrackFX_SetOffline(reaper.GetMasterTrack(0), data.fx_idx, false)
             reaper.TrackFX_SetEnabled(reaper.GetMasterTrack(0), data.fx_idx, true)
        end
        imgui.PopStyleColor(ctx)
    elseif data.status == "ACTIVE" then
        imgui.Text(ctx, "M:")
        imgui.SameLine(ctx); imgui.TextColored(ctx, PackColor(0.4, 1, 0.4, 1), string.format("%.1f", data.m))
        imgui.SameLine(ctx, 0, 10); imgui.Text(ctx, "S:")
        imgui.SameLine(ctx); imgui.TextColored(ctx, PackColor(0.2, 0.8, 1, 1), string.format("%.1f", data.s))
        imgui.SameLine(ctx, 0, 10); imgui.Text(ctx, "I:")
        imgui.SameLine(ctx); imgui.TextColored(ctx, PackColor(1, 0.8, 0.2, 1), string.format("%.1f", data.i))
    end
    
    imgui.PopStyleVar(ctx)
    imgui.EndGroup(ctx)
    if imgui.IsItemHovered(ctx) then ShowTooltip("Master Loudness (M: Momentary, S: Short-term, I: Integrated)") end
end

function DrawStatusBar(ctx, bar_height)
    local master_track = reaper.GetMasterTrack(0)
    local w, h = imgui.GetWindowSize(ctx)
    local p_x, p_y = imgui.GetCursorScreenPos(ctx)
    
    -- Force position to bottom of window
    imgui.SetCursorPosY(ctx, h - bar_height)
    local start_y = imgui.GetCursorPosY(ctx)
    local dl = imgui.GetWindowDrawList(ctx)
    local scr_x, scr_y = imgui.GetCursorScreenPos(ctx)
    
    -- Draw Background
    imgui.DrawList_AddRectFilled(dl, scr_x, scr_y, scr_x + w, scr_y + bar_height, 0x111111FF)
    imgui.DrawList_AddLine(dl, scr_x, scr_y, scr_x + w, scr_y, 0x444444FF) -- Top border
    
    local lufs_data = GetMasterLoudnessData()
    
    -- Vertical align centers (Lifted up slightly)
    local text_y_off = 4 
    imgui.SetCursorPos(ctx, 10, start_y + text_y_off)
    
    imgui.BeginGroup(ctx)
    -- Reduced spacing to fit LRA
    imgui.PushStyleVar(ctx, imgui.StyleVar_ItemSpacing, 10, 0)
    
    local function DrawStat(label, val, val_col)
        imgui.TextColored(ctx, 0xAAAAAAFF, label)
        imgui.SameLine(ctx)
        
        local start_val_x = imgui.GetCursorPosX(ctx)
        local val_str = "---"
        if val then
            if val <= -90 then
                val_str = "-inf"
                if not val_col then val_col = 0x666666FF end -- Dim gray default for silence
            else
                val_str = string.format("%.1f", val)
            end
        end
        
        imgui.TextColored(ctx, val_col or 0xFFFFFFFF, val_str)
        imgui.SameLine(ctx)
        
        -- Fixed width for value to prevent jitter (approx 50px)
        local end_val_x = imgui.GetCursorPosX(ctx)
        local width_so_far = end_val_x - start_val_x
        if width_so_far < 50 then
            imgui.Dummy(ctx, 50 - width_so_far, 1)
            imgui.SameLine(ctx)
        end
    end
    
    if lufs_data.status == "ACTIVE" then
        -- 1. True Peak (from Plugin)
        local peak_val = lufs_data.peak or -144
        local peak_col = 0x00FF00FF
        if peak_val > -1.0 then peak_col = 0xFF0000FF elseif peak_val > -6.0 then peak_col = 0xFFFF00FF end
        
        -- Special handling for Peak String to include "dB"
        imgui.TextColored(ctx, 0xAAAAAAFF, "TRUE PEAK:")
        imgui.SameLine(ctx)
        
        local start_p_x = imgui.GetCursorPosX(ctx)
        if peak_val <= -90 then
            imgui.TextColored(ctx, 0x666666FF, "-inf dB")
        else
            imgui.TextColored(ctx, peak_col, string.format("%.1f dB", peak_val))
        end
        imgui.SameLine(ctx)
        
        -- Fixed width for Peak value (approx 60px to include " dB")
        local end_p_x = imgui.GetCursorPosX(ctx)
        local width_p_so_far = end_p_x - start_p_x
        if width_p_so_far < 60 then
            imgui.Dummy(ctx, 60 - width_p_so_far, 1)
            imgui.SameLine(ctx)
        end
        
        -- Separator
        imgui.TextDisabled(ctx, "|")
        imgui.SameLine(ctx)
        
        -- 2. RMS (Momentary)
        DrawStat("RMS-M:", lufs_data.rms_m, 0xDDDDDDFF)
        
        imgui.TextDisabled(ctx, "|")
        imgui.SameLine(ctx)
        
        -- 3. LUFS
        DrawStat("LUFS-M:", lufs_data.m, 0x00FF00FF)
        DrawStat("LUFS-S:", lufs_data.s, 0x00FFFFFF)
        DrawStat("LUFS-I:", lufs_data.i, 0xFFCC00FF)
        
        -- LRA Display
        if lufs_data.lra then
             imgui.TextDisabled(ctx, "|")
             imgui.SameLine(ctx)
             DrawStat("LRA:", lufs_data.lra, 0xAAAAAAFF)
        end
        
        
    elseif lufs_data.status == "MISSING" then
        if imgui.Button(ctx, "Install Loudness Meter on Master") then EnsureMasterLoudnessMeter() end
    elseif lufs_data.status == "OFFLINE" then
        -- Ensure button is visible by slight padding adjustment or centering
 
        if imgui.Button(ctx, "Meter Offline - Click to Enable") then 
             reaper.TrackFX_SetOffline(master_track, lufs_data.fx_idx, false)
             reaper.TrackFX_SetEnabled(master_track, lufs_data.fx_idx, true)
        end
    else
        imgui.Text(ctx, "Status: " .. tostring(lufs_data.status))
    end
    
    imgui.PopStyleVar(ctx)
    imgui.EndGroup(ctx)
end

-- --- SCRIPT START AND EXIT ---
function Main()
    load_pinned_params()
    load_custom_menu()
    load_theme_setting()
    update_and_check_tracks()
    loop()
end

reaper.defer(Main)

