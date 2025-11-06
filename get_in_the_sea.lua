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
local Randomize = include("lib/randomize")

mxsamples_instruments = {}
m = midi.connect()

local draw_metro = metro.init()

local seafarers = {}
local any_playing = false
local ensemble = nil
local k1_down = false
-- Page-based UI model
local ui_pages = {
  { id = "seafarers", label = "Seafarers" },
  { id = "ensemble", label = "Ensemble" },
  { id = "info", label = "Info" },
  { id = "human", label = "Humanize" },
  { id = "engine", label = "Engine" },
  { id = "output", label = "Output & MIDI" },
  { id = "random", label = "Randomize" },
}
local ui_page_index = 1
local ui_element_index = 1

local function sign(d)
  if d > 0 then return 1 elseif d < 0 then return -1 else return 0 end
end

local function wrap(val, lo, hi)
  if val < lo then return hi elseif val > hi then return lo else return val end
  return val
end

local function current_page()
  return ui_pages[ui_page_index]
end

local function get_selected_player()
  return params:get("selected_player") or 1
end

local function engine_elements_for_active_engine(selected_id)
  local elements = {}
  -- engine activation selector (always at index 1)
  table.insert(elements, { type = "engine_select" })
  local ae = string.lower(engine.name or "")
  if ae == "mxsamples" then
    -- per-seafarer instrument selector if available
    if mxsamples_instruments ~= nil and #mxsamples_instruments > 0 then
      table.insert(elements, { type = "param", id = selected_id .. "_mxsamples_instrument" })
    end
  elseif ae == "polyperc" then
    for _, id in ipairs({ "amp", "release", "cutoff", "gain", "pan" }) do
      table.insert(elements, { type = "param", id = id })
    end
  elseif ae == "passersby" then
    for _, id in ipairs({ "pb_amp", "pb_attack", "pb_decay", "pb_reverb_mix", "pb_timbre_all" }) do
      table.insert(elements, { type = "param", id = id })
    end
  elseif ae == "odashodasho" then
    for _, id in ipairs({ "odash_attack", "odash_decay", "odash_index", "odash_index_scale", "odash_reverb_db" }) do
      table.insert(elements, { type = "param", id = id })
    end
  else
    -- fm7 or unknown: engine select only
  end
  return elements
end

local function page_element_count()
  local page = current_page()
  if page.id == "seafarers" then
    return #seafarers
  elseif page.id == "ensemble" then
    return 3
  elseif page.id == "info" then
    return 1
  elseif page.id == "human" then
    return 4
  elseif page.id == "engine" then
    local sel = get_selected_player()
    return #engine_elements_for_active_engine(sel)
  elseif page.id == "output" then
    return 3
  elseif page.id == "random" then
    return 4
  end
  return 1
end

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
    -- limit defaults to [-2..2]
    local default_octaves = { 0, -1, -2, -2, 1, 2, 2, -1 }
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
    -- E1: cycle pages
    local delta = sign(d)
    if delta ~= 0 then
      ui_page_index = wrap(ui_page_index + delta, 1, #ui_pages)
      ui_element_index = 1
    end
  elseif n == 2 then
    -- E2: cycle elements within current page
    local page = current_page()
    if page.id == "seafarers" then
      params:delta("selected_player", sign(d))
    else
      local delta = sign(d)
      if delta ~= 0 then
        ui_element_index = wrap(ui_element_index + delta, 1, page_element_count())
      end
    end
  elseif n == 3 then
    -- E3: adjust selected element
    local page = current_page()
    if page.id == "seafarers" then
      local mode = ensemble:get_mode()
      if mode == "semi-autonomous" then
        if d > 0 then ensemble:advance_all_target() end
      elseif mode == "manual" then
        if d > 0 then
          local sel = get_selected_player()
          local s = seafarers[sel]
          if s and s.can_user_advance and s.advance_one_by_user then
            if s:can_user_advance() then s:advance_one_by_user() end
          end
        end
      else
        -- autonomous: no-op
      end
    elseif page.id == "ensemble" then
      if ui_element_index == 1 then
        params:delta("ensemble_mode", sign(d))
      elseif ui_element_index == 2 then
        params:delta("pulse_enabled", sign(d))
      elseif ui_element_index == 3 then
        params:delta("ensemble_tempo", sign(d))
      end
    elseif page.id == "human" then
      if ui_element_index == 1 then
        params:delta("human_timing_ms", sign(d))
      elseif ui_element_index == 2 then
        params:delta("human_volume_pct", sign(d))
      elseif ui_element_index == 3 then
        params:delta("human_adv_ms", sign(d))
      elseif ui_element_index == 4 then
        params:delta("human_skip_pct", sign(d))
      end
    elseif page.id == "engine" then
      local sel = get_selected_player()
      local els = engine_elements_for_active_engine(sel)
      local idx = math.max(1, math.min(ui_element_index, #els))
      local el = els[idx]
      if el and el.type == "engine_select" then
        local function build_engine_list()
          local list = {}
          local function add_if(trigger_id, name)
            if params:lookup_param(trigger_id) ~= nil then table.insert(list, name) end
          end
          add_if("activate_mxsamples", "MxSamples")
          add_if("activate_polyperc", "PolyPerc")
          add_if("activate_fm7", "FM7")
          add_if("activate_passersby", "Passersby")
          add_if("activate_odashodasho", "Odashodasho")
          if #list == 0 then
            -- fallback
            list = engine.names or { "PolyPerc", "FM7", "Passersby", "Odashodasho", "MxSamples" }
          end
          return list
        end
        local list = build_engine_list()
        if #list > 0 then
          local cur = 1
          local target = string.lower(engine.name or "")
          for i, nm in ipairs(list) do
            if string.lower(nm or "") == target then cur = i break end
          end
          local next_i = cur + sign(d)
          if next_i < 1 then next_i = #list end
          if next_i > #list then next_i = 1 end
          local pick = list[next_i]
          if pick ~= nil then
            local id = "activate_" .. string.lower(pick)
            if params:lookup_param(id) ~= nil then
              params:bang(id)
            end
          end
        end
      elseif el and el.type == "param" and el.id ~= nil then
        params:delta(el.id, sign(d))
      end
    elseif page.id == "output" then
      local sel = get_selected_player()
      if ui_element_index == 1 then
        params:delta(sel .. "_output", sign(d))
      elseif ui_element_index == 2 then
        params:delta(sel .. "midi_out_device", sign(d))
      elseif ui_element_index == 3 then
        params:delta(sel .. "_midi_out_channel", sign(d))
      end
    elseif page.id == "random" then
      if ui_element_index == 1 then
        params:delta("rand_instruments", sign(d))
      elseif ui_element_index == 2 then
        params:delta("rand_engine_params", sign(d))
      elseif ui_element_index == 3 then
        params:delta("rand_humanization", sign(d))
      elseif ui_element_index == 4 then
        params:delta("rand_octaves", sign(d))
      end
    else
      -- info page: read-only
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
      -- K3: Randomize according to toggles
      if Randomize ~= nil and Randomize.apply ~= nil then
        Randomize.apply(seafarers, ensemble)
      end
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
  UI.draw(seafarers, any_playing, ensemble, ui_page_index, ui_element_index, ui_pages)
end

function cleanup()
  for s = 1, #seafarers do
    seafarers[s]:reset()
  end
end
