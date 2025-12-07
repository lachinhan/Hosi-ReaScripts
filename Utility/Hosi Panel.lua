--[[
@description    Hosi Panel (ReaImGui Version)
@author         Hosi
@version        1.1
@reaper_version 6.0+
@provides
  [main] . > Hosi_Panel (ReaImGui).lua

@about
  # Hosi Panel: Configurable Action Launcher

  A simple, customizable ReaImGui panel designed to quickly launch REAPER actions.

  - **Customization:** Click "Edit" to add, remove, and customize buttons and pages (tabs) directly within the interface.
  - **Global Save:** Button configurations are saved globally across your REAPER installation.

@changelog
  + v1.1 (2025-11-02) - Initial release of the core panel with editable pages and buttons.
--]]
-- --- INITIALIZE REAIM GUI ---
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local imgui = require('imgui')('0.10')

if not imgui or type(imgui) ~= "table" then
  reaper.ShowMessageBox("Could not initialize ReaImGui library.\n\nPlease install it (v0.10+) via ReaPack.", "ReaImGui Error", 0)
  return
end

-- << REVERTED: Check for required js_ReaScriptAPI (Import/Export ONLY) >>
if not reaper.JS_Dialog_BrowseForSaveFile then
    reaper.ShowMessageBox("This script requires the 'js_ReaScriptAPI' extension for Import/Export features.\n\nPlease install it via ReaPack.", "Missing API Error", 0)
    -- We don't 'return' here, we just disable the feature.
    -- But for this script, let's just make it mandatory.
    return
end

local config = {
    win_title = "Hosi Panel v1.2",
    button_size_w = 80, 
    button_size_h = 40,
    current_theme = "Default" -- Default theme
}

local Themes = {
    ["Default"] = {
        window_bg = 0x333333ff,
        text = 0xffffffff,
        button = 0x555555ff,
        button_hover = 0x666666ff,
        button_active = 0x777777ff
    },
    ["Dark"] = {
        window_bg = 0x1a1a1aff,
        text = 0xccccccff,
        button = 0x333333ff,
        button_hover = 0x444444ff,
        button_active = 0x555555ff
    },
    ["Light"] = {
        window_bg = 0xeeeeeeff,
        text = 0x222222ff,
        button = 0xccccccff,
        button_hover = 0xddddddff,
        button_active = 0xbbbbbbff
    },
    ["Ocean"] = {
        window_bg = 0x001e26ff,
        text = 0xb2ebf2ff,
        button = 0x006064ff,
        button_hover = 0x00838fff,
        button_active = 0x00acc1ff
    },
    ["Cherry"] = {
        window_bg = 0x2b0000ff,
        text = 0xffccccff,
        button = 0x880e4fff,
        button_hover = 0xad1457ff,
        button_active = 0xc2185bff
    },
    ["Reaper Sync"] = { -- Special marker for dynamic theme
        window_bg = 0, text = 0, button = 0, button_hover = 0, button_active = 0
    }
}

-- << IMAGE CACHE SYSTEM >>
local ImageCache = {}

function GetCachedImage(path)
    if not path or path == "" then return nil end
    if ImageCache[path] then return ImageCache[path] end
    
    -- Load new image
    local img = imgui.CreateImage(path)
    if img then
        ImageCache[path] = img
        return img
    end
    return nil
end

function BrowseForImage()
    if reaper.JS_Dialog_BrowseForOpenFiles then
        local retval, file = reaper.JS_Dialog_BrowseForOpenFiles("Select Image", "", "", "Images (.png .jpg)\0*.png;*.jpg\0All Files\0*.*\0", false)
        if retval and file and file ~= "" then return file end
    else
        reaper.ShowMessageBox("Requires js_ReaScriptAPI to browse files.", "Error", 0)
    end
    return nil
end

local DEFAULT_COLOR_STR = "0.8,0.8,0.8,1.0"

local ctx = imgui.CreateContext(config.win_title)

-- --- STATE VARIABLES ---
local state = {
    is_open = true,
    pages = {}, 
    current_page_idx = 1,
    is_edit_mode = false,
    
    -- << CHANGED: Renamed 'button' to 'item' for clarity >>
    new_button_name = "",
    new_button_id = "",
    new_button_color = DEFAULT_COLOR_STR, 
    new_button_w = config.button_size_w,
    new_button_h = config.button_size_h,
    item_to_delete_idx = nil,
    editing_item_idx = nil, -- << CHANGED
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

    trigger_resize = false,
    
    -- << NEW: State for adding labels >>
    new_label_name = "",

    -- << NEW: State for Visual Enhancements >>
    new_item_icon = "",
    new_item_tooltip = "",
    temp_edit_icon = "",
    temp_edit_tooltip = "",
    new_page_columns = 0,
    temp_page_columns = 0,
    -- << NEW: Image Support >>
    new_item_image_path = "",
    temp_edit_image_path = ""
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
            -- << CHANGED: Migrate old 'buttons' to new 'items' structure >>
            state.pages = { { name = "Main", items = old_buttons } } 
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
    local a_int = math.floor(a * 255 + 0.5)
    return a_int * 0x1000000 + b_int * 0x10000 + g_int * 0x100 + r_int
end

-- << VISUAL OVERHAUL HELPERS >>
local JJ_STYLE = {
    WindowRounding    = 8.0,
    FrameRounding     = 4.0,
    PopupRounding     = 6.0,
    ItemSpacingX      = 10.0,
    ItemSpacingY      = 8.0,
    FramePaddingX     = 10.0,
    FramePaddingY     = 6.0,
    WindowPaddingX    = 15.0,
    WindowPaddingY    = 15.0
}

function GetReaperThemeColor(element_str, fallback)
    local retval = reaper.GetThemeColor(element_str, 0)
    if retval == -1 or retval == 0 then return fallback end
    local r, g, b = reaper.ColorFromNative(retval)
    return (0xFF << 24) | (b << 16) | (g << 8) | r
end

function CreateContrastTextColor(bg_int)
    local r = bg_int & 0xFF
    local g = (bg_int >> 8) & 0xFF
    local b = (bg_int >> 16) & 0xFF
    local luma = (0.299 * r + 0.587 * g + 0.114 * b)
    return luma > 150 and 0xFF000000 or 0xFFFFFFFF
end

function AdjustColor(color_int, delta)
    local a = (color_int >> 24) & 0xFF
    local b = (color_int >> 16) & 0xFF
    local g = (color_int >> 8) & 0xFF
    local r = color_int & 0xFF
    local function clamp(val) return math.max(0, math.min(255, val)) end
    return (a << 24) | (clamp(b + delta) << 16) | (clamp(g + delta) << 8) | (clamp(r + delta))
end

-- << HELPER: Apply Theme >>
function ApplyTheme(theme_name)
    local t = Themes[theme_name] or Themes["Default"]
    local colors_pushed = 0
    local vars_pushed = 0
    
    if theme_name == "Reaper Sync" then
        -- 1. DYNAMIC REAPER COLORS
        local win_bg = GetReaperThemeColor("col_main_window_bg", 0xFF333333)
        local text_col = CreateContrastTextColor(win_bg)
        
        -- Vibrant Button Logic
        local accent_col = reaper.GetThemeColor("col_trans_sel2", 0)
        local btn_col = 0xFFC06B5C -- Indigo Fallback
        if accent_col ~= -1 and accent_col ~= 0 then
            local r, g, b = reaper.ColorFromNative(accent_col)
            btn_col = (0xFF << 24) | (b << 16) | (g << 8) | r
        end

        imgui.PushStyleColor(ctx, imgui.Col_WindowBg, win_bg)
        imgui.PushStyleColor(ctx, imgui.Col_PopupBg, win_bg)
        imgui.PushStyleColor(ctx, imgui.Col_TitleBg, win_bg)
        imgui.PushStyleColor(ctx, imgui.Col_TitleBgActive, win_bg)
        imgui.PushStyleColor(ctx, imgui.Col_Text, text_col)
        imgui.PushStyleColor(ctx, imgui.Col_Button, btn_col)
        imgui.PushStyleColor(ctx, imgui.Col_ButtonHovered, AdjustColor(btn_col, 30))
        imgui.PushStyleColor(ctx, imgui.Col_ButtonActive, AdjustColor(btn_col, -20))
        imgui.PushStyleColor(ctx, imgui.Col_Border, AdjustColor(btn_col, 50))
        
        colors_pushed = 8 -- Win, Pop, Tit, TitAct, Txt, Btn, BtnH, BtnA, Bdr (Wait 9?) 
        -- Count: 1=Win, 2=Pop, 3=Tit, 4=TitAct, 5=Txt, 6=Btn, 7=BtnH, 8=BtnA, 9=Bdr
        colors_pushed = 9
        
        imgui.PushStyleVar(ctx, imgui.StyleVar_FrameBorderSize, 1.0)
        vars_pushed = vars_pushed + 1
    else
        -- 2. STANDARD PRESET THEMES (Existing Logic)
        imgui.PushStyleColor(ctx, imgui.Col_WindowBg, t.window_bg)
        imgui.PushStyleColor(ctx, imgui.Col_Text, t.text)
        imgui.PushStyleColor(ctx, imgui.Col_Button, t.button)
        imgui.PushStyleColor(ctx, imgui.Col_ButtonHovered, t.button_hover)
        imgui.PushStyleColor(ctx, imgui.Col_ButtonActive, t.button_active)
        colors_pushed = 5
    end

    -- 3. GLOBAL ROUNDED STYLES (Apply for ALL themes)
    imgui.PushStyleVar(ctx, imgui.StyleVar_WindowRounding, JJ_STYLE.WindowRounding)
    imgui.PushStyleVar(ctx, imgui.StyleVar_FrameRounding, JJ_STYLE.FrameRounding)
    imgui.PushStyleVar(ctx, imgui.StyleVar_PopupRounding, JJ_STYLE.PopupRounding)
    imgui.PushStyleVar(ctx, imgui.StyleVar_ItemSpacing, JJ_STYLE.ItemSpacingX, JJ_STYLE.ItemSpacingY)
    imgui.PushStyleVar(ctx, imgui.StyleVar_FramePadding, JJ_STYLE.FramePaddingX, JJ_STYLE.FramePaddingY)
    imgui.PushStyleVar(ctx, imgui.StyleVar_WindowPadding, JJ_STYLE.WindowPaddingX, JJ_STYLE.WindowPaddingY)
    imgui.PushStyleVar(ctx, imgui.StyleVar_Alpha, 1.0) -- Force Opacity
    
    vars_pushed = vars_pushed + 7

    return colors_pushed, vars_pushed
end

-- --- MAIN GUI LOOP ---
function loop()
    local window_flags = 0
    -- << CHANGED: Removed AlwaysAutoResize to prevent UI explosion >>
    -- if state.is_edit_mode and state.trigger_resize then
    --     window_flags = imgui.WindowFlags_AlwaysAutoResize
    -- end
    
    -- << CHANGED: Apply Theme BEFORE Begin to support WindowRounding >>
    local pushed_theme_c, pushed_theme_v = ApplyTheme(config.current_theme)
    
    local visible, is_open_ret = imgui.Begin(ctx, config.win_title, state.is_open, window_flags)
    state.is_open = is_open_ret

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
        
        if state.editing_item_idx or state.editing_page_idx then imgui.BeginDisabled(ctx) end -- << CHANGED
        
        local btn_h = state.is_edit_mode and 25 or 0 -- Use 25 in Edit, 0 in Run
        if imgui.Button(ctx, edit_btn_text, edit_btn_w, btn_h) then
            state.is_edit_mode = not state.is_edit_mode
        end
        if state.editing_item_idx or state.editing_page_idx then imgui.EndDisabled(ctx) end -- << CHANGED
        
        imgui.PopStyleColor(ctx, pushed_colors) -- Pop 1 or 2 colors
        -- << END CHANGED >>
        
        -- Main Area
        if state.is_edit_mode then
            -- --- EDIT MODE ---
            
            local is_editing_item = (state.editing_item_idx ~= nil) -- << CHANGED
            local is_editing_page = (state.editing_page_idx ~= nil)
            
            imgui.Separator(ctx) -- << ADDED separator
            
            -- === PART 1: PAGE MANAGEMENT ===
            imgui.Text(ctx, "Page Management")
            
            if is_editing_item then imgui.BeginDisabled(ctx) end -- << This is correct (L327)
            
            if not is_editing_page then
                imgui.PushItemWidth(ctx, -120)
                local name_changed, new_name = imgui.InputText(ctx, "##new_page_name", state.new_page_name, 128)
                if name_changed then state.new_page_name = new_name end
                imgui.PopItemWidth(ctx)
                imgui.SameLine(ctx)
                if imgui.Button(ctx, "Add Page", 110, 0) then
                    if state.new_page_name ~= "" then
                        table.insert(state.pages, { name = state.new_page_name, items = {}, columns = 0 }) -- << CHANGED: Default columns = 0
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
                        state.pages[i].columns = state.temp_page_columns or 0 -- << Save Columns
                        state.editing_page_idx = nil
                        save_data()
                    end
                    imgui.SameLine(ctx)
                    if imgui.Button(ctx, "Cancel##cancelpage"..i) then
                        state.editing_page_idx = nil
                    end
                    
                    -- << Grid Settings >>
                    imgui.SetNextItemWidth(ctx, 100)
                    local col_changed, new_col = imgui.InputInt(ctx, "Columns (0=Auto)##page_col"..i, state.temp_page_columns)
                    if col_changed then 
                        if new_col < 0 then new_col = 0 end
                        state.temp_page_columns = new_col 
                    end
                else
                    if is_editing_page then imgui.BeginDisabled(ctx) end
                    
                    if imgui.SmallButton(ctx, "X##delpage"..i) then
                        state.page_to_delete_idx = i
                    end
                    imgui.SameLine(ctx)
                    if imgui.SmallButton(ctx, "Rename/Edit##page"..i) then
                        state.editing_page_idx = i
                        state.temp_page_name = page.name
                        state.temp_page_columns = page.columns or 0 -- << Load Columns
                    end
                    imgui.SameLine(ctx)

                    -- << CHANGED: Wrap DND logic in a DUAL check >>
                    if not is_editing_page and not is_editing_item then -- << CHANGED
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
            
            if is_editing_item then imgui.EndDisabled(ctx) end -- << This is correct (L448)
            
            imgui.Separator(ctx)

            -- === PART 2: BUTTON MANAGEMENT ===
            if #state.pages == 0 then
                imgui.Text(ctx, "No pages exist. Please add a page to begin.")
            elseif not state.pages[state.current_page_idx] then
                 imgui.Text(ctx, "Error: Selected page index is invalid.")
                 state.current_page_idx = 1
            else
                local current_page = state.pages[state.current_page_idx]
                -- << CHANGED: 'buttons' to 'items' >>
                local current_items = current_page.items or {} 
                current_page.items = current_items -- Ensure it exists
                
                imgui.Text(ctx, string.format('Editing Items for Page: "%s"', current_page.name))

                -- << START FIX: REMOVED BeginDisabled from here >>
                -- if is_editing_page or is_editing_item then imgui.BeginDisabled(ctx) end -- << REMOVED
                -- << END FIX >>
            
                if not is_editing_item then -- << CHANGED
                    -- << START FIX: ADDED BeginDisabled here >>
                    if is_editing_page then imgui.BeginDisabled(ctx) end
                    -- << END FIX >>
                    
                    imgui.Text(ctx, "Add New Button")
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
                        -- << REVERTED: Removed "Find" button >>
                        imgui.TableNextColumn(ctx); imgui.Text(ctx, "Action ID")
                        imgui.TableNextColumn(ctx); imgui.PushItemWidth(ctx, -1)
                        local id_changed, new_id = imgui.InputText(ctx, "##new_id", state.new_button_id, 256)
                        if id_changed then state.new_button_id = new_id end
                        imgui.PopItemWidth(ctx)
                        -- << END REVERT >>
                        
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
                        imgui.PushItemWidth(ctx, 125) -- << INCREASED FROM 80
                        local w_changed, new_w = imgui.InputInt(ctx, "##new_w", state.new_button_w)
                        if w_changed then state.new_button_w = new_w end
                        imgui.PopItemWidth(ctx)
                        imgui.SameLine(ctx)
                        imgui.PushItemWidth(ctx, 125) -- << INCREASED FROM 80
                        local h_changed, new_h = imgui.InputInt(ctx, "##new_h", state.new_button_h)
                        if h_changed then state.new_button_h = new_h end
                        imgui.PopItemWidth(ctx)
                        
                        -- Row 5: Icon & Tooltip
                        imgui.TableNextColumn(ctx); imgui.Text(ctx, "Icon (Emoji)")
                        imgui.TableNextColumn(ctx); imgui.PushItemWidth(ctx, -1)
                        local icon_changed, new_icon = imgui.InputText(ctx, "##new_icon", state.new_item_icon, 16)
                        if icon_changed then state.new_item_icon = new_icon end
                        imgui.PopItemWidth(ctx)

                        imgui.TableNextColumn(ctx); imgui.Text(ctx, "Tooltip")
                        imgui.TableNextColumn(ctx); imgui.PushItemWidth(ctx, -1)
                        local tt_changed, new_tt = imgui.InputText(ctx, "##new_tt", state.new_item_tooltip, 128)
                        if tt_changed then state.new_item_tooltip = new_tt end
                        imgui.PopItemWidth(ctx)
                        
                        -- Row 6: Image Path (Browse)
                        imgui.TableNextColumn(ctx); imgui.Text(ctx, "Image")
                        imgui.TableNextColumn(ctx)
                        imgui.PushItemWidth(ctx, -35)
                        local img_changed, new_img = imgui.InputText(ctx, "##new_img", state.new_item_image_path, 512)
                        if img_changed then state.new_item_image_path = new_img end
                        imgui.PopItemWidth(ctx)
                        imgui.SameLine(ctx)
                        if imgui.Button(ctx, "...##browse_new", 25, 0) then
                            local f = BrowseForImage()
                            if f then state.new_item_image_path = f end
                        end

                        imgui.EndTable(ctx)
                    end
                    
                    if imgui.Button(ctx, "Add Button", -1, 40) then -- << CHANGED width
                        if state.new_button_name ~= "" and state.new_button_id ~= "" then
                            local new_button = {
                                type = "button", -- << NEW
                                name = state.new_button_name,
                                id = state.new_button_id,
                                color = state.new_button_color,
                                width = state.new_button_w,
                                height = state.new_button_h,
                                icon = state.new_item_icon,
                                tooltip = state.new_item_tooltip,
                                image_path = state.new_item_image_path -- << NEW
                            }
                            table.insert(current_page.items, new_button)
                            
                            state.new_button_name = ""
                            state.new_button_id = ""
                            state.new_button_color = DEFAULT_COLOR_STR
                            state.new_button_w = config.button_size_w
                            state.new_button_h = config.button_size_h
                            state.new_item_icon = ""
                            state.new_item_tooltip = ""
                            state.new_item_image_path = ""
                            
                            save_data()
                            state.trigger_resize = true
                        end
                    end
                    
                    -- << NEW: Add Label / Separator sections >>
                    imgui.Separator(ctx)
                    imgui.Text(ctx, "Add New Label")
                    imgui.PushItemWidth(ctx, -100)
                    local label_changed, new_label = imgui.InputText(ctx, "##new_label", state.new_label_name, 128)
                    if label_changed then state.new_label_name = new_label end
                    imgui.PopItemWidth(ctx)
                    imgui.SameLine(ctx)
                    if imgui.Button(ctx, "Add Label", 90, 0) then
                        if state.new_label_name ~= "" then
                            table.insert(current_page.items, {
                                type = "label",
                                name = state.new_label_name
                            })
                            state.new_label_name = ""
                            save_data()
                            state.trigger_resize = true
                        end
                    end
                    
                    imgui.Separator(ctx)
                    if imgui.Button(ctx, "Add Separator", -1, 0) then
                        table.insert(current_page.items, { type = "separator" })
                        save_data()
                        state.trigger_resize = true
                    end
                    -- << END NEW >>
                    
                    -- << START FIX: ADDED EndDisabled here >>
                    if is_editing_page then imgui.EndDisabled(ctx) end
                    -- << END FIX >>
                end 

                imgui.Separator(ctx)
                
                -- << CHANGED: Added break flag >>
                local button_loop_break = false
                for i, item in ipairs(current_page.items) do -- << CHANGED
                    local item_type = item.type or "button" -- Default to button for migration
                
                    if state.editing_item_idx == i then -- << CHANGED
                        
                        if item_type == "button" then
                            imgui.Text(ctx, "Editing Button:")
                            
                            imgui.PushItemWidth(ctx, -70) -- << Align standard fields
                            local name_changed, new_name = imgui.InputText(ctx, "Name##edit"..i, state.temp_edit_name, 128)
                            if name_changed then state.temp_edit_name = new_name end 
                            imgui.PopItemWidth(ctx)
                            
                            -- << REVERTED: Removed "Find" button >>
                            imgui.PushItemWidth(ctx, -70)
                            local id_changed, new_id = imgui.InputText(ctx, "ID##edit"..i, state.temp_edit_id, 256)
                            if id_changed then state.temp_edit_id = new_id end
                            imgui.PopItemWidth(ctx)
                            -- << END REVERT >>

                            -- << NEW: Icon & Tooltip Edit >>
                            imgui.PushItemWidth(ctx, -70)
                            local icon_changed, new_icon = imgui.InputText(ctx, "Icon##edit"..i, state.temp_edit_icon, 16)
                            if icon_changed then state.temp_edit_icon = new_icon end
                            imgui.PopItemWidth(ctx)
                            
                            imgui.PushItemWidth(ctx, -70)
                            local tt_changed, new_tt = imgui.InputText(ctx, "Tooltip##edit"..i, state.temp_edit_tooltip, 128)
                            if tt_changed then state.temp_edit_tooltip = new_tt end
                            imgui.PopItemWidth(ctx)
                            
                            -- << NEW: Image Edit >>
                            -- Layout: [Input ... ] [Btn] [Label]
                            -- Reserve Space: 70 (Label) + 25 (Btn) + 8 (Space) + 4 (Buffer) ~= 107 -> Use -110
                            imgui.PushItemWidth(ctx, -110) 
                            local img_changed, new_img = imgui.InputText(ctx, "##edit_img"..i, state.temp_edit_image_path, 512)
                            if img_changed then state.temp_edit_image_path = new_img end
                            imgui.PopItemWidth(ctx)
                            imgui.SameLine(ctx)
                            if imgui.Button(ctx, "...##browse_edit"..i, 25, 0) then
                                local f = BrowseForImage()
                                if f then state.temp_edit_image_path = f end
                            end
                            imgui.SameLine(ctx)
                            imgui.Text(ctx, "Image") -- Label on right side
                            -- << END NEW >>
                            
                            -- << START FIX: Restoring missing block >>
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
                            
                            imgui.PushItemWidth(ctx, 125) -- << INCREASED FROM 80
                            local w_changed, new_w = imgui.InputInt(ctx, "W##edit_w"..i, state.temp_edit_w)
                            if w_changed then state.temp_edit_w = new_w end
                            imgui.PopItemWidth(ctx)
                            imgui.SameLine(ctx)
                            imgui.PushItemWidth(ctx, 125) -- << INCREASED FROM 80
                            local h_changed, new_h = imgui.InputInt(ctx, "H##edit_h"..i, state.temp_edit_h)
                            if h_changed then state.temp_edit_h = new_h end
                            imgui.PopItemWidth(ctx)

                            if imgui.Button(ctx, "Save##saveedit"..i) then
                                current_page.items[i].name = state.temp_edit_name
                                current_page.items[i].id = state.temp_edit_id
                                current_page.items[i].color = state.temp_edit_color
                                current_page.items[i].width = state.temp_edit_w
                                current_page.items[i].height = state.temp_edit_h
                                current_page.items[i].icon = state.temp_edit_icon
                                current_page.items[i].tooltip = state.temp_edit_tooltip
                                current_page.items[i].image_path = state.temp_edit_image_path
                                
                                save_data()
                                state.editing_item_idx = nil
                                state.trigger_resize = true
                            end
                            -- << END FIX: Restored missing block >>
                            imgui.SameLine(ctx)
                            
                            if imgui.Button(ctx, "Cancel##canceledit"..i) then
                                state.editing_item_idx = nil -- << CHANGED
                            end
                        
                        elseif item_type == "label" then
                            imgui.Text(ctx, "Editing Label:")
                            local name_changed, new_name = imgui.InputText(ctx, "Name##edit"..i, state.temp_edit_name, 128)
                            if name_changed then state.temp_edit_name = new_name end 

                            if imgui.Button(ctx, "Save##saveedit"..i) then
                                current_page.items[i].name = state.temp_edit_name
                                save_data()
                                state.editing_item_idx = nil -- << CHANGED
                                state.trigger_resize = true
                            end
                            imgui.SameLine(ctx)
                            if imgui.Button(ctx, "Cancel##canceledit"..i) then
                                state.editing_item_idx = nil -- << CHANGED
                            end
                        
                        -- Separators cannot be edited, so they won't trigger this block
                        end

                    else
                        -- << START FIX: ADDED BeginDisabled here >>
                        if is_editing_item or is_editing_page then imgui.BeginDisabled(ctx) end
                        
                        if imgui.SmallButton(ctx, "X##del"..i) then
                            state.item_to_delete_idx = i
                        end
                        imgui.SameLine(ctx)
                        
                        -- << NEW: Only show Edit button for buttons and labels >>
                        if item_type == "button" or item_type == "label" then
                            if imgui.SmallButton(ctx, "Edit##"..i) then
                                state.editing_item_idx = i -- << CHANGED
                                state.temp_edit_name = item.name
                                if item_type == "button" then
                                    state.temp_edit_id = item.id
                                    state.temp_edit_color = item.color or DEFAULT_COLOR_STR
                                    state.temp_edit_w = item.width or config.button_size_w
                                    state.temp_edit_h = item.height or config.button_size_h
                                    state.temp_edit_icon = item.icon or ""
                                    state.temp_edit_tooltip = item.tooltip or ""
                                    state.temp_edit_image_path = item.image_path or ""
                                end
                                state.trigger_resize = true
                            end
                            imgui.SameLine(ctx)
                        else
                            -- Add spacing to align the DND handle
                            imgui.InvisibleButton(ctx, "##spacer"..i, 15, 15)
                            imgui.SameLine(ctx)
                        end
                        
                        -- << CHANGED: Wrap DND logic in a DUAL check >>
                        if not is_editing_item and not is_editing_page then -- << CHANGED
                            -- << CHANGED: Replaced Text() with Selectable() >>
                            imgui.Selectable(ctx, "::##dnd_item"..i, false, 0, 15, 15) -- << CHANGED
                            
                            -- 1. Source
                            if imgui.BeginDragDropSource(ctx) then
                                local payload_str = tostring(i)
                                imgui.SetDragDropPayload(ctx, "DND_ITEM", payload_str) -- << CHANGED
                                imgui.Text(ctx, "Moving " .. (item.name or "Separator")) -- Tooltip
                                imgui.EndDragDropSource(ctx)
                            end
                            
                            -- 2. Target
                            if imgui.BeginDragDropTarget(ctx) then
                                local accepted, payload = imgui.AcceptDragDropPayload(ctx, "DND_ITEM") -- << CHANGED
                                if accepted and payload then
                                    local source_idx = tonumber(payload)
                                    local target_idx = i
                                    
                                    if source_idx and target_idx and source_idx ~= target_idx then
                                        -- Perform the move
                                        local moved_item = table.remove(current_page.items, source_idx) -- << CHANGED
                                        table.insert(current_page.items, target_idx, moved_item) -- << CHANGED
                                        
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
                            imgui.Selectable(ctx, "::##dnd_item_dis"..i, false, imgui.SelectableFlags_Disabled, 15, 15) -- << CHANGED
                        end
                        -- << END CHANGED >>
                        
                        imgui.SameLine(ctx)
                        -- << NEW: Display based on type >>
                        if item_type == "button" then
                            imgui.Text(ctx, string.format('Button: "%s" (ID: %s)', item.name, item.id))
                        elseif item_type == "label" then
                            imgui.Text(ctx, string.format('Label: "%s"', item.name))
                        elseif item_type == "separator" then
                            imgui.Text(ctx, "--- Separator ---")
                        end
                        
                        -- << START FIX: ADDED EndDisabled here >>
                        if is_editing_item or is_editing_page then imgui.EndDisabled(ctx) end
                    end
                    
                    -- << CHANGED: Check flag after loop iteration >>
                    if button_loop_break then break end
                end
                
                if state.item_to_delete_idx then
                    table.remove(current_page.items, state.item_to_delete_idx) -- << CHANGED
                    state.item_to_delete_idx = nil
                    save_data()
                    state.trigger_resize = true
                end
                
                -- << START FIX: REMOVED EndDisabled from here >>
                -- if is_editing_page or is_editing_item then imgui.EndDisabled(ctx) end -- << REMOVED
                -- << END FIX >>
            end 

            -- << NEW: PART 3: CONFIGURATION (IMPORT/EXPORT & THEMES) >>
            imgui.Separator(ctx)
            imgui.Text(ctx, "Configuration")

            if is_editing_item or is_editing_page then imgui.BeginDisabled(ctx) end

            -- Theme Slector
            imgui.Text(ctx, "Theme:")
            imgui.SameLine(ctx)
            imgui.SetNextItemWidth(ctx, 150)
            if imgui.BeginCombo(ctx, "##theme_selector", config.current_theme) then
                for theme_name, _ in pairs(Themes) do
                    local is_selected = (config.current_theme == theme_name)
                    if imgui.Selectable(ctx, theme_name, is_selected) then
                        config.current_theme = theme_name
                        -- In a real app we might want to save this to ExtState separately or in the main blob
                        -- For now, let's just save it with the data if we want, or separate?
                        -- To keep it simple, let's just keep it in memory for session or save to ExtState "Theme"
                        reaper.SetExtState("Hosi.Panel", "Theme", theme_name, true)
                    end
                    if is_selected then imgui.SetItemDefaultFocus(ctx) end
                end
                imgui.EndCombo(ctx)
            end

            imgui.SameLine(ctx)
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

            if is_editing_item or is_editing_page then imgui.EndDisabled(ctx) end -- << This is correct (L825)
            -- << END NEW >>

        else
            -- --- RUN MODE ---
            
            -- << UI CHANGE: TabBar logic was MOVED UP to the toolbar >>
            
            -- Render content for the *selected* tab
            if #state.pages > 0 and state.pages[state.current_page_idx] then
                local current_page = state.pages[state.current_page_idx]
                local items = current_page.items or {}
                
                local cols = current_page.columns or 0
                local use_grid = (cols > 0)
                
                if use_grid then
                    if imgui.BeginTable(ctx, "PageGrid", cols, imgui.TableFlags_SizingStretchProp) then
                         -- No specific setup needed for strict grid unless we want borders
                    else
                         use_grid = false -- Fail safe
                    end
                end

                if #items == 0 then
                    imgui.Text(ctx, "No items on this page. Click 'Edit' to add one.")
                end
                
                local visible_items_count = 0 
                for i, item in ipairs(items) do
                    -- Filter implementation: Visible per context could go here
                    
                    if use_grid then
                        imgui.TableNextColumn(ctx)
                        -- Expand to cell width
                         imgui.PushItemWidth(ctx, -1)
                    end

                    local item_type = item.type or "button"
                    
                    if item_type == "button" then
                        local color_str = item.color or DEFAULT_COLOR_STR 
                        
                        -- In Grid Mode, we might want to ignore custom width and fill the cell
                        -- Or respect it? Let's respect it if not in grid, fill if in grid?
                        -- "TableFlags_SizingStretchProp" means columns share width. 
                        -- Typically in a grid button you want full width (-1) or specific.
                        -- Let's use item.width if > 0, else -1?
                        -- Actually, let's use the defined width if not in grid, and -1 (Full Cell) if in grid.
                        
                        local w = (use_grid) and -1.0 or (item.width or config.button_size_w)
                        local h = item.height or config.button_size_h
                        
                        imgui.PushStyleColor(ctx, imgui.Col_Button, PackColor(color_str))
                        
                        -- Label logic: Use Icon if present, else Name
                        local display_label = item.name or "Button"
                        if item.icon and item.icon ~= "" then
                            display_label = item.icon .. " " .. display_label
                        end
                        
                        -- DO BUTTON (Image or Text)
                        local clicked = false
                        local img_obj = GetCachedImage(item.image_path)
                        
                        if img_obj then
                            -- Image Button
                            if imgui.ImageButton(ctx, "##imgbtn"..i, img_obj, w, h) then
                                clicked = true
                            end
                        else
                            -- Normal Button
                            if imgui.Button(ctx, display_label .. "##btn" .. i, w, h) then
                                clicked = true
                            end
                        end
                        
                        if clicked then
                            local num_cmd = tonumber(item.id)
                            if num_cmd then
                                reaper.Main_OnCommand(num_cmd, 0)
                            else
                                reaper.Main_OnCommand(reaper.NamedCommandLookup(item.id), 0)
                            end
                        end
                        
                        -- Tooltip
                        if item.tooltip and item.tooltip ~= "" then
                            if imgui.IsItemHovered(ctx) then
                                imgui.SetTooltip(ctx, item.tooltip)
                            end
                        end
                        
                        imgui.PopStyleColor(ctx)
                        
                        if not use_grid then
                            local next_item = items[i+1]
                            local next_w = 0
                            if next_item and (next_item.type == "button" or not next_item.type) then
                                next_w = next_item.width or config.button_size_w
                            end
                            
                            -- Simple auto-flow logic (only if next item is also a button)
                            if next_w > 0 and (imgui.GetCursorPosX(ctx) + item_spacing_x + next_w < available_w) then
                                imgui.SameLine(ctx, 0, item_spacing_x)
                            end
                        end
                        
                    elseif item_type == "label" then
                        imgui.Text(ctx, item.name)
                        
                    elseif item_type == "separator" then
                        imgui.Separator(ctx)
                    end
                end
            else
                -- << UI CHANGE: This check is now handled above >>
            end
        end

        -- << REMOVED: Call to DrawActionPickerPopup() >>

        -- << REMOVED: Call to DrawActionPickerPopup() >>

    end
    
    -- << CHANGED: Pop styles OUTSIDE 'if visible' block because ApplyTheme is before Begin >>
    imgui.PopStyleColor(ctx, pushed_theme_c)
    imgui.PopStyleVar(ctx, pushed_theme_v)
    
    if visible then imgui.End(ctx) end

    if state.is_open then reaper.defer(loop) end
end

-- --- SCRIPT START AND EXIT ---
function Main()
    load_data() 
    
    local needs_save = false
    
    -- << NEW: Migration logic for data structure v1.1.0 >>
    for _, page in ipairs(state.pages) do
        -- 1. Get the list (might be old 'buttons' or new 'items')
        local item_list = page.items or page.buttons
        if item_list then
            -- 2. Run old v1.0.0 migration first
            if migrate_buttons_v1_3_3(item_list) then 
                needs_save = true
            end
            
            -- 3. Run new v1.1.0 migration (add 'type')
            for _, item in ipairs(item_list) do
                if item.type == nil then
                    item.type = "button"
                    needs_save = true
                end
            end
            
            -- 4. Standardize on 'items'
            page.items = item_list
            page.buttons = nil
        else
            -- If page has neither, initialize 'items'
            page.items = {}
        end
    end
    -- << END NEW >>
    
    if needs_save then
        save_data()
    end
    
    loop()
end

reaper.defer(Main)

