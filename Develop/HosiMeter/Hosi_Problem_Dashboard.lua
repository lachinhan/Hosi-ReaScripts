--[[
@description Problem Dashboard for hmeterz
@author      Hosi
@version     0.1
@provides
  [main] . > Hosi_Problem_Dashboard.lua

@about
  # Problem Dashboard for hmeterz

  This script acts as an intelligent assistant, automatically scanning your
  project for potential audio issues based on data from the hmeterz system.

  v0.1:
  - Initial release.
  - Detects and lists tracks that have clipped.
  - Allows quick navigation to the problematic track.

  ## Requirements:
  - 'ReaImGui' library (install via ReaPack).
  - 'hmeterztx' JSFX plugin inserted on tracks.
--]]

local reaper = reaper

-- =============================================================================
-- INITIALIZE AND CHECK REAIMGUI
-- =============================================================================
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local imgui = require('imgui')('0.10')

if not imgui or type(imgui) ~= "table" then
    reaper.ShowMessageBox("Error: Could not initialize ReaImGui library.\n\nPlease install ReaImGui (v0.10+ recommended) from ReaPack to run this script.", "Library Error", 0)
    return
end

-- =============================================================================
-- CONNECT TO SHARED MEMORY & CONSTANTS
-- =============================================================================
reaper.gmem_attach("meterz")

local SCRIPT_NAME = "Problem Dashboard"
local _NGRP, _NTX = 16, 16
local _PRMSZ, _PRMP = _NGRP * 16, 256
local _TXSZ = _NGRP * _NTX
local gmem_base = {
  _TXON      = _PRMP + _PRMSZ,
  _RMS       = _PRMP + _PRMSZ + _TXSZ * 1,
  _PK        = _PRMP + _PRMSZ + _TXSZ * 2,
  _PKHOLD    = _PRMP + _PRMSZ + _TXSZ * 3,
  _HUE       = _PRMP + _PRMSZ + _TXSZ * 4,
  _CLIP      = _PRMP + _PRMSZ + _TXSZ * 5,
  _CLIPCOUNT = _PRMP + _PRMSZ + _TXSZ * 6,
}

local ctx = imgui.CreateContext(SCRIPT_NAME)
local is_open = true

-- Colors for different severity levels
local colors = {
    critical = { 255, 60, 60, 255 },
    warning  = { 255, 180, 0, 255 },
    info     = { 100, 150, 255, 255 }
}

-- =============================================================================
-- HELPER FUNCTIONS
-- =============================================================================

-- Helper function to pack RGBA values into a single integer for ImGui
function PackColor(r, g, b, a)
    a = a or 255
    return ((a << 24) | (b << 16) | (g << 8) | r)
end

-- =============================================================================
-- CORE LOGIC & DATA
-- =============================================================================

local track_map = {} -- Stores { name = "...", ptr = track_pointer } for each meter
local problems = {}  -- Stores detected issues
local last_scan_time = 0
local last_analysis_time = 0

-- Function to get a unique ID for a meter
function get_meter_id(group_idx, meter_num)
    return string.format("g%d-m%d", group_idx, meter_num)
end

-- Scans the project to map meters to actual REAPER tracks
function ScanProjectForTracks()
  track_map = {}
  local num_tracks = reaper.CountTracks(0)
  for i = 0, num_tracks - 1 do
    local track = reaper.GetTrack(0, i)
    local num_fx = reaper.TrackFX_GetCount(track)
    for fx_index = 0, num_fx - 1 do
      local _, fx_name = reaper.TrackFX_GetFXName(track, fx_index, "")
      if fx_name and string.match(string.lower(fx_name), "hmeterz tx") then
        local group_idx = math.floor(reaper.TrackFX_GetParam(track, fx_index, 0) + 0.5)
        local meter_num = math.floor(reaper.TrackFX_GetParam(track, fx_index, 1) + 0.5)
        if meter_num > 0 then
          local _, track_name_str = reaper.GetTrackName(track, "")
          local meter_id = get_meter_id(group_idx, meter_num)
          track_map[meter_id] = { name = track_name_str, ptr = track, g = group_idx, m = meter_num }
        end
      end
    end
  end
  last_scan_time = reaper.time_precise()
end

-- Rule Engine: Part 1 - Rule Definition
function checkClipping(meter_id, track_info)
    local gmem_index = track_info.m + track_info.g * _NTX
    local clip_count = reaper.gmem_read(gmem_base._CLIPCOUNT + gmem_index)

    if clip_count > 0 then
        -- A problem is found, return a problem description table
        return {
            severity = "critical",
            description = string.format("clipped %d time(s)", clip_count),
            value = clip_count,
            action_title = "Find Track & Reset"
        }
    end
    -- No problem found
    return nil
end

-- Rule Engine: Part 2 - Analysis Core
function RunAnalysis()
    -- No need to run analysis every single frame
    if reaper.time_precise() - last_analysis_time < 0.25 then return end

    -- We will rebuild the problem list completely to remove resolved issues.
    local new_problems = {}

    for meter_id, track_info in pairs(track_map) do
        -- RULE: Check for clipping
        local clip_problem = checkClipping(meter_id, track_info)
        if clip_problem then
            new_problems[meter_id] = {
                track = track_info,
                issue = clip_problem
            }
        end
        
        -- Future rules can be added here, e.g.:
        -- local phase_problem = checkPhase(...)
        -- if phase_problem then ... end
    end
    
    problems = new_problems
    last_analysis_time = reaper.time_precise()
end

-- =============================================================================
-- GUI DRAWING
-- =============================================================================
function loop()
  local visible
  visible, is_open = imgui.Begin(ctx, SCRIPT_NAME, is_open)

  if visible then
      imgui.Text(ctx, "Scanning project for audio issues in real-time...")
      imgui.Separator(ctx)

      if imgui.Button(ctx, "Rescan Project Tracks") then
          ScanProjectForTracks()
      end
      imgui.SameLine(ctx)
      if imgui.IsItemHovered(ctx) then
          imgui.SetTooltip(ctx, "Click this if you've added or removed hmeterztx plugins.")
      end
      
      -- Run the analysis core to update the problems list
      RunAnalysis()

      imgui.Separator(ctx)
      
      -- FIX v1.2: Add a check for available space to prevent a crash when the window is too small.
      -- The ImGui assertion fails if BeginChild is called when there's no space to draw it.
      local content_w, content_h = imgui.GetContentRegionAvail(ctx)
      if content_w > 1 and content_h > 1 then
        imgui.BeginChild(ctx, "problem_list", 0, 0)

        if not next(problems) then
            imgui.TextWrapped(ctx, "No problems detected. Everything looks great!")
        else
            for meter_id, p_info in pairs(problems) do
                local severity_label, color
                if p_info.issue.severity == "critical" then
                    severity_label = "CRITICAL"
                    color = colors.critical
                elseif p_info.issue.severity == "warning" then
                    severity_label = "WARNING"
                    color = colors.warning
                else
                    severity_label = "INFO"
                    color = colors.info
                end

                -- Display Severity
                -- FIX v1.3: Replaced the potentially missing function with the compatible PackColor helper.
                imgui.PushStyleColor(ctx, imgui.Col_Text, PackColor(color[1], color[2], color[3], color[4]))
                imgui.Text(ctx, string.format("[%s]", severity_label))
                imgui.PopStyleColor(ctx, 1)
                
                imgui.SameLine(ctx)
                
                -- Display Track Name and Description
                imgui.Text(ctx, string.format("Track '%s' has %s.", p_info.track.name, p_info.issue.description))

                -- Action Button
                if imgui.Button(ctx, string.format("%s##%s", p_info.issue.action_title, meter_id)) then
                    local target_track = p_info.track.ptr
                    if target_track then
                        -- Action 1: Select the track
                        reaper.Main_OnCommand(40297, 0) -- Unselect all tracks
                        reaper.SetTrackSelected(target_track, true)
                        reaper.gmem_write(gmem_base._CLIP + (p_info.track.m + p_info.track.g * _NTX), 0)
                        reaper.gmem_write(gmem_base._CLIPCOUNT + (p_info.track.m + p_info.track.g * _NTX), 0)
                        
                        -- Action 2 (Future): Center view on track, add marker, etc.
                    end
                end
                imgui.Separator(ctx)
            end
        end

        imgui.EndChild(ctx)
      end
  end

  imgui.End(ctx)

  if is_open then
    -- Rescan tracks automatically every 5 seconds if needed
    if reaper.time_precise() - last_scan_time > 5 then
        ScanProjectForTracks()
    end
    reaper.defer(loop)
  end
end

-- =============================================================================
-- SCRIPT ENTRY POINT
-- =============================================================================
ScanProjectForTracks()
reaper.defer(loop)

