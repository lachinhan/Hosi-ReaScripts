--[[
@description Freesound Search and Import for REAPER (ReaImGui)
@version 1.4
@author Hosi Prod
@changelog
    - v1.4 Added cross-platform support for macOS, Windows, and Linux.
    - v1.3 Added a Favorites/Bookmarking system.
		   Implemented a table layout for search results for better clarity.
    - v1.2 Added "Find Similar" functionality & Search History feature.
    - v1.1 Aligned status text to the right.
    - v1.0 Pro Version 27-Aug-2025
--]]

-- --- REAIMGUI SETUP ---
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require('imgui')('0.9.3')
if not ImGui or type(ImGui) ~= "table" then
    reaper.ShowMessageBox("Failed to initialize ReaImGui library. Please ensure it is installed and up to date via ReaPack.", "Error", 0)
    return
end
local ctx = ImGui.CreateContext('Hosi Freesound Search')

-- --- CONFIGURATION ---
local settings_file = reaper.GetResourcePath() .. '/hosi_freesound_settings.txt'
local token_file = reaper.GetResourcePath() .. '/hosi_freesound_tokens.txt'
local history_file = reaper.GetResourcePath() .. '/hosi_freesound_history.txt'
local favorites_file = reaper.GetResourcePath() .. '/hosi_freesound_favorites.txt'

-- --- SCRIPT SETUP ---
local reaper = reaper
local ok, script_file_path = reaper.get_action_context()
if not ok then
  reaper.ShowMessageBox("Could not determine script path.\n\nPlease ensure the script is run from the Action List.", "Script Error", 0)
  return
end
local script_path = script_file_path:match("^(.*[/\\])")
local python_script_path = script_path .. "hosi_freesound_logic_pro.py"

-- --- GUI STATE ---
local settings = {
  api_key = "",
  client_id = "",
  download_path = "",
  python_path = ""
}
local tokens = {
  access_token = nil,
  refresh_token = nil
}
local logged_in_user = nil
local is_logging_in = false
local is_batch_downloading = false

local search_query = "synth pad"
local results = {}
local status = "Initializing..."
local is_searching = false
local show_settings_window = false
local filter_cc0_only = false
local max_duration_str = "0"
local filter_tags = ""
local categories = {"Any", "Sound effects", "Music", "Instrument samples", "Soundscapes", "Speech"}
local categories_str = table.concat(categories, "\0") .. "\0"
local selected_category_idx = 1
local playing_item = nil
local temp_preview_path = reaper.GetResourcePath() .. "/FreesoundTempPreview/"
local preview_track = nil

local sort_options = {"Relevance", "Most Popular", "Shortest First", "Longest First"}
local sort_options_str = table.concat(sort_options, "\0") .. "\0"
local selected_sort_idx = 0

local current_page = 1
local total_results = 0
local has_next = false
local has_prev = false
local cache_path = reaper.GetResourcePath() .. "/FreesoundCache/"
local original_file_cache = {}
local search_mode = "text" -- "text" or "similar"
local view_mode = "search" -- "search" or "favorites"
local is_fetching_favorites = false
local similar_search_origin_id = nil
local similar_search_origin_name = nil
local initial_check_done = false
local pending_action = nil -- Action queue to solve GUI focus issues
-- Search History
local search_history = {}
local max_history_items = 20
-- Favorites
local favorites = {}

-- --- SETTINGS, HISTORY & FAVORITES MANAGEMENT ---
function save_favorites()
    local file = io.open(favorites_file, "w")
    if file then
        for id, _ in pairs(favorites) do
            file:write(tostring(id) .. "\n")
        end
        file:close()
    end
end

function load_favorites()
    local file = io.open(favorites_file, "r")
    if file then
        favorites = {} -- Clear existing
        for line in file:lines() do
            local id = tonumber(line:match("^%s*(.-)%s*$"))
            if id then
                favorites[id] = true
            end
        end
        file:close()
    end
end

function save_history()
    local file = io.open(history_file, "w")
    if file then
        for i = 1, #search_history do
            file:write(search_history[i] .. "\n")
        end
        file:close()
    end
end

function load_history()
    local file = io.open(history_file, "r")
    if file then
        search_history = {} -- Clear existing
        for line in file:lines() do
            local trimmed_line = line:match("^%s*(.-)%s*$")
            if #trimmed_line > 0 then
                table.insert(search_history, trimmed_line)
            end
        end
        file:close()
    end
end

function save_settings()
    local file = io.open(settings_file, "w")
    if file then
        file:write(settings.api_key .. "\n")
        file:write(settings.download_path .. "\n")
        file:write(settings.python_path .. "\n")
        file:write(settings.client_id .. "\n")
        file:close()
    end
end

function load_settings()
    local file = io.open(settings_file, "r")
    if file then
        settings.api_key = (file:read("*line") or ""):match("^%s*(.-)%s*$")
        settings.download_path = (file:read("*line") or ""):match("^%s*(.-)%s*$")
        settings.python_path = (file:read("*line") or ""):match("^%s*(.-)%s*$")
        settings.client_id = (file:read("*line") or ""):match("^%s*(.-)%s*$")
        file:close()
    end
    if settings.download_path == "" then
        settings.download_path = reaper.GetResourcePath() .. "/Freesound Downloads"
    end
    settings.download_path = settings.download_path:gsub("\\", "/")
end

-- --- HELPER FUNCTIONS ---
function FileExists(path)
    if not path or path == "" then return false end
    local f = io.open(path, "r")
    if f then f:close(); return true end
    return false
end

function ConvertColor(r, g, b, a)
    local r_int = math.floor(r * 255 + 0.5)
    local g_int = math.floor(g * 255 + 0.5)
    local b_int = math.floor(b * 255 + 0.5)
    local a_int = math.floor(a * 255 + 0.5)
    return (a_int << 24) | (b_int << 16) | (g_int << 8) | r_int
end

function FormatLicenseName(url)
    if not url then return "Unknown" end
    if string.find(url, "/publicdomain/zero/", 1, true) then
        return "Creative Commons 0"
    elseif string.find(url, "/by-nc/", 1, true) then
        return "Attribution NonCommercial"
    elseif string.find(url, "/by/", 1, true) then
        return "Attribution"
    elseif string.find(url, "/sampling+/", 1, true) then
        return "Sampling+"
    end
    return url
end

function ValidateAndFindPython()
    if FileExists(settings.python_path) then
        return true
    end
    status = "Python path not set or invalid, attempting to auto-detect..."
    reaper.defer(function() end)

    local os_type = reaper.GetOS()
    local find_cmd
    if os_type:find("Win") then
        find_cmd = "where python.exe"
    else -- macOS and Linux
        find_cmd = "which python3"
    end

    local handle = io.popen(find_cmd)
    if handle then
        local result = handle:read("*a")
        handle:close()
        if result and result ~= '' then
            local first_path = result:match("([^\r\n]+)")
            if first_path and FileExists(first_path) then
                settings.python_path = first_path
                status = "Python detected automatically. Ready."
                save_settings()
                return true
            end
        end
    end
    settings.python_path = ""
    if os_type:find("Win") then
        status = "Could not find python.exe. Please set the path in Settings."
    else
        status = "Could not find python3. Please set the path in Settings."
    end
    show_settings_window = true
    is_searching = false
    return false
end

function StopAndClearPreview()
    if playing_item then
        reaper.OnStopButton()
    end
    playing_item = nil
    if preview_track and reaper.ValidatePtr(preview_track, "MediaTrack*") then
        while reaper.CountTrackMediaItems(preview_track) > 0 do
            reaper.DeleteTrackMediaItem(preview_track, reaper.GetTrackMediaItem(preview_track, 0))
        end
    end
end

function CleanupAndRemovePreviewTrack()
    StopAndClearPreview()
    if preview_track and reaper.ValidatePtr(preview_track, "MediaTrack*") then
        reaper.DeleteTrack(preview_track)
        preview_track = nil
    end
end

function FindOrCreatePreviewTrack()
    if preview_track and reaper.ValidatePtr(preview_track, "MediaTrack*") then
        return preview_track
    end
    local track_name_to_find = "[Freesound Preview]"
    for i = 0, reaper.CountTracks(0) - 1 do
        local tr = reaper.GetTrack(0, i)
        local _, name = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
        if name == track_name_to_find then
            preview_track = tr
            return preview_track
        end
    end
    reaper.Undo_BeginBlock()
    reaper.InsertTrackAtIndex(0, true)
    local new_track = reaper.GetTrack(0, 0)
    reaper.GetSetMediaTrackInfo_String(new_track, "P_NAME", track_name_to_find, true)
    reaper.SetMediaTrackInfo_Value(new_track, "B_SHOWINTCP", 0)
    reaper.SetMediaTrackInfo_Value(new_track, "B_SHOWINMIXER", 0)
    reaper.TrackList_AdjustWindows(false)
    reaper.Undo_EndBlock("Create Freesound Preview Track", -1)
    preview_track = new_track
    return new_track
end

function ExecutePython(args_table)
  if not settings.python_path or not FileExists(settings.python_path) then
    return 'return {error = "Python path is not set or invalid. Please configure it in Settings."}'
  end

  local os_type = reaper.GetOS()
  local shell_command

  if os_type:find("Win") then
    -- Windows-specific command using PowerShell to handle UTF-8 correctly
    local escaped_python_path = settings.python_path:gsub("'", "''")
    local escaped_script_path = python_script_path:gsub("'", "''")
    local command_parts = {"& '" .. escaped_python_path .. "' '" .. escaped_script_path .. "'"}
    for i = 1, #args_table do
      local escaped_arg = tostring(args_table[i]):gsub("'", "''")
      table.insert(command_parts, " '" .. escaped_arg .. "'")
    end
    local ps_command = table.concat(command_parts)
    local full_ps_command = "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; " .. ps_command
    shell_command = 'powershell -WindowStyle Hidden -NoProfile -Command "' .. full_ps_command .. '"'
  else
    -- macOS and Linux command using standard shell
    -- Helper to safely escape arguments for shell
    local function escape_shell_arg(s)
      return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
    end
    
    local command_parts = {
        escape_shell_arg(settings.python_path),
        escape_shell_arg(python_script_path)
    }
    for i = 1, #args_table do
        table.insert(command_parts, escape_shell_arg(args_table[i]))
    end
    shell_command = table.concat(command_parts, " ")
  end
  
  local p = io.popen(shell_command, "r")
  if not p then return 'return {error = "io.popen failed to execute command."}' end
  local popen_output = p:read("*a")
  p:close()
  return popen_output or 'return {error = "Python script returned no output."}'
end

-- --- OAUTH2 AND USER FUNCTIONS ---
function SaveTokensInLua()
    if not (tokens and tokens.access_token and tokens.refresh_token) then
        status = "Error: Invalid or missing token data before saving."
        return
    end
    local file, err = io.open(token_file, "w")
    if not file then
        status = "ERROR: Could not write to token file: " .. tostring(err)
        reaper.ShowMessageBox(status .. "\n\nPath: " .. token_file, "Token Save Error", 0)
        return
    end
    file:write(tokens.access_token .. "\n")
    file:write(tokens.refresh_token .. "\n")
    file:close()
end

function Logout()
    if FileExists(token_file) then
        os.remove(token_file)
    end
    tokens.access_token = nil
    tokens.refresh_token = nil
    logged_in_user = nil
    status = "Logged out successfully."
end

function GetUserInfo()
    if not tokens.access_token then
        is_logging_in = false
        return
    end
    reaper.defer(function()
        local result_string = ExecutePython({"get_user", tokens.access_token})
        local chunk, err = load(result_string)
        if chunk then
            local ok, data = pcall(chunk)
            if ok and data and not data.error then
                logged_in_user = data.username
                status = "Ready."
            else
                Logout()
                if ok and data and data.error then
                    status = "Session expired or invalid: " .. tostring(data.error)
                else
                    status = "Session expired. Please log in again."
                end
            end
        else
            Logout()
            status = "Error processing user info. Please log in again."
        end
        is_logging_in = false
    end)
end

function LoadTokens()
    if not FileExists(token_file) then
        status = "Ready. Please login to download original files."
        return false
    end
    local file, err = io.open(token_file, "r")
    if not file then
        status = "Ready. Could not open token file: " .. tostring(err)
        return false
    end
    local access = file:read("*line")
    local refresh = file:read("*line")
    file:close()
    if access and refresh and access ~= "" and refresh ~= "" then
        tokens.access_token = access
        tokens.refresh_token = refresh
        return true
    else
        os.remove(token_file)
        status = "Ready. Token file was invalid, deleting it."
        return false
    end
end

function Authorize()
    if is_logging_in then return end
    if settings.client_id == "" or settings.api_key == "" then
        status = "Error: Client ID and API Key must be set in Settings."
        show_settings_window = true
        return
    end
    is_logging_in = true
    status = "Opening browser for Freesound login..."
    reaper.defer(function()
        local result_string = ExecutePython({"authorize", settings.client_id, settings.api_key})
        local chunk, err = load(result_string)
        if chunk then
            local ok, data = pcall(chunk)
            if ok then
                if data and data.status == "success" and data.tokens then
                    status = "Login successful! Fetching user info..."
                    tokens.access_token = data.tokens.access_token
                    tokens.refresh_token = data.tokens.refresh_token
                    SaveTokensInLua()
                    GetUserInfo()
                elseif data and data.error then
                    status = "Login failed: " .. tostring(data.error)
                    is_logging_in = false
                else
                    status = "Login failed. Invalid response from Python script."
                    is_logging_in = false
                end
            else
                status = "Login script error: " .. tostring(data)
                is_logging_in = false
            end
        else
            status = "Login failed. No valid response from Python script."
            is_logging_in = false
        end
    end)
end

-- --- DOWNLOAD AND SAMPLER FUNCTIONS ---

function DownloadFileAsync(sound, is_original, callback)
    reaper.defer(function()
        local result_string
        if is_original then
            if not logged_in_user or not tokens.access_token then
                status = "Error: You must be logged in to download original files."
                if callback then callback(false, nil, nil) end
                return
            end
            status = "Downloading original: " .. sound.name
            result_string = ExecutePython({"download_original", sound.id, settings.download_path, tokens.access_token})
        else
            status = "Downloading preview: " .. sound.name
            local preview_url = sound.previews['preview-hq-mp3']
            if not preview_url then
                status = "Error: No HQ preview available for this sound."
                if callback then callback(false, nil, nil) end
                return
            end
            local safe_filename = sound.id .. ".mp3"
            local output_path = temp_preview_path .. safe_filename
            result_string = ExecutePython({"download_preview", preview_url, output_path})
        end
        local chunk, err = load(result_string)
        if not chunk then
            status = "Error: Could not load download status from Python."
            if callback then callback(false, nil, nil) end
            return
        end
        local ok, data = pcall(chunk)
        if ok and data and data.status == "success" then
            status = (is_original and "Downloaded original: " or "Downloaded preview: ") .. data.path:match("([^/\\]+)$")
            if callback then callback(true, data.path, data.filename) end
        else
            status = "Error downloading: " .. (data and (data.message or data.error) or "Unknown Python error.")
            if callback then callback(false, nil, nil) end
        end
    end)
end

function DownloadAndImportPreview(sound)
    local target_track = reaper.GetSelectedTrack(0, 0)
    if not target_track then
        status = "Error: Please select a track to import the file into."
        reaper.ShowMessageBox(status, "Import Error", 0)
        return
    end
    local _, track_name = reaper.GetSetMediaTrackInfo_String(target_track, "P_NAME", "", false)
    if track_name == "[Freesound Preview]" then
        status = "Error: Cannot import to the preview track. Please select a different track."
        reaper.ShowMessageBox(status, "Import Error", 0)
        return
    end
    StopAndClearPreview()

    local safe_filename = sound.id .. "_" .. sound.name:gsub("[^%w%._-]", "") .. ".mp3"
    local output_path = settings.download_path .. "/" .. safe_filename
    local function ImportToTargetTrack(path)
        reaper.SetOnlyTrackSelected(target_track)
        reaper.InsertMedia(path, 0)
        status = "Imported: " .. path:match("([^/\\]+)$")
    end
    if FileExists(output_path) then
        ImportToTargetTrack(output_path)
        return
    end
    status = "Downloading preview for import: " .. sound.name
    local preview_url = sound.previews['preview-hq-mp3']
    if not preview_url then
        status = "Error: No HQ preview available for this sound."
        return
    end
    
    DownloadFileAsync(sound, false, function(success, path)
        if success then
            ImportToTargetTrack(path)
        end
    end)
end

function SendToSampler(sound)
    status = "Preparing to send to sampler..."
    local function SetSamplerFile(file_path)
        local sampler_track_name = "[Freesound Sampler]"
        local sampler_fx_name = "ReaSamplOmatic5000"
        local sampler_track = nil
        for i = 0, reaper.CountTracks(0) - 1 do
            local tr = reaper.GetTrack(0, i)
            local _, name = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
            if name == sampler_track_name then
                sampler_track = tr
                break
            end
        end
        if not sampler_track then
            reaper.Undo_BeginBlock()
            reaper.InsertTrackAtIndex(reaper.CountTracks(0), true)
            sampler_track = reaper.GetTrack(0, reaper.CountTracks(0) - 1)
            reaper.GetSetMediaTrackInfo_String(sampler_track, "P_NAME", sampler_track_name, true)
            reaper.Undo_EndBlock("Create Freesound Sampler Track", -1)
        end
        local fx_index = reaper.TrackFX_GetByName(sampler_track, sampler_fx_name, false)
        if fx_index == -1 then
            fx_index = reaper.TrackFX_AddByName(sampler_track, sampler_fx_name, false, -1)
        end
        if fx_index ~= -1 then
            reaper.TrackFX_SetNamedConfigParm(sampler_track, fx_index, "FILE0", file_path)
            status = "Sent '" .. sound.name .. "' to sampler."
        else
            status = "Error: Could not find or add ReaSamplOmatic5000."
        end
    end
    if original_file_cache[sound.id] and FileExists(original_file_cache[sound.id]) then
        SetSamplerFile(original_file_cache[sound.id])
        return
    end
    DownloadFileAsync(sound, true, function(success, file_path)
        if success and file_path then
            original_file_cache[sound.id] = file_path
            SetSamplerFile(file_path)
        end
    end)
end

-- --- MAIN SCRIPT FUNCTIONS ---

function DownloadAllOriginals()
    if is_batch_downloading or #results == 0 or not logged_in_user then return end
    is_batch_downloading = true
    local total_files = #results
    local downloaded_count = 0
    local function DownloadNext(index)
        if index > total_files then
            status = "Batch download complete. " .. downloaded_count .. "/" .. total_files .. " files downloaded."
            is_batch_downloading = false
            return
        end
        local sound = results[index]
        status = "Downloading (" .. index .. "/" .. total_files .. "): " .. sound.name
        DownloadFileAsync(sound, true, function(success, path)
            if success then downloaded_count = downloaded_count + 1 end
            DownloadNext(index + 1)
        end)
    end
    DownloadNext(1)
end

function FetchFavoritesDetails()
    if is_fetching_favorites or settings.api_key == "" then return end
    is_fetching_favorites = true
    results, total_results, has_next, has_prev = {}, 0, false, false
    local fav_ids = {}
    for id, _ in pairs(favorites) do
        table.insert(fav_ids, tostring(id))
    end
    if #fav_ids == 0 then
        status = "You have no favorite sounds yet. Click the star ★ next to a sound to add it."
        is_fetching_favorites = false
        return
    end

    status = "Fetching details for " .. #fav_ids .. " favorite(s)..."
    
    reaper.defer(function()
        local ids_string = table.concat(fav_ids, ",")
        local result_string = ExecutePython({"get_favorites_details", settings.api_key, ids_string})
        local chunk, err_msg = load(result_string)
        if chunk then
            local ok, data = pcall(chunk)
            if ok and data and not data.error then
                results = data.results or {}
                total_results = data.count or 0
                status = "Showing " .. #results .. " favorite sound(s)."
            else
                status = "Error fetching favorites: " .. (data and data.error or "Unknown error")
            end
        else
            status = "Error processing favorites from Python: " .. tostring(err_msg)
        end
        is_fetching_favorites = false
    end)
end

function FetchResults(page_to_fetch)
    if is_searching or is_logging_in then return end
    page_to_fetch = page_to_fetch or 1
    local cache_key_base = ""
    if search_mode == "similar" then
        cache_key_base = "similar_" .. tostring(similar_search_origin_id) .. tostring(page_to_fetch)
    else -- "text" mode
        local sort_map = { "relevance", "downloads_desc", "duration_asc", "duration_desc" }
        local sort_to_send = sort_map[selected_sort_idx + 1] or "relevance"
        local cat_str = categories[selected_category_idx] or "Any"
        cache_key_base = search_query .. tostring(filter_cc0_only) .. max_duration_str .. filter_tags .. cat_str .. tostring(page_to_fetch) .. sort_to_send
    end
    local sanitized_key = cache_key_base:gsub("[^%w%._-]", "_"):sub(1, 100)
    local cache_filepath = cache_path .. sanitized_key .. ".cache"
    if FileExists(cache_filepath) then
        local file = io.open(cache_filepath, "r")
        if file then
            local content = file:read("*a")
            file:close()
            local chunk, err_msg = load(content, "cache_data", "t")
            if chunk then
                local ok, data = pcall(chunk)
                if ok and data and type(data) == 'table' and not data.error then
                    status = "Loading from cache..."
                    results = data.results or {}
                    total_results = data.count or 0
                    has_next = data.next ~= nil
                    has_prev = data.previous ~= nil
                    current_page = page_to_fetch
                    if total_results > 0 then
                        local start_num = ((current_page - 1) * 25) + 1
                        local end_num = start_num + #results - 1
                        if search_mode == "similar" then
                            status = "Showing similar sounds " .. start_num .. "-" .. end_num .. " of " .. total_results .. " (cached)"
                        else
                            status = "Showing results " .. start_num .. "-" .. end_num .. " of " .. total_results .. " (cached)"
                        end
                    else
                        status = "No results found for your query."
                    end
                    return
                end
            end
        end
    end
    is_searching = true
    reaper.defer(function()
        if not ValidateAndFindPython() then is_searching = false; return end
        if settings.api_key == "" then
            status = "Error: API Key is missing. Please set it in Settings."
            show_settings_window = true
            is_searching = false
            return
        end
        results = {}
        local args_table = {}
        if search_mode == "similar" then
            status = "Searching for sounds similar to '" .. similar_search_origin_name .. "' (page " .. page_to_fetch .. ")..."
            args_table = {"get_similar", settings.api_key, tostring(similar_search_origin_id), tostring(page_to_fetch)}
        else
            status = "Searching page " .. page_to_fetch .. " for '" .. search_query .. "'..."
            local sort_map = { "relevance", "downloads_desc", "duration_asc", "duration_desc" }
            local sort_to_send = sort_map[selected_sort_idx + 1] or "relevance"
            local tags_to_send = (filter_tags == "" and "NONE" or filter_tags)
            local duration_to_send = (max_duration_str == "" and "0" or max_duration_str)
            local category_to_send = categories[selected_category_idx] or "Any"
            args_table = {"search", settings.api_key, search_query, tostring(filter_cc0_only), duration_to_send, tags_to_send, category_to_send, tostring(page_to_fetch), sort_to_send}
        end
        local result_string = ExecutePython(args_table)
        local chunk_test, err_msg_test = load(result_string, "test_chunk", "t")
        if chunk_test then
            local ok_test, data_test = pcall(chunk_test)
            if ok_test and data_test and not data_test.error then
                if not FileExists(cache_path) then os.execute('mkdir "' .. cache_path:gsub("/", "\\") .. '"') end
                local file = io.open(cache_filepath, "w")
                if file then file:write(result_string); file:close() end
            end
        end
        local chunk, err_msg = load(result_string, "temp_data", "t")
        if not chunk then
            status = "Error: Failed to load response from Python."
        else
            local ok, data = pcall(chunk)
            if ok and data and type(data) == 'table' then
                if data.error then
                    status = "Error from Python: " .. tostring(data.error)
                    results, total_results = {}, 0
                else
                    results, total_results = data.results or {}, data.count or 0
                    has_next, has_prev = data.next ~= nil, data.previous ~= nil
                    current_page = page_to_fetch
                    if total_results > 0 then
                        local start_num = ((current_page - 1) * 25) + 1
                        local end_num = start_num + #results - 1
                        if search_mode == "similar" then
                            status = "Showing sounds similar to '".. similar_search_origin_name .."' (" .. start_num .. "-" .. end_num .. " of " .. total_results .. ")"
                        else
                            status = "Showing results " .. start_num .. "-" .. end_num .. " of " .. total_results
                        end
                    else
                        status = "No results found for your query."
                    end
                end
            else
                status = "Error: Failed to execute response code from Python."
            end
        end
        is_searching = false
    end)
end

function UpdateSearchHistory(query)
    if not query or query:match("^%s*$") then return end 
    for i = #search_history, 1, -1 do
        if search_history[i] == query then
            table.remove(search_history, i)
        end
    end
    table.insert(search_history, 1, query)
    while #search_history > max_history_items do
        table.remove(search_history)
    end
end

function StartTextSearch()
    UpdateSearchHistory(search_query)
    search_mode = "text"
    FetchResults(1)
end

function StartSimilarSearch(sound)
    search_mode = "similar"
    similar_search_origin_id = sound.id
    similar_search_origin_name = sound.name
    search_query = ""
    filter_cc0_only = false
    max_duration_str = "0"
    filter_tags = ""
    selected_category_idx = 1
    selected_sort_idx = 0
    FetchResults(1)
end

function DownloadOriginalFile(sound, and_import)
    local target_track
    if and_import then
        target_track = reaper.GetSelectedTrack(0, 0)
        if not target_track then
            reaper.ShowMessageBox("Error: Please select a track to import the file into.", "Import Error", 0)
            return
        end
        local _, track_name = reaper.GetSetMediaTrackInfo_String(target_track, "P_NAME", "", false)
        if track_name == "[Freesound Preview]" then
            reaper.ShowMessageBox("Error: Cannot import to the preview track. Please select a different track.", "Import Error", 0)
            return
        end
    end
    if original_file_cache[sound.id] and FileExists(original_file_cache[sound.id]) then
        local existing_path = original_file_cache[sound.id]
        if and_import then
            reaper.SetOnlyTrackSelected(target_track)
            reaper.InsertMedia(existing_path, 0)
            status = "Imported cached original file: " .. existing_path:match("([^/\\]+)$")
        else
            status = "Downloaded original file: " .. existing_path:match("([^/\\]+)$")
        end
        return
    end
    DownloadFileAsync(sound, true, function(success, file_path)
        if success and file_path then
            original_file_cache[sound.id] = file_path
            if and_import then
                reaper.SetOnlyTrackSelected(target_track)
                reaper.InsertMedia(file_path, 0)
                status = "Imported original file: " .. file_path:match("([^/\\]+)$")
            else
                status = "Downloaded original file: " .. file_path:match("([^/\\]+)$")
            end
        end
    end)
end

function PlayPreview(sound)
    StopAndClearPreview()
    local temp_filename = sound.id .. ".mp3"
    local temp_full_path = temp_preview_path .. temp_filename
    local function PlayLocalFile(path)
        local track = FindOrCreatePreviewTrack()
        if not track then
            status = "Error: Could not create a preview track."
            return
        end
        reaper.SetOnlyTrackSelected(track)
        reaper.InsertMedia(path, 0)
        local item_count = reaper.CountTrackMediaItems(track)
        playing_item = reaper.GetTrackMediaItem(track, item_count - 1)
        if playing_item then
            reaper.SelectAllMediaItems(0, false)
            reaper.SetMediaItemSelected(playing_item, true)
            local item_pos = reaper.GetMediaItemInfo_Value(playing_item, "D_POSITION")
            reaper.SetEditCurPos(item_pos, true, true)
            status = "Playing: " .. sound.name
            reaper.OnPlayButton()
        else
            status = "Error: Could not insert file into REAPER."
            playing_item = nil
        end
    end
    if FileExists(temp_full_path) then
        PlayLocalFile(temp_full_path)
    else
        status = "Downloading preview of '" .. sound.name .. "'..."
        DownloadFileAsync(sound, false, function(success, file_path)
            if success then
                PlayLocalFile(file_path)
            end
        end)
    end
end

function ClearPreviewCache()
    local function remove_dir(path)
        local command = 'rmdir /s /q "' .. path:gsub("/", "\\") .. '"'
        os.execute(command)
    end
    remove_dir(temp_preview_path)
    status = "Preview cache has been cleared."
end

-- --- GUI DRAWING FUNCTIONS ---
function DrawSettingsWindow()
  ImGui.SetNextWindowSize(ctx, 450, 580, ImGui.Cond_FirstUseEver)
  local visible, open = ImGui.Begin(ctx, 'Settings', true, ImGui.WindowFlags_NoCollapse)
  if not open then
      save_settings()
      show_settings_window = false
  end
  if visible then
    ImGui.TextWrapped(ctx, "Get your credentials from the Freesound API page.")
    if ImGui.Button(ctx, "Open Freesound API Page") then
        reaper.CF_ShellExecute("https://freesound.org/apiv2/apply")
    end
    ImGui.Separator(ctx)
    ImGui.Text(ctx, "OAuth2 Client ID")
    ImGui.PushItemWidth(ctx, -1)
    local id_changed, new_id = ImGui.InputText(ctx, "##ClientID", settings.client_id, 128)
    if id_changed then settings.client_id = new_id end
    ImGui.PopItemWidth(ctx)
    ImGui.Text(ctx, "API Key / Client Secret")
    ImGui.PushItemWidth(ctx, -1)
    local api_key_changed, new_api_key = ImGui.InputText(ctx, "##APIKey", settings.api_key, 128)
    if api_key_changed then settings.api_key = new_api_key end
    ImGui.PopItemWidth(ctx)
    ImGui.Separator(ctx)
    ImGui.TextWrapped(ctx, "IMPORTANT: Your OAuth2 Redirect URI on the Freesound site must be set to http://127.0.0.1:8008/")
    ImGui.Separator(ctx)
    ImGui.Text(ctx, "Download Path")
    ImGui.PushItemWidth(ctx, -1)
    local path_changed, new_path = ImGui.InputText(ctx, "##DownloadPath", settings.download_path, 512)
    if path_changed then settings.download_path = new_path end
    ImGui.PopItemWidth(ctx)
    ImGui.Separator(ctx)
    ImGui.Text(ctx, "Python Executable Path")
    ImGui.PushItemWidth(ctx, -1)
    local python_path_changed, new_python_path = ImGui.InputText(ctx, "##PythonPath", settings.python_path, 512)
    if python_path_changed then settings.python_path = new_python_path end
    ImGui.PopItemWidth(ctx)
    ImGui.Separator(ctx)
    if ImGui.Button(ctx, "Clear Preview Cache", -1) then
        ClearPreviewCache()
    end
    ImGui.Separator(ctx)
    if ImGui.Button(ctx, "Save & Close", -1) then
        save_settings()
        show_settings_window = false
    end
  end
  ImGui.End(ctx)
end

function DrawGUI()
  if view_mode == "search" then
      ImGui.PushItemWidth(ctx, -560) 
      local changed, new_text = ImGui.InputText(ctx, "##SearchQuery", search_query, 128)
      if changed then
          search_query = new_text
      end
      if ImGui.IsItemFocused(ctx) and ImGui.IsKeyPressed(ctx, ImGui.Key_Enter, false) then
          StartTextSearch()
      end
      ImGui.PopItemWidth(ctx)
      
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "▼", 28, 24) then
          ImGui.OpenPopup(ctx, "search_history_popup")
      end
      if ImGui.BeginPopup(ctx, "search_history_popup") then
          if #search_history > 0 then
              for i, history_item in ipairs(search_history) do
                  if ImGui.MenuItem(ctx, history_item) then
                      search_query = history_item
                      StartTextSearch()
                  end
              end
              ImGui.Separator(ctx)
              if ImGui.MenuItem(ctx, "Clear History") then
                  search_history = {}
                  save_history()
              end
          else
              ImGui.TextDisabled(ctx, "No history yet.")
          end
          ImGui.EndPopup(ctx)
      end

      ImGui.SameLine(ctx)
      local search_disabled = is_searching or is_logging_in or is_batch_downloading
      if search_disabled then ImGui.PushStyleVar(ctx, ImGui.StyleVar_Alpha, 0.5) end
      if ImGui.Button(ctx, "Search", 80, 24) and not search_disabled then StartTextSearch() end
      if search_disabled then ImGui.PopStyleVar(ctx) end
  else -- favorites mode
      if ImGui.Button(ctx, "<< Back to Search", 120, 24) then
          view_mode = "search"
          results = {}
          total_results = 0
          status = "Ready."
      end
  end
  
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Favorites ★", 100, 24) then
      view_mode = "favorites"
      pending_action = { name = "show_favorites" }
  end
  
  ImGui.SameLine(ctx)
  local dl_all_disabled = not logged_in_user or is_batch_downloading or is_searching or #results == 0
  if dl_all_disabled then ImGui.PushStyleVar(ctx, ImGui.StyleVar_Alpha, 0.5) end
  if is_batch_downloading then
      ImGui.Button(ctx, "Downloading...", 100, 24)
  else
      if ImGui.Button(ctx, "Download All", 100, 24) and not dl_all_disabled then pending_action = { name = "download_all" } end
  end
  if dl_all_disabled then ImGui.PopStyleVar(ctx) end

  ImGui.SameLine(ctx)
  if logged_in_user then
      if ImGui.Button(ctx, "Logout", 80, 24) then Logout() end
  else
      if is_logging_in then
          ImGui.PushStyleVar(ctx, ImGui.StyleVar_Alpha, 0.5)
          ImGui.Button(ctx, "Logging in...", 80, 24)
          ImGui.PopStyleVar(ctx)
      else
          if ImGui.Button(ctx, "Login", 80, 24) then Authorize() end
      end
  end

  ImGui.SameLine(ctx, ImGui.GetWindowWidth(ctx) - 40)
  if ImGui.Button(ctx, "⚙", 28, 24) then show_settings_window = not show_settings_window end
  
  if view_mode == "search" then
      local filter_changed, new_filter_state = ImGui.Checkbox(ctx, "Commercial Use (CC0)", filter_cc0_only)
      if filter_changed then filter_cc0_only = new_filter_state end
      
      ImGui.SameLine(ctx)
      ImGui.SetCursorPosX(ctx, ImGui.GetWindowWidth(ctx) - 160)
      ImGui.Text(ctx, "Max Len (s):")
      ImGui.SameLine(ctx)
      ImGui.PushItemWidth(ctx, 60)
      local duration_changed, new_duration = ImGui.InputText(ctx, "##MaxDuration", max_duration_str, 8)
      if duration_changed then max_duration_str = new_duration:gsub("[^0-9%.]", "") end
      ImGui.PopItemWidth(ctx)
      
      ImGui.Text(ctx, "Tags (comma separated):")
      ImGui.SameLine(ctx)
      ImGui.PushItemWidth(ctx, -1)
      local tags_changed, new_tags = ImGui.InputText(ctx, "##FilterTags", filter_tags, 128)
      if tags_changed then filter_tags = new_tags end
      ImGui.PopItemWidth(ctx)
      
      ImGui.Text(ctx, "Category:")
      ImGui.SameLine(ctx)
      ImGui.PushItemWidth(ctx, 150)
      local category_changed, new_category_idx = ImGui.Combo(ctx, "##CategoryFilter", selected_category_idx, categories_str)
      if category_changed then selected_category_idx = new_category_idx end
      ImGui.PopItemWidth(ctx)

      ImGui.SameLine(ctx)
      ImGui.Text(ctx, "Sort by:")
      ImGui.SameLine(ctx)
      ImGui.PushItemWidth(ctx, -1)
      local sort_changed, new_sort_idx = ImGui.Combo(ctx, "##SortBy", selected_sort_idx, sort_options_str)
      if sort_changed then selected_sort_idx = new_sort_idx end
      ImGui.PopItemWidth(ctx)
  end
  
  ImGui.Separator(ctx)
  
  -- Begin Results Child Window
  ImGui.BeginChild(ctx, "Results", 0, -60, 1, 0)
  if #results > 0 then
    -- Table Layout Implementation
    local table_flags = ImGui.TableFlags_BordersOuter | ImGui.TableFlags_RowBg | ImGui.TableFlags_Resizable | ImGui.TableFlags_ScrollY
    if ImGui.BeginTable(ctx, "results_table", 5, table_flags) then
        ImGui.TableSetupColumn(ctx, "★", ImGui.TableColumnFlags_WidthFixed, 30)
        ImGui.TableSetupColumn(ctx, "Name", ImGui.TableColumnFlags_WidthStretch)
        ImGui.TableSetupColumn(ctx, "Duration", ImGui.TableColumnFlags_WidthFixed, 65)
        ImGui.TableSetupColumn(ctx, "Downloads", ImGui.TableColumnFlags_WidthFixed, 80)
        ImGui.TableSetupColumn(ctx, "Actions", ImGui.TableColumnFlags_WidthFixed, 230)
        ImGui.TableHeadersRow(ctx)

        for i = #results, 1, -1 do -- Iterate backwards to safely remove items
            local sound = results[i]
            ImGui.PushID(ctx, "sound" .. sound.id)
            ImGui.TableNextRow(ctx)

            -- Column 1: Favorite Button
            ImGui.TableNextColumn(ctx)
            local is_favorite = favorites[sound.id] == true
            if is_favorite then
                ImGui.PushStyleColor(ctx, ImGui.Col_Button, ConvertColor(0.9, 0.7, 0.1, 1.0))
            end
            if ImGui.Button(ctx, "★", 24, 22) then
                if is_favorite then
                    favorites[sound.id] = nil
                    if view_mode == "favorites" then
                        table.remove(results, i)
                        total_results = #results
                    end
                else
                    favorites[sound.id] = true
                end
                save_favorites()
            end
            if is_favorite then
                ImGui.PopStyleColor(ctx)
            end

            -- Column 2: Name and License
            ImGui.TableNextColumn(ctx)
            ImGui.Text(ctx, sound.name)
            local license_display = FormatLicenseName(sound.license)
            ImGui.TextDisabled(ctx, license_display)

            -- Column 3: Duration
            ImGui.TableNextColumn(ctx)
            local duration = os.date("!%M:%S", math.floor(sound.duration))
            ImGui.Text(ctx, duration)
            
            -- Column 4: Downloads
            ImGui.TableNextColumn(ctx)
            ImGui.Text(ctx, tostring(sound.num_downloads))

            -- Column 5: Action Buttons
            ImGui.TableNextColumn(ctx)
            if ImGui.Button(ctx, "Listen", 60) then PlayPreview(sound) end
            ImGui.SameLine(ctx)
            if ImGui.Button(ctx, "Import MP3", 80) then
                pending_action = { name = "import_preview", sound = sound }
            end
            ImGui.SameLine(ctx)
            
            local original_disabled = not logged_in_user
            if original_disabled then ImGui.PushStyleVar(ctx, ImGui.StyleVar_Alpha, 0.5) end
            
            if ImGui.Button(ctx, "Actions", 70) then ImGui.OpenPopup(ctx, "actions_popup") end
            if ImGui.BeginPopup(ctx, "actions_popup") then
                if ImGui.MenuItem(ctx, "Find Similar") then StartSimilarSearch(sound) end
                ImGui.Separator(ctx)
                if ImGui.MenuItem(ctx, "Download Original") then 
                    pending_action = { name = "download_original", sound = sound, and_import = false }
                end
                if ImGui.MenuItem(ctx, "Import Original") then 
                    pending_action = { name = "download_original", sound = sound, and_import = true }
                end
                if ImGui.MenuItem(ctx, "Send to Sampler") then 
                    pending_action = { name = "send_to_sampler", sound = sound }
                end
                ImGui.Separator(ctx)
                if ImGui.MenuItem(ctx, "Open Link") then reaper.CF_ShellExecute(sound.url) end
                ImGui.EndPopup(ctx)
            end

            if original_disabled then ImGui.PopStyleVar(ctx) end

            ImGui.PopID(ctx)
        end -- End of for loop
        ImGui.EndTable(ctx)
    end
  else
    if is_searching or is_fetching_favorites then
        ImGui.Text(ctx, "Loading...")
    elseif status == "Initializing..." then
        ImGui.Text(ctx, "Enter a query and press Search to begin.")
    else
        ImGui.Text(ctx, status)
    end
  end
  ImGui.EndChild(ctx) -- End Results Child Window
  
  ImGui.Separator(ctx)
  if view_mode == "search" and total_results > 0 then
    local button_size_x = 100
    local window_width = ImGui.GetWindowWidth(ctx)
    local total_buttons_width = button_size_x * 2 + 10
    local start_pos_x = (window_width - total_buttons_width) / 2
    ImGui.SetCursorPosX(ctx, start_pos_x)

    local prev_disabled = not has_prev or is_searching or is_logging_in
    if prev_disabled then ImGui.PushStyleVar(ctx, ImGui.StyleVar_Alpha, 0.5) end
    if ImGui.Button(ctx, "<< Previous", button_size_x, 0) and not prev_disabled then FetchResults(current_page - 1) end
    if prev_disabled then ImGui.PopStyleVar(ctx) end
    
    ImGui.SameLine(ctx)
    
    local next_disabled = not has_next or is_searching or is_logging_in
    if next_disabled then ImGui.PushStyleVar(ctx, ImGui.StyleVar_Alpha, 0.5) end
    if ImGui.Button(ctx, "Next >>", button_size_x, 0) and not next_disabled then FetchResults(current_page + 1) end
    if next_disabled then ImGui.PopStyleVar(ctx) end
  end

  ImGui.Separator(ctx)
  
  local left_status_text
  if logged_in_user then
      left_status_text = "Logged in as: " .. logged_in_user
  else
      left_status_text = status
  end
  ImGui.Text(ctx, left_status_text)

  if total_results > 0 then
      local right_status_text
      if view_mode == "search" then
          local start_num = ((current_page - 1) * 25) + 1
          local end_num = start_num + #results - 1
          right_status_text = "Showing results " .. start_num .. "-" .. end_num .. " of " .. total_results
      else
          right_status_text = "Showing " .. total_results .. " favorite(s)"
      end
      
      local text_width, _ = ImGui.CalcTextSize(ctx, right_status_text)
      local window_width = ImGui.GetWindowWidth(ctx)
      local right_padding = 8 
      
      ImGui.SameLine(ctx, window_width - text_width - right_padding)
      ImGui.Text(ctx, right_status_text)
  end
end

-- --- MAIN UPDATE LOOP ---
function Loop()
  -- First, process any action that was queued in the previous frame.
  -- This ensures that Reaper's main window has regained focus, making selection functions reliable.
  if pending_action then
      if pending_action.name == "import_preview" then
          DownloadAndImportPreview(pending_action.sound)
      elseif pending_action.name == "send_to_sampler" then
          SendToSampler(pending_action.sound)
      elseif pending_action.name == "download_original" then
          DownloadOriginalFile(pending_action.sound, pending_action.and_import)
      elseif pending_action.name == "download_all" then
          DownloadAllOriginals()
      elseif pending_action.name == "show_favorites" then
          FetchFavoritesDetails()
      end
      pending_action = nil -- Reset after processing
  end

  -- Now, draw the GUI for the current frame.
  ImGui.SetNextWindowSize(ctx, 800, 600, ImGui.Cond_FirstUseEver)
  local visible, open = ImGui.Begin(ctx, 'Freesound Search Pro v1.4###HosiFreesoundSearch', true)
  if visible then
    if not initial_check_done then
      initial_check_done = true
      reaper.defer(function()
        ValidateAndFindPython()
        if LoadTokens() then
          GetUserInfo()
        end
      end)
    end
    DrawGUI()
    ImGui.End(ctx)
  end

  if show_settings_window then DrawSettingsWindow() end
  
  -- Schedule the next frame or clean up.
  if open then 
    reaper.defer(Loop)
  else
    CleanupAndRemovePreviewTrack()
    save_history()
    save_favorites()
  end
end

-- --- SCRIPT START ---
load_settings()
load_history()
load_favorites()
reaper.defer(Loop)

