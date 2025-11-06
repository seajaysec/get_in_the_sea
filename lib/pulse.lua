-- Pulse agent: optional metronomic eighth-note voice

MusicUtil = require "musicutil"

local Pulse = {}
Pulse.__index = Pulse

function Pulse:new()
  local o = {
    enabled = false,
    running = false,
    volume = 0.8,
    ensembleRef = nil,
    runner = nil,
  }
  setmetatable(o, Pulse)
  return o
end

function Pulse:set_volume(v)
  self.volume = v or self.volume
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
    -- Use an existing instrument if any player has one selected
    local inst = nil
    if self.ensembleRef and self.ensembleRef.players and #self.ensembleRef.players > 0 then
      for _, s in ipairs(self.ensembleRef.players) do
        if s.mx_instrument and s.mx_instrument ~= "" then inst = s.mx_instrument break end
      end
    end
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
    -- Respect current engine parameters; just trigger
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
  self.ensembleRef = ensemble
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

function Pulse:begin_fade(duration)
  if not self.enabled then return end
  local dur = duration or 3
  clock.run(function()
    local steps = 20
    local startv = self.volume
    for i = 1, steps do
      self.volume = util.linlin(1, steps, startv, 0, i)
      clock.sleep(dur / steps)
    end
    self:stop()
  end)
end

return Pulse


