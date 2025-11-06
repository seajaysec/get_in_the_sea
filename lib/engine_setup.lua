-- Engine and parameter setup for Get in the Sea
-- External references noted inline where used

local EngineSetup = {}

-- External: utility helpers used to detect installed libraries on norns
local Utils = include("lib/utils")
local tab = require "tabutil"

-- local helpers (engine-specific)
local function mxSamplesInit()
  if skeys ~= nil then
    skeys:reset()
  end
end

local function polypercInit()
  if string.lower(engine.name or "") ~= "polyperc" then return end
  engine.amp(0.5)
  engine.release(1.2)
  engine.cutoff(800)
  engine.gain(1)
  engine.pan(0)
end

-- helper: add an Activate trigger inside an engine group
local function add_activate_trigger(id, label, engine_name, switch_engine)
  params:add_trigger(id, label)
  params:set_action(id, function()
    if switch_engine ~= nil then switch_engine(engine_name) end
  end)
end

-- add parameter groups per engine
local function add_polyperc_params(switch_engine)
  params:add_group("PolyPerc", 8)
  add_activate_trigger("activate_polyperc", "Activate: PolyPerc", "PolyPerc", switch_engine)
  params:add_separator("PARAMETERS")
  local cs_AMP = controlspec.new(0, 1, 'lin', 0, 0.5, '')
  params:add { type = "control", id = "amp", controlspec = cs_AMP, action = function(x)
    if string.lower(engine.name or "") == "polyperc" then
      engine.amp(x)
    end
  end }

  local cs_PW = controlspec.new(0, 100, 'lin', 0, 50, '%')
  params:add { type = "control", id = "pw", controlspec = cs_PW, action = function(x)
    if string.lower(engine.name or "") == "polyperc" then
      engine.pw(x / 100)
    end
  end }

  local cs_REL = controlspec.new(0.1, 3.2, 'lin', 0, 1.2, 's')
  params:add { type = "control", id = "release", controlspec = cs_REL, action = function(x)
    if string.lower(engine.name or "") == "polyperc" then
      engine.release(x)
    end
  end }

  local cs_CUT = controlspec.new(50, 5000, 'exp', 0, 800, 'hz')
  params:add { type = "control", id = "cutoff", controlspec = cs_CUT, action = function(x)
    if string.lower(engine.name or "") == "polyperc" then
      engine.cutoff(x)
    end
  end }

  local cs_GAIN = controlspec.new(0, 4, 'lin', 0, 1, '')
  params:add { type = "control", id = "gain", controlspec = cs_GAIN, action = function(x)
    if string.lower(engine.name or "") == "polyperc" then
      engine.gain(x)
    end
  end }

  local cs_PAN = controlspec.new(-1, 1, 'lin', 0, 0, '')
  params:add { type = "control", id = "pan", controlspec = cs_PAN, action = function(x)
    if string.lower(engine.name or "") == "polyperc" then
      engine.pan(x)
    end
  end }
end

local function add_odashodasho_params(switch_engine)
  params:add_group("Odashodasho", 18)
  add_activate_trigger("activate_odashodasho", "Activate: Odashodasho", "Odashodasho", switch_engine)
  params:add_separator("PARAMETERS")
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
end

local function add_passersby_params(switch_engine)
  params:add_group("Passersby", 18)
  add_activate_trigger("activate_passersby", "Activate: Passersby", "Passersby", switch_engine)
  params:add_separator("PARAMETERS")
  params:add { type = "control", id = "pb_amp", name = "amp", controlspec = controlspec.new(0, 1, 'lin', 0, 1, ''), action = function(
      v)
    if string.lower(engine.name or "") == "passersby" then engine.amp(v) end
  end }
  params:add { type = "control", id = "pb_attack", name = "attack", controlspec = controlspec.new(0.003, 8, 'lin', 0.001, 0.04, 's'), action = function(
      v)
    if string.lower(engine.name or "") == "passersby" then engine.attack(v) end
  end }
  params:add { type = "control", id = "pb_decay", name = "decay", controlspec = controlspec.new(0.01, 8, 'lin', 0.001, 1, 's'), action = function(
      v)
    if string.lower(engine.name or "") == "passersby" then engine.decay(v) end
  end }
  params:add { type = "control", id = "pb_drift", name = "drift", controlspec = controlspec.new(0, 1, 'lin', 0, 0, ''), action = function(
      v)
    if string.lower(engine.name or "") == "passersby" then engine.drift(v) end
  end }
  params:add_option("pb_env_type", "env type", { "LPG", "Sustain" }, 1)
  params:set_action("pb_env_type",
    function(i) if string.lower(engine.name or "") == "passersby" then engine.envType(i) end end)
  params:add { type = "control", id = "pb_fm1_amount", name = "fm1 amount", controlspec = controlspec.new(0, 1, 'lin', 0, 0, ''), action = function(
      v)
    if string.lower(engine.name or "") == "passersby" then engine.fm1Amount(v) end
  end }
  params:add { type = "control", id = "pb_fm1_ratio", name = "fm1 ratio", controlspec = controlspec.new(0.1, 10, 'lin', 0.01, 3.3, 'x'), action = function(
      v)
    if string.lower(engine.name or "") == "passersby" then engine.fm1Ratio(v) end
  end }
  params:add { type = "control", id = "pb_fm2_amount", name = "fm2 amount", controlspec = controlspec.new(0, 1, 'lin', 0, 0, ''), action = function(
      v)
    if string.lower(engine.name or "") == "passersby" then engine.fm2Amount(v) end
  end }
  params:add { type = "control", id = "pb_fm2_ratio", name = "fm2 ratio", controlspec = controlspec.new(0.1, 1, 'lin', 0.01, 0.66, 'x'), action = function(
      v)
    if string.lower(engine.name or "") == "passersby" then engine.fm2Ratio(v) end
  end }
  params:add { type = "control", id = "pb_glide", name = "glide", controlspec = controlspec.new(0, 5, 'lin', 0, 0, ''), action = function(
      v)
    if string.lower(engine.name or "") == "passersby" then engine.glide(v) end
  end }
  params:add { type = "control", id = "pb_lfo_freq", name = "lfo freq", controlspec = controlspec.new(0.001, 10, 'exp', 0, 0.5, 'hz'), action = function(
      v)
    if string.lower(engine.name or "") == "passersby" then engine.lfoFreq(v) end
  end }
  params:add_option("pb_lfo_shape", "lfo shape", { "Triangle", "Ramp", "Square", "Random" }, 1)
  params:set_action("pb_lfo_shape",
    function(i) if string.lower(engine.name or "") == "passersby" then engine.lfoShape(i) end end)
  params:add { type = "control", id = "pb_wave_folds", name = "wave folds", controlspec = controlspec.new(0, 3, 'lin', 0, 0, ''), action = function(
      v)
    if string.lower(engine.name or "") == "passersby" then engine.waveFolds(v) end
  end }
  params:add { type = "control", id = "pb_wave_shape", name = "wave shape", controlspec = controlspec.new(0, 1, 'lin', 0, 0, ''), action = function(
      v)
    if string.lower(engine.name or "") == "passersby" then engine.waveShape(v) end
  end }
  params:add { type = "control", id = "pb_reverb_mix", name = "reverb mix", controlspec = controlspec.new(0, 1, 'lin', 0, 0, ''), action = function(
      v)
    if string.lower(engine.name or "") == "passersby" then engine.reverbMix(v) end
  end }
  params:add { type = "control", id = "pb_timbre_all", name = "timbre all", controlspec = controlspec.new(0, 1, 'lin', 0, 0, ''), action = function(
      v)
    if string.lower(engine.name or "") == "passersby" then engine.timbreAll(v) end
  end }
end

local function add_mxsamples_params(seafarers, switch_engine)
  if mxsamples ~= nil and mxsamples_instruments ~= nil and #mxsamples_instruments > 0 then
    params:add_group("Seafarer Instruments", #seafarers + 3)
    add_activate_trigger("activate_mxsamples", "Activate: MxSamples", "MxSamples", switch_engine)
    params:add_trigger("mxsamples_randomize", "Randomize instruments")
    params:set_action("mxsamples_randomize", function()
      if #mxsamples_instruments == 0 then return end
      for _, s in ipairs(seafarers) do
        local idx = math.random(1, #mxsamples_instruments)
        params:set(s.id .. "_mxsamples_instrument", idx)
      end
    end)
    params:add_separator("INSTRUMENTS")
    for _, s in ipairs(seafarers) do s:add_instrument_param() end
  end
end

local function add_fm7_group(is_available, switch_engine)
  if is_available then
    params:add_group("FM7", 1)
    add_activate_trigger("activate_fm7", "Activate: FM7", "FM7", switch_engine)
  end
end

function EngineSetup.setup(seafarers)
  -- ENGINE selection and activation plumbing (no hidden params)
  local function engine_available(name)
    if engine.names == nil or #engine.names == 0 then return true end
    return tab.contains(engine.names, name)
  end

  local engines_list = { "PolyPerc", "FM7", "Passersby", "Odashodasho" }
  -- External: check if MxSamples is installed so we can expose it as an option
  if Utils.lib_installed("mx.samples/lib/mx.samples") then
    table.insert(engines_list, "MxSamples")
  end

  local available_engines = {}
  for _, name in ipairs(engines_list) do
    if engine_available(name) then table.insert(available_engines, name) end
  end

  local function switch_engine(name)
    if name == nil or name == engine.name then return end
    clock.run(function()
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
  end

  -- AUDIO ENGINE SETTINGS
  params:add_separator("AUDIO ENGINE SETTINGS")
  add_polyperc_params(switch_engine)
  -- If MxSamples is installed, prepare instrument list and client (create its group here under AUDIO ENGINE SETTINGS)
  if Utils.lib_installed("mx.samples/lib/mx.samples") then
    mxsamples = include("mx.samples/lib/mx.samples")
    skeys = mxsamples:new()
    mxsamples_instruments = skeys:list_instruments()
    mxSamplesInit()
  end
  add_mxsamples_params(seafarers, switch_engine)
  local is_fm7_available = false
  for _, n in ipairs(available_engines) do
    if n == "FM7" then
      is_fm7_available = true
      break
    end
  end
  add_fm7_group(is_fm7_available, switch_engine)
  add_odashodasho_params(switch_engine)
  add_passersby_params(switch_engine)
end

return EngineSetup
