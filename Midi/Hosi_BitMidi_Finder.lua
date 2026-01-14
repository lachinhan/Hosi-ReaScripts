-- @description Hosi BitMidi Finder
-- @version 1.1
-- @author Hosi
-- @about
--   Search and import MIDI files from BitMidi.com directly into REAPER.
--   Features:
--   - Search BitMidi database (Smart Caching included)
--   - Preview MIDI files (with ReaSynth and Safety Limiter)
--   - One-click Import (adds to project and auto-removes preview track)
--   - Modern Dark UI
-- @changelog
--   v1.1
--     + Added Smart Caching (Instant repeated searches, 24h expiration)
--     + Improved Robust HTML Parsing (Handles quotes, attributes, and entities)
--     + Added "Force Refresh" (Shift + Click Search)
--     + Fixed Import bug (Prevented deletion of imported items when previewing)
--   v1.0
--     + Initial Release
--     + Search, Preview, Import functionality
--     + Modern Dark UI

-- Check if ReaImGui is installed
if not reaper.APIExists('ImGui_GetVersion') then
    reaper.ShowMessageBox("This script requires ReaImGui.\nPlease install it via ReaPack.", "Missing Library Error", 0)
    return
end

local ctx = reaper.ImGui_CreateContext('BitMidi Finder')
local FLT_MIN, FLT_MAX = reaper.ImGui_NumericLimits_Float()

-- Configuration
local CONFIG = {
    temp_dir = reaper.GetResourcePath() .. "/Scripts/", -- Temporary file location
    cache_dir = reaper.GetResourcePath() .. "/Scripts/Hosi_BitMidi_Cache/", -- Cache location
    search_file = "bitmidi_search.html",
    detail_file = "bitmidi_detail.html",
    midi_file = "downloaded_midi.mid",
    user_agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
}

-- State variables
local state = {
    search_query = "",
    results = {}, -- Format { {name="Mario", link="/mario"}, ... }
    status = "Ready.",
    is_loading = false,
    selected_index = -1
}

-- GM Instrument Map (0-127)
local GM_INSTRUMENTS = {
    [0]="Acoustic Grand Piano", [1]="Bright Acoustic Piano", [2]="Electric Grand Piano", [3]="Honky-tonk Piano",
    [4]="Electric Piano 1", [5]="Electric Piano 2", [6]="Harpsichord", [7]="Clavinet",
    [8]="Celesta", [9]="Glockenspiel", [10]="Music Box", [11]="Vibraphone",
    [12]="Marimba", [13]="Xylophone", [14]="Tubular Bells", [15]="Dulcimer",
    [16]="Drawbar Organ", [17]="Percussive Organ", [18]="Rock Organ", [19]="Church Organ",
    [20]="Reed Organ", [21]="Accordion", [22]="Harmonica", [23]="Tango Accordion",
    [24]="Acoustic Guitar (nylon)", [25]="Acoustic Guitar (steel)", [26]="Electric Guitar (jazz)", [27]="Electric Guitar (clean)",
    [28]="Electric Guitar (muted)", [29]="Overdriven Guitar", [30]="Distortion Guitar", [31]="Guitar Harmonics",
    [32]="Acoustic Bass", [33]="Electric Bass (finger)", [34]="Electric Bass (pick)", [35]="Fretless Bass",
    [36]="Slap Bass 1", [37]="Slap Bass 2", [38]="Synth Bass 1", [39]="Synth Bass 2",
    [40]="Violin", [41]="Viola", [42]="Cello", [43]="Contrabass",
    [44]="Tremolo Strings", [45]="Pizzicato Strings", [46]="Orchestral Harp", [47]="Timpani",
    [48]="String Ensemble 1", [49]="String Ensemble 2", [50]="SynthStrings 1", [51]="SynthStrings 2",
    [52]="Choir Aahs", [53]="Voice Oohs", [54]="Synth Voice", [55]="Orchestra Hit",
    [56]="Trumpet", [57]="Trombone", [58]="Tuba", [59]="Muted Trumpet",
    [60]="French Horn", [61]="Brass Section", [62]="SynthBrass 1", [63]="SynthBrass 2",
    [64]="Soprano Sax", [65]="Alto Sax", [66]="Tenor Sax", [67]="Baritone Sax",
    [68]="Oboe", [69]="English Horn", [70]="Bassoon", [71]="Clarinet",
    [72]="Piccolo", [73]="Flute", [74]="Recorder", [75]="Pan Flute",
    [76]="Blown Bottle", [77]="Shakuhachi", [78]="Whistle", [79]="Ocarina",
    [80]="Lead 1 (square)", [81]="Lead 2 (sawtooth)", [82]="Lead 3 (calliope)", [83]="Lead 4 (chiff)",
    [84]="Lead 5 (charang)", [85]="Lead 6 (voice)", [86]="Lead 7 (fifths)", [87]="Lead 8 (bass + lead)",
    [88]="Pad 1 (new age)", [89]="Pad 2 (warm)", [90]="Pad 3 (polysynth)", [91]="Pad 4 (choir)",
    [92]="Pad 5 (bowed)", [93]="Pad 6 (metallic)", [94]="Pad 7 (halo)", [95]="Pad 8 (sweep)",
    [96]="FX 1 (rain)", [97]="FX 2 (soundtrack)", [98]="FX 3 (crystal)", [99]="FX 4 (atmosphere)",
    [100]="FX 5 (brightness)", [101]="FX 6 (goblins)", [102]="FX 7 (echoes)", [103]="FX 8 (sci-fi)",
    [104]="Sitar", [105]="Banjo", [106]="Shamisen", [107]="Koto",
    [108]="Kalimba", [109]="Bag pipe", [110]="Fiddle", [111]="Shanai",
    [112]="Tinkle Bell", [113]="Agogo", [114]="Steel Drums", [115]="Woodblock",
    [116]="Taiko Drum", [117]="Melodic Tom", [118]="Synth Drum", [119]="Reverse Cymbal",
    [120]="Guitar Fret Noise", [121]="Breath Noise", [122]="Seashore", [123]="Bird Tweet",
    [124]="Telephone Ring", [125]="Helicopter", [126]="Applause", [127]="Gunshot"
}

-- =========================================================
-- UTILITIES
-- =========================================================

-- Determine file path based on OS
local function get_path(filename)
    local path = CONFIG.temp_dir .. filename
    if reaper.GetOS() == "Win32" or reaper.GetOS() == "Win64" then
        path = path:gsub("/", "\\")
    end
    return path
end

-- URL Encode for search query
local function url_encode(str)
    if (str) then
        str = string.gsub(str, "\n", "\r\n")
        str = string.gsub(str, "([^%w %-%_%.%~])",
            function(c) return string.format("%%%02X", string.byte(c)) end)
        str = string.gsub(str, " ", "+")
    end
    return str
end

-- Read text file
local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local content = f:read("*all")
    f:close()
    return content
end

-- Write text file
local function write_file(path, content)
    local f = io.open(path, "wb")
    if not f then return false end
    f:write(content)
    f:close()
    return true
end

-- Ensure Cache Directory Exists
local function ensure_cache_dir()
    if reaper.RecursiveCreateDirectory then
        reaper.RecursiveCreateDirectory(CONFIG.cache_dir, 0)
    else
        -- Fallback for older Reaper versions, strict OS checks might be needed but assuming modern Reaper
        os.execute('mkdir "' .. CONFIG.cache_dir .. '"') 
    end
end

-- Get Cache Path from Query
local function get_cache_path(query)
    -- Sanitize query for filename
    local safe_name = query:gsub("[^%w%s]", ""):gsub("%s+", "_"):lower()
    return CONFIG.cache_dir .. "search_" .. safe_name .. ".html"
end

-- Helper: Decode HTML Entities
local function html_decode(str)
    local entities = {
        ["&amp;"] = "&",
        ["&quot;"] = '"',
        ["&apos;"] = "'",
        ["&lt;"] = "<",
        ["&gt;"] = ">",
        ["&#039;"] = "'"
    }
    for k, v in pairs(entities) do
        str = str:gsub(k, v)
    end
    return str
end

-- Execute curl command (Blocking)
-- Based on report: Use os.execute with cURL to download HTML
local function run_curl(url, output_file)
    local cmd = string.format('curl -s -L -A "%s" -o "%s" "%s"', 
        CONFIG.user_agent, output_file, url)
    
    -- Use reaper.ExecProcess to run silently (no flashing window)
    -- Note: ExecProcess requires full command line. 
    -- On Windows, curl is typically in System32, which works fine.
    reaper.ExecProcess(cmd, 0)
end

-- =========================================================
-- CORE LOGIC
-- =========================================================

-- 1. Search
local function perform_search(force_refresh)
    if state.search_query == "" then 
        state.status = "Please enter a keyword!"
        return 
    end

    state.status = "Searching... (Please wait)"
    state.results = {} -- Clear old results
    state.selected_index = -1
    
    ensure_cache_dir()
    local cache_path = get_cache_path(state.search_query)
    local content = nil
    
    -- Check Cache (if not forced)
    if not force_refresh and reaper.file_exists(cache_path) then
        local f = io.open(cache_path, "rb")
        if f then
            local header = f:read("*l") -- Read first line
            local body = f:read("*all")
            f:close()
            
            -- Parsing Header: EXPIRY:<timestamp>
            local timestamp = header and header:match("EXPIRY:(%d+)")
            
            -- Validate: Has timestamp, Body exists (>100 bytes), and Age < 24h
            if timestamp and body and #body > 100 then
                 local age = os.time() - tonumber(timestamp)
                 if age < 86400 then -- 86400 seconds = 24 hours
                     state.status = "Loading from cache..."
                     content = body
                 end
            end
        end
    end
    
    if not content then
        -- Build search URL
        local search_url = "https://bitmidi.com/search?q=" .. url_encode(state.search_query)
        local output_path = get_path(CONFIG.search_file)
    
        -- Call cURL
        run_curl(search_url, output_path)
    
        -- Read and Parse HTML
        local dl_content = read_file(output_path)
        
        -- Save to Cache only if valid
        if dl_content and #dl_content > 100 then
            state.status = "Saving to cache..."
            content = dl_content -- Use downloaded content
            
            -- Write with Header
            local f = io.open(cache_path, "wb")
            if f then
                f:write("EXPIRY:" .. os.time() .. "\n")
                f:write(content)
                f:close()
            end
        end
    end

    if not content then
        state.status = "Error: Could not read data."
        return
    end

    -- Use Lua Pattern to extract (Robust Version)
    -- 1. href=['"] : Start with href= and quote (single/double)
    -- 2. (/[^'"]-) : Capture 1 -> Link (starts with / and no quotes)
    -- 3. ['"]      : Closing quote
    -- 4. [^>]*>    : Ignore other attributes until closing >
    -- 5. (.-)</a>  : Capture 2 -> Song Name (until </a>)
    local pattern = "href=['\"](/[^'\"]-)['\"][^>]*>(.-)</a>"

    for link, name in string.gmatch(content, pattern) do
        -- Filter out junk links
        if not link:match("search") and 
           not link:match("login") and 
           not link:match("register") and 
           not link:match("tag") and
           not link:match("/about") and
           not link:match("/random") and
           not link:match("/privacy") and
           not link:match("twitter") and
           link:match("-") and 
           name:len() > 1 then
           
            -- 1. Strip HTML tags from name
            name = name:gsub("<[^>]+>", "")
            
            -- 2. Trim whitespace
            name = name:match("^%s*(.-)%s*$")
            
            -- 3. Decode HTML Entities (e.g. &amp; -> &)
            name = html_decode(name)
            
            table.insert(state.results, {name = name, link = link})
        end
    end

    if #state.results == 0 then
        state.status = "No results found."
    else
        state.status = "Found " .. #state.results .. " songs."
    end
end

-- 3. Preview Logic
state.playing_index = -1
state.preview_track_name = "BitMidi Preview"

local function get_preview_track()
    -- Find existing track
    for i = 0, reaper.CountTracks(0) - 1 do
        local tr = reaper.GetTrack(0, i)
        local _, name = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
        if name == state.preview_track_name then
            return tr
        end
    end
    
    -- Create if missing
    reaper.InsertTrackAtIndex(0, true)
    local tr = reaper.GetTrack(0, 0)
    reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", state.preview_track_name, true)
    reaper.SetMediaTrackInfo_Value(tr, "I_SOLO", 1) -- Solo it so we hear it clearly
    
    -- Add ReaSynth
    local idx = reaper.TrackFX_GetByName(tr, "VST: ReaSynth", false)
    if idx == -1 then
        reaper.TrackFX_AddByName(tr, "VST: ReaSynth", false, -1)
    end
    
    -- Add Safety Limiter
    local limitIdx = reaper.TrackFX_GetByName(tr, "JS: Event Horizon Limiter/Clipper", false)
    if limitIdx == -1 then
        local addedIdx = reaper.TrackFX_AddByName(tr, "JS: Event Horizon Limiter/Clipper", false, -1)
        -- Set Ceiling to -0.1dB to be safe
        if addedIdx >= 0 then
             reaper.TrackFX_SetParamNormalized(tr, addedIdx, 1, 0.99) -- Approx -0.1dB ceiling
        end
    end
    
    return tr
end

local function delete_preview_track()
    for i = reaper.CountTracks(0) - 1, 0, -1 do
        local tr = reaper.GetTrack(0, i)
        local _, name = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
        if name == state.preview_track_name then
            reaper.DeleteTrack(tr)
        end
    end
end

local function stop_preview()
    reaper.OnStopButton()
    state.playing_index = -1
    
    local tr = get_preview_track()
    if tr then
        -- Clear items on preview track
        local count = reaper.CountTrackMediaItems(tr)
        for i = count - 1, 0, -1 do
            local item = reaper.GetTrackMediaItem(tr, i)
            reaper.DeleteTrackMediaItem(tr, item)
        end
    end
    reaper.UpdateArrange()
end

local function preview_midi(index)
    -- If already playing this one, stop
    if state.playing_index == index then
        stop_preview()
        return
    end

    local item = state.results[index]
    if not item then return end
    
    state.status = "Preparing preview..."
    stop_preview() -- Stop any current preview
    
    -- 1. Find link (Code duplication here could be refactored, but keeping simple for now)
    local detail_url = "https://bitmidi.com" .. item.link
    local detail_path = get_path(CONFIG.detail_file)
    run_curl(detail_url, detail_path)
    
    local content = read_file(detail_path)
    if not content then return end
    
    -- Robust .mid link parsing (Single/Double quotes)
    local midi_link = string.match(content, "href=['\"]([^'\"]-%.mid)['\"]")
    
    if not midi_link then state.status = "Preview Error: No link"; return end
    
    if not midi_link:match("http") then midi_link = "https://bitmidi.com" .. midi_link end
    
    -- 2. Download to preview file
    local preview_path = get_path("preview.mid")
    run_curl(midi_link, preview_path)
    
    -- 3. Insert to Preview Track (Low Level API to avoid Prompt)
    local tr = get_preview_track()
    reaper.SetOnlyTrackSelected(tr)
    reaper.SetMediaTrackInfo_Value(tr, "I_SOLO", 1) -- Ensure solo
    
    -- Create Item manually
    local newItem = reaper.AddMediaItemToTrack(tr)
    local newTake = reaper.AddTakeToMediaItem(newItem)
    
    -- Create Source
    local src = reaper.PCM_Source_CreateFromFile(preview_path)
    if not src then 
        state.status = "Preview Error: Bad Source" 
        reaper.DeleteTrackMediaItem(tr, newItem)
        return 
    end
    
    reaper.SetMediaItemTake_Source(newTake, src)
    reaper.SetMediaItemTakeInfo_Value(newTake, "D_STARTOFFS", 0)
    
    -- Set item position and length
    local length, isQN = reaper.GetMediaSourceLength(src)
    if isQN then 
        -- If length is in QN, convert to time? Actually PCM_Source usually returns seconds for .mid if imported as item?
        -- For MIDI source length returns QN often. Converting:
        length = reaper.TimeMap2_QNToTime(0, length)
    end
    
    reaper.SetMediaItemInfo_Value(newItem, "D_POSITION", reaper.GetCursorPosition())
    reaper.SetMediaItemInfo_Value(newItem, "D_LENGTH", length)
    reaper.UpdateItemInProject(newItem)
    
    -- 4. Play
    -- Move cursor to start of item
    reaper.SetEditCurPos(reaper.GetCursorPosition(), false, false)
    reaper.OnPlayButton()
    state.playing_index = index
    state.status = "Previewing: " .. item.name
end



-- Analysis Function
local function analyze_imported_tracks(start_idx, end_idx)
    -- Iterate the range of newly added tracks
    for i = start_idx, end_idx - 1 do
        local tr = reaper.GetTrack(0, i)
        local item_count = reaper.CountTrackMediaItems(tr)
        
        -- Check first item's active take
        if item_count > 0 then
            local item = reaper.GetTrackMediaItem(tr, 0)
            local take = reaper.GetActiveTake(item)
            
            if take and reaper.TakeIsMIDI(take) then
                local _, notecnt, ccevtcnt, _ = reaper.MIDI_CountEvts(take)
                
                -- 1. Check for Drums (Channel 10) - (Chan 10 is index 9)
                local is_drums = false
                for n = 0, notecnt - 1 do
                    local _, _, _, _, _, chan, _, _ = reaper.MIDI_GetNote(take, n)
                    if chan == 9 then
                        is_drums = true
                        break
                    end
                end
                
                if is_drums then
                    reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "Drums", true)
                else
                    -- 2. Check for Program Change
                    for c = 0, ccevtcnt - 1 do
                        local _, _, _, _, chanmsg, _, msg2, _ = reaper.MIDI_GetCC(take, c)
                        
                        -- Program Change is 0xC0 (192) - 0xCF (207)
                        if (chanmsg & 0xF0) == 192 then
                             local pc_num = msg2
                             local inst_name = GM_INSTRUMENTS[pc_num]
                             if inst_name then
                                 reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", inst_name, true)
                                 break -- Found first PC, rename and next track
                             end
                        end
                    end
                end
            end
        end
    end
end

-- 2. Download and Import
local function download_and_import(index)
    local item = state.results[index]
    if not item then return end

    state.status = "Fetching download link..."
    
    -- Step 2.1: Download detail page to find real .mid link
    local detail_url = "https://bitmidi.com" .. item.link
    local detail_path = get_path(CONFIG.detail_file)
    run_curl(detail_url, detail_path)

    local content = read_file(detail_path)
    if not content then return end

    -- Find .mid link (Robust Pattern)
    local midi_link = string.match(content, "href=['\"]([^'\"]-%.mid)['\"]")
    
    if not midi_link then
        state.status = "Error: Could not find download link on this page."
        return
    end

    -- Handle relative links if necessary
    if not midi_link:match("http") then
        midi_link = "https://bitmidi.com" .. midi_link
    end

    -- Step 2.2: Download MIDI file
    state.status = "Downloading MIDI file..."
    local midi_path = get_path(CONFIG.midi_file)
    run_curl(midi_link, midi_path)

    -- Step 2.3: Import into Reaper
    state.status = "Importing into Reaper..."
    
    local prev_track_cnt = reaper.CountTracks(0) -- Capture track count BEFORE import
    
    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock()
    
    -- Add to new track or current track
    local track = reaper.GetSelectedTrack(0, 0)
    
    -- Fix: If selected track is Preview Track, ignore it (deselect) so we don't import onto it
    if track then
         local _, tr_name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
         if tr_name == state.preview_track_name then
             reaper.SetTrackSelected(track, false) -- Deselect preview track
             track = nil -- Force logic below to find another track or create new one
         end
    end
    
    if not track then
        -- If no track selected (or was preview), add to end
        reaper.InsertTrackAtIndex(reaper.CountTracks(0), true)
        track = reaper.GetTrack(0, reaper.CountTracks(0)-1)
    end
    
    -- Use InsertMedia
    reaper.SetOnlyTrackSelected(track)
    local result = reaper.InsertMedia(midi_path, 0) -- 0: Add to current track/new track depending on prefs
    
    -- Rename Item nicely (Use song name)
    local item_media = reaper.GetSelectedMediaItem(0, 0)
    if item_media then
        local take = reaper.GetActiveTake(item_media)
        if take then
            reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", item.name, true)
        end
    end

    reaper.Undo_EndBlock("Import BitMidi: " .. item.name, -1)
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
    
    -- Cleanup Preview Track
    stop_preview() -- Ensure playback stops
    delete_preview_track()
    
    state.status = "Done: " .. item.name
    
    -- Auto-Analyze names using the new track range
    local new_track_cnt = reaper.CountTracks(0)
    analyze_imported_tracks(prev_track_cnt, new_track_cnt)
end



-- =========================================================
-- UI THEME & STYLING
-- =========================================================

local THEME = {
    WinBg       = 0x121212FF,
    ChildBg     = 0x1E1E1EFF,
    FrameBg     = 0x2C2C3EFF,
    FrameBgHov  = 0x3D3D55FF,
    FrameBgAct  = 0x4A90E2FF,
    Button      = 0x2C2C3EFF,
    ButtonHov   = 0x3D3D55FF,
    ButtonAct   = 0x4A90E2FF,
    Text        = 0xE0E0E0FF,
    TextDis     = 0x808080FF,
    Accent      = 0x4A90E2FF,
    Success     = 0x00CC66FF,
    Border      = 0x40404077,
    Header      = 0x2C2C3EFF,
    HeaderHov   = 0x3D3D55FF,
    HeaderAct   = 0x4A90E2FF,
}

local function push_theme(ctx)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(),     THEME.WinBg)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ChildBg(),      THEME.ChildBg)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBg(),      THEME.FrameBg)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgHovered(), THEME.FrameBgHov)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgActive(),  THEME.FrameBgAct)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),       THEME.Button)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(),  THEME.ButtonHov)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),   THEME.ButtonAct)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(),         THEME.Text)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(),       THEME.Border)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(),       THEME.Header)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderHovered(),  THEME.HeaderHov)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderActive(),   THEME.HeaderAct)

    -- Rounding
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(), 8)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ChildRounding(), 6)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 4)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_GrabRounding(), 4)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_PopupRounding(), 6)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ScrollbarRounding(), 6)
    
    -- Spacing
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), 8, 8)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), 10, 6)
end

local function pop_theme(ctx)
    reaper.ImGui_PopStyleVar(ctx, 8)
    reaper.ImGui_PopStyleColor(ctx, 13)
end

-- =========================================================
-- REAIMGUI INTERFACE (GUI LOOP)
-- =========================================================

local function loop()
    push_theme(ctx)
    -- FIX: Add NoScrollbar to main window to prevent button being pushed off
    local window_flags = reaper.ImGui_WindowFlags_NoScrollbar() 
    local visible, open = reaper.ImGui_Begin(ctx, 'BitMidi Finder', true, window_flags)
    
    if visible then
        -- 1. HEADER
        -- Draw a nice title bar or branding if needed, but standard ImGui title is active.
        
        -- Custom Search Bar
        local w, h = reaper.ImGui_GetContentRegionAvail(ctx)
        
        reaper.ImGui_SetNextItemWidth(ctx, w - 100)
        local enter_pressed
        _, state.search_query = reaper.ImGui_InputTextWithHint(ctx, '##SearchBox', 'Search for songs (e.g. Mario, Zelda)...', state.search_query)
        local is_input_active = reaper.ImGui_IsItemActive(ctx)
        local is_enter = reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Enter())
        
        reaper.ImGui_SameLine(ctx)
        
        if reaper.ImGui_Button(ctx, 'Search', 92, 0) or (is_input_active and is_enter) then
            -- Force Refresh if Shift is held
            local force = false
            if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_LeftShift()) or reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_RightShift()) then
                force = true
            end
            perform_search(force)
        end

        reaper.ImGui_Spacing(ctx)
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_Spacing(ctx)

        -- 2. RESULTS LIST
        -- Use a child window with a slightly lighter/different bg for contrast
        local child_flags = reaper.ImGui_ChildFlags_Border and reaper.ImGui_ChildFlags_Border() or 1
        
        -- FIX: Get remaining height at THIS exact point, then subtract footer
        local avail_w_for_list, avail_h_for_list = reaper.ImGui_GetContentRegionAvail(ctx)
        local footer_height = 110 -- Increased to 110 to ensure button fits completely with padding
        -- Corrected: Allow list to be small if window is small (min 20px)
        local list_h = math.max(20, avail_h_for_list - footer_height)
        
        if reaper.ImGui_BeginChild(ctx, 'ResultsRegion', 0, list_h, child_flags) then
            if #state.results > 0 then
                for i, item in ipairs(state.results) do
                    -- Play/Stop Button
                    local is_playing = (state.playing_index == i)
                    local icon = is_playing and "Stop" or "Play" -- Simple text fallback if no icons, or use Arrow
                    
                    if is_playing then
                        if reaper.ImGui_Button(ctx, "Stop##" .. i) then stop_preview() end
                    else
                        if reaper.ImGui_ArrowButton(ctx, "Play##" .. i, reaper.ImGui_Dir_Right()) then preview_midi(i) end
                    end
                    
                    reaper.ImGui_SameLine(ctx)
                    
                    -- Identify selected
                    local is_selected = (state.selected_index == i)
                    
                    -- Custom Selectable Styling
                    if is_selected then
                        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(), THEME.Accent)
                        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0xFFFFFFFF) -- White on selection
                    end
                    
                    if reaper.ImGui_Selectable(ctx, "  " .. item.name .. "##" .. i, is_selected) then
                        state.selected_index = i
                    end
                    
                    if is_selected then
                        reaper.ImGui_PopStyleColor(ctx, 2)
                    end
                    
                    -- Tooltip for full name/extra info
                    if reaper.ImGui_IsItemHovered(ctx) then
                        reaper.ImGui_SetTooltip(ctx, "Source: BitMidi.com\nDouble-click to import.\nRight Arrow to Preview.")
                        
                        if reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
                            state.selected_index = i
                            download_and_import(i)
                        end
                    end
                end
            else
                -- Empty State Styling
                local avail_w, avail_h = reaper.ImGui_GetContentRegionAvail(ctx)
                reaper.ImGui_SetCursorPos(ctx, (avail_w - 150) / 2, avail_h / 2 - 20)
                reaper.ImGui_TextColored(ctx, THEME.TextDis, "Enter a keyword to search...")
            end
            reaper.ImGui_EndChild(ctx)
        end

        -- 3. FOOTER
        reaper.ImGui_Spacing(ctx)
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_Spacing(ctx)
        
        -- Status Line
        if state.status:match("Error") then
             reaper.ImGui_TextColored(ctx, 0xFF4444FF, state.status)
        elseif state.status:match("Done") then
             reaper.ImGui_TextColored(ctx, THEME.Success, state.status)
        else
             reaper.ImGui_TextColored(ctx, 0xAAAAAAFF, state.status)
        end
        
        -- Big Download Button
        local avail_w = reaper.ImGui_GetContentRegionAvail(ctx)
        
        if state.selected_index == -1 then
            reaper.ImGui_BeginDisabled(ctx)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x333333FF)
        else
            -- Active Button Color (Green or Blue)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x2A70C0FF)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x3A80D0FF)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), 0x1A60B0FF)
        end

        if reaper.ImGui_Button(ctx, 'IMPORT TO REAPER', avail_w, 45) then
            download_and_import(state.selected_index)
        end
        
        if state.selected_index ~= -1 then
             reaper.ImGui_PopStyleColor(ctx, 3)
        else
             reaper.ImGui_PopStyleColor(ctx, 1)
             reaper.ImGui_EndDisabled(ctx)
        end
        
        reaper.ImGui_End(ctx)
    end

    pop_theme(ctx)

    if open then
        reaper.defer(loop)
    else
        if reaper.ImGui_DestroyContext then
            reaper.ImGui_DestroyContext(ctx)
        end
    end
end

-- Start Script
local function cleanup_script()
    stop_preview()
    delete_preview_track()
end
reaper.atexit(cleanup_script)
reaper.defer(loop)