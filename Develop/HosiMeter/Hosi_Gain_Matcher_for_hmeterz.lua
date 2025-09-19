--[[
@description Hosi Gain Matcher for hmeterz
@author      Hosi (based on the hmeterz system and idea)
@version     1.0
@provides
  [main] . > Hosi_Gain_Matcher_for_hmeterz.lua

@changelog
  + v1.0: Gain Matcher for hmeterz automatically inserts/updates the "JS: Volume/Pan Smoother v5"
          plugin to adjust gain, ensuring accuracy and reliability.

@about
  # Hosi Gain Matcher for hmeterz

  This tool scans the highest peak data from the hmeterz system, then
  automatically inserts a Volume plugin at the beginning of the FX chain and adjusts it
  to bring all tracks to a target peak level.

  ## Requirements:
  - "JS: Volume/Pan Smoother v5" plugin (built-in in REAPER).

  ## Instructions:
  1. Run the 'Hosi_hmeterz_Meter_Bridge' script (v0.7+) and play music through the loudest sections.
  2. Run this script, enter the target Peak level.
  3. Click "Analyze & Fetch Data".
  4. Click "Apply Changes". The script will automatically add and adjust the plugin.
--]]

local reaper = reaper

-- =============================================================================
-- INITIALIZE AND CHECK REAIMGUI
-- =============================================================================
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local imgui = require('imgui')('0.10')

if not imgui or type(imgui) ~= "table" then
    reaper.ShowMessageBox("Error: Could not initialize ReaImGui library.\n\nPlease install ReaImGui (v0.10+ recommended) from ReaPack.", "Library Error", 0)
    return
end

-- =============================================================================
-- CONNECT TO SHARED MEMORY & CONSTANTS
-- =============================================================================
reaper.gmem_attach("meterz")

local SCRIPT_NAME = "Hosi Gain Matcher"
local PLUGIN_TO_ADD = "JS: Volume/Pan Smoother v5"
local PLUGIN_CUSTOM_NAME = "Gain Matcher"

local _NGRP, _NTX = 16, 16
local _PRMSZ, _PRMP = _NGRP * 16, 256
local _TXSZ = _NGRP * _NTX
local gmem_base = {
  _TXON      = _PRMP + _PRMSZ,
  _MAXPEAK   = _PRMP + _PRMSZ + _TXSZ * 7,
}
local _LDB = 8.685889638065 -- 20/ln(10)
local DB_MIN = -120

local ctx = imgui.CreateContext(SCRIPT_NAME)
local is_open = true
local flags = imgui.WindowFlags_AlwaysAutoResize

-- =============================================================================
-- UTILITY FUNCTIONS
-- =============================================================================
function lin_to_db(lin)
  if lin < 0.000001 then return DB_MIN end
  return math.max(DB_MIN, _LDB * math.log(lin))
end

-- Function to move an FX on a track using a compatible method.
-- This is inspired by the logic in Hosi_FX Homie Manager.
function MoveFx(track, source_slot, target_slot)
    if not track or source_slot == target_slot then return end
    -- The last parameter 'true' makes it a move operation instead of copy.
    reaper.TrackFX_CopyToTrack(track, source_slot, track, target_slot, true)
end


-- =============================================================================
-- CORE LOGIC & DATA
-- =============================================================================

local target_db_str = "-10.0"
local analysis_results = {}
local track_map = {}

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
          local gmem_index = meter_num + group_idx * _NTX
          track_map[gmem_index] = { name = track_name_str, ptr = track }
        end
      end
    end
  end
end

function RunAnalysis()
  analysis_results = {}
  local target_db = tonumber(target_db_str)
  if not target_db then
    reaper.ShowMessageBox("Invalid target dB level. Please enter a number.", "Error", 0)
    return
  end

  ScanProjectForTracks()

  for gmem_index, track_info in pairs(track_map) do
    if reaper.gmem_read(gmem_base._TXON + gmem_index) == 1 then
      local max_peak_val_lin = reaper.gmem_read(gmem_base._MAXPEAK + gmem_index)
      local max_peak_db = lin_to_db(max_peak_val_lin)

      if max_peak_db > DB_MIN then
        local adjustment_db = target_db - max_peak_db
        table.insert(analysis_results, {
          track_ptr = track_info.ptr,
          track_name = track_info.name,
          current_peak = max_peak_db,
          adjustment = adjustment_db
        })
      end
    end
  end

  table.sort(analysis_results, function(a,b)
    if a.track_name and b.track_name then
        return a.track_name < b.track_name
    end
    return false
  end)
end

function ApplyGainChanges()
  if not next(analysis_results) then
    reaper.ShowMessageBox("No data to apply. Please run the analysis first.", "Notice", 0)
    return
  end

  reaper.Undo_BeginBlock()

  local changed_count = 0
  for _, result in ipairs(analysis_results) do
    local track = result.track_ptr
    if track then
      local new_trim_db = result.adjustment
      
      local gain_matcher_idx = -1
      local hmeterz_tx_idx = -1

      -- Find our plugins
      local fx_count = reaper.TrackFX_GetCount(track)
      for i = 0, fx_count - 1 do
        local _, fx_name = reaper.TrackFX_GetFXName(track, i, "")
        if fx_name == PLUGIN_CUSTOM_NAME then
          gain_matcher_idx = i
        end
        if string.match(string.lower(fx_name), "hmeterz tx") then
          hmeterz_tx_idx = i
        end
      end
      
      -- Only proceed if hmeterzTX was found
      if hmeterz_tx_idx > -1 then
        local target_slot = hmeterz_tx_idx
        
        -- Case 1: Gain Matcher doesn't exist. Add it right before hmeterz.
        if gain_matcher_idx == -1 then
          -- The API inserts *at* a position, shifting others down.
          -- So we use the hmeterz index as the target.
          local new_fx_idx = reaper.TrackFX_AddByName(track, PLUGIN_TO_ADD, false, -1000 - target_slot)
          if new_fx_idx > -1 then
            gain_matcher_idx = new_fx_idx
            reaper.TrackFX_SetNamedConfigParm(track, gain_matcher_idx, "renamed_name", PLUGIN_CUSTOM_NAME)
          else
            reaper.ShowMessageBox(string.format("ERROR: Could not find plugin '%s'.\nPlease ensure it is installed.\n\nSkipping track: %s", PLUGIN_TO_ADD, result.track_name or "[Untitled]"), "Plugin Not Found", 0)
            goto continue_loop
          end
        
        -- Case 2: Gain Matcher exists but is AFTER hmeterz. Move it.
        elseif gain_matcher_idx > hmeterz_tx_idx then
            MoveFx(track, gain_matcher_idx, target_slot)
            -- After moving, its new index is the target_slot.
            gain_matcher_idx = target_slot
        end
        
        -- At this point, the plugin is guaranteed to exist and be in the correct position.
        -- We just need to find its current index again in case it moved.
        local final_gm_idx = -1
        for i=0, reaper.TrackFX_GetCount(track)-1 do
            local _, fx_name = reaper.TrackFX_GetFXName(track, i, "")
            if fx_name == PLUGIN_CUSTOM_NAME then
                final_gm_idx = i
                break
            end
        end

        if final_gm_idx > -1 then
            reaper.TrackFX_SetParam(track, final_gm_idx, 0, new_trim_db) -- Parameter 0 is Volume
            changed_count = changed_count + 1
        end

      end
    end
    ::continue_loop::
  end
  
  reaper.Undo_EndBlock("Apply Gain Matcher to " .. changed_count .. " tracks", -1)
  reaper.UpdateArrange()
  
  reaper.ShowMessageBox(string.format("%d track(s) have been processed.", changed_count), "Complete", 0)
end


-- =============================================================================
-- GRAPHICAL USER INTERFACE
-- =============================================================================
function loop()
  local visible
  visible, is_open = imgui.Begin(ctx, SCRIPT_NAME, is_open, flags)

  if visible then
    imgui.Text(ctx, "Gain matching tool based on hmeterz data.")
    imgui.Separator(ctx)

    imgui.PushItemWidth(ctx, 100)
    local changed, new_val = imgui.InputText(ctx, "Target Peak Level (dB)", target_db_str, 64)
    if changed then target_db_str = new_val end
    imgui.PopItemWidth(ctx)
    imgui.SameLine(ctx)
    if imgui.IsItemHovered(ctx) then imgui.SetTooltip(ctx, "Enter the peak level you want all tracks to reach.") end

    if imgui.Button(ctx, "Analyze & Fetch Data") then RunAnalysis() end
    imgui.SameLine(ctx)
    if imgui.Button(ctx, "Apply Changes") then ApplyGainChanges() end
    imgui.SameLine(ctx)
    if imgui.Button(ctx, "Clear Results") then analysis_results = {} end

    imgui.Separator(ctx)

    if imgui.BeginTable(ctx, "results_table", 3, imgui.TableFlags_Borders | imgui.TableFlags_RowBg) then
        imgui.TableSetupColumn(ctx, "Track Name")
        imgui.TableSetupColumn(ctx, "Current Peak (dB)")
        imgui.TableSetupColumn(ctx, "Required Gain (dB)")
        imgui.TableHeadersRow(ctx)

        for _, result in ipairs(analysis_results) do
            imgui.TableNextRow(ctx)
            imgui.TableSetColumnIndex(ctx, 0)
            imgui.Text(ctx, result.track_name or "[Untitled Track]")
            imgui.TableSetColumnIndex(ctx, 1)
            imgui.Text(ctx, string.format("%.2f", result.current_peak))
            imgui.TableSetColumnIndex(ctx, 2)
            imgui.Text(ctx, string.format("%+.2f", result.adjustment))
        end
        imgui.EndTable(ctx)
    end
  end
  imgui.End(ctx)

  if is_open then
    reaper.defer(loop)
  end
end

-- =============================================================================
-- SCRIPT ENTRY POINT
-- =============================================================================
ScanProjectForTracks()
reaper.defer(loop)

