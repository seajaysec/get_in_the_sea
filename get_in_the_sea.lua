-- scriptname: get_in_the_sea
-- @tomw
--
-- E1 start/stop
-- E2 reset

engine.name = "MxSamples"

local Seafarer = include("lib/seafarer")
-- External module: engine selection & per-engine parameter setup
local EngineSetup = include("lib/engine_setup")
-- External module: global script parameters (max drift, repeat probability, grace length)
local GlobalParams = include("lib/global_params")
-- Ensemble manager: modes, tempo, pulse, coordination
local Ensemble = include("lib/ensemble")
-- External module: MIDI transport handler (start/stop/continue)
local Midi = include("lib/midi")
-- External module: UI drawing for screen
local UI = include("lib/ui")
local tab = require "tabutil"

mxsamples_instruments = {}
m = midi.connect()

local draw_metro = metro.init()

local seafarers = {}
local any_playing = false
local ensemble = nil
local k1_down = false
local ui_focus = "header" -- 'header' or 'seafarers'
local header_items = { "mode", "pulse", "tempo", "info" }
local header_index = 1
local ui_show_info = false

function init()
  -- instantiate seafarers
  table.insert(seafarers, Seafarer:new(1))
  table.insert(seafarers, Seafarer:new(2))
  table.insert(seafarers, Seafarer:new(3))
  table.insert(seafarers, Seafarer:new(4))

  table.insert(seafarers, Seafarer:new(5))
  table.insert(seafarers, Seafarer:new(6))
  table.insert(seafarers, Seafarer:new(7))
  table.insert(seafarers, Seafarer:new(8))

  -- External: engine selection & per-engine parameter setup (includes MxSamples instruments)
  EngineSetup.setup(seafarers)

  -- (engine-specific params moved to EngineSetup)

  -- External: global script parameters
  GlobalParams.setup()

  -- Ensemble params and state
  ensemble = Ensemble:new(seafarers)
  ensemble:setup_params()
  for _, s in ipairs(seafarers) do s:set_ensemble(ensemble) end

  -- ORCA-style sections (no menu diving)
  -- OUTPUT
  params:add_separator("SEAFARER OUTPUT")
  for _, s in ipairs(seafarers) do s:add_output_param() end

  -- OCTAVE
  params:add_separator("SEAFARER OCTAVE")
  for _, s in ipairs(seafarers) do s:add_octave_param() end
  do
    local default_octaves = { 0, -1, -2, -3, 1, 2, 3, -1 }
    for i, s in ipairs(seafarers) do
      params:set(s.id .. "_octave", default_octaves[i])
    end
  end

  -- MIDI DEVICE
  params:add_separator("SEAFARER MIDI DEVICE")
  for _, s in ipairs(seafarers) do s:add_midi_device_param() end

  -- MIDI CHANNEL
  params:add_separator("SEAFARER MIDI CHANNEL")
  for _, s in ipairs(seafarers) do s:add_midi_channel_param() end

  params:default()

  screen.aa(1)

  draw_metro.event = update
  draw_metro:start(1 / 10)
end

-- External: MIDI transport handler
Midi.register_transport(m, seafarers)

function enc(n, d)
  if ensemble == nil then return end
  if n == 1 then
    if d > 0 then ui_focus = "seafarers" elseif d < 0 then ui_focus = "header" end
  elseif n == 2 then
    if ui_focus == "header" then
      local count = #header_items
      local prev = header_index
      header_index = header_index + d
      if header_index < 1 then header_index = 1 end
      if header_index > count then header_index = count end
      if header_items[header_index] == "info" and d > 0 then
        -- bridge to seafarers from Info using E2
        ui_focus = "seafarers"
      end
    else
      -- bridge back to header Info when moving left from first seafarer
      local sel_before = params:get("selected_player") or 1
      if d < 0 and sel_before <= 1 then
        ui_focus = "header"
        -- jump to Info header item
        for i, nme in ipairs(header_items) do
          if nme == "info" then
            header_index = i
            break
          end
        end
        return
      end
      params:delta("selected_player", d)
    end
  elseif n == 3 then
    if ui_focus == "header" then
      local item = header_items[header_index]
      if item == "mode" then
        params:delta("ensemble_mode", d)
      elseif item == "pulse" then
        -- toggle on movement; support multi-step by delta
        params:delta("pulse_enabled", d)
      elseif item == "tempo" then
        params:delta("ensemble_tempo", d)
      else
        -- Info: toggle info screen
        ui_show_info = not ui_show_info
      end
    else
      -- seafarers focus: E3 advances based on mode
      local mode = ensemble:get_mode()
      if mode == "semi-autonomous" then
        if d > 0 then ensemble:advance_all_target() end
      elseif mode == "manual" then
        if d > 0 then
          local sel = params:get("selected_player") or 1
          local s = seafarers[sel]
          if s then
            s.phrase = math.min(#phrases, s.phrase + 1)
            s.phrase_note = 1
          end
        end
      else
        -- autonomous: no-op
      end
    end
  end
end

function key(n, z)
  if z == 1 then
    if n == 1 then
      k1_down = true
    elseif n == 2 then
      if any_playing then
        ensemble:stop_all()
      else
        ensemble:start_all()
      end
    elseif n == 3 then
      ensemble:reset_all()
    end
  else
    if n == 1 then k1_down = false end
  end
end

function update()
  local all_end = true
  any_playing = false
  for s = 1, #seafarers do
    if seafarers[s].phrase ~= #phrases then all_end = false end
    if seafarers[s].playing then any_playing = true end
  end

  if ensemble ~= nil then
    ensemble:update_median()
    -- Ending protocol trigger
    if all_end then ensemble:maybe_start_ending(true) end
    for s = 1, #seafarers do
      seafarers[s].all_at_end = all_end
      seafarers[s].allowed_min_phrase = seafarers[s].allowed_min_phrase or 1
      seafarers[s].allowed_max_phrase = seafarers[s].allowed_max_phrase or (#phrases)
    end
  end

  redraw()
end

function redraw()
  -- External: delegate screen drawing to UI module
  UI.draw(seafarers, any_playing, ensemble, ui_focus, header_index, ui_show_info)
end

function cleanup()
  for s = 1, #seafarers do
    seafarers[s]:reset()
  end
end
