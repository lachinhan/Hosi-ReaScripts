--[[
@description    Hosi Mini Track Mixer (ReaImGui Version)
@author         Hosi
@version        1.1
@reaper_version 6.0
@provides
  [main] . > Hosi_Mini Track Mixer (ReaImGui).lua

@about
  # Hosi Mini Track Mixer (ReaImGui Version)

  A small GUI workflow for mixing track volume, pan, and FX.

  ## Requirements:
  - REAPER 6.0+
  - js_ReaScriptAPI extension
  - ReaImGui library

@changelog
  v1.1 (2025-09-23)
  - Added: Double-click a folder track to collapse/expand its child tracks.
  v1.0 (2025-09-23)
  - Initial release.
--]]

-- --- USER CONFIGURATION ---
local config = {
    win_title = "Hosi Mini Track Mixer v1.1",
    refresh_interval = 0.5, -- Shorter interval for faster response
    indent_size = 15.0 -- Indent size for child tracks
}

-- --- INITIALIZE REAIM GUI ---
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local imgui = require('imgui')('0.10')

if not imgui or type(imgui) ~= "table" then
  reaper.ShowMessageBox("Could not initialize ReaImGui library.\n\nPlease install it (v0.10+) via ReaPack.", "ReaImGui Error", 0)
  return
end

local ctx = imgui.CreateContext(config.win_title)

-- --- STATE VARIABLES ---
local state = {
    is_open = true,
    last_refresh_time = 0,
    change_pan = true, -- true = Pan, false = Volume
    filter_text = "",
    -- Track data
    tracks = {},
    tracksPan = {},
    tracksVol = {},
    tracksSel = {},
    tracksMut = {},
    tracksSol = {},
    tracksFX = {},
    tracksDepth = {},
    isFolder = {},
    tracksGanged = {},
    folderCollapsed = {}, -- New: Store folder collapse state
    -- Presets
    preset1 = { track = {} },
    preset2 = { track = {} },
    preset3 = { track = {} },
    preset4 = { track = {} },
    preset5 = { track = {} }
}

-- --- UTILITY AND LOGIC FUNCTIONS ---

function PackColor(r, g, b, a)
    local r_int = math.floor(r * 255 + 0.5)
    local g_int = math.floor(g * 255 + 0.5)
    local b_int = math.floor(b * 255 + 0.5)
    local a_int = math.floor(a * 255 + 0.5)
    return a_int * 0x1000000 + b_int * 0x10000 + g_int * 0x100 + r_int
end

function GainToDB(gain)
    if gain < 0.0000000298 then return -144.0 end
    return 20 * (math.log(gain) / math.log(10))
end

function DBToGain(db)
    return 10 ^ (db / 20)
end

function update_and_check_tracks()
    local changed = false
    local new_track_count = reaper.CountTracks(0)

    if #state.tracks ~= new_track_count then
        changed = true
        state.tracks = {}
        state.tracksSel = {}
        state.tracksDepth = {}
        state.isFolder = {}
        state.tracksGanged = {}
        state.folderCollapsed = {} -- Reset collapse state
    end

    for i = 1, new_track_count do
        local track = reaper.GetTrack(0, i - 1)
        local fx_visible = reaper.TrackFX_GetChainVisible(track)
        local pan = reaper.GetMediaTrackInfo_Value(track, "D_PAN")
        local vol = reaper.GetMediaTrackInfo_Value(track, "D_VOL")
        local mute = reaper.GetMediaTrackInfo_Value(track, "B_MUTE")
        local solo = reaper.GetMediaTrackInfo_Value(track, "I_SOLO")
        local track_depth = reaper.GetTrackDepth(track)
        local is_folder = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1
        
        if state.tracks[i] ~= track or state.tracksPan[i] ~= pan or state.tracksVol[i] ~= vol or
           state.tracksMut[i] ~= mute or state.tracksSol[i] ~= solo or state.tracksFX[i] ~= fx_visible or
           state.tracksDepth[i] ~= track_depth or state.isFolder[i] ~= is_folder then
            changed = true
        end

        state.tracks[i] = track
        state.tracksPan[i] = pan
        state.tracksVol[i] = vol
        state.tracksMut[i] = mute
        state.tracksSol[i] = solo
        state.tracksFX[i] = fx_visible
        state.tracksDepth[i] = track_depth
        state.isFolder[i] = is_folder
        
        if state.tracksSel[i] == nil then state.tracksSel[i] = false end
        if state.tracksGanged[i] == nil then state.tracksGanged[i] = false end
        if state.folderCollapsed[i] == nil then state.folderCollapsed[i] = false end
    end
    return changed
end

function save_preset(preset_num)
    local preset_table
    if preset_num == 1 then preset_table = state.preset1
    elseif preset_num == 2 then preset_table = state.preset2
    elseif preset_num == 3 then preset_table = state.preset3
    elseif preset_num == 4 then preset_table = state.preset4
    elseif preset_num == 5 then preset_table = state.preset5
    else return end

    preset_table.track = {}
    preset_table.pan = {}
    preset_table.vol = {}
    preset_table.mute = {}
    preset_table.solo = {}
    
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
    local preset_table
    if preset_num == 1 then preset_table = state.preset1
    elseif preset_num == 2 then preset_table = state.preset2
    elseif preset_num == 3 then preset_table = state.preset3
    elseif preset_num == 4 then preset_table = state.preset4
    elseif preset_num == 5 then preset_table = state.preset5
    else return end

    if #preset_table.track == 0 then
        reaper.ShowMessageBox("Preset " .. preset_num .. " is empty.", "Notification", 0)
        return
    end

    for i = 1, #preset_table.track do
        if state.tracks[i] and reaper.ValidatePtr(state.tracks[i], "MediaTrack*") then
            reaper.SetMediaTrackInfo_Value(state.tracks[i], "D_VOL", preset_table.vol[i])
            reaper.SetMediaTrackInfo_Value(state.tracks[i], "D_PAN", preset_table.pan[i])
            reaper.SetMediaTrackInfo_Value(state.tracks[i], "B_MUTE", preset_table.mute[i])
            reaper.SetMediaTrackInfo_Value(state.tracks[i], "I_SOLO", preset_table.solo[i])
        end
    end
    reaper.ShowMessageBox("Preset " .. preset_num .. " loaded.", "Notification", 0)
end

-- --- MAIN GUI LOOP ---
function loop()
    local current_time = reaper.time_precise()
    if current_time > state.last_refresh_time + config.refresh_interval then
        update_and_check_tracks()
        state.last_refresh_time = current_time
    end

    local visible
    visible, state.is_open = imgui.Begin(ctx, config.win_title, state.is_open)
    if visible then
        -- New Toolbar
        local content_avail = imgui.GetContentRegionAvail(ctx)
        local available_w = type(content_avail) == 'table' and content_avail.x or content_avail
        
        local preset_btn_w = 25
        local preset_spacing = 2
        local presets_width = (preset_btn_w * 5) + (preset_spacing * 4)
        local toggle_btn_w = 110
        local group_spacing = 10
        local search_width = available_w - presets_width - toggle_btn_w - group_spacing - 15
        if search_width < 50 then search_width = 50 end
        
        -- 1. Search Bar
        imgui.PushItemWidth(ctx, search_width)
        local filter_changed, new_filter_text = imgui.InputText(ctx, "##Search", state.filter_text, 256)
        if filter_changed then state.filter_text = new_filter_text end
        if state.filter_text == "" then
            local min_x, min_y = imgui.GetItemRectMin(ctx)
            local max_x, max_y = imgui.GetItemRectMax(ctx)
            local draw_list = imgui.GetWindowDrawList(ctx)
            local text_height = 16
            local padding_x = 5
            local padding_y = ((max_y - min_y) - text_height) / 2
            imgui.DrawList_AddText(draw_list, min_x + padding_x, min_y + padding_y, PackColor(0.5, 0.5, 0.5, 1.0), "Search...")
        end
        imgui.PopItemWidth(ctx)
        
        -- 2. Toggle Button
        imgui.SameLine(ctx, 0, group_spacing)
        if imgui.Button(ctx, state.change_pan and "EDITING PAN" or "EDITING VOL", toggle_btn_w, 25) then 
            state.change_pan = not state.change_pan
        end
        
        -- 3. Preset Buttons
        imgui.SameLine(ctx)
        for i=1, 5 do
            if i > 1 then imgui.SameLine(ctx, 0, preset_spacing) end
            if imgui.Button(ctx, "P"..i, preset_btn_w, 25) then load_preset(i) end
            if imgui.IsItemClicked(ctx, 1) then save_preset(i) end
        end

        imgui.Separator(ctx)

        local flags = imgui.TableFlags_BordersInnerV + imgui.TableFlags_Resizable
        if imgui.BeginTable(ctx, 'MainMixerArea', 2, flags) then
            imgui.TableSetupColumn(ctx, "Tracks", imgui.TableColumnFlags_WidthFixed, 245)
            imgui.TableSetupColumn(ctx, "Controls", imgui.TableColumnFlags_WidthStretch)

            local hide_children_of_collapsed_folder = false
            local collapsed_folder_depth = -1

            for i = 1, #state.tracks do
                local track = state.tracks[i]
                if reaper.ValidatePtr(track, "MediaTrack*") then
                    
                    local current_depth = state.tracksDepth[i]
                    if hide_children_of_collapsed_folder and current_depth <= collapsed_folder_depth then
                        hide_children_of_collapsed_folder = false
                        collapsed_folder_depth = -1
                    end

                    local _, name = reaper.GetTrackName(track)
                    local show_track = true
                    
                    if hide_children_of_collapsed_folder then
                        show_track = false
                    end

                    if show_track and state.filter_text ~= "" and not string.find(string.lower(name), string.lower(state.filter_text), 1, true) then
                        show_track = false
                    end

                    if show_track then
                        local indent_pixels = state.tracksDepth[i] * config.indent_size
                        
                        -- Column 1: Track Info
                        imgui.TableNextColumn(ctx)
                        if indent_pixels > 0 then imgui.Indent(ctx, indent_pixels) end
                        
                        if imgui.BeginTable(ctx, 'track_line'..i, 3, 0) then
                            imgui.TableSetupColumn(ctx, 'gang'..i, imgui.TableColumnFlags_WidthFixed, 25)
                            imgui.TableSetupColumn(ctx, 'name'..i, imgui.TableColumnFlags_WidthStretch)
                            imgui.TableSetupColumn(ctx, 'buttons'..i, imgui.TableColumnFlags_WidthFixed, 85)
                
                            imgui.TableNextColumn(ctx)
                            local gang_changed, gang_new = imgui.Checkbox(ctx, "##gang"..i, state.tracksGanged[i])
                            if gang_changed then state.tracksGanged[i] = gang_new end

                            imgui.TableNextColumn(ctx)
                            local display_name = string.format("%02d: %s", i, name)
                            if state.isFolder[i] then
                                if state.folderCollapsed[i] then
                                    display_name = "📂 " .. display_name -- Collapsed icon
                                else
                                    display_name = "📁 " .. display_name -- Expanded icon
                                end
                            end

                            local r, g, b = reaper.ColorFromNative(reaper.GetTrackColor(track))
                            
                            imgui.PushStyleColor(ctx, imgui.Col_Header, PackColor(r/255, g/255, b/255, 0.3))
                            imgui.PushStyleColor(ctx, imgui.Col_HeaderHovered, PackColor(r/255, g/255, b/255, 0.5))
                            imgui.PushStyleColor(ctx, imgui.Col_HeaderActive, PackColor(r/255, g/255, b/255, 0.7))
                            
                            local sel_changed = imgui.Selectable(ctx, display_name, state.tracksSel[i])
                            if sel_changed then 
                                state.tracksSel[i] = not state.tracksSel[i] 
                            end
                            
                            if imgui.IsItemHovered(ctx) and imgui.IsMouseDoubleClicked(ctx, 0) then
                                if state.isFolder[i] then
                                    state.folderCollapsed[i] = not state.folderCollapsed[i]
                                end
                            end
                
                            imgui.PopStyleColor(ctx, 3)
                
                            imgui.TableNextColumn(ctx)
                            
                            if state.tracksMut[i] == 1 then imgui.PushStyleColor(ctx, imgui.Col_Button, PackColor(1, 0, 0, 0.5)) end
                            if imgui.Button(ctx, "M##"..i, 20, 0) then reaper.SetMediaTrackInfo_Value(track, "B_MUTE", 1 - state.tracksMut[i]) end
                            if state.tracksMut[i] == 1 then imgui.PopStyleColor(ctx) end
                            
                            imgui.SameLine(ctx, 0, 2)
                            if state.tracksSol[i] > 0 then imgui.PushStyleColor(ctx, imgui.Col_Button, PackColor(1, 1, 0, 0.5)) end
                            if imgui.Button(ctx, "S##"..i, 20, 0) then reaper.SetMediaTrackInfo_Value(track, "I_SOLO", state.tracksSol[i] > 0 and 0 or 1) end
                            if state.tracksSol[i] > 0 then imgui.PopStyleColor(ctx) end
                            
                            imgui.SameLine(ctx, 0, 2)
                            if state.tracksFX[i] ~= -1 then imgui.PushStyleColor(ctx, imgui.Col_Button, PackColor(0, 1, 0, 0.5)) end
                            if imgui.Button(ctx, "FX##"..i, 20, 0) then reaper.TrackFX_Show(track, 0, state.tracksFX[i] == -1 and 1 or -1) end
                            if state.tracksFX[i] ~= -1 then imgui.PopStyleColor(ctx) end
                
                            imgui.EndTable(ctx)
                        end

                        if indent_pixels > 0 then imgui.Unindent(ctx, indent_pixels) end
                        
                        -- Column 2: Slider
                        imgui.TableNextColumn(ctx)
                        if state.change_pan then
                            local label, value, min, max = "##Pan" .. i, state.tracksPan[i], -100, 100
                            local int_value = math.floor(value * 100 + 0.5)
                            imgui.PushItemWidth(ctx, -50) -- Reserve space for text
                            local changed, new_val_int = imgui.SliderInt(ctx, label, int_value, min, max, "")
                            imgui.PopItemWidth(ctx)
                            imgui.SameLine(ctx, 0, 5)
                            imgui.Text(ctx, string.format("%d", int_value))

                            if changed then
                                local old_pan = state.tracksPan[i]
                                local new_pan = new_val_int / 100.0
                                reaper.SetMediaTrackInfo_Value(track, "D_PAN", new_pan)
                                if state.tracksGanged[i] then
                                    local delta_pan = new_pan - old_pan
                                    for j = 1, #state.tracks do
                                        if i ~= j and state.tracksGanged[j] then
                                            local other_track = state.tracks[j]
                                            if reaper.ValidatePtr(other_track, "MediaTrack*") then
                                                local current_other_pan = state.tracksPan[j]
                                                local new_other_pan = current_other_pan + delta_pan
                                                if new_other_pan > 1.0 then new_other_pan = 1.0 end
                                                if new_other_pan < -1.0 then new_other_pan = -1.0 end
                                                reaper.SetMediaTrackInfo_Value(other_track, "D_PAN", new_other_pan)
                                            end
                                        end
                                    end
                                end
                                update_and_check_tracks()
                            end
                            if (imgui.IsItemHovered(ctx) and imgui.IsMouseDoubleClicked(ctx, 0)) or imgui.IsItemClicked(ctx, 1) then
                                reaper.SetMediaTrackInfo_Value(track, "D_PAN", 0)
                                update_and_check_tracks()
                            end
                        else
                            local value_db, min_db, max_db, format = GainToDB(state.tracksVol[i]), -60, 12, "%.1f dB"
                            local slider_val
                            if value_db >= 0 then slider_val = (value_db / max_db) * 100
                            else slider_val = (value_db / math.abs(min_db)) * 100 end
                            slider_val = math.floor(slider_val + 0.5)
                            
                            local label = "##Vol" .. i
                            imgui.PushItemWidth(ctx, -60)
                            local changed, new_slider_val = imgui.SliderInt(ctx, label, slider_val, -100, 100, "")
                            imgui.PopItemWidth(ctx)
                            imgui.SameLine(ctx, 0, 5)
                            imgui.Text(ctx, string.format(format, value_db))

                            if changed then
                                local old_vol_db = GainToDB(state.tracksVol[i])
                                local new_db_val
                                if new_slider_val >= 0 then new_db_val = (new_slider_val / 100) * max_db
                                else new_db_val = (new_slider_val / 100) * math.abs(min_db) end
                                
                                reaper.SetMediaTrackInfo_Value(track, "D_VOL", DBToGain(new_db_val))
                                if state.tracksGanged[i] then
                                    local delta_db = new_db_val - old_vol_db
                                    for j = 1, #state.tracks do
                                        if i ~= j and state.tracksGanged[j] then
                                            local other_track = state.tracks[j]
                                            if reaper.ValidatePtr(other_track, "MediaTrack*") then
                                                local current_other_db = GainToDB(state.tracksVol[j])
                                                local new_other_db = current_other_db + delta_db
                                                reaper.SetMediaTrackInfo_Value(other_track, "D_VOL", DBToGain(new_other_db))
                                            end
                                        end
                                    end
                                end
                                update_and_check_tracks()
                            end
                            if (imgui.IsItemHovered(ctx) and imgui.IsMouseDoubleClicked(ctx, 0)) or imgui.IsItemClicked(ctx, 1) then
                                reaper.SetMediaTrackInfo_Value(track, "D_VOL", 1) -- 1.0 gain is 0 dB
                                update_and_check_tracks()
                            end
                        end
                        
                        if state.isFolder[i] and state.folderCollapsed[i] then
                            hide_children_of_collapsed_folder = true
                            collapsed_folder_depth = current_depth
                        end
                    end
                end
            end
            
            imgui.EndTable(ctx)
        end
        imgui.End(ctx)
    end

    if state.is_open then
        reaper.defer(loop)
    end
end

-- --- SCRIPT START AND EXIT ---
function Main()
    update_and_check_tracks()
    state.last_refresh_time = reaper.time_precise()
    loop()
end

reaper.defer(Main)

