-- scriptname: get_in_the_sea
-- @tomw
--
-- E1 start/stop
-- E2 reset

engine.name = "MxSamples"

local Seafarer = include("lib/seafarer")
local tab = require "tabutil"

mxsamples_instruments = {}
m = midi.connect()

local draw_metro = metro.init()

local seafarers = {}
local any_playing = false

function init()
  if libInstalled("mx.samples/lib/mx.samples") then
    mxsamples = include("mx.samples/lib/mx.samples")
    skeys = mxsamples:new()
    mxsamples_instruments = skeys:list_instruments()
    mxSamplesInit()
  end

  -- GLOBAL settings
  params:add_group("GLOBAL", 3)
  params:add { type = "number", id = "max_drift", name = "max phrase drift", min = 1, max = 10, default = 3 }
  params:add { type = "number", id = "repeat_probability", name = "repeat probability", min = 0, max = 10, default = 5 }
  params:add { type = "control", id = "grace_len_beats", name = "grace length (beats)", controlspec = controlspec.new(0.0625, 0.5, 'lin', 0, 0.0625, 'beats') }

  -- add seafarers
  table.insert(seafarers, Seafarer:new(1))
  table.insert(seafarers, Seafarer:new(2))
  table.insert(seafarers, Seafarer:new(3))
  table.insert(seafarers, Seafarer:new(4))

  table.insert(seafarers, Seafarer:new(5))
  table.insert(seafarers, Seafarer:new(6))
  table.insert(seafarers, Seafarer:new(7))
  table.insert(seafarers, Seafarer:new(8))

  -- ORCA-style sections
  -- OUTPUT
  params:add_group("SEAFARER OUTPUT", #seafarers)
  for _, s in ipairs(seafarers) do s:add_output_param() end

  -- INSTRUMENT (MxSamples only)
  if mxsamples ~= nil and #mxsamples_instruments > 0 then
    params:add_group("SEAFARER INSTRUMENT", #seafarers)
    for _, s in ipairs(seafarers) do s:add_instrument_param() end
  end

  -- OCTAVE
  params:add_group("SEAFARER OCTAVE", #seafarers)
  for _, s in ipairs(seafarers) do s:add_octave_param() end

  -- MIDI DEVICE
  params:add_group("SEAFARER MIDI DEVICE", #seafarers)
  for _, s in ipairs(seafarers) do s:add_midi_device_param() end

  -- MIDI CHANNEL
  params:add_group("SEAFARER MIDI CHANNEL", #seafarers)
  for _, s in ipairs(seafarers) do s:add_midi_channel_param() end

  params:default()

  screen.aa(1)

  draw_metro.event = update
  draw_metro:start(1 / 10)
end

function mxSamplesInit()
  skeys:reset()
end

function libInstalled(file)
  local dirs = { norns.state.path, _path.code, _path.extn }
  for _, dir in ipairs(dirs) do
    local p = dir .. file .. '.lua'
    if util.file_exists(p) then
      return true
    end
  end
  return false
end

m.event = function(data)
  local d = midi.to_msg(data)
  if d.type == "start" or d.type == "stop" or d.type == "continue" then
    for s = 1, #seafarers do
      if d.type == "start" then
        seafarers[s]:reset()
      elseif d.type == "stop" then
        seafarers[s]:all_notes_off()
      end

      seafarers[s].playing = d.type == "start" or d.type == "continue"
    end
  end
end

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
  screen.clear()
  screen.font_face(12)
  screen.font_size(12)
  screen.level(15)

  screen.move(0, 10)
  screen.text("Get in the sea!")

  screen.font_size(10)

  local x = 0
  local y = 24
  for s = 1, #seafarers do
    screen.move(x, y)
    screen.text(string.format("%02d", seafarers[s].phrase))

    x = x + 30
    if s == 4 then
      y = 44
      x = 0
    end
  end

  screen.font_size(8)
  screen.move(0, 60)
  if any_playing then
    screen.text("Stop   Reset")
  else
    screen.text("Start  Reset")
  end

  screen.update()
end

function cleanup()
  for s = 1, #seafarers do
    seafarers[s]:reset()
  end
end
