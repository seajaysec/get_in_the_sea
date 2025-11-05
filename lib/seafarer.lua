MusicUtil = require "musicutil"
local ALT_SCORE = include("lib/score")


-- Build phrases with note names, velocities, rests, and grace notes
local pitch_to_semitone = {
  C = 0,
  ["C#"] = 1,
  Db = 1,
  D = 2,
  ["D#"] = 3,
  Eb = 3,
  E = 4,
  F = 5,
  ["F#"] = 6,
  Gb = 6,
  G = 7,
  ["G#"] = 8,
  Ab = 8,
  A = 9,
  ["A#"] = 10,
  Bb = 10,
  B = 11,
}

local function note_name_to_midi(name)
  if name == nil then return nil end
  -- patterns: C4, F#5, Bb3
  local letter, accidental, octave = string.match(name, "^([A-G])([#b]?)(%d)$")
  if not letter then return nil end
  local pc = letter .. accidental
  local semitone = pitch_to_semitone[pc]
  local oct = tonumber(octave)
  if semitone == nil or oct == nil then return nil end
  -- MIDI: C4 = 60
  return 12 * (oct + 1) + semitone
end

local function velocity_from_level(level)
  if level == "low" then return 50 end
  if level == "medium" then return 90 end
  if level == "high" then return 120 end
  return 100
end

phrases = {}
for _, phr in ipairs(ALT_SCORE) do
  local events = {}
  for _, ev in ipairs(phr.score or {}) do
    local is_note = ev.note ~= nil
    local event = {
      midi = is_note and note_name_to_midi(ev.note) or nil,
      velocity = is_note and velocity_from_level(ev.velocity) or nil,
      duration = ev.duration or 0,
      is_grace = ev.gracenote == true,
    }
    table.insert(events, event)
  end
  table.insert(phrases, events)
end

options = {
  OUTPUT = { "audio", "midi", "audio + midi", "crow out 1+2", "crow ii JF" }
}


Seafarer = {}
Seafarer.__index = Seafarer

function Seafarer:new(id)
  local o = {
    id = id,
    playing = false,

    phrase = 1,
    phrase_note = 1,
    all_at_end = false,
    max_phrase = 3,

    output = 0,
    midi_out_device = midi.connect(1),
    midi_out_channel = 0,
    mx_instrument = "",

    active_notes = {},
    carry_beat_adjustment = 0,
    octave = 0,
  }

  setmetatable(o, Seafarer)
  o:init_params()

  clock.run(Seafarer.step, o)

  return o
end

function Seafarer:init_params()
  local param_count = mxsamples == nil and 4 or 5

  params:add_group("seafarer " .. self.id, param_count)

  params:add { type = "option", id = self.id .. "_output", name = "output",
    options = options.OUTPUT,
    action = function(value)
      self:all_notes_off()

      if value == 4 then
        crow.output[2].action = "{to(5,0),to(0,0.25)}"
      elseif value == 5 then
        crow.ii.pullup(true)
        crow.ii.jf.mode(1)
      end
      self.output = value
    end
  }

  if mxsamples ~= nil then
    params:add { type = "option", id = self.id .. "_mxsamples_instrument", name = "mx inst.", options = mxsamples_instruments,
      action = function(value)
        self:all_notes_off()
        self.mx_instrument = mxsamples_instruments[value]
      end
    }
  end

  params:add { type = "number", id = self.id .. "_octave", name = "octave",
    min = -3, max = 3, default = 0,
    action = function(value)
      self.octave = value
    end
  }

  params:add { type = "number", id = self.id .. "midi_out_device", name = "midi out device",
    min = 1, max = 4, default = 1, action = function(value)
    self:all_notes_off()
    self.midi_out_device = midi.connect(value)
  end
  }

  params:add { type = "number", id = self.id .. "_midi_out_channel", name = "midi out channel",
    min = 1, max = 16, default = 1,
    action = function(value)
      self:all_notes_off()
      self.midi_out_channel = value
    end }
end

function Seafarer:get_param(idx)
  return params:get(self.id .. "_" .. idx)
end

function Seafarer:reset()
  self.phrase = 1
  self.phrase_note = 1
  self:all_notes_off()
end

function Seafarer:all_notes_off()
  for _, a in pairs(self.active_notes) do
    if self.output == 2 or self.output == 3 then
      self.midi_out_device:note_off(a, nil, self.midi_out_channel)
    end

    if (self.output == 1 or self.output == 3) and engine.name == "MxSamples" then
      skeys:off({ name = self.mx_instrument, midi = a })
    end
    if (self.output == 1 or self.output == 3) and engine.name == "MxSynths" and params:get("mxsynths_voice_id") == self.id then
      engine.mx_note_off(a)
    end
  end
  self.active_notes = {}
end

function Seafarer:set_output(value)
  self:all_notes_off()
  if value == 4 then
    crow.output[2].action = "{to(5,0),to(0,0.25)}"
  elseif value == 5 then
    crow.ii.pullup(true)
    crow.ii.jf.mode(1)
  end
  self.output = value
end

function Seafarer:step()
  clock.sync(1)
  local waitCount = 0

  while true do
    if self.playing then
      if waitCount <= 0 then
        self:all_notes_off()

        -- get current event in the phrase
        local event = phrases[self.phrase][self.phrase_note]
        if event == nil then event = { duration = 0 } end

        -- play the event if it's a note
        if event.midi ~= nil then
          local note_num = event.midi + ((self.octave or 0) * 12)
          local velocity = event.velocity or 100
          local freq = MusicUtil.note_num_to_freq(note_num)

          if self.output == 1 or self.output == 3 then
            -- audio engine
            local ae = audio_engines[params:get("audio_engine")]
            if ae == "MxSamples" then
              skeys:on({ name = self.mx_instrument, midi = note_num, velocity = velocity })
              table.insert(self.active_notes, note_num)
            elseif ae == "MxSynths" then
              if params:get("mxsynths_voice_id") == self.id then
                local amp = math.min(1.0, math.max(0.1, (velocity or 100) / 100))
                local tempo = clock.get_tempo()
                local beat_len
                if event.is_grace then
                  beat_len = params:get("grace_len_beats") or 0.0625
                else
                  local dur = event.duration or 0
                  dur = dur - (self.carry_beat_adjustment or 0)
                  if dur < 0 then dur = 0 end
                  beat_len = dur
                end
                local duration_sec = (beat_len > 0) and (beat_len * 60 / tempo) or 0.05
                engine.mx_note_on(note_num, amp, duration_sec)
                table.insert(self.active_notes, note_num)
              end
            else
              engine.hz(freq)
            end
          elseif self.output == 4 then
            crow.output[1].volts = (note_num - 60) / 12
            crow.output[2].execute()
          elseif self.output == 5 then
            crow.ii.jf.play_note((note_num - 60) / 12, 5)
          end

          -- MIDI out
          if (self.output == 2 or self.output == 3) then
            self.midi_out_device:note_on(note_num, velocity, self:get_param("midi_out_channel"))
            table.insert(self.active_notes, note_num)
          end
        end


        -- move through the phrase
        self.phrase_note = self.phrase_note + 1
        if self.phrase_note > #phrases[self.phrase] then
          self.phrase_note = 1

          local rnd = math.random(10)
          local prob = params:get("repeat_probability")
          if rnd > prob and self.phrase < self.max_phrase then
            self.phrase = self.phrase + 1
            if self.phrase > #phrases then
              self.phrase = #phrases

              -- if all players are at the end we can stop
              if self.all_at_end then
                self.playing = false
                self:all_notes_off()
              end
            end
          end
        end

        -- compute wait time (in 16th notes)
        local beat_len
        if event.is_grace then
          beat_len = params:get("grace_len_beats") or 0.125
          self.carry_beat_adjustment = beat_len
        else
          local dur = event.duration or 0
          dur = dur - (self.carry_beat_adjustment or 0)
          if dur < 0 then dur = 0 end
          beat_len = dur
          self.carry_beat_adjustment = 0
        end

        local steps = math.floor((beat_len / 0.25) + 0.0001)
        waitCount = math.max(0, steps - 1)
      else
        waitCount = waitCount - 1
      end
    end

    clock.sync(0.25)
  end
end

return Seafarer
