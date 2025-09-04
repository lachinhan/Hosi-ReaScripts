--[[
@description FX Homie Manager (Toggleable Window)
@author      Sexan & Hosi (Combined)
@version     1.0.5
@link        https://forum.cockos.com/showthread.php?p=2680992#post2680992
@provides
  [main] . > Hosi_FX Homie Manager (Toggleable Window).lua

@changelog
  v1.0.5
    - New: Added "Delete All by Name" to the right-click context menu in TOGGLE mode.
  v1.0.4
    - New: Added a right-click context menu in TOGGLE Mode and FAVORITE Mode.
  v1.0.3
    - New: Added Drag and Drop to reorder FX in TOGGLE mode.
  v1.0.2
    - New: Added "Replace by Name" (Ctrl+Shift+R) to replace all instances of an FX across selected tracks.
    - Mod: Maintained "Replace All FX by Slot" (Ctrl+R) for existing functionality.
  v1.0.1
    - Fix: Improved the FX replacement logic for more stable performance.
  v1.0.0
    - Initial combined release (23/Aug/2025).
--]]

local r = reaper
local SCRIPT_TITLE = 'FX Homie Manager'

-- ///////////////////////////////////////////////////////////////////
-- // DEPENDENCY CHECKING
-- ///////////////////////////////////////////////////////////////////
local reaper_path = r.GetResourcePath()
local fx_browser_script_path = reaper_path .. "/Scripts/Sexan_Scripts/FX/Sexan_FX_Browser_ParserV7.lua"

function ThirdPartyDeps()
    local reapack_process; local repos={{name="Sexan_Scripts",url='https://github.com/GoranKovac/ReaScripts/raw/master/index.xml'}}; for i=1,#repos do local retinfo=r.ReaPack_GetRepositoryInfo(repos[i].name); if not retinfo then r.ReaPack_AddSetRepository(repos[i].name,repos[i].url,true,0); reapack_process=true end end; if reapack_process then r.ReaPack_ProcessQueue(true) end
end
local function CheckDeps()
    ThirdPartyDeps(); local deps={};
    if not r.ImGui_GetVersion then deps[#deps+1]='"Dear Imgui"' end
    if not r.JS_Window_Find then deps[#deps+1]='"js_ReaScriptAPI"' end
    if not r.file_exists(fx_browser_script_path) then deps[#deps+1]='"FX Browser Parser V7"' end
    if #deps~=0 then r.ShowMessageBox("Need Additional Packages.\nPlease Install it in next window","MISSING DEPENDENCIES",0); r.ReaPack_BrowsePackages(table.concat(deps," OR ")); return true end
end
if CheckDeps() then return end

dofile(r.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.9.3')
if r.file_exists(fx_browser_script_path) then dofile(fx_browser_script_path) end

local ctx = r.ImGui_CreateContext(SCRIPT_TITLE)
local FX_LIST = ReadFXFile()
if not FX_LIST then FX_LIST = MakeFXFiles() end

-- ///////////////////////////////////////////////////////////////////
-- // FAVORITES SYSTEM
-- ///////////////////////////////////////////////////////////////////
local favorites_file_path = r.GetResourcePath() .. "/Scripts/FX_Homie_Favorites.txt"
local FAVORITES_LIST = {}

function SaveFavorites()
    local file = io.open(favorites_file_path, "w")
    if not file then return end
    table.sort(FAVORITES_LIST)
    for _, fx_name in ipairs(FAVORITES_LIST) do
        file:write(fx_name .. "\n")
    end
    file:close()
end

function LoadFavorites()
    local file = io.open(favorites_file_path, "r")
    if not file then return {} end
    local favs = {}
    for line in file:lines() do
        if line ~= "" then table.insert(favs, line) end
    end
    file:close()
    table.sort(favs)
    return favs
end

FAVORITES_LIST = LoadFavorites()

function AddToFavorites(fx_name)
    for _, fav in ipairs(FAVORITES_LIST) do
        if fav == fx_name then return end -- Already exists
    end
    table.insert(FAVORITES_LIST, fx_name)
    SaveFavorites()
end

function RemoveFromFavorites(fx_name)
    for i, fav in ipairs(FAVORITES_LIST) do
        if fav == fx_name then
            table.remove(FAVORITES_LIST, i)
            SaveFavorites()
            return
        end
    end
end

-- ///////////////////////////////////////////////////////////////////
-- // UTILITY FUNCTIONS AND LOGIC
-- ///////////////////////////////////////////////////////////////////
local SLOT = 1
local MODE = "ADD" -- ADD, TOGGLE, FAVORITE
local REPLACE_INFO = { active = false, track = nil, slot = -1, name = "", mode = "SLOT" }
local FILTER = ''
local selected_entry = 1
local FOCUS = true

-- Helper function to safely check for truthy values from the Reaper API
function IsTruthy(val)
    if type(val) == 'boolean' then return val end
    if type(val) == 'number' then return val ~= 0 end
    return val ~= nil -- Default case
end

local function Lead_Trim_ws(s) return s:match '^%s*(.*)' end
local tsort=table.sort; function SortTable(tab,val1,val2) tsort(tab,function(a,b) if(a[val1]<b[val1])then return true elseif(a[val1]>b[val1])then return false else return a[val2]<b[val2]end end)end
local function SetMinMax(Input,Min,Max) if Input>=Max then Input=Max elseif Input<=Min then Input=Min end; return Input end
local function scroll(pos) if not r.ImGui_IsItemVisible(ctx)then r.ImGui_SetScrollHereY(ctx,pos)end end
local old_t={}; local old_filter=""; function Filter_FX_List(filter_text) if old_filter==filter_text then return old_t end; filter_text=Lead_Trim_ws(filter_text); local t={}; if filter_text==""or not filter_text then return t end; for i=1,#FX_LIST do local name=FX_LIST[i]:lower(); local found=true; for word in filter_text:gmatch("%S+")do if not name:find(word:lower(),1,true)then found=false; break end end; if found then t[#t+1]={score=FX_LIST[i]:len()-filter_text:len(),name=FX_LIST[i]}end end; if#t>=2 then SortTable(t,"score","name")end; old_t=t; old_filter=filter_text; return t end

function GetActiveFX(track, filter_text)
    local t = {}
    if not track then return t end
    local fx_count = r.TrackFX_GetCount(track)
    filter_text = Lead_Trim_ws(filter_text):lower()
    for i = 0, fx_count - 1 do
        local retval, buf = r.TrackFX_GetFXName(track, i, "")
        if retval then
            -- Safely check status using the helper function
            local is_bypassed = not IsTruthy(r.TrackFX_GetEnabled(track, i))
            local is_offline = IsTruthy(r.TrackFX_GetOffline(track, i))
            
            local status_prefix = ""
            if is_bypassed then status_prefix = status_prefix .. "[B] " end -- Bypassed
            if is_offline then status_prefix = status_prefix .. "[O] " end -- Offline
            
            local formatted_name = string.format("%s[Slot %d] %s", status_prefix, i + 1, buf)
            
            if filter_text == "" or formatted_name:lower():find(filter_text, 1, true) then
                t[#t + 1] = {
                    name = formatted_name,
                    original_name = buf, -- Store original name for actions
                    slot = i
                }
            end
        end
    end
    return t
end

function GetFavoritesList(filter_text) local t={}; filter_text=Lead_Trim_ws(filter_text):lower(); for _,fx_name in ipairs(FAVORITES_LIST)do if filter_text==""or fx_name:lower():find(filter_text,1,true)then table.insert(t,{name=fx_name})end end; return t end
function AddFxToTracks(fx) if r.CountTracks(0)==1 and r.CountSelectedTracks(0)==0 then local track=r.GetTrack(0,0); r.TrackFX_AddByName(track,fx,false,-1000-(SLOT-1)); return end; for t=1,r.CountSelectedTracks(0,0)do r.TrackFX_AddByName(r.GetSelectedTrack(0,t-1),fx,false,-1000-(SLOT-1))end end
function ToggleFxWindow(track,fx_slot) if not track then return end; local is_open=IsTruthy(r.TrackFX_GetOpen(track,fx_slot)); r.TrackFX_Show(track,fx_slot, is_open and 0 or 1) end
function ToggleFxBypass(track,fx_slot) if not track then return end; local is_enabled = IsTruthy(r.TrackFX_GetEnabled(track, fx_slot)); r.TrackFX_SetEnabled(track, fx_slot, not is_enabled) end
function ToggleFxOnline(track,fx_slot) if not track then return end; local is_offline = IsTruthy(r.TrackFX_GetOffline(track,fx_slot)); r.TrackFX_SetOffline(track,fx_slot,not is_offline)end
function DeleteFx(track,fx_slot) if not track then return end; r.TrackFX_Delete(track,fx_slot,false)end

function DeleteFxByName(name_to_delete)
    if r.CountSelectedTracks(0) == 0 then return end
    r.Undo_BeginBlock()
    for i = 0, r.CountSelectedTracks(0) - 1 do
        local track = r.GetSelectedTrack(0, i)
        if track then
            for fx_idx = r.TrackFX_GetCount(track) - 1, 0, -1 do
                local retval, current_fx_name = r.TrackFX_GetFXName(track, fx_idx, "")
                if retval and current_fx_name == name_to_delete then
                    r.TrackFX_Delete(track, fx_idx, false)
                end
            end
        end
    end
    r.Undo_EndBlock("Delete FX by name on selected tracks", -1)
    r.TrackList_AdjustWindows(false)
    r.UpdateArrange()
end

-- ==================================================================
-- ==          FX REORDERING LOGIC (IMPROVED COMPATIBILITY)      ==
-- ==================================================================
function MoveFx(track, source_slot, target_slot)
    if not track or source_slot == target_slot then return end
    r.Undo_BeginBlock()
    -- Use TrackFX_CopyToTrack to move the FX for better compatibility with older Reaper versions.
    -- The last parameter (is_move) is 'true' to move instead of copy.
    r.TrackFX_CopyToTrack(track, source_slot, track, target_slot, true)
    r.Undo_EndBlock(string.format("Move FX from slot %d to %d", source_slot + 1, target_slot + 1), -1)
    -- Update the GUI to reflect changes immediately
    r.TrackList_AdjustWindows(false)
    r.UpdateArrange()
end
-- ==================================================================


-- ==================================================================
-- ==                      REPLACEMENT LOGIC                     ==
-- ==================================================================
function ReplaceFxBySlot(fx_slot, new_fx_name)
    if r.CountSelectedTracks(0) == 0 then return end
    r.Undo_BeginBlock()
    for i = 0, r.CountSelectedTracks(0) - 1 do
        local current_track = r.GetSelectedTrack(0, i)
        if current_track and r.TrackFX_GetCount(current_track) > fx_slot then
            r.TrackFX_Delete(current_track, fx_slot, false)
            local insert_pos = -1000 - fx_slot
            r.TrackFX_AddByName(current_track, new_fx_name, false, insert_pos)
        end
    end
    r.Undo_EndBlock("Replace FX by slot on selected tracks", -1)
    r.TrackList_AdjustWindows(false)
    r.UpdateArrange()
end

function ReplaceFxByName(name_to_replace, new_fx_name)
    if r.CountSelectedTracks(0) == 0 then return end
    r.Undo_BeginBlock()
    for i = 0, r.CountSelectedTracks(0) - 1 do
        local track = r.GetSelectedTrack(0, i)
        if track then
            for fx_idx = r.TrackFX_GetCount(track) - 1, 0, -1 do
                local retval, current_fx_name = r.TrackFX_GetFXName(track, fx_idx, "")
                if retval and current_fx_name == name_to_replace then
                    r.TrackFX_Delete(track, fx_idx, false)
                    local insert_pos = -1000 - fx_idx
                    r.TrackFX_AddByName(track, new_fx_name, false, insert_pos)
                end
            end
        end
    end
    r.Undo_EndBlock("Replace FX by name on selected tracks", -1)
    r.TrackList_AdjustWindows(false)
    r.UpdateArrange()
end

function ReplaceFx(new_fx_name)
    if REPLACE_INFO.mode == "SLOT" then
        ReplaceFxBySlot(REPLACE_INFO.slot, new_fx_name)
    elseif REPLACE_INFO.mode == "NAME" then
        ReplaceFxByName(REPLACE_INFO.name, new_fx_name)
    end
end
-- ==================================================================

local keys={r.ImGui_Key_1(),r.ImGui_Key_2(),r.ImGui_Key_3(),r.ImGui_Key_4(),r.ImGui_Key_5(),r.ImGui_Key_6(),r.ImGui_Key_7(),r.ImGui_Key_8(),r.ImGui_Key_9(),r.ImGui_Key_GraveAccent(),r.ImGui_Key_0()}
local numpad_keys={r.ImGui_Key_Keypad1(),r.ImGui_Key_Keypad2(),r.ImGui_Key_Keypad3(),r.ImGui_Key_Keypad4(),r.ImGui_Key_Keypad5(),r.ImGui_Key_Keypad6(),r.ImGui_Key_Keypad7(),r.ImGui_Key_Keypad8(),r.ImGui_Key_Keypad9(),r.ImGui_Key_Keypad0()}
function CheckKeyNumbers() local CTRL=r.ImGui_IsKeyDown(ctx,r.ImGui_Key_LeftCtrl()); if not CTRL then return end; for i=1,9 do if r.ImGui_IsKeyPressed(ctx,keys[i])then SLOT=i;return end end; if r.ImGui_IsKeyPressed(ctx,keys[10])or r.ImGui_IsKeyPressed(ctx,keys[11])then SLOT=100;return end; for i=1,9 do if r.ImGui_IsKeyPressed(ctx,numpad_keys[i])then SLOT=i;return end end; if r.ImGui_IsKeyPressed(ctx,numpad_keys[10])then SLOT=100;return end end

-- ///////////////////////////////////////////////////////////////////
-- // MAIN INTERFACE DRAWING FUNCTION
-- ///////////////////////////////////////////////////////////////////
function DrawInterface()
    local selected_track=r.GetSelectedTrack(0,0)
    local track_name_display=" (No Track Selected)"
    if selected_track then local _,name=r.GetTrackName(selected_track,""); track_name_display=string.format(" (%s)",name)end

    if r.ImGui_IsKeyPressed(ctx,r.ImGui_Key_LeftAlt())and not REPLACE_INFO.active then
        if MODE=="ADD"then MODE="TOGGLE"elseif MODE=="TOGGLE"then MODE="FAVORITE"else MODE="ADD"end
        selected_entry=1; FILTER=""
    end

    CheckKeyNumbers()

    if r.ImGui_IsKeyPressed(ctx,r.ImGui_Key_Escape())then if REPLACE_INFO.active then REPLACE_INFO.active=false; MODE="TOGGLE"; FILTER=""; FOCUS=true elseif#FILTER>0 then FILTER=""; FOCUS=true end end

    local title_text
    if REPLACE_INFO.active then
        local num_sel_tracks = r.CountSelectedTracks(0)
        if REPLACE_INFO.mode == "NAME" then
            title_text = string.format("[REPLACING '%s' ON %d TRACKS]", REPLACE_INFO.name, num_sel_tracks)
        else -- SLOT mode
            if num_sel_tracks > 1 then
                title_text = string.format("[REPLACING SLOT %d ON %d TRACKS]", REPLACE_INFO.slot + 1, num_sel_tracks)
            else
                title_text = string.format("[REPLACING SLOT %d]%s", REPLACE_INFO.slot + 1, track_name_display)
            end
        end
    else
        title_text = string.format("[%s MODE] SLOT: %s%s", MODE, (SLOT < 100 and tostring(SLOT) or "LAST"), track_name_display)
    end
    r.ImGui_Text(ctx,title_text)

    r.ImGui_PushItemWidth(ctx,-1)
    if FOCUS then r.ImGui_SetKeyboardFocusHere(ctx); FOCUS=nil end
    _,FILTER=r.ImGui_InputText(ctx,'##input',FILTER)
    r.ImGui_PopItemWidth(ctx)

    local current_list={}
    if MODE=="ADD"then current_list=Filter_FX_List(FILTER)
    elseif MODE=="TOGGLE"then if selected_track then current_list=GetActiveFX(selected_track,FILTER)else r.ImGui_Text(ctx,"Please select a track to manage FX.")end
    else -- FAVORITE MODE
        current_list=GetFavoritesList(FILTER)
    end

    selected_entry=SetMinMax(selected_entry or 1,1,#current_list)

    if r.ImGui_BeginChild(ctx,"list_child",0,-25)then
        for i=1,#current_list do
            r.ImGui_PushID(ctx,i)
            if r.ImGui_Selectable(ctx,current_list[i].name,i==selected_entry)then
                if MODE=="ADD"or MODE=="FAVORITE"then
                    if REPLACE_INFO.active then ReplaceFx(current_list[i].name); REPLACE_INFO.active=false; MODE="TOGGLE"else AddFxToTracks(current_list[i].name)end
                else ToggleFxWindow(selected_track,current_list[i].slot)end
            end
            
            -- ///////////////////////////////////////////////////////////////////
            -- // CONTEXT MENUS (Right-click)
            -- ///////////////////////////////////////////////////////////////////
            if MODE == "TOGGLE" and r.ImGui_BeginPopupContextItem(ctx, "fx_context_menu") then
                local target_fx = current_list[i]
                selected_entry = i -- Select the right-clicked item
                
                if r.ImGui_MenuItem(ctx, 'Toggle Bypass') then ToggleFxBypass(selected_track, target_fx.slot); r.ImGui_CloseCurrentPopup(ctx) end
                if r.ImGui_MenuItem(ctx, 'Toggle Online/Offline') then ToggleFxOnline(selected_track, target_fx.slot); r.ImGui_CloseCurrentPopup(ctx) end
                if r.ImGui_MenuItem(ctx, 'Delete FX') then DeleteFx(selected_track, target_fx.slot); r.ImGui_CloseCurrentPopup(ctx) end
                if r.ImGui_MenuItem(ctx, 'Delete All by Name...') then DeleteFxByName(target_fx.original_name); r.ImGui_CloseCurrentPopup(ctx) end
                r.ImGui_Separator(ctx)
                if r.ImGui_MenuItem(ctx, 'Replace by Slot...') then
                    REPLACE_INFO.active = true
                    REPLACE_INFO.mode = "SLOT"
                    REPLACE_INFO.track = selected_track
                    REPLACE_INFO.slot = target_fx.slot
                    REPLACE_INFO.name = ""
                    MODE = "ADD"; FILTER = ""; FOCUS = true
                    r.ImGui_CloseCurrentPopup(ctx)
                end
                if r.ImGui_MenuItem(ctx, 'Replace by Name...') then
                    REPLACE_INFO.active = true
                    REPLACE_INFO.mode = "NAME"
                    REPLACE_INFO.name = target_fx.original_name
                    REPLACE_INFO.slot = -1
                    MODE = "ADD"; FILTER = ""; FOCUS = true
                    r.ImGui_CloseCurrentPopup(ctx)
                end
                r.ImGui_Separator(ctx)
                if r.ImGui_MenuItem(ctx, 'Add to Favorites') then AddToFavorites(target_fx.original_name); r.ImGui_CloseCurrentPopup(ctx) end
                
                r.ImGui_EndPopup(ctx)
            end

            if MODE == "FAVORITE" and r.ImGui_BeginPopupContextItem(ctx, "fav_context_menu") then
                selected_entry = i -- Select the right-clicked item
                if r.ImGui_MenuItem(ctx, 'Delete from Favorites') then 
                    RemoveFromFavorites(current_list[i].name)
                    r.ImGui_CloseCurrentPopup(ctx)
                end
                r.ImGui_EndPopup(ctx)
            end


            -- ///////////////////////////////////////////////////////////////////
            -- // DRAG AND DROP LOGIC (Only active in TOGGLE mode)
            -- ///////////////////////////////////////////////////////////////////
            if MODE == "TOGGLE" then
                if r.ImGui_BeginDragDropSource(ctx) then
                    r.ImGui_SetDragDropPayload(ctx, "FX_SLOT", current_list[i].slot, r.ImGui_Cond_Once())
                    r.ImGui_Text(ctx, "Move " .. current_list[i].original_name)
                    r.ImGui_EndDragDropSource(ctx)
                end
                if r.ImGui_BeginDragDropTarget(ctx) then
                    local payload_type, source_slot_str = r.ImGui_AcceptDragDropPayload(ctx, "FX_SLOT")
                    if source_slot_str then
                        local source_slot = tonumber(source_slot_str)
                        if source_slot then
                           local target_slot = current_list[i].slot
                           MoveFx(selected_track, source_slot, target_slot)
                        end
                    end
                    r.ImGui_EndDragDropTarget(ctx)
                end
            end
            -- ///////////////////////////////////////////////////////////////////

            r.ImGui_PopID(ctx)
            if i==selected_entry then scroll(nil)end
        end

        if#current_list>0 then
            local is_ctrl_down=r.ImGui_IsKeyDown(ctx,r.ImGui_Key_LeftCtrl())
            local is_shift_down=r.ImGui_IsKeyDown(ctx,r.ImGui_Key_LeftShift())
            
            if r.ImGui_IsKeyPressed(ctx,r.ImGui_Key_Enter())or r.ImGui_IsKeyPressed(ctx,r.ImGui_Key_KeypadEnter())then
                if MODE=="ADD"or MODE=="FAVORITE"then
                    if REPLACE_INFO.active then ReplaceFx(current_list[selected_entry].name); REPLACE_INFO.active=false; MODE="TOGGLE"else AddFxToTracks(current_list[selected_entry].name)end
                elseif MODE=="TOGGLE"then
                    if is_ctrl_down then ToggleFxBypass(selected_track,current_list[selected_entry].slot)
                    elseif is_shift_down then ToggleFxOnline(selected_track,current_list[selected_entry].slot)
                    else ToggleFxWindow(selected_track,current_list[selected_entry].slot)end
                end
            elseif r.ImGui_IsKeyPressed(ctx,r.ImGui_Key_Delete())then
                if MODE=="TOGGLE"then DeleteFx(selected_track,current_list[selected_entry].slot)
                elseif MODE=="FAVORITE"then RemoveFromFavorites(current_list[selected_entry].name)end
            elseif r.ImGui_IsKeyPressed(ctx,r.ImGui_Key_R())and is_ctrl_down and MODE=="TOGGLE"then
                if is_shift_down then -- Ctrl+Shift+R: Replace by Name
                    REPLACE_INFO.active = true
                    REPLACE_INFO.mode = "NAME"
                    local _, fx_name_only = r.TrackFX_GetFXName(selected_track, current_list[selected_entry].slot, "")
                    REPLACE_INFO.name = fx_name_only
                    REPLACE_INFO.slot = -1
                    MODE = "ADD"; FILTER = ""; FOCUS = true
                else -- Ctrl+R: Replace by Slot
                    REPLACE_INFO.active = true
                    REPLACE_INFO.mode = "SLOT"
                    REPLACE_INFO.track = selected_track
                    REPLACE_INFO.slot = current_list[selected_entry].slot
                    REPLACE_INFO.name = ""
                    MODE = "ADD"; FILTER = ""; FOCUS = true
                end
            elseif r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_S()) and is_ctrl_down and MODE == "ADD" then
                AddToFavorites(current_list[selected_entry].name)
            elseif r.ImGui_IsKeyPressed(ctx,r.ImGui_Key_UpArrow())then selected_entry=selected_entry-1
            elseif r.ImGui_IsKeyPressed(ctx,r.ImGui_Key_DownArrow())then selected_entry=selected_entry+1 end
        end
        r.ImGui_EndChild(ctx)
    end
    
    local help_text
    if MODE == "ADD" then help_text = "Alt: Switch Mode | Ctrl+S: Add to Favorites | Ctrl+Number: Change Slot"
    elseif MODE == "TOGGLE" then help_text = "Alt: Switch Mode | Drag: Reorder | Right-click for options | Del: Remove"
    elseif MODE == "FAVORITE" then help_text = "Alt: Switch Mode | Right-click or Del to Remove" end
    r.ImGui_Separator(ctx)
    r.ImGui_Text(ctx, help_text)
end

-- ///////////////////////////////////////////////////////////////////
-- // MAIN LOOP AND ENTRY POINT
-- ///////////////////////////////////////////////////////////////////
function loop()
    r.ImGui_SetNextWindowSize(ctx,420,350,r.ImGui_Cond_FirstUseEver())
    local visible,open=r.ImGui_Begin(ctx,SCRIPT_TITLE,true,r.ImGui_WindowFlags_NoCollapse())
    if visible then DrawInterface() r.ImGui_End(ctx)end
    if open then r.defer(loop)end
end

local hwnd=r.JS_Window_Find(SCRIPT_TITLE,true)
if hwnd then r.JS_Window_Close(hwnd)else FOCUS=true; r.defer(loop)end
