--[[
@description    Hosi Panel (ReaImGui Version)
@author         Hosi
@version        1.0.0
@reaper_version 6.0+
@provides
  [main] . > Hosi_Panel (ReaImGui).lua

@about
  # Hosi Panel: Configurable Action Launcher

  A simple, customizable ReaImGui panel designed to quickly launch REAPER actions.

  - **Customization:** Click "Edit" to add, remove, and customize buttons and pages (tabs) directly within the interface.
  - **Global Save:** Button configurations are saved globally across your REAPER installation.

@changelog
  + v1.0.0 (2025-11-02) - Initial release of the core panel with editable pages and buttons.
--]]
-- --- INITIALIZE REAIM GUI ---
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local imgui = require('imgui')('0.10')

if not imgui or type(imgui) ~= "table" then
  reaper.ShowMessageBox("Could not initialize ReaImGui library.\n\nPlease install it (v0.10+) via ReaPack.", "ReaImGui Error", 0)
  return
end

-- << NEW: Check for required js_ReaScriptAPI >>
if not reaper.JS_Dialog_BrowseForSaveFile then
    reaper.ShowMessageBox("This script requires the 'js_ReaScriptAPI' extension for Import/Export features.\n\nPlease install it via ReaPack.", "Missing API Error", 0)
    -- We don't 'return' here, we just disable the feature.
    -- But for this script, let's just make it mandatory.
    return
end

local config = {
    win_title = "Hosi Panel v1.0.0", -- << CHANGED
    button_size_w = 80, 
    button_size_h = 40
}

local DEFAULT_COLOR_STR = "0.8,0.8,0.8,1.0"

local ctx = imgui.CreateContext(config.win_title)

-- --- STATE VARIABLES ---
local state = {
    is_open = true,
    pages = {}, 
    current_page_idx = 1,
    is_edit_mode = false,
    
    -- Button edit state
    new_button_name = "",
    new_button_id = "",
    new_button_color = DEFAULT_COLOR_STR, 
    new_button_w = config.button_size_w,
    new_button_h = config.button_size_h,
    item_to_delete_idx = nil,
    editing_button_idx = nil,
    temp_edit_name = "",
    temp_edit_id = "",
    temp_edit_color = DEFAULT_COLOR_STR, 
    temp_edit_w = config.button_size_w,
    temp_edit_h = config.button_size_h,
    
    -- Page edit state
    new_page_name = "",
    page_to_delete_idx = nil,
    editing_page_idx = nil,
    temp_page_name = "",

    trigger_resize = false
}

-- --- UTILITY FUNCTIONS (SERIALIZATION) ---
function serialize_table(val)
    if type(val) == "string" then
        return string.format("%q", val)
    elseif type(val) == "number" or type(val) == "boolean" then
        return tostring(val)
    elseif type(val) == "table" then
        local parts = {}
        local is_array = true
        local n = 0
        for k, _ in pairs(val) do
            n = n + 1
            if type(k) ~= "number" or k ~= n then is_array = false end
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

function save_data()
    local data_string = serialize_table(state.pages)
    reaper.SetExtState("Hosi.Panel", "Pages", data_string, true) 
end

function load_data()
    -- 1. Try loading new "Pages" data
    local data_string = reaper.GetExtState("Hosi.Panel", "Pages")
    if data_string and data_string ~= "" then
        local success, result = pcall(load("return " .. data_string))
        if success and type(result) == "table" then
            state.pages = result
            return
        end
    end
    
    -- 2. "Pages" failed, try loading old "Buttons" data for migration
    local old_data_string = reaper.GetExtState("Hosi.Panel", "Buttons")
    if old_data_string and old_data_string ~= "" then
        local success, old_buttons = pcall(load("return " .. old_data_string))
        if success and type(old_buttons) == "table" then
            state.pages = { { name = "Main", buttons = old_buttons } }
            state.current_page_idx = 1
            save_data() 
            return 
        end
    end

    -- 3. Nothing found, start fresh
    state.pages = {}
    state.current_page_idx = 1
end

function migrate_buttons_v1_3_3(buttons_table)
    local needs_save = false
    if not buttons_table then return false end
    
    for _, button in ipairs(buttons_table) do
        if type(button.color) == "table" then
            local c = button.color
            button.color = string.format("%.2f,%.2f,%.2f,%.2f", c[1] or 0.8, c[2] or 0.8, c[3] or 0.8, c[4] or 1.0)
            needs_save = true
        elseif button.color == nil then
            button.color = DEFAULT_COLOR_STR
            needs_save = true
        end
        if button.width == nil then
            button.width = config.button_size_w
            needs_save = true
        end
        if button.height == nil then
            button.height = config.button_size_h
            needs_save = true
        end
    end
    return needs_save
end

-- --- COLOR UTILITY ---
function ParseColor(color_str)
    local r, g, b, a = 0.8, 0.8, 0.8, 1.0
    local nums = {}
    if type(color_str) == "string" then
        for num in string.gmatch(color_str, "([%d%.%-]+)") do
            table.insert(nums, tonumber(num))
        end
    end
    if #nums == 4 then
        r, g, b, a = nums[1], nums[2], nums[3], nums[4]
    end
    return r, g, b, a
end

-- << ADDED: Converts an 0xAABBGGRR integer back to an "R,G,B,A" string >>
function Convert_ABGR_Int_To_RGBA_String(color_int)
    local a_int = math.floor(color_int / 0x1000000) % 0x100
    local b_int = math.floor(color_int / 0x10000) % 0x100
    local g_int = math.floor(color_int / 0x100) % 0x100
    local r_int = color_int % 0x100
    
    local a_f = a_int / 255
    local b_f = b_int / 255
    local g_f = g_int / 255
    local r_f = r_int / 255
    
    return string.format("%.3f,%.3f,%.3f,%.3f", r_f, g_f, b_f, a_f)
end

-- << NOTE: PackColor (String to Int) is used as-is >>
function PackColor(color_str)
    local r, g, b, a = ParseColor(color_str)
    local r_int = math.floor(r * 255 + 0.5)
    local g_int = math.floor(g * 255 + 0.5)
    local b_int = math.floor(b * 255 + 0.5)
    local a_int = math.floor(a * 255 + 0.5)
    return a_int * 0x1000000 + b_int * 0x10000 + g_int * 0x100 + r_int
end

-- --- MAIN GUI LOOP ---
function loop()
    local window_flags = 0
    if state.is_edit_mode and state.trigger_resize then
        window_flags = imgui.WindowFlags_AlwaysAutoResize
    end
    
    local visible, is_open_ret = imgui.Begin(ctx, config.win_title, state.is_open, window_flags)
    state.is_open = is_open_ret

    if state.trigger_resize then
        state.trigger_resize = false
    end

    if visible then
        -- Toolbar
        local content_avail = imgui.GetContentRegionAvail(ctx)
        local available_w = type(content_avail) == 'table' and content_avail.x or content_avail
        local item_spacing_x = 8.0 
        local win_pad_x = 8.0 -- << CHANGED: Hardcoded fallback for GetStyle()
        
        local edit_btn_text = state.is_edit_mode and "Done" or "Edit"
        local edit_btn_w = 60
        
        -- << UI CHANGE: Draw TabBar on the toolbar line in Run Mode >>
        if not state.is_edit_mode then
            -- RUN MODE: Draw TabBar on the same line
            
            -- << CHANGED: Corrected space reservation to override padding >>
            imgui.PushItemWidth(ctx, available_w - edit_btn_w - item_spacing_x + win_pad_x) 
            
            if #state.pages == 0 then
                -- Show placeholder text if no pages
                imgui.TextDisabled(ctx, "No pages. Click 'Edit' to add one.")
            else
                -- Validate current_page_idx
                if not state.pages[state.current_page_idx] then state.current_page_idx = 1 end
                
                if imgui.BeginTabBar(ctx, "PageTabBar", imgui.TabBarFlags_None) then
                    for i, page in ipairs(state.pages) do
                        local flags = 0
                        if i == state.current_page_idx then flags = imgui.TabItemFlags_SetSelected end
                        
                        if imgui.BeginTabItem(ctx, page.name .. "##tab" .. i, flags) then
                            state.current_page_idx = i
                            imgui.EndTabItem(ctx)
                        end
                    end
                    imgui.EndTabBar(ctx)
                end
            end
            imgui.PopItemWidth(ctx)
        else
            -- EDIT MODE: Show nothing here, leave the space empty
            -- (The "Done" button will fill the right side)
        end
        -- << END UI CHANGE >>

        -- Draw the Edit/Done button (aligned right)
        imgui.SameLine(ctx, available_w - edit_btn_w + win_pad_x) -- << CHANGED: Override padding
        local was_edit_mode = state.is_edit_mode
        
        -- << ADDED: Vertical alignment for Run Mode >>
        if not was_edit_mode then
            imgui.SetCursorPosY(ctx, imgui.GetCursorPosY(ctx) - 4) -- << MOVE UP 4 pixels
        end
        
        -- << CHANGED: Make "Edit" button flat, keep "Done" button red >>
        local pushed_colors = 0
        if was_edit_mode then 
            -- Red "Done" button
            imgui.PushStyleColor(ctx, imgui.Col_Button, PackColor("0.8,0.2,0.2,1.0"))
            pushed_colors = 1
        elseif not state.is_edit_mode then
            -- Flat "Edit" button in Run Mode
            imgui.PushStyleColor(ctx, imgui.Col_Button, 0) -- 0 = transparent background
            imgui.PushStyleColor(ctx, imgui.Col_Border, 0) -- 0 = transparent border
            pushed_colors = 2
        end
        
        -- << REMOVED: Vertical alignment for Run Mode (moved up) >>
        
        if state.editing_button_idx or state.editing_page_idx then imgui.BeginDisabled(ctx) end
        
        local btn_h = state.is_edit_mode and 25 or 0 -- Use 25 in Edit, 0 in Run
        if imgui.Button(ctx, edit_btn_text, edit_btn_w, btn_h) then
            state.is_edit_mode = not state.is_edit_mode
        end
        if state.editing_button_idx or state.editing_page_idx then imgui.EndDisabled(ctx) end
        
        imgui.PopStyleColor(ctx, pushed_colors) -- Pop 1 or 2 colors
        -- << END CHANGED >>
        
        -- Main Area
        if state.is_edit_mode then
            -- --- EDIT MODE ---
            
            local is_editing_btn = (state.editing_button_idx ~= nil)
            local is_editing_page = (state.editing_page_idx ~= nil)
            
            imgui.Separator(ctx) -- << ADDED separator
            
            -- === PART 1: PAGE MANAGEMENT ===
            imgui.Text(ctx, "Page Management")
            
            if is_editing_btn then imgui.BeginDisabled(ctx) end
            
            if not is_editing_page then
                imgui.PushItemWidth(ctx, -120)
                local name_changed, new_name = imgui.InputText(ctx, "##new_page_name", state.new_page_name, 128)
                if name_changed then state.new_page_name = new_name end
                imgui.PopItemWidth(ctx)
                imgui.SameLine(ctx)
                if imgui.Button(ctx, "Add Page", 110, 0) then
                    if state.new_page_name ~= "" then
                        table.insert(state.pages, { name = state.new_page_name, buttons = {} })
                        state.new_page_name = ""
                        save_data()
                        state.current_page_idx = #state.pages 
                        state.trigger_resize = true
                    end
                end
            end
            
            -- << CHANGED: Added break flag >>
            local page_loop_break = false
            for i, page in ipairs(state.pages) do
                if state.editing_page_idx == i then
                    local name_changed, temp_name = imgui.InputText(ctx, "##edit_page"..i, state.temp_page_name, 128)
                    if name_changed then state.temp_page_name = temp_name end
                    imgui.SameLine(ctx)
                    if imgui.Button(ctx, "Save##savepage"..i) then
                        state.pages[i].name = state.temp_page_name
                        state.editing_page_idx = nil
                        save_data()
                    end
                    imgui.SameLine(ctx)
                    if imgui.Button(ctx, "Cancel##cancelpage"..i) then
                        state.editing_page_idx = nil
                    end
                else
                    if is_editing_page then imgui.BeginDisabled(ctx) end
                    
                    if imgui.SmallButton(ctx, "X##delpage"..i) then
                        state.page_to_delete_idx = i
                    end
                    imgui.SameLine(ctx)
                    if imgui.SmallButton(ctx, "Rename##page"..i) then
                        state.editing_page_idx = i
                        state.temp_page_name = page.name
                    end
                    imgui.SameLine(ctx)

                    -- << CHANGED: Wrap DND logic in a DUAL check >>
                    if not is_editing_page and not is_editing_btn then
                        -- << CHANGED: Replaced Text() with Selectable() >>
                        imgui.Selectable(ctx, "::##dnd_page"..i, false, 0, 15, 15)
                        
                        -- 1. Source (Item being dragged)
                        if imgui.BeginDragDropSource(ctx) then
                            local payload_str = tostring(i)
                            imgui.SetDragDropPayload(ctx, "DND_PAGE", payload_str) 
                            imgui.Text(ctx, "Moving page " .. page.name) -- Tooltip
                            imgui.EndDragDropSource(ctx)
                        end
                        
                        -- 2. Target (Item being dropped onto)
                        if imgui.BeginDragDropTarget(ctx) then
                            local accepted, payload = imgui.AcceptDragDropPayload(ctx, "DND_PAGE")
                            if accepted and payload then
                                local source_idx = tonumber(payload)
                                local target_idx = i
                                
                                if source_idx and target_idx and source_idx ~= target_idx then
                                    -- Perform the move
                                    local moved_page = table.remove(state.pages, source_idx)
                                    table.insert(state.pages, target_idx, moved_page)
                                    
                                    -- Update current_page_idx to follow the moved page
                                    if state.current_page_idx == source_idx then
                                        state.current_page_idx = target_idx
                                    elseif source_idx < state.current_page_idx and target_idx >= state.current_page_idx then
                                        state.current_page_idx = state.current_page_idx - 1
                                    elseif source_idx > state.current_page_idx and target_idx <= state.current_page_idx then
                                        state.current_page_idx = state.current_page_idx + 1
                                    end
                                    
                                    save_data()
                                    -- << REMOVED: state.trigger_resize = true >>
                                    page_loop_break = true -- << CHANGED: Set flag instead of break
                                end
                            end
                            imgui.EndDragDropTarget(ctx)
                        end
                    else
                        -- Show a disabled handle
                        -- << CHANGED: Replaced TextDisabled() with disabled Selectable() >>
                        imgui.Selectable(ctx, "::##dnd_page_dis"..i, false, imgui.SelectableFlags_Disabled, 15, 15)
                    end
                    -- << END CHANGED >>

                    imgui.SameLine(ctx)
                    imgui.Text(ctx, string.format('Page: "%s"', page.name))
                    
                    if is_editing_page then imgui.EndDisabled(ctx) end
                end
                
                -- << CHANGED: Check flag after loop iteration >>
                if page_loop_break then break end
            end
            
            if state.page_to_delete_idx then
                table.remove(state.pages, state.page_to_delete_idx)
                if state.current_page_idx > #state.pages then
                    state.current_page_idx = #state.pages
                end
                if state.current_page_idx == 0 and #state.pages > 0 then
                    state.current_page_idx = 1
                end
                state.page_to_delete_idx = nil
                save_data()
                state.trigger_resize = true
            end
            
            if is_editing_btn then imgui.EndDisabled(ctx) end
            
            imgui.Separator(ctx)

            -- === PART 2: BUTTON MANAGEMENT ===
            if #state.pages == 0 then
                imgui.Text(ctx, "No pages exist. Please add a page to begin.")
            elseif not state.pages[state.current_page_idx] then
                 imgui.Text(ctx, "Error: Selected page index is invalid.")
                 state.current_page_idx = 1
            else
                local current_page = state.pages[state.current_page_idx]
                imgui.Text(ctx, string.format('Editing Buttons for Page: "%s"', current_page.name))

                if is_editing_page then imgui.BeginDisabled(ctx) end
            
                if not is_editing_btn then 
                    if imgui.BeginTable(ctx, "AddButtonTable", 2, imgui.TableFlags_None, 0, 0) then
                        imgui.TableSetupColumn(ctx, "Labels", imgui.TableColumnFlags_WidthFixed)
                        imgui.TableSetupColumn(ctx, "Inputs", imgui.TableColumnFlags_WidthStretch)

                        -- Row 1: Name
                        imgui.TableNextColumn(ctx); imgui.Text(ctx, "Name")
                        imgui.TableNextColumn(ctx); imgui.PushItemWidth(ctx, -1)
                        local name_changed, new_name = imgui.InputText(ctx, "##new_name", state.new_button_name, 128)
                        if name_changed then state.new_button_name = new_name end
                        imgui.PopItemWidth(ctx)
                        
                        -- Row 2: Action ID
                        imgui.TableNextColumn(ctx); imgui.Text(ctx, "Action ID")
                        imgui.TableNextColumn(ctx); imgui.PushItemWidth(ctx, -1)
                        local id_changed, new_id = imgui.InputText(ctx, "##new_id", state.new_button_id, 256)
                        if id_changed then state.new_button_id = new_id end
                        imgui.PopItemWidth(ctx)
                        
                        -- Row 3: Color
                        -- << CHANGED: Replaced InputText with ColorEdit4 (Integer Version) >>
                        imgui.TableNextColumn(ctx)
                        imgui.Text(ctx, "Color")
                        
                        imgui.TableNextColumn(ctx); imgui.PushItemWidth(ctx, -1)
                        -- 1. Convert our stored string ("R,G,B,A") to the integer format (0xAABBGGRR)
                        local color_int_in = PackColor(state.new_button_color)
                        -- 2. Set flags (Show Alpha bar, default is integer)
                        local color_flags = imgui.ColorEditFlags_AlphaBar
                        
                        -- 3. Call ColorEdit4 as per the API doc (ctx, label, int_in, flags)
                        local changed, color_int_out = imgui.ColorEdit4(ctx, "##new_color", color_int_in, color_flags)
                        
                        -- 4. If changed, convert the output integer back to our string format
                        if changed then
                            state.new_button_color = Convert_ABGR_Int_To_RGBA_String(color_int_out)
                        end
                        imgui.PopItemWidth(ctx)
                        -- << END CHANGED >>
                        
                        -- Row 4: Size
                        imgui.TableNextColumn(ctx); imgui.Text(ctx, "Size (W, H)")
                        imgui.TableNextColumn(ctx)
                        imgui.PushItemWidth(ctx, 80)
                        local w_changed, new_w = imgui.InputInt(ctx, "##new_w", state.new_button_w)
                        if w_changed then state.new_button_w = new_w end
                        imgui.PopItemWidth(ctx)
                        imgui.SameLine(ctx)
                        imgui.PushItemWidth(ctx, 80)
                        local h_changed, new_h = imgui.InputInt(ctx, "##new_h", state.new_button_h)
                        if h_changed then state.new_button_h = new_h end
                        imgui.PopItemWidth(ctx)
                        
                        imgui.EndTable(ctx)
                    end
                    
                    if imgui.Button(ctx, "Add Button", 100, 40) then
                        if state.new_button_name ~= "" and state.new_button_id ~= "" then
                            local new_button = {
                                name = state.new_button_name,
                                id = state.new_button_id,
                                color = state.new_button_color, -- << This is now the updated string
                                width = state.new_button_w,
                                height = state.new_button_h
                            }
                            table.insert(current_page.buttons, new_button) 
                            
                            state.new_button_name = ""
                            state.new_button_id = ""
                            state.new_button_color = DEFAULT_COLOR_STR -- << Reset string
                            state.new_button_w = config.button_size_w
                            state.new_button_h = config.button_size_h
                            
                            save_data()
                            state.trigger_resize = true
                        end
                    end
                end 

                imgui.Separator(ctx)
                
                -- << CHANGED: Added break flag >>
                local button_loop_break = false
                for i, button in ipairs(current_page.buttons) do
                    if state.editing_button_idx == i then
                        imgui.Text(ctx, "Editing:")
                        
                        local name_changed, new_name = imgui.InputText(ctx, "Name##edit"..i, state.temp_edit_name, 128)
                        if name_changed then state.temp_edit_name = new_name end
                        
                        local id_changed, new_id = imgui.InputText(ctx, "ID##edit"..i, state.temp_edit_id, 256)
                        if id_changed then state.temp_edit_id = new_id end
                        
                        -- << CHANGED: Replaced InputText with ColorEdit4 (Integer Version) >>
                        imgui.Text(ctx, "Color")
                        
                        -- 1. Convert our temp string to the integer format
                        local color_int_in = PackColor(state.temp_edit_color)
                        -- 2. Set flags
                        local color_flags = imgui.ColorEditFlags_AlphaBar
                        
                        -- 3. Call ColorEdit4
                        local changed, color_int_out = imgui.ColorEdit4(ctx, "##edit_color"..i, color_int_in, color_flags)
                        
                        -- 4. If changed, update our temp string
                        if changed then
                            state.temp_edit_color = Convert_ABGR_Int_To_RGBA_String(color_int_out)
                        end
                        -- << END CHANGED >>
                        
                        imgui.PushItemWidth(ctx, 80)
                        local w_changed, new_w = imgui.InputInt(ctx, "W##edit_w"..i, state.temp_edit_w)
                        if w_changed then state.temp_edit_w = new_w end
                        imgui.PopItemWidth(ctx)
                        imgui.SameLine(ctx)
                        imgui.PushItemWidth(ctx, 80)
                        local h_changed, new_h = imgui.InputInt(ctx, "H##edit_h"..i, state.temp_edit_h)
                        if h_changed then state.temp_edit_h = new_h end
                        imgui.PopItemWidth(ctx)

                        if imgui.Button(ctx, "Save##saveedit"..i) then
                            current_page.buttons[i].name = state.temp_edit_name
                            current_page.buttons[i].id = state.temp_edit_id
                            current_page.buttons[i].color = state.temp_edit_color -- << Save the updated string
                            current_page.buttons[i].width = state.temp_edit_w
                            current_page.buttons[i].height = state.temp_edit_h
                            
                            save_data()
                            state.editing_button_idx = nil
                            state.trigger_resize = true
                        end
                        imgui.SameLine(ctx)
                        
                        if imgui.Button(ctx, "Cancel##canceledit"..i) then
                            state.editing_button_idx = nil
                        end

                    else
                        if is_editing_btn then imgui.BeginDisabled(ctx) end
                        
                        if imgui.SmallButton(ctx, "X##del"..i) then
                            state.item_to_delete_idx = i
                        end
                        imgui.SameLine(ctx)
                        
                        if imgui.SmallButton(ctx, "Edit##"..i) then
                            state.editing_button_idx = i
                            state.temp_edit_name = button.name
                            state.temp_edit_id = button.id
                            state.temp_edit_color = button.color or DEFAULT_COLOR_STR -- << This is already a string
                            state.temp_edit_w = button.width or config.button_size_w
                            state.temp_edit_h = button.height or config.button_size_h
                            state.trigger_resize = true
                        end
                        imgui.SameLine(ctx)
                        
                        -- << CHANGED: Wrap DND logic in a DUAL check >>
                        if not is_editing_btn and not is_editing_page then
                            -- << CHANGED: Replaced Text() with Selectable() >>
                            imgui.Selectable(ctx, "::##dnd_btn"..i, false, 0, 15, 15)
                            
                            -- 1. Source
                            if imgui.BeginDragDropSource(ctx) then
                                local payload_str = tostring(i)
                                imgui.SetDragDropPayload(ctx, "DND_BUTTON", payload_str) 
                                imgui.Text(ctx, "Moving " .. button.name) -- Tooltip
                                imgui.EndDragDropSource(ctx)
                            end
                            
                            -- 2. Target
                            if imgui.BeginDragDropTarget(ctx) then
                                local accepted, payload = imgui.AcceptDragDropPayload(ctx, "DND_BUTTON")
                                if accepted and payload then
                                    local source_idx = tonumber(payload)
                                    local target_idx = i
                                    
                                    if source_idx and target_idx and source_idx ~= target_idx then
                                        -- Perform the move
                                        local moved_button = table.remove(current_page.buttons, source_idx)
                                        table.insert(current_page.buttons, target_idx, moved_button)
                                        
                                        save_data()
                                        -- << REMOVED: state.trigger_resize = true >>
                                        button_loop_break = true -- << CHANGED: Set flag instead of break
                                    end
                                end
                                imgui.EndDragDropTarget(ctx)
                            end
                        else
                            -- Show a disabled handle
                            -- << CHANGED: Replaced TextDisabled() with disabled Selectable() >>
                            imgui.Selectable(ctx, "::##dnd_btn_dis"..i, false, imgui.SelectableFlags_Disabled, 15, 15)
                        end
                        -- << END CHANGED >>
                        
                        imgui.SameLine(ctx)
                        imgui.Text(ctx, string.format('"%s" (ID: %s)', button.name, button.id))
                        
                        if is_editing_btn then imgui.EndDisabled(ctx) end
                    end
                    
                    -- << CHANGED: Check flag after loop iteration >>
                    if button_loop_break then break end
                end
                
                if state.item_to_delete_idx then
                    table.remove(current_page.buttons, state.item_to_delete_idx)
                    state.item_to_delete_idx = nil
                    save_data()
                    state.trigger_resize = true
                end
                
                if is_editing_page then imgui.EndDisabled(ctx) end
            end 

            -- << NEW: PART 3: CONFIGURATION (IMPORT/EXPORT) >>
            imgui.Separator(ctx)
            imgui.Text(ctx, "Configuration (Import/Export)")

            if is_editing_btn or is_editing_page then imgui.BeginDisabled(ctx) end

            if imgui.Button(ctx, "Export Pages", 100, 0) then
                if #state.pages == 0 then
                    reaper.ShowMessageBox("Nothing to export. Add some pages first.", "Export Warning", 0)
                else
                    local path = reaper.GetResourcePath()
                    -- << CHANGED: Replaced non-existent reaper.GetUserFileNameForWrite with reaper.JS_Dialog_BrowseForSaveFile >>
                    local extlist = "Hosi Panel Config (*.txt)\0*.txt\0All Files (*.*)\0*.*\0"
                    local retval, ret_filename = reaper.JS_Dialog_BrowseForSaveFile("Save Hosi Panel Config", path, "HosiPanelConfig.txt", extlist)
                    
                    if retval and ret_filename and ret_filename ~= "" then
                        local data_string = serialize_table(state.pages)
                        local file, err = io.open(ret_filename, "w")
                        if not file then
                            reaper.ShowMessageBox("Error: Could not open file for writing.\n" .. tostring(err), "Export Error", 0)
                        else
                            file:write(data_string)
                            file:close()
                            reaper.ShowMessageBox("Export successful!", "Export Complete", 0)
                        end
                    end
                end
            end

            imgui.SameLine(ctx)

            if imgui.Button(ctx, "Import Pages", 100, 0) then
                local path = reaper.GetResourcePath()
                local retval, ret_filename = reaper.GetUserFileNameForRead("", "Load Hosi Panel Config", ".txt")
				if retval and ret_filename and ret_filename ~= "" then
				local file, err = io.open(ret_filename, "r")
                    if not file then
                        reaper.ShowMessageBox("Error: Could not open file for reading.\n" .. tostring(err), "Import Error", 0)
                    else
                        local data_string = file:read("*a")
                        file:close()
                        
                        if data_string and data_string ~= "" then
                            local success, result = pcall(load("return " .. data_string))
                            if success and type(result) == "table" then
                                state.pages = result
                                state.current_page_idx = 1
                                if #state.pages == 0 then state.current_page_idx = 0 end -- Handle empty import
                                
                                save_data() -- Save the newly imported data
                                state.trigger_resize = true -- Trigger resize for new content
                                reaper.ShowMessageBox("Import successful! Panel will refresh.", "Import Complete", 0)
                            else
                                reaper.ShowMessageBox("Import failed. File is corrupt or not a valid Hosi Panel config.", "Import Error", 0)
                            end
                        else
                             reaper.ShowMessageBox("Import failed. File was empty.", "Import Error", 0)
                        end
                    end
                end
            end

            if is_editing_btn or is_editing_page then imgui.EndDisabled(ctx) end
            -- << END NEW >>

        else
            -- --- RUN MODE ---
            
            -- << UI CHANGE: TabBar logic was MOVED UP to the toolbar >>
            
            -- Render content for the *selected* tab
            if #state.pages > 0 and state.pages[state.current_page_idx] then
                local current_page = state.pages[state.current_page_idx]
                local buttons = current_page.buttons
                
                if #buttons == 0 then
                    imgui.Text(ctx, "No buttons on this page. Click 'Edit' to add one.")
                end
                
                for i, button in ipairs(buttons) do
                    local color_str = button.color or DEFAULT_COLOR_STR 
                    local w = button.width or config.button_size_w
                    local h = button.height or config.button_size_h
                    
                    imgui.PushStyleColor(ctx, imgui.Col_Button, PackColor(color_str))
                    
                    if imgui.Button(ctx, button.name .. "##btn" .. i, w, h) then
                        local num_cmd = tonumber(button.id)
                        if num_cmd then
                            reaper.Main_OnCommand(num_cmd, 0)
                        else
                            reaper.Main_OnCommand(reaper.NamedCommandLookup(button.id), 0)
                        end
                    end
                    
                    imgui.PopStyleColor(ctx)
                    
                    local next_w = 0
                    if buttons[i+1] then
                        next_w = buttons[i+1].width or config.button_size_w
                    end
                    
                    if next_w > 0 and (imgui.GetCursorPosX(ctx) + item_spacing_x + next_w < available_w) then
                        imgui.SameLine(ctx, 0, item_spacing_x)
                    end
                end
            else
                -- << UI CHANGE: This check is now handled above >>
            end
        end

        imgui.End(ctx)
    end

    if state.is_open then reaper.defer(loop) end
end

-- --- SCRIPT START AND EXIT ---
function Main()
    load_data() 
    
    local needs_save = false
    for _, page in ipairs(state.pages) do
        if migrate_buttons_v1_3_3(page.buttons) then 
            needs_save = true
        end
    end
    if needs_save then
        save_data()
    end
    
    loop()
end

reaper.defer(Main)

