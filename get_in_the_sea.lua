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
  -- ENGINE section (Orca-style engine triggers)
  local function engine_available(name)
    if engine.names == nil or #engine.names == 0 then return true end
    return tab.contains(engine.names, name)
  end

  local engines_list = {"PolyPerc", "FM7", "Passersby", "Odashodasho"}
  if libInstalled("mx.samples/lib/mx.samples") then
    table.insert(engines_list, "MxSamples")
  end

  local available_engines = {}
  for _, name in ipairs(engines_list) do
    if engine_available(name) then table.insert(available_engines, name) end
  end

  params:add_separator("ENGINE")
  local default_engine_index = 1
  for i, n in ipairs(available_engines) do if n == engine.name then default_engine_index = i break end end
  params:add_number("engine_index", "engine index", 1, #available_engines, default_engine_index)
  params:hide("engine_index")
  params:set_action("engine_index", function(idx)
    local name = available_engines[idx]
    if name == nil or name == engine.name then return end
    clock.run(function()
      -- stop current notes before switching
      for s = 1, #seafarers do
        seafarers[s]:all_notes_off()
      end
      engine.load(name, function()
        engine.name = name
        if name == "MxSamples" then
          mxSamplesInit()
        elseif name == "PolyPerc" then
          polypercInit()
        end
      end)
    end)
  end)
  for i, name in ipairs(available_engines) do
    params:add_trigger("engine_activate_" .. name, "Activate: " .. name)
    params:set_action("engine_activate_" .. name, function()
      params:set("engine_index", i)
    end)
  end

  if libInstalled("mx.samples/lib/mx.samples") then
    mxsamples = include("mx.samples/lib/mx.samples")
    skeys = mxsamples:new()
    mxsamples_instruments = skeys:list_instruments()
    mxSamplesInit()
  end

  -- instantiate seafarers
  table.insert(seafarers, Seafarer:new(1))
  table.insert(seafarers, Seafarer:new(2))
  table.insert(seafarers, Seafarer:new(3))
  table.insert(seafarers, Seafarer:new(4))

  table.insert(seafarers, Seafarer:new(5))
  table.insert(seafarers, Seafarer:new(6))
  table.insert(seafarers, Seafarer:new(7))
  table.insert(seafarers, Seafarer:new(8))

  -- AUDIO ENGINE SETTINGS (placed directly after ENGINE activation)
  params:add_separator("AUDIO ENGINE SETTINGS")

  -- PolyPerc params
  params:add_group("PolyPerc", 6)
  cs_AMP = controlspec.new(0, 1, 'lin', 0, 0.5, '')
  params:add { type = "control", id = "amp", controlspec = cs_AMP, action = function(x) if string.lower(engine.name) == "polyperc" then engine.amp(x) end end }

  cs_PW = controlspec.new(0, 100, 'lin', 0, 50, '%')
  params:add { type = "control", id = "pw", controlspec = cs_PW,
    action = function(x) if string.lower(engine.name) == "polyperc" then engine.pw(x / 100) end end }

  cs_REL = controlspec.new(0.1, 3.2, 'lin', 0, 1.2, 's')
  params:add { type = "control", id = "release", controlspec = cs_REL,
    action = function(x) if string.lower(engine.name) == "polyperc" then engine.release(x) end end }

  cs_CUT = controlspec.new(50, 5000, 'exp', 0, 800, 'hz')
  params:add { type = "control", id = "cutoff", controlspec = cs_CUT,
    action = function(x) if string.lower(engine.name) == "polyperc" then engine.cutoff(x) end end }

  cs_GAIN = controlspec.new(0, 4, 'lin', 0, 1, '')
  params:add { type = "control", id = "gain", controlspec = cs_GAIN,
    action = function(x) if string.lower(engine.name) == "polyperc" then engine.gain(x) end end }

  cs_PAN = controlspec.new(-1, 1, 'lin', 0, 0, '')
  params:add { type = "control", id = "pan", controlspec = cs_PAN,
    action = function(x) if string.lower(engine.name) == "polyperc" then engine.pan(x) end end }

  -- MxSamples per-seafarer instruments
  if mxsamples ~= nil and #mxsamples_instruments > 0 then
    params:add_group("MxSamples", #seafarers + 1)
    params:add_trigger("mxsamples_randomize", "Randomize instruments")
    params:set_action("mxsamples_randomize", function()
      if #mxsamples_instruments == 0 then return end
      for _, s in ipairs(seafarers) do
        local idx = math.random(1, #mxsamples_instruments)
        params:set(s.id .. "_mxsamples_instrument", idx)
      end
    end)
    for _, s in ipairs(seafarers) do s:add_instrument_param() end
  end

  -- Odashodasho params
  params:add_group("Odashodasho", 16)
  params:add { type = "control", id = "odash_attack", name = "attack", controlspec = controlspec.new(0, 8, 'lin', 0.01, 0.01, 's') }
  params:add { type = "control", id = "odash_decay", name = "decay", controlspec = controlspec.new(0, 8, 'lin', 0.01, 0.5, 's') }
  params:add { type = "control", id = "odash_attack_curve", name = "attack curve", controlspec = controlspec.new(-8, 8, 'lin', 1, 4, '') }
  params:add { type = "control", id = "odash_decay_curve", name = "decay curve", controlspec = controlspec.new(-8, 8, 'lin', 1, -4, '') }
  params:add { type = "control", id = "odash_mod_ratio", name = "mod ratio", controlspec = controlspec.new(0, 8, 'lin', 0.01, 1, 'x') }
  params:add { type = "control", id = "odash_car_ratio", name = "car ratio", controlspec = controlspec.new(0, 50, 'lin', 0.01, 1, 'x') }
  params:add { type = "control", id = "odash_index", name = "index", controlspec = controlspec.new(0, 200, 'lin', 0.1, 1.5, '') }
  params:add { type = "control", id = "odash_index_scale", name = "index scale", controlspec = controlspec.new(0, 10, 'lin', 0.1, 4, '') }
  params:add { type = "control", id = "odash_reverb_db", name = "reverb send (dB)", controlspec = controlspec.new(-96, 12, 'lin', 0.1, -18, 'dB') }
  params:add_control("odash_eq_freq", "eq freq", controlspec.WIDEFREQ)
  params:set("odash_eq_freq", 1200)
  params:add { type = "control", id = "odash_eq_db", name = "eq boost (dB)", controlspec = controlspec.new(-96, 36, 'lin', 0.1, 0, 'dB') }
  params:add_control("odash_lpf", "lpf", controlspec.WIDEFREQ)
  params:set("odash_lpf", 20000)
  params:add { type = "control", id = "odash_noise_db", name = "noise (dB)", controlspec = controlspec.new(-96, 20, 'lin', 1, -96, 'dB') }
  params:add { type = "control", id = "odash_noise_attack", name = "noise attack", controlspec = controlspec.new(0, 6, 'lin', 0.01, 0.01, 's') }
  params:add { type = "control", id = "odash_noise_decay", name = "noise decay", controlspec = controlspec.new(0, 6, 'lin', 0.01, 0.3, 's') }
  params:add { type = "control", id = "odash_pan", name = "pan", controlspec = controlspec.new(-1, 1, 'lin', 0, 0, '') }

  -- Passersby params
  params:add_group("Passersby", 16)
  params:add { type = "control", id = "pb_amp", name = "amp", controlspec = controlspec.new(0, 1, 'lin', 0, 1, '') , action = function(v) if string.lower(engine.name)=="passersby" then engine.amp(v) end end }
  params:add { type = "control", id = "pb_attack", name = "attack", controlspec = controlspec.new(0.003, 8, 'lin', 0.001, 0.04, 's') , action = function(v) if string.lower(engine.name)=="passersby" then engine.attack(v) end end }
  params:add { type = "control", id = "pb_decay", name = "decay", controlspec = controlspec.new(0.01, 8, 'lin', 0.001, 1, 's') , action = function(v) if string.lower(engine.name)=="passersby" then engine.decay(v) end end }
  params:add { type = "control", id = "pb_drift", name = "drift", controlspec = controlspec.new(0, 1, 'lin', 0, 0, '') , action = function(v) if string.lower(engine.name)=="passersby" then engine.drift(v) end end }
  params:add_option("pb_env_type", "env type", {"LPG","Sustain"}, 1)
  params:set_action("pb_env_type", function(i) if string.lower(engine.name)=="passersby" then engine.envType(i) end end)
  params:add { type = "control", id = "pb_fm1_amount", name = "fm1 amount", controlspec = controlspec.new(0, 1, 'lin', 0, 0, '') , action = function(v) if string.lower(engine.name)=="passersby" then engine.fm1Amount(v) end end }
  params:add { type = "control", id = "pb_fm1_ratio", name = "fm1 ratio", controlspec = controlspec.new(0.1, 10, 'lin', 0.01, 3.3, 'x') , action = function(v) if string.lower(engine.name)=="passersby" then engine.fm1Ratio(v) end end }
  params:add { type = "control", id = "pb_fm2_amount", name = "fm2 amount", controlspec = controlspec.new(0, 1, 'lin', 0, 0, '') , action = function(v) if string.lower(engine.name)=="passersby" then engine.fm2Amount(v) end end }
  params:add { type = "control", id = "pb_fm2_ratio", name = "fm2 ratio", controlspec = controlspec.new(0.1, 1, 'lin', 0.01, 0.66, 'x') , action = function(v) if string.lower(engine.name)=="passersby" then engine.fm2Ratio(v) end end }
  params:add { type = "control", id = "pb_glide", name = "glide", controlspec = controlspec.new(0, 5, 'lin', 0, 0, '') , action = function(v) if string.lower(engine.name)=="passersby" then engine.glide(v) end end }
  params:add { type = "control", id = "pb_lfo_freq", name = "lfo freq", controlspec = controlspec.new(0.001, 10, 'exp', 0, 0.5, 'hz') , action = function(v) if string.lower(engine.name)=="passersby" then engine.lfoFreq(v) end end }
  params:add_option("pb_lfo_shape", "lfo shape", {"Triangle","Ramp","Square","Random"}, 1)
  params:set_action("pb_lfo_shape", function(i) if string.lower(engine.name)=="passersby" then engine.lfoShape(i) end end)
  params:add { type = "control", id = "pb_wave_folds", name = "wave folds", controlspec = controlspec.new(0, 3, 'lin', 0, 0, '') , action = function(v) if string.lower(engine.name)=="passersby" then engine.waveFolds(v) end end }
  params:add { type = "control", id = "pb_wave_shape", name = "wave shape", controlspec = controlspec.new(0, 1, 'lin', 0, 0, '') , action = function(v) if string.lower(engine.name)=="passersby" then engine.waveShape(v) end end }
  params:add { type = "control", id = "pb_reverb_mix", name = "reverb mix", controlspec = controlspec.new(0, 1, 'lin', 0, 0, '') , action = function(v) if string.lower(engine.name)=="passersby" then engine.reverbMix(v) end end }
  params:add { type = "control", id = "pb_timbre_all", name = "timbre all", controlspec = controlspec.new(0, 1, 'lin', 0, 0, '') , action = function(v) if string.lower(engine.name)=="passersby" then engine.timbreAll(v) end end }

  -- GLOBAL settings (after engine settings)
  params:add_separator("GLOBAL")
  params:add { type = "number", id = "max_drift", name = "max phrase drift", min = 1, max = 10, default = 3 }
  params:add { type = "number", id = "repeat_probability", name = "repeat probability", min = 0, max = 10, default = 5 }
  params:add { type = "control", id = "grace_len_beats", name = "grace length (beats)", controlspec = controlspec.new(0.0625, 0.5, 'lin', 0, 0.0625, 'beats') }

  -- ORCA-style sections (no menu diving)
  -- OUTPUT
  params:add_separator("SEAFARER OUTPUT")
  for _, s in ipairs(seafarers) do s:add_output_param() end

  -- OCTAVE
  params:add_separator("SEAFARER OCTAVE")
  for _, s in ipairs(seafarers) do s:add_octave_param() end
  do
    local default_octaves = {0, 0, -1, -2, -3, 1, 2, 3}
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

function mxSamplesInit()
  skeys:reset()
end

function polypercInit()
  if string.lower(engine.name) ~= "polyperc" then return end
  engine.amp(0.5)
  engine.release(1.2)
  engine.cutoff(800)
  engine.gain(1)
  engine.pan(0)
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
