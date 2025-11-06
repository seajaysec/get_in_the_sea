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

local function total_pattern_beats(idx)
  local seq = phrases[idx] or {}
  local sum = 0
  for _, ev in ipairs(seq) do
    local d = ev.duration or 0
    sum = sum + d
  end
  return sum
end

local AVG_PATTERN_BEATS = (function()
  local s = 0
  for i = 1, #phrases do s = s + total_pattern_beats(i) end
  if #phrases == 0 then return 1 end
  return s / #phrases
end)()

local function clamp(x, lo, hi)
  if x < lo then return lo end
  if x > hi then return hi end
  return x
end

local function gaussian_ms(std_ms)
  -- Box-Muller transform for mean 0, std deviation std_ms
  local u1 = math.max(1e-9, math.random())
  local u2 = math.random()
  local z0 = math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
  return z0 * (std_ms or 0)
end

function Seafarer:new(id)
  local o = {
    id = id,
    playing = false,

    phrase = 1,
    phrase_note = 1,
    all_at_end = false,
    max_phrase = 3,
    allowed_min_phrase = 1,
    allowed_max_phrase = #phrases,

    output = 0,
    midi_out_device = midi.connect(1),
    midi_out_channel = 0,
    mx_instrument = "",

    active_notes = {},
    carry_beat_adjustment = 0,
    octave = 0,

    -- Agent state
    repetitions_remaining = 0,
    is_resting = false,
    rest_patterns_remaining = 0,
    displaced_octave = 0,
    time_in_phrase_sec = 0,
    ready_indicator = false,
    auto_advance_warning = false,
    ensembleRef = nil,
    velocity_scale = 1.0,
    human_volume_factor = 1.0,
  }

  setmetatable(o, Seafarer)

  clock.run(Seafarer.step, o)

  return o
end

function Seafarer:set_ensemble(ensemble)
  self.ensembleRef = ensemble
end

function Seafarer:add_output_param()
  params:add { type = "option", id = self.id .. "_output", name = "S" .. self.id .. " output",
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
end

function Seafarer:add_instrument_param()
  if mxsamples ~= nil then
    params:add { type = "option", id = self.id .. "_mxsamples_instrument", name = "S" .. self.id, options = mxsamples_instruments,
      action = function(value)
        self:all_notes_off()
        self.mx_instrument = mxsamples_instruments[value]
      end
    }
  end
end

function Seafarer:add_octave_param()
  params:add { type = "number", id = self.id .. "_octave", name = "S" .. self.id .. " octave",
    min = -3, max = 3, default = 0,
    action = function(value)
      self.octave = value
    end
  }
end

function Seafarer:add_midi_device_param()
  params:add { type = "number", id = self.id .. "midi_out_device", name = "S" .. self.id .. " midi device",
    min = 1, max = 4, default = 1, action = function(value)
    self:all_notes_off()
    self.midi_out_device = midi.connect(value)
  end
  }
end

function Seafarer:add_midi_channel_param()
  params:add { type = "number", id = self.id .. "_midi_out_channel", name = "S" .. self.id .. " midi channel",
    min = 1, max = 16, default = 1,
    action = function(value)
      self:all_notes_off()
      self.midi_out_channel = value
    end }
end

-- (no timber params)

function Seafarer:get_param(idx)
  return params:get(self.id .. "_" .. idx)
end

function Seafarer:reset()
  self.phrase = 1
  self.phrase_note = 1
  self:all_notes_off()
  self.repetitions_remaining = 0
  self.is_resting = false
  self.rest_patterns_remaining = 0
  self.displaced_octave = 0
  self.time_in_phrase_sec = 0
  self.ready_indicator = false
end

function Seafarer:all_notes_off()
  for _, a in pairs(self.active_notes) do
    if self.output == 2 or self.output == 3 then
      self.midi_out_device:note_off(a, nil, self.midi_out_channel)
    end

    if (self.output == 1 or self.output == 3) and engine.name == "MxSamples" then
      skeys:off({ name = self.mx_instrument, midi = a })
    elseif (self.output == 1 or self.output == 3) and string.lower(engine.name) == "fm7" then
      engine.stop(a)
    elseif (self.output == 1 or self.output == 3) and string.lower(engine.name) == "passersby" then
      engine.noteOff(a)
    end
  end
  self.active_notes = {}
end

function Seafarer:step()
  clock.sync(1)
  local waitCount = 0
  local BASE_STEP = 0.0625 -- 1/64 note resolution

  while true do
    if self.playing then
      if waitCount <= 0 then
        self:all_notes_off()

        -- enforce separation relative to ensemble median
        if self.ensembleRef ~= nil then
          local med = self.ensembleRef.median_pattern or 1
          if self.phrase > (self.allowed_max_phrase or (med + 3)) then
            -- too far ahead: wait/rest on current phrase without advancing
            -- simply idle for a 16th note
            waitCount = 1
            clock.sync(BASE_STEP)
            goto continue
          elseif self.phrase < (self.allowed_min_phrase or math.max(1, med - 2)) then
            -- too far behind: jump forward toward median
            self.phrase = math.max(1, med - 1)
            self.phrase_note = 1
            self.repetitions_remaining = 0
          end
        end

        -- initialize repetitions upon entering/starting phrase
        if self.repetitions_remaining <= 0 and not self.is_resting then
          -- octave displacement on phrase entry
          local disp_pct = params:get("octave_disp_pct") or 30
          if math.random(100) <= disp_pct then
            -- weighted up:0.7, down:0.3
            local dir = (math.random() < 0.7) and 1 or -1
            self.displaced_octave = dir -- 1 or -1
          else
            self.displaced_octave = 0
          end

          -- calculate repetitions from tempo and phrase length
          local tempo = params:get("ensemble_tempo") or clock.get_tempo()
          local pattern_beats = total_pattern_beats(self.phrase)
          local avg_beats = AVG_PATTERN_BEATS
          local base_duration = util.linlin(69, 132, 60, 45, tempo) -- slower -> longer base
          local normalized = base_duration * (avg_beats / math.max(0.25, pattern_beats))
          local min_s = math.max(30, normalized * 0.75)
          local max_s = normalized * 1.5
          local one_rep_s = (pattern_beats * 60) / math.max(1, tempo)
          local min_reps = math.max(1, math.floor(min_s / math.max(0.25, one_rep_s)))
          local max_reps = math.max(min_reps, math.ceil(max_s / math.max(0.25, one_rep_s)))

          -- bias toward middle
          local mid = math.floor((min_reps + max_reps) / 2)
          local r = math.random(min_reps, max_reps)
          self.repetitions_remaining = util.round(util.linlin(min_reps, max_reps, mid, r, r), 1)
          if self.repetitions_remaining < 1 then self.repetitions_remaining = 1 end
          self.ready_indicator = false
          self.time_in_phrase_sec = 0
        end

        -- handle resting between phrases
        if self.is_resting then
          if self.rest_patterns_remaining > 0 then
            -- idle for one phrase length equivalent time
            local tempo = params:get("ensemble_tempo") or clock.get_tempo()
            local pattern_beats = total_pattern_beats(self.phrase)
            local rest_steps = math.max(1,
              math.floor(((pattern_beats * 60) / tempo) / (BASE_STEP * clock.get_beat_sec())))
            waitCount = rest_steps
            self.rest_patterns_remaining = self.rest_patterns_remaining - 1
            goto continue
          else
            self.is_resting = false
          end
        end

        -- get current event in the phrase
        local event = phrases[self.phrase][self.phrase_note]
        if event == nil then event = { duration = 0 } end

        -- play the event if it's a note
        if event.midi ~= nil then
          local note_num = event.midi + (((self.octave or 0) + (self.displaced_octave or 0)) * 12)
          local base_vel = event.velocity or 100
          -- humanized volume random walk
          local hvp = (self.ensembleRef and self.ensembleRef.human_volume_pct) or 5
          local step = (hvp / 100) * 0.5
          local delta = (math.random() * 2 - 1) * step
          self.human_volume_factor = clamp((self.human_volume_factor or 1.0) + delta, 1 - (hvp / 100), 1 + (hvp / 100))
          local velocity = clamp(math.floor(base_vel * self.velocity_scale * self.human_volume_factor), 1, 127)
          local freq = MusicUtil.note_num_to_freq(note_num)

          -- optional human timing offset (only positive delay applied)
          local std_ms = (self.ensembleRef and self.ensembleRef.human_timing_ms) or 0
          local offs_ms = math.max(0, gaussian_ms(std_ms))
          local function trigger_note()
            if self.output == 1 or self.output == 3 then
              -- audio engine
              local ae = engine.name
              if ae == "MxSamples" then
                skeys:on({ name = self.mx_instrument, midi = note_num, velocity = velocity })
                table.insert(self.active_notes, note_num)
              else
                local ae_lower = string.lower(ae or "")
                if ae_lower == "polyperc" then
                  engine.hz(freq)
                  table.insert(self.active_notes, note_num)
                elseif ae_lower == "fm7" then
                  engine.start(note_num, freq)
                  table.insert(self.active_notes, note_num)
                elseif ae_lower == "passersby" then
                  engine.noteOn(note_num, freq, velocity)
                  table.insert(self.active_notes, note_num)
                elseif ae_lower == "odashodasho" then
                  local amp = math.min(1.0, math.max(0.1, (velocity or 100) / 127))
                  local pan = params:get("odash_pan") or 0
                  local attack = params:get("odash_attack") or 0.01
                  local decay = params:get("odash_decay") or 0.5
                  local cAtk = params:get("odash_attack_curve") or 4
                  local cRel = params:get("odash_decay_curve") or -4
                  local mRatio = params:get("odash_mod_ratio") or 1
                  local cRatio = params:get("odash_car_ratio") or 1
                  local index = params:get("odash_index") or 1.5
                  local iScale = params:get("odash_index_scale") or 4
                  local fxsend = params:get("odash_reverb_db") or -18
                  local eqFreq = params:get("odash_eq_freq") or 1200
                  local eqDB = params:get("odash_eq_db") or 0
                  local lpf = params:get("odash_lpf") or 20000
                  local noise = util.dbamp(params:get("odash_noise_db") or -96)
                  local natk = params:get("odash_noise_attack") or 0.01
                  local nrel = params:get("odash_noise_decay") or 0.3
                  local voice = "sea" .. tostring(self.id)
                  local record = 0
                  local path = ""
                  engine.fm1(note_num, amp, pan, attack, decay, cAtk, cRel, mRatio, cRatio, index, iScale, fxsend, eqFreq,
                    eqDB, lpf, noise, natk, nrel, voice, record, path)
                  table.insert(self.active_notes, note_num)
                else
                  -- Unknown engine; skip audio trigger to avoid errors
                end
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

          if offs_ms > 0 then
            clock.run(function()
              clock.sleep(offs_ms / 1000)
              trigger_note()
            end)
          else
            trigger_note()
          end
        end


        -- move through the phrase
        self.phrase_note = self.phrase_note + 1
        if self.phrase_note > #phrases[self.phrase] then
          self.phrase_note = 1
          self.repetitions_remaining = math.max(0, (self.repetitions_remaining or 1) - 1)

          -- ready indicator after minimum time (approx 45s)
          if self.time_in_phrase_sec >= 45 and not self.ready_indicator then
            self.ready_indicator = true
          end

          -- semi-autonomous: wait for user advance
          if self.ensembleRef ~= nil and self.ensembleRef:get_mode() == "semi-autonomous" then
            if self.ensembleRef.user_pattern_target ~= nil and self.ensembleRef.user_pattern_target > self.phrase then
              self.phrase = math.min(#phrases, self.ensembleRef.user_pattern_target)
              self.repetitions_remaining = 0
              self.ready_indicator = false
            end
          else
            -- autonomous advancement; manual holds
            local mode = (self.ensembleRef and self.ensembleRef:get_mode()) or "autonomous"
            if mode == "manual" then
              -- do not auto-advance; optional catch-up if too far behind
              if self.ensembleRef and self.ensembleRef.auto_catchup_enabled then
                local med = self.ensembleRef.median_pattern or 1
                if math.abs(self.phrase - med) > 3 then
                  self.phrase = math.max(1, med - 1)
                  self.phrase_note = 1
                end
              end
            else
              if self.repetitions_remaining <= 0 and self.phrase < #phrases then
                -- rest behavior at transitions
                local active_players = 0
                if self.ensembleRef ~= nil then
                  for _, s in ipairs(self.ensembleRef.players) do
                    if s.playing and not s.is_resting then
                      active_players =
                          active_players + 1
                    end
                  end
                end
                local min_active = (self.ensembleRef and self.ensembleRef.min_active_players) or 3
                local rest_pct = (self.ensembleRef and self.ensembleRef.rest_probability_pct) or 15
                local should_rest = (math.random(100) <= rest_pct) and (active_players > min_active)

                if should_rest then
                  self.is_resting = true
                  self.rest_patterns_remaining = math.random(1, 3)
                end

                -- advance one pattern respecting allowed max
                if self.phrase + 1 <= (self.allowed_max_phrase or #phrases) then
                  self.phrase = self.phrase + 1
                  -- occasional skip
                  local skip_pct = (self.ensembleRef and self.ensembleRef.human_skip_pct) or 0
                  if math.random(100) <= skip_pct then
                    self.phrase = math.min(#phrases, self.phrase + 1)
                  end
                end

                -- pattern 53 handling
                if self.phrase >= #phrases then
                  self.phrase = #phrases
                end
              end
            end
          end
        end

        -- compute wait time (in 16th notes)
        local beat_len
        if event.is_grace then
          local grace_map = { 0.0625, 0.125, 0.25 }
          local idx = params:get("grace_len_beats") or 2
          beat_len = grace_map[idx] or 0.125
          self.carry_beat_adjustment = beat_len
        else
          local dur = event.duration or 0
          dur = dur - (self.carry_beat_adjustment or 0)
          if dur < 0 then dur = 0 end
          beat_len = dur
          self.carry_beat_adjustment = 0
        end

        local steps = math.floor((beat_len / BASE_STEP) + 0.0001)
        waitCount = math.max(0, steps - 1)
        -- add human advance delay at phrase boundary (in ms)
        if self.phrase_note == 1 then
          local adv_ms = (self.ensembleRef and self.ensembleRef.human_adv_delay_ms) or 0
          if adv_ms > 0 then
            local beat_sec = clock.get_beat_sec()
            local beats = (adv_ms / 1000) / math.max(1e-6, beat_sec)
            local add_steps = math.max(0, math.floor((beats / BASE_STEP) + 0.5))
            waitCount = waitCount + add_steps
          end
        end
        self.time_in_phrase_sec = self.time_in_phrase_sec + (beat_len * 60) / math.max(1, clock.get_tempo())
      else
        waitCount = waitCount - 1
      end
    end

    clock.sync(BASE_STEP)
    ::continue::
  end
end

return Seafarer
