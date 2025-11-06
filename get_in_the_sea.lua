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
end

function key(n, z)
  if z == 1 then
    for s = 1, #seafarers do
      if n == 2 then
        seafarers[s].playing = not seafarers[s].playing
        seafarers[s]:all_notes_off()
      elseif n == 3 then
        seafarers[s]:reset()
      end
    end
  end
end

function update()
  local all_end = true
  any_playing = false
  local min_phrase = 999
  for s = 1, #seafarers do
    -- check if all players have reached the end (probably shouldn't be here)
    if seafarers[s].phrase ~= #phrases then
      all_end = false
    end
    -- check if all players are playing
    if seafarers[s].playing then
      any_playing = true
    end
    -- get the lowest phrase to stop seafarers racing ahead
    if seafarers[s].phrase < min_phrase then
      min_phrase = seafarers[s].phrase
    end
  end

  -- let all seafarers know what the others are up to
  for s = 1, #seafarers do
    seafarers[s].all_at_end = all_end
    seafarers[s].max_phrase = min_phrase + params:get("max_drift")
  end

  redraw()
end

function redraw()
  -- External: delegate screen drawing to UI module
  UI.draw(seafarers, any_playing)
end

function cleanup()
  for s = 1, #seafarers do
    seafarers[s]:reset()
  end
end
