-- Pulse agent: optional metronomic eighth-note voice

MusicUtil = require "musicutil"

local Pulse = {}
Pulse.__index = Pulse

function Pulse:new()
  local o = {
    enabled = false,
    running = false,
    volume = 0.8,
    mxsamples_instrument = nil,
    runner = nil,
  }
  setmetatable(o, Pulse)
  return o
end

function Pulse:set_volume(v)
  self.volume = v or self.volume
end

function Pulse:set_mx_instrument(name)
  self.mxsamples_instrument = name
end

local function engine_supports_poly()
  return string.lower(engine.name or "") == "polyperc"
end

local function engine_supports_fm7()
  return string.lower(engine.name or "") == "fm7"
end

local function engine_supports_passersby()
  return string.lower(engine.name or "") == "passersby"
end

local function engine_supports_mxsamples()
  return engine.name == "MxSamples" and skeys ~= nil
end

local function note_num_to_freq(n)
  return MusicUtil.note_num_to_freq(n)
end

function Pulse:play_tick()
  local note_num = 96 -- C7
  local vel = math.floor(math.min(127, math.max(1, self.volume * 127)))
  local freq = note_num_to_freq(note_num)

  if engine_supports_mxsamples() then
    local inst = self.mxsamples_instrument or (mxsamples_instruments and mxsamples_instruments[1])
    if inst ~= nil then
      skeys:on({ name = inst, midi = note_num, velocity = vel })
      clock.run(function()
        clock.sleep(clock.get_beat_sec() / 2)
        skeys:off({ name = inst, midi = note_num })
      end)
      return
    end
  end

  if engine_supports_poly() then
    engine.amp(self.volume)
    engine.hz(freq)
  elseif engine_supports_fm7() then
    engine.start(note_num, freq)
    clock.run(function()
      clock.sleep(clock.get_beat_sec() / 2)
      engine.stop(note_num)
    end)
  elseif engine_supports_passersby() then
    engine.noteOn(note_num, freq, vel)
    clock.run(function()
      clock.sleep(clock.get_beat_sec() / 2)
      engine.noteOff(note_num)
    end)
  else
    -- Unknown engine: do nothing to avoid errors
  end
end

function Pulse:start(ensemble)
  if self.running then return end
  self.enabled = true
  self.running = true
  self.runner = clock.run(function()
    -- Start a little before entry per spec (5s)
    clock.sleep(5)
    while self.enabled do
      -- eighth-note spacing
      self:play_tick()
      clock.sync(0.5)
    end
  end)
end

function Pulse:stop()
  self.enabled = false
  self.running = false
end

return Pulse


