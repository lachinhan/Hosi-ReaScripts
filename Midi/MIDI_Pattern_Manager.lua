--[[
@description    MIDI Pattern Manager (Multi-Mode Paste)
@author         Hosi & Alex
@version        1.2
@reaper_version 6.12+
@extensions     ReaImGui
@provides
  [main] . > Hosi_MIDI Pattern Manager (Multi-Mode Paste).lua

@about
  # MIDI Pattern Manager: Multi-Mode Paste

  A powerful tool to store, rename, and reuse selected MIDI notes as reusable patterns.
  It utilizes a ReaImGui window and supports four pasting modes:

  ## Paste Modes:
  1. **Pitch Only:** Applies the pattern's melodic pitches to selected notes (keeps rhythm/length).
  2. **Velocity Only:** Applies the pattern's velocities to selected notes (keeps rhythm/length/pitch).
  3. **Rhythm Only:** Applies the pattern's start times and lengths to selected notes (keeps pitch/velocity).
  4. **Full Stamp:** Applies the full pattern (Pitch, Rhythm, Velocity) to selected notes, OR stamps new notes if no notes are selected.

  ## Instructions:
  1. Open the MIDI Editor and select the notes you want to save.
  2. Press "STORE Selected Notes as Pattern".
  3. Select a pattern from the list and choose a Paste Mode.
  4. Press "PASTE (Selected Pattern)".

@changelog
  + v1.2 (2025-11-07) - ADD: Tagging System. Can add tags (#Chord, #Arp) to patterns.
                      - ADD: Search now finds matches in both Name and Tags.
                      - FIX: Updated save/load format to be backward-compatible with tags.
					  - FIX: Rewrote "Full Stamp" mode. It now modifies selected notes (looping) like other modes.
                      - If no notes are selected, "Full Stamp" pastes new notes at the cursor (original behavior).
					  - ADD: Window is now "Always On Top" (within REAPER's context).
					  - FIX: Corrected paste looping logic (Modulo fix) for Pitch, Velocity, and Rhythm modes.
  + v1.1 (2025-11-06) - Added Search Bar & Favorites system
  + v1.0 (2025-11-06) - Initial release.
--]]

local reaper = reaper
local script_path = ({reaper.get_action_context()})[2]:match('^(.+[\\/])')
local file_path = script_path .. "midi_patterns.dat"

-- CHECK ReaImGui
if not reaper.ImGui_CreateContext then
    return
end

-- SAVE / LOAD
local function save_patterns(p)
    local f = io.open(file_path, "wb")
    if f then
        for i, v in ipairs(p) do
            f:write("===PAT" .. i .. "===\n")
            f:write(v.name .. "\n")
            f:write((v.is_favorite and "true" or "false") .. "\n") -- v1.1+
            f:write((v.tags or "") .. "\n") -- NEW v1.5: Save tags
            f:write(#v.data .. "\n")
            f:write(v.data)
        end
        f:write("===END===\n")
        f:close()
    end
end

local function load_patterns()
    local p = {}
    local f = io.open(file_path, "rb")
    if f then
        local d = f:read("*a"); f:close()
        local i = 1
        while i < #d do
            local s = d:find("===PAT", i)
            if not s then break end
            i = d:find("===\n", s) + 4
            
            -- Read Name
            local n = d:find("\n", i)
            if not n then break end
            local name = d:sub(i, n - 1)
            i = n + 1
            
            -- Read Line 2 (Could be Fav or Len)
            local l2_end = d:find("\n", i)
            if not l2_end then break end
            local line2 = d:sub(i, l2_end - 1)
            i = l2_end + 1
            
            local is_favorite = false
            local tags = "" -- NEW v1.5
            local len = 0
            
            if line2 == "true" or line2 == "false" then
                -- v1.1 or v1.5 format
                is_favorite = (line2 == "true")
                
                -- Read Line 3 (Could be Tags or Len)
                local l3_end = d:find("\n", i)
                if not l3_end then break end
                local line3 = d:sub(i, l3_end - 1)
                i = l3_end + 1
                
                local len_check = tonumber(line3)
                if len_check then
                    -- v1.1 format (Line 3 is Len)
                    tags = "" -- No tags
                    len = len_check
                else
                    -- v1.5 format (Line 3 is Tags)
                    tags = line3
                    -- Read Line 4 (Must be Len)
                    local l4_end = d:find("\n", i)
                    if not l4_end then break end
                    len = tonumber(d:sub(i, l4_end - 1)) or 0
                    i = l4_end + 1
                end
                
            else
                -- v1.0 format (Line 2 is Len)
                is_favorite = false
                tags = ""
                len = tonumber(line2) or 0
            end

            -- Read Data
            if i + len - 1 > #d then break end -- Fix potential corruption
            local data = d:sub(i, i + len - 1)
            i = i + len
            
            table.insert(p, {name = name, data = data, is_favorite = is_favorite, tags = tags})
        end
    end
    return p
end

-- STORE FULL: SAVE ENTIRE (RHYTHM, LENGTH, PITCH, VELOCITY)
local function get_selected_full()
    local editor = reaper.MIDIEditor_GetActive()
    if not editor then return nil end
    local take = reaper.MIDIEditor_GetTake(editor)
    if not take then return nil end

    local selected_notes = {}
    local _, notes = reaper.MIDI_CountEvts(take)
    for i = 0, notes - 1 do
        local _, sel, _, sp, ep, _, pitch, vel = reaper.MIDI_GetNote(take, i)
        if sel then
            sp = tonumber(sp) or 0
            ep = tonumber(ep) or 0
            table.insert(selected_notes, {start = sp, len = ep - sp, pitch = pitch or 60, vel = vel or 100})
        end
    end

    if #selected_notes == 0 then return nil end
    
    -- Sort notes by start time
    table.sort(selected_notes, function(a, b) return a.start < b.start end)

    local base_start = selected_notes[1].start
    local events = {}
    for _, note in ipairs(selected_notes) do
        local offset = note.start - base_start
        local note_on = string.pack("BBB", 0x90, note.pitch, note.vel)
        local note_off = string.pack("BBB", 0x80, note.pitch, 0)
        table.insert(events, string.pack("i4BB", offset, 0, #note_on) .. note_on)
        table.insert(events, string.pack("i4BB", offset + note.len, 0, #note_off) .. note_off)
    end

    local packed = table.concat(events)
    return packed, take, #selected_notes
end

---
--- HELPER FUNCTIONS (NEW FOR MULTI-MODE)
---

-- NEW FUNCTION: Parse binary data into a note table
-- Requires 'take' to calculate default note length
local function parse_pattern_data(data, take)
    if not data or #data == 0 then return nil end

    local pattern_notes = {}
    local pending_notes = {} -- Key = pitch, Value = {offset, vel}

    -- Default length if NOTE OFF is missing (e.g., 1/4 note)
    -- FIX: Add check for 'take' existence
    local default_len = take and reaper.MIDI_GetPPQPosFromProjTime(take, 0.5) or 480 

    local pos = 1
    local data_len = #data
    while pos + 7 < data_len do
        local offset, _, msg_len = string.unpack("i4BB", data, pos)
        pos = pos + 6
        if pos + msg_len > data_len then break end
        local msg = data:sub(pos, pos + msg_len - 1)
        pos = pos + msg_len
        
        local status = msg:byte(1)
        local pitch = msg:byte(2)
        local vel = msg:byte(3)

        if (status == 0x90 and vel > 0) then -- Note On
            -- If this note is already "on" (no off yet), process the old one first
            if pending_notes[pitch] then
                table.insert(pattern_notes, {
                    offset = pending_notes[pitch].offset, 
                    length = default_len, 
                    pitch = pitch, 
                    vel = pending_notes[pitch].vel
                })
            end
            pending_notes[pitch] = {offset = offset, vel = vel}
            
        elseif (status == 0x80 or (status == 0x90 and vel == 0)) then -- Note Off
            if pending_notes[pitch] then
                local note_on = pending_notes[pitch]
                local length = offset - note_on.offset
                if length <= 0 then length = default_len end -- Ensure valid length
                
                table.insert(pattern_notes, {
                    offset = note_on.offset, 
                    length = length, 
                    pitch = pitch, 
                    vel = note_on.vel
                })
                pending_notes[pitch] = nil -- Remove from pending list
            end
        end
    end
    
    -- Process remaining notes that didn't get a NOTE OFF
    for pitch, note_on in pairs(pending_notes) do
        table.insert(pattern_notes, {
            offset = note_on.offset, 
            length = default_len, 
            pitch = pitch, 
            vel = note_on.vel
        })
    end

    if #pattern_notes == 0 then return nil end
    
    -- Sort notes by offset
    table.sort(pattern_notes, function(a, b) return a.offset < b.offset end)
    return pattern_notes
end

-- NEW FUNCTION: Get selected notes, grouped by start time
local function get_selected_notes_grouped(take)
    local selected_groups = {}
    local _, notes = reaper.MIDI_CountEvts(take)
    for i = 0, notes - 1 do
        local _, sel, _, sp, ep, _, pitch, vel = reaper.MIDI_GetNote(take, i)
        if sel then
            sp = tonumber(sp) or 0
            ep = tonumber(ep) or 0
            local group_key = sp
            if not selected_groups[group_key] then selected_groups[group_key] = {} end
            table.insert(selected_groups[group_key], {idx = i, note_end = ep, vel = vel or 100, pitch = pitch or 60})
        end
    end

    local selected_timings = {}
    for k in pairs(selected_groups) do table.insert(selected_timings, k) end
    table.sort(selected_timings)
    
    if #selected_timings == 0 then return nil, nil end
    return selected_groups, selected_timings
end

-- NEW FUNCTION: Get selected notes, sorted
local function get_selected_notes_sorted(take)
    local selected_notes = {}
    local first_sp = -1
    local _, notes = reaper.MIDI_CountEvts(take)
    for i = 0, notes - 1 do
        local _, sel, _, sp, ep, _, pitch, vel = reaper.MIDI_GetNote(take, i)
        if sel then
            sp = tonumber(sp) or 0
            ep = tonumber(ep) or 0
            table.insert(selected_notes, {idx = i, sp = sp, ep = ep, pitch = pitch or 60, vel = vel or 100})
            if first_sp == -1 or sp < first_sp then
                first_sp = sp
            end
        end
    end
    
    table.sort(selected_notes, function(a, b) return a.sp < b.sp end)
    
    if first_sp == -1 then -- If no notes are selected
        -- FIX (FINAL): Use main REAPER API (GetCursorPosition)
        -- This function always exists and returns the timeline cursor time (seconds)
        local cursor_time_sec = reaper.GetCursorPosition()
        first_sp = reaper.MIDI_GetPPQPosFromProjTime(take, cursor_time_sec)
    end

    return selected_notes, first_sp
end


---
--- PASTE MODE FUNCTIONS (NEW)
---

-- MODE 1: PASTE PITCH ONLY
local function paste_pitch_only(data, take)
    local selected_groups, selected_timings = get_selected_notes_grouped(take)
    local pattern_notes = parse_pattern_data(data, take)
    if not selected_groups or not pattern_notes then return end

    -- Group pattern by offset
    local pattern_groups = {}
    for _, note in ipairs(pattern_notes) do
        if not pattern_groups[note.offset] then pattern_groups[note.offset] = {} end
        table.insert(pattern_groups[note.offset], note)
    end
    local pattern_timings = {}
    for k in pairs(pattern_groups) do table.insert(pattern_timings, k) end
    table.sort(pattern_timings)
    if #pattern_timings == 0 then return end
    
    local num_pat_timings = #pattern_timings

    reaper.Undo_BeginBlock()

    local pat_timing_idx = 1
    for _, sel_timing in ipairs(selected_timings) do
        -- FIX v1.2: Use Modulo for looping timings
        local wrapped_pat_timing_idx = ((pat_timing_idx - 1) % num_pat_timings) + 1
        local pat_timing = pattern_timings[wrapped_pat_timing_idx]
        
        local pat_notes_at_timing = pattern_groups[pat_timing] or {}
        local num_pat_notes_at_timing = #pat_notes_at_timing

        local sel_notes = selected_groups[sel_timing]
        local base_note = sel_notes[1] or {}
        local default_len = base_note.note_end - sel_timing
        local default_vel = base_note.vel

        local pitch_idx = 1
        for _, note in ipairs(sel_notes) do
            -- FIX v1.2: Use Modulo for looping pitches
            local wrapped_pitch_idx = 1
            local pat_pitch = base_note.pitch or 60
            if num_pat_notes_at_timing > 0 then
                wrapped_pitch_idx = ((pitch_idx - 1) % num_pat_notes_at_timing) + 1
                pat_pitch = pat_notes_at_timing[wrapped_pitch_idx] and pat_notes_at_timing[wrapped_pitch_idx].pitch or pat_pitch
            end
            
            reaper.MIDI_SetNote(take, note.idx, true, false, -1, -1, -1, pat_pitch, -1, false)
            pitch_idx = pitch_idx + 1
        end

        -- This loop adds new notes if the pattern chord has more notes than the selected chord
        while pitch_idx <= num_pat_notes_at_timing do
            -- FIX v1.2: Use Modulo for looping pitches (for added notes)
            local wrapped_pitch_idx = ((pitch_idx - 1) % num_pat_notes_at_timing) + 1
            local pat_note = pat_notes_at_timing[wrapped_pitch_idx]
            
            if pat_note then
                reaper.MIDI_InsertNote(take, false, false, sel_timing, sel_timing + default_len, -1, pat_note.pitch, pat_note.vel, false)
            end
            pitch_idx = pitch_idx + 1
        end

        pat_timing_idx = pat_timing_idx + 1
    end

    reaper.MIDI_Sort(take)
    reaper.Undo_EndBlock('Paste Pitch Only', -1)
    reaper.UpdateArrange()
end

-- MODE 2: PASTE VELOCITY ONLY
local function paste_velocity_only(data, take)
    local selected_groups, selected_timings = get_selected_notes_grouped(take)
    local pattern_notes = parse_pattern_data(data, take)
    if not selected_groups or not pattern_notes then return end

    -- Group pattern by offset
    local pattern_groups = {}
    for _, note in ipairs(pattern_notes) do
        if not pattern_groups[note.offset] then pattern_groups[note.offset] = {} end
        table.insert(pattern_groups[note.offset], note)
    end
    local pattern_timings = {}
    for k in pairs(pattern_groups) do table.insert(pattern_timings, k) end
    table.sort(pattern_timings)
    if #pattern_timings == 0 then return end
    
    local num_pat_timings = #pattern_timings

    reaper.Undo_BeginBlock()

    local pat_timing_idx = 1
    for _, sel_timing in ipairs(selected_timings) do
        -- FIX v1.2: Use Modulo for looping timings
        local wrapped_pat_timing_idx = ((pat_timing_idx - 1) % num_pat_timings) + 1
        local pat_timing = pattern_timings[wrapped_pat_timing_idx]
        
        local pat_notes_at_timing = pattern_groups[pat_timing] or {}
        local num_pat_notes_at_timing = #pat_notes_at_timing
        
        local sel_notes = selected_groups[sel_timing]
        local base_note = sel_notes[1] or {}

        local vel_idx = 1
        for _, note in ipairs(sel_notes) do
            -- FIX v1.2: Use Modulo for looping velocities
            local wrapped_vel_idx = 1
            local pat_vel = base_note.vel or 100
            if num_pat_notes_at_timing > 0 then
                wrapped_vel_idx = ((vel_idx - 1) % num_pat_notes_at_timing) + 1
                pat_vel = pat_notes_at_timing[wrapped_vel_idx] and pat_notes_at_timing[wrapped_vel_idx].vel or pat_vel
            end

            reaper.MIDI_SetNote(take, note.idx, true, false, -1, -1, -1, -1, pat_vel, false)
            vel_idx = vel_idx + 1
        end
        pat_timing_idx = pat_timing_idx + 1
    end

    reaper.Undo_EndBlock('Paste Velocity Only', -1)
    reaper.UpdateArrange()
end

-- MODE 3: PASTE RHYTHM ONLY
local function paste_rhythm_only(data, take)
    local selected_notes, first_sp = get_selected_notes_sorted(take)
    local pattern_notes = parse_pattern_data(data, take)
    if not selected_notes or #selected_notes == 0 or not pattern_notes or #pattern_notes == 0 then return end
    
    local pat_base_offset = pattern_notes[1].offset or 0
    local num_pat_notes = #pattern_notes
    
    reaper.Undo_BeginBlock()
    
    local pat_idx = 1
    for _, sel_note in ipairs(selected_notes) do
        -- FIX v1.2: Use Modulo for looping rhythm notes
        local wrapped_pat_idx = ((pat_idx - 1) % num_pat_notes) + 1
        local pat_note = pattern_notes[wrapped_pat_idx]
        
        if pat_note then
            local new_sp = first_sp + (pat_note.offset - pat_base_offset)
            local new_ep = new_sp + pat_note.length
            
            reaper.MIDI_SetNote(take, sel_note.idx, true, false, new_sp, new_ep, -1, -1, -1, false)
        end
        
        pat_idx = pat_idx + 1
    end
    
    reaper.MIDI_Sort(take)
    reaper.Undo_EndBlock('Paste Rhythm Only', -1)
    reaper.UpdateArrange()
end

-- MODE 4: PASTE FULL STAMP
-- *** FIX v1.4: Rewritten to handle both modification and stamping ***
local function paste_full_stamp(data, take)
    local selected_notes, first_sp = get_selected_notes_sorted(take)
    local pattern_notes = parse_pattern_data(data, take)
    if not pattern_notes or #pattern_notes == 0 then return end
    
    local pat_base_offset = pattern_notes[1].offset or 0
    local num_pat_notes = #pattern_notes

    reaper.Undo_BeginBlock()

    if selected_notes and #selected_notes > 0 then
        -- Kịch bản 1: Sửa đổi các nốt đã chọn (Giống như người dùng mong đợi)
        local pat_idx = 1
        for _, sel_note in ipairs(selected_notes) do
            -- Lấy nốt pattern (quay vòng)
            local wrapped_pat_idx = ((pat_idx - 1) % num_pat_notes) + 1
            local pat_note = pattern_notes[wrapped_pat_idx]
            
            if pat_note then
                -- Tính toán vị trí và độ dài mới (giống Rhythm Only)
                local new_sp = first_sp + (pat_note.offset - pat_base_offset)
                local new_ep = new_sp + pat_note.length
                -- Áp dụng CẢ BA (Pitch, Vel, Rhythm)
                reaper.MIDI_SetNote(take, sel_note.idx, true, false, new_sp, new_ep, -1, pat_note.pitch, pat_note.vel, false)
            end
            
            pat_idx = pat_idx + 1
        end
        reaper.MIDI_Sort(take)
        reaper.Undo_EndBlock('Paste Full (Modify Selected)', -1)

    else
        -- Kịch bản 2: Dán mới tại con trỏ (hành vi cũ nếu không có gì được chọn)
        reaper.MIDI_SelectAll(take, false) -- Bỏ chọn
        local _, old_count = reaper.MIDI_CountEvts(take)

        for _, pat_note in ipairs(pattern_notes) do
            local sp = first_sp + (pat_note.offset - pat_base_offset)
            local ep = sp + pat_note.length
            reaper.MIDI_InsertNote(take, false, false, sp, ep, -1, pat_note.pitch, pat_note.vel, true)
        end
        
        reaper.MIDI_Sort(take)
        local _, new_count = reaper.MIDI_CountEvts(take)
        
        -- Chọn các nốt mới
        for i = old_count, new_count - 1 do
            reaper.MIDI_SetNote(take, i, true, false, -1, -1, -1, -1, -1, true) 
        end
        reaper.Undo_EndBlock('Paste Full (Stamp New)', -1)
    end
    
    reaper.UpdateArrange()
end


---
--- UI
---

local ctx = reaper.ImGui_CreateContext('MIDI Pattern Manager')
local patterns = load_patterns()
local selected = 1
local rename_mode = false
local name_input = ""
local rename_tag_input = "" -- NEW v1.2: For editing tags in rename mode
local paste_mode = 1 -- 1:Pitch, 2:Velocity, 3:Rhythm, 4:Stamp
local category_input = "" -- NEW: For category input
local tag_input = "" -- NEW v1.2: For tag input
local search_query = "" -- NEW v1.1: For search bar

local function draw()
    -- Increased default height for new category field
    reaper.ImGui_SetNextWindowSize(ctx, 400, 520, reaper.ImGui_Cond_FirstUseEver())
    
    -- NEW v1.2: Add "Always On Top" flag
    local flags = reaper.ImGui_WindowFlags_AlwaysOnTop
    local visible, open = reaper.ImGui_Begin(ctx, 'MIDI Pattern Manager', true, flags)
    
    if not visible then return open end

    local editor = reaper.MIDIEditor_GetActive()
    local take = editor and reaper.MIDIEditor_GetTake(editor)

    if not editor or not take then
        reaper.ImGui_TextColored(ctx, 0xFFFFFFE0, "OPEN MIDI EDITOR TO USE!")
    else
        -- === STORE ===
        -- Category Input
        local cat_changed, new_cat = reaper.ImGui_InputText(ctx, 'Category (Optional)', category_input)
        if cat_changed then category_input = new_cat end
        
        -- NEW v1.2: Tag Input
        local tag_changed, new_tag = reaper.ImGui_InputText(ctx, 'Tags (e.g., #C, #Arp)', tag_input)
        if tag_changed then tag_input = new_tag end

        if reaper.ImGui_Button(ctx, 'STORE Selected Notes as Pattern') then
            local data, _, count = get_selected_full()
            if data and count > 0 then
                local pattern_number = 1
                for _, p in ipairs(patterns) do
                    -- Check for patterns both with and without categories
                    local base_name = p.name:match("([^/]+)$") or p.name
                    local count_str, num = base_name:match("(%d+) Notes Pattern (%d+)")
                    
                    if count_str and tonumber(count_str) == count then
                        pattern_number = math.max(pattern_number, tonumber(num) + 1)
                    end
                end
                
                local name = count .. " Notes Pattern " .. pattern_number
                
                -- NEW: Prepend category if it exists
                if category_input:match("%S") then -- If not empty or just whitespace
                    name = category_input .. "/" .. name
                end

                -- NEW v1.2: Add tags
                table.insert(patterns, {name = name, data = data, is_favorite = false, tags = tag_input})
                save_patterns(patterns)
                selected = #patterns -- Automatically select the new pattern
                category_input = "" -- Clear category input
                tag_input = "" -- Clear tag input
            end
        end

        reaper.ImGui_Separator(ctx)

        -- === PASTE ===
        reaper.ImGui_Text(ctx, "Paste Mode:")
        if reaper.ImGui_RadioButton(ctx, 'Pitch Only', paste_mode == 1) then paste_mode = 1 end
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_RadioButton(ctx, 'Velocity Only', paste_mode == 2) then paste_mode = 2 end
        
        if reaper.ImGui_RadioButton(ctx, 'Rhythm Only', paste_mode == 3) then paste_mode = 3 end
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_RadioButton(ctx, 'Full Stamp', paste_mode == 4) then paste_mode = 4 end

        if reaper.ImGui_Button(ctx, 'PASTE (Selected Pattern)') and take and selected <= #patterns and patterns[selected] then
            local data = patterns[selected].data
            if paste_mode == 1 then
                paste_pitch_only(data, take)
            elseif paste_mode == 2 then
                paste_velocity_only(data, take)
            elseif paste_mode == 3 then
                paste_rhythm_only(data, take)
            elseif paste_mode == 4 then
                -- FIX v1.4: Changed function call
                paste_full_stamp(data, take)
            end
        end

        reaper.ImGui_Separator(ctx)

        -- === LIST === (Now with Categories and Search)
        reaper.ImGui_Text(ctx, "Pattern List:")

        -- NEW v1.1: Search Bar
        local search_changed, new_search = reaper.ImGui_InputText(ctx, 'Search', search_query)
        if search_changed then search_query = new_search end
        local search_lower = search_query:lower()
        reaper.ImGui_Separator(ctx)
 
        
        -- NEW v1.1: Check window height before drawing child
        local _, win_h = reaper.ImGui_GetWindowSize(ctx)
        local cur_y = reaper.ImGui_GetCursorPosY(ctx) -- FIX v1.2.3: Correctly get single return value

        -- Check if there is enough vertical space for the child window + bottom buttons
        -- (approx 100px for child list + 25px for bottom buttons)
        if win_h - cur_y > 125 then

            -- FIX ImGui_BeginChild: (ctx, id, w, h, border_size, flags)
            -- NEW v1.1: Wrap content in a check
            if reaper.ImGui_BeginChild(ctx, 'PatternList', 0, -25, 1, 0) then
            
                -- NEW: Build a temporary tree structure for the UI
                local tree = {}
                local item_to_rename = -1
                
                -- NEW v1.1: Always create Favorites category
                tree["★ Favorites"] = {}

                -- 1. Build the category tree (with filtering)
                for i, p in ipairs(patterns) do
                    -- NEW v1.1: Add to favorites list
                    if p.is_favorite then
                        local _, pat_name = p.name:match("([^/]+)/(.+)")
                        if not pat_name then pat_name = p.name end
                        
                        table.insert(tree["★ Favorites"], {
                            display_name = pat_name, 
                            original_index = i,
                            full_name = p.name 
                        })
                    end

                    -- NEW v1.2: Update search logic to include tags
                    local search_match = p.name:lower():match(search_lower) or (p.tags and p.tags:lower():match(search_lower))
                    
                    if search_lower == "" or search_match then
                        local cat_name, pat_name = p.name:match("([^/]+)/(.+)")
                        if not cat_name then
                            cat_name = "Uncategorized" -- Default category
                            pat_name = p.name
                        end
                        
                        if not tree[cat_name] then tree[cat_name] = {} end
                        table.insert(tree[cat_name], {
                            display_name = pat_name, 
                            original_index = i, -- Store the index from the flat 'patterns' table
                            full_name = p.name 
                        })
                    end
                end

                -- NEW v1.1: If favorites category is empty, remove it
                if #tree["★ Favorites"] == 0 then
                    tree["★ Favorites"] = nil
                end

                -- 2. Draw the tree
                -- NEW v1.1: Get sorted category keys
                local category_keys = {}
                for cat_name in pairs(tree) do
                    table.insert(category_keys, cat_name)
                end
                table.sort(category_keys, function(a, b)
                    if a == "★ Favorites" then return true end
                    if b == "★ Favorites" then return false end
                    if a == "Uncategorized" then return false end -- (FIXED typo from v1.1)
                    if b == "Uncategorized" then return true end
                    return a:lower() < b:lower()
                end)

                for _, cat_name in ipairs(category_keys) do
                    local items = tree[cat_name]
                    
                    -- Set default open state
                    if (cat_name == "★ Favorites" or (cat_name == "Uncategorized" and #patterns > 0)) and #items > 0 then
                        reaper.ImGui_SetNextItemOpen(ctx, true, reaper.ImGui_Cond_Once())
                    end
                    
                    local node_open = reaper.ImGui_TreeNode(ctx, cat_name .. "##cat" .. cat_name)
                    
                    -- FIX v1.1: Check for click on the folder header
                    if reaper.ImGui_IsItemClicked(ctx) then
                        if cat_name == "Uncategorized" then
                            category_input = ""
                        elseif cat_name ~= "★ Favorites" then -- Don't fill from favorites
                            category_input = cat_name
                        end
                        tag_input = "" -- NEW v1.2: Clear tags when clicking folder
                    end
                    
                    if node_open then
                        for _, item in ipairs(items) do
                            local item_index = item.original_index
                            if rename_mode and selected == item_index then
                                -- Rename mode (now inside the loop)
                                -- The input now edits the FULL name (e.g., "Category/Name")
                                local changed, new_name = reaper.ImGui_InputText(ctx, 'Name##rename'..item_index, name_input)
                                if changed then name_input = new_name end
                                
                                -- NEW v1.5: Add tag editing in-place
                                local tag_edit_changed, new_tag_edit = reaper.ImGui_InputText(ctx, 'Tags##tags_edit'..item_index, rename_tag_input)
                                if tag_edit_changed then rename_tag_input = new_tag_edit end
                                
                                reaper.ImGui_SameLine(ctx)
                                if reaper.ImGui_Button(ctx, 'Save##'..item_index) then
                                    patterns[item_index].name = name_input
                                    patterns[item_index].tags = rename_tag_input -- Save tags
                                    save_patterns(patterns)
                                    rename_mode = false
                                end
                                reaper.ImGui_SameLine(ctx)
                                if reaper.ImGui_Button(ctx, 'Cancel##'..item_index) then
                                    rename_mode = false
                                end
                            else
                                -- Normal display mode
                                
                                -- NEW v1.1: Favorite Toggle
                                local fav_label = (patterns[item_index].is_favorite and "★" or "☆") .. "##fav" .. item_index
                                if reaper.ImGui_Button(ctx, fav_label) then
                                    patterns[item_index].is_favorite = not patterns[item_index].is_favorite
                                    save_patterns(patterns)
                                    -- No need to break loop, ImGui will handle redraw on next frame
                                end
                                reaper.ImGui_SameLine(ctx)
                                
                                -- NEW v1.2: Show tags in selectable label
                                local display_label = item.display_name
                                local item_tags = patterns[item_index].tags or ""
                                if item_tags:match("%S") then
                                    display_label = display_label .. " [" .. item_tags .. "]"
                                end

                                if reaper.ImGui_Selectable(ctx, display_label .. " ##" .. item_index, selected == item_index) then
                                    selected = item_index
                                    tag_input = patterns[item_index].tags or "" -- NEW v1.2: Populate tags
                                    
                                    -- FIX v1.1: Update category input on item selection
                                    if cat_name == "Uncategorized" then
                                        category_input = ""
                                    elseif cat_name ~= "★ Favorites" then
                                        category_input = cat_name
                                    end
                                end
                                if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseClicked(ctx, 1) then -- Right-click
                                    item_to_rename = item_index
                                end
                            end
                        end
                        reaper.ImGui_TreePop(ctx)
                    end
                end
                
                if item_to_rename > 0 then
                    rename_mode = true
                    selected = item_to_rename
                    name_input = patterns[item_to_rename].name -- Use full name for rename
                    rename_tag_input = patterns[item_to_rename].tags or "" -- NEW v1.2: Load tags for rename
                end
            
            end -- NEW v1.1: End of BeginChild check
            reaper.ImGui_EndChild(ctx)

        else
            -- Window is too small, show a message instead of drawing the list
            reaper.ImGui_TextColored(ctx, 0x808080FF, "(Resize window to see pattern list)")
            reaper.ImGui_Dummy(ctx, 0, -25) -- Consume space to keep bottom buttons in place
        end

        -- === MANAGEMENT BUTTONS ===
        if reaper.ImGui_Button(ctx, 'Rename Selected') and selected <= #patterns and patterns[selected] then
            rename_mode = true
            name_input = patterns[selected].name
            rename_tag_input = patterns[selected].tags or "" -- NEW v1.2: Load tags for rename
        end
        reaper.ImGui_SameLine(ctx)
        
        -- NEW: Duplicate Button
        if reaper.ImGui_Button(ctx, 'Duplicate Selected') and selected <= #patterns and patterns[selected] then
            local original = patterns[selected]
            local new_name = original.name .. " (Copy)"
            -- NEW v1.2: Copy tags as well
            local new_pattern = { name = new_name, data = original.data, is_favorite = false, tags = original.tags or "" }
            table.insert(patterns, new_pattern)
            save_patterns(patterns)
            selected = #patterns -- Select the new copy
            -- NEW v1.2: Populate fields with new copy's data
            category_input, name_input = new_pattern.name:match("([^/]+)/(.+)")
            if not category_input then category_input = "" end
            tag_input = new_pattern.tags or ""
            
            rename_mode = false
        end
        reaper.ImGui_SameLine(ctx)

        if reaper.ImGui_Button(ctx, 'DELETE Selected') and selected <= #patterns and patterns[selected] then
            table.remove(patterns, selected)
            save_patterns(patterns)
            selected = math.max(1, math.min(selected, #patterns))
            rename_mode = false
        end
    end

    -- reaper.ImGui_Text(ctx, "File: " .. file_path)
    reaper.ImGui_End(ctx)
    return open
end

local function loop()
    if draw() then
        reaper.defer(loop)
    else
        if reaper.ImGui_DestroyContext then
            reaper.ImGui_DestroyContext(ctx)
        end
    end
end

reaper.defer(loop)