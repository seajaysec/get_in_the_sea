-- scriptname: get_in_the_sea
-- @tomw
--
-- E1 start/stop
-- E2 reset

engine.name = "PolyPerc"

local Seafarer = include("lib/seafarer")

audio_engines = { "PolyPerc", "MxSynths" }
mxsamples_instruments = {}
m = midi.connect()
mxsynths = nil
mxsynths_initialized = false

local draw_metro = metro.init()

local seafarers = {}
local any_playing = false
local selected_seafarer = 1
local k1_held = false

function init()
  if libInstalled("mx.samples/lib/mx.samples") then
    mxsamples = include("mx.samples/lib/mx.samples")
    skeys = mxsamples:new()
    mxsamples_instruments = skeys:list_instruments()
    if #mxsamples_instruments > 0 then
      table.insert(audio_engines, "MxSamples")
    end
  end

  -- Pre-initialize mx.synths params (avoid adding param groups during engine switch)
  if libInstalled("mx.synths/lib/mx.synths") then
    mxSynthsInit()
  end

  -- add polyperc params
  params:add_group("PolyPerc", 6)
  cs_AMP = controlspec.new(0, 1, 'lin', 0, 0.5, '')
  params:add { type = "control", id = "amp", controlspec = cs_AMP, action = function(x) engine.amp(x) end }

  cs_PW = controlspec.new(0, 100, 'lin', 0, 50, '%')
  params:add { type = "control", id = "pw", controlspec = cs_PW,
    action = function(x) engine.pw(x / 100) end }

  cs_REL = controlspec.new(0.1, 3.2, 'lin', 0, 1.2, 's')
  params:add { type = "control", id = "release", controlspec = cs_REL,
    action = function(x) engine.release(x) end }

  cs_CUT = controlspec.new(50, 5000, 'exp', 0, 800, 'hz')
  params:add { type = "control", id = "cutoff", controlspec = cs_CUT,
    action = function(x) engine.cutoff(x) end }

  cs_GAIN = controlspec.new(0, 4, 'lin', 0, 1, '')
  params:add { type = "control", id = "gain", controlspec = cs_GAIN,
    action = function(x) engine.gain(x) end }

  cs_PAN = controlspec.new(-1, 1, 'lin', 0, 0, '')
  params:add { type = "control", id = "pan", controlspec = cs_PAN,
    action = function(x) engine.pan(x) end }

  -- orca-like engine UX: hidden index + triggers
  params:add_group("ENGINE", 1)
  params:add_number("engine_index", "engine index", 1, 3, 1)
  params:hide("engine_index")
  local function load_engine_by_index(idx)
    local name = audio_engines[idx]
    if name == nil then return end
    if name ~= engine.name then
      clock.run(function()
        engine.load(name, function()
          if name == "MxSamples" then
            mxSamplesInit()
          elseif name == "MxSynths" then
            mxSynthsInit()
          end
        end)
      end)
    end
  end
  params:set_action("engine_index", function(val)
    load_engine_by_index(val)
  end)
  params:add_trigger("engine_polyperc", "Activate PolyPerc")
  params:set_action("engine_polyperc", function()
    params:set("engine_index", 1)
  end)
  params:add_trigger("engine_mxsynths", "Activate MxSynths")
  params:set_action("engine_mxsynths", function()
    params:set("engine_index", 2)
  end)
  if tab.contains(audio_engines, "MxSamples") then
    params:add_trigger("engine_mxsamples", "Activate MxSamples")
    params:set_action("engine_mxsamples", function()
      -- PolyPerc, MxSynths, MxSamples → index is 3 for MxSamples when present
      local idx = 3
      params:set("engine_index", idx)
    end)
  end

  params:add { type = "number", id = "max_drift", name = "max phrase drift", min = 1, max = 10, default = 3 }
  params:add { type = "number", id = "repeat_probability", name = "repeat probability", min = 0, max = 10, default = 5 }
  params:add { type = "control", id = "grace_len_beats", name = "grace length (beats)", controlspec = controlspec.new(0.0625, 0.5, 'lin', 0, 0.0625, 'beats') }
  params:add { type = "number", id = "mxsynths_voice_id", name = "mx.synths voice id (0=off)", min = 0, max = 8, default = 1 }

  -- add seafarers and their params
  table.insert(seafarers, Seafarer:new(1))
  table.insert(seafarers, Seafarer:new(2))
  table.insert(seafarers, Seafarer:new(3))
  table.insert(seafarers, Seafarer:new(4))

  table.insert(seafarers, Seafarer:new(5))
  table.insert(seafarers, Seafarer:new(6))
  table.insert(seafarers, Seafarer:new(7))
  table.insert(seafarers, Seafarer:new(8))

  params:default()

  screen.aa(1)

  draw_metro.event = update
  draw_metro:start(1 / 10)
end

function mxSamplesInit()
  skeys:reset()
end

function mxSynthsInit()
  if mxsynths_initialized then return end
  local mxsynths_ = include("mx.synths/lib/mx.synths")
  mxsynths = mxsynths_:new()
  mxsynths_initialized = true
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
  if n == 1 then
    -- change engine
    local idx = util.clamp(params:get("engine_index") + (d > 0 and 1 or -1), 1, #audio_engines)
    params:set("engine_index", idx)
  elseif n == 2 then
    -- select seafarer
    selected_seafarer = util.clamp(selected_seafarer + (d > 0 and 1 or -1), 1, #seafarers)
  elseif n == 3 then
    local s = seafarers[selected_seafarer]
    if s ~= nil then
      if k1_held then
        s.octave = util.clamp((s.octave or 0) + (d > 0 and 1 or -1), -3, 3)
      else
        local outputs = options.OUTPUT
        local next_out = s.output + (d > 0 and 1 or -1)
        if next_out < 1 then next_out = #outputs end
        if next_out > #outputs then next_out = 1 end
        if s.set_output ~= nil then s:set_output(next_out) else s.output = next_out end
      end
    end
  end
end

function key(n, z)
  if n == 1 then k1_held = (z == 1) return end
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
    local marker = (s == selected_seafarer) and ">" or " "
    screen.text(marker .. string.format("%02d", seafarers[s].phrase))

    x = x + 30
    if s == 4 then
      y = 44
      x = 0
    end
  end

  screen.font_size(8)
  screen.move(0, 60)
  local eng = engine.name or audio_engines[params:get("engine_index")] or "?"
  local ui = (any_playing and "Stop" or "Start") .. "  Reset   E1:Engine  E2:Sel  E3:" .. (k1_held and "Oct" or "Out")
  screen.text(string.sub(eng, 1, 9) .. " | " .. ui)

  screen.update()
end

function cleanup()
  for s = 1, #seafarers do
    seafarers[s]:reset()
  end
end
