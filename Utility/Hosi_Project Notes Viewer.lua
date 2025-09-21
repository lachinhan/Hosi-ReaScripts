--[[
@description    Project Notes Editor (ReaImGui Version)
@author         Hosi
@version        1.0
@provides
  [main] . > Hosi_Project Notes Editor (ReaImGui).lua

@about
  # Project Notes Editor (ReaImGui Version)

  Displays and allows editing of the project's Title, Author, and
  Notes in a dockable ReaImGui window.

  Features:
  - Simple and stable layout. Input fields now fill the window width.
  - Displays the total project duration and frame rate.
  - Edit Title, Author, and Notes directly in the window.
  - Auto-saves changes every few seconds when you are not typing.
  - Always sets the project title from the filename on start.
  - Always sets the author to "Hosi Prod" on start.
  
  Changelog:
  Changelog:
  v1.0: 20-09-2025 - Initial release.
--]]

-- --- CONFIGURATION ---
local config = {
  win_title = "Project Notes Editor",
  refresh_interval = 2.0 -- Time in seconds for auto-refresh and auto-save
}

-- Initialize ReaImGui correctly
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local imgui = require('imgui')('0.10')

if not imgui or type(imgui) ~= "table" then
  reaper.ShowMessageBox("Failed to initialize ReaImGui library.\n\nPlease ensure it is installed (v0.10+ recommended) and up to date via ReaPack.", "ReaImGui Error", 0)
  return
end
local ctx = imgui.CreateContext(config.win_title)

-- --- STATE VARIABLES ---
local project_data = { title = "", author = "", notes = "", length = 0, framerate = 0 }
local is_open = true
local last_refresh_time = 0

-- --- DATA FUNCTIONS ---

function GetProjectName()
  local proj = reaper.EnumProjects(-1, "")
  if not proj then return "" end
  local proj_name_with_ext = reaper.GetProjectName(proj, "", 512)
  local proj_name = proj_name_with_ext:gsub("%.rpp$", "")
  return proj_name
end

function FormatTime(seconds)
    if not seconds or seconds < 0 then return "00:00" end
    local mins = math.floor(seconds / 60)
    local secs = math.fmod(seconds, 60)
    return string.format("%02d:%02.0f", mins, secs)
end

function FetchProjectData()
  local proj = reaper.EnumProjects(-1, "")
  if not proj then
    return { title = "Error", author = "Project not found", notes = "Please open a project.", length = 0, framerate = 0 }
  end

  local _, title = reaper.GetSetProjectInfo_String(proj, 'PROJECT_TITLE', '', false)
  local _, author = reaper.GetSetProjectInfo_String(proj, 'PROJECT_AUTHOR', '', false)
  -- Replace carriage return + newline with just newline for consistency
  local notes_raw = reaper.GetSetProjectNotes(proj, false, "")
  local notes = notes_raw:gsub("\r\n", "\n")
  local length = reaper.GetProjectLength(proj)
  local framerate = reaper.TimeMap_curFrameRate(proj)

  return { title = title or "", author = author or "", notes = notes or "", length = length or 0, framerate = framerate or 0 }
end

function SaveProjectData()
    local proj = reaper.EnumProjects(-1, "")
    if not proj then return end

    reaper.GetSetProjectInfo_String(proj, 'PROJECT_TITLE', project_data.title, true)
    reaper.GetSetProjectInfo_String(proj, 'PROJECT_AUTHOR', project_data.author, true)
    -- Ensure notes are saved with the correct newline format for REAPER
    local notes_to_save = project_data.notes:gsub("\n", "\r\n")
    reaper.GetSetProjectNotes(proj, true, notes_to_save)
    reaper.UpdateArrange()
    
    -- Force Project Settings window to refresh if it's open
    reaper.Main_OnCommand(40006, 0) -- Project settings...
    reaper.Main_OnCommand(40006, 0) -- Call it again to close it immediately
end


-- --- MAIN GUI LOOP ---
function loop()
  local current_time = reaper.time_precise()
  if not imgui.IsAnyItemActive(ctx) and current_time > last_refresh_time + config.refresh_interval then
      SaveProjectData()
      project_data = FetchProjectData()
      last_refresh_time = current_time
  end

  local visible
  visible, is_open = imgui.Begin(ctx, config.win_title, is_open)

  if visible then
    imgui.Text(ctx, string.format("Title: (Frame Rate: %.3f fps)", project_data.framerate))
    imgui.PushItemWidth(ctx, -1)
    local title_changed, new_title = imgui.InputText(ctx, '##Title', project_data.title, 512)
    if title_changed then project_data.title = new_title end
    imgui.PopItemWidth(ctx)

    imgui.Text(ctx, "Author:")
    imgui.PushItemWidth(ctx, -1)
    local author_changed, new_author = imgui.InputText(ctx, '##Author', project_data.author, 512)
    if author_changed then project_data.author = new_author end
    imgui.PopItemWidth(ctx)

    imgui.Separator(ctx)
    imgui.Text(ctx, "Notes: (Duration: " .. FormatTime(project_data.length) .. ")")

    imgui.PushItemWidth(ctx, -1)
    local notes_changed, new_notes = imgui.InputTextMultiline(ctx, '##NotesEditor', project_data.notes, 0, -10)
    if notes_changed then project_data.notes = new_notes end
    imgui.PopItemWidth(ctx)

    imgui.End(ctx)
  end

  if is_open then
    reaper.defer(loop)
  end
end

-- --- SCRIPT INITIALIZATION ---
function Main()
  project_data = FetchProjectData()

  local proj_name = GetProjectName()
  if proj_name and proj_name ~= "" then
    project_data.title = proj_name
  end
  
  project_data.author = "Hosi Prod"

  SaveProjectData() 
  last_refresh_time = reaper.time_precise()
  loop()
end

reaper.defer(Main)

