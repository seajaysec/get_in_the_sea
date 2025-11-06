-- Ensemble manager for Get in the Sea

local Pulse = include("lib/pulse")

local Ensemble = {}
Ensemble.__index = Ensemble

local MODE_OPTIONS = { "autonomous", "semi-autonomous", "manual" }

function Ensemble:new(seafarers)
  local o = {
    players = seafarers or {},
    mode_index = 1, -- 1=autonomous, 2=semi-autonomous, 3=manual
    tempo_bpm = clock.get_tempo() or 120,
    pulse_enabled = false,
    pulse_volume = 0.8,
    median_pattern = 1,
    convergence_mode = false,
    elapsed_seconds = 0,
    user_pattern_target = 1,
    min_active_players = 3,
    rest_probability_pct = 15,
    octave_displacement_pct = 30,
    auto_catchup_enabled = true,
    selected_player = 1,
    pulse = nil,
  }

  setmetatable(o, Ensemble)

  o.pulse = Pulse:new()
  return o
end

function Ensemble:setup_params()
  params:add_separator("ENSEMBLE")

  params:add_option("ensemble_mode", "mode", MODE_OPTIONS, self.mode_index)
  params:set_action("ensemble_mode", function(i)
    self.mode_index = i
  end)

  params:add{ type = "number", id = "ensemble_tempo", name = "tempo (bpm)", min = 69, max = 132, default = math.floor(self.tempo_bpm) }
  params:set_action("ensemble_tempo", function(v)
    self.tempo_bpm = v
    clock.tempo(v)
  end)

  params:add{ type = "option", id = "pulse_enabled", name = "pulse enabled", options = { "off", "on" }, default = self.pulse_enabled and 2 or 1 }
  params:set_action("pulse_enabled", function(i)
    self.pulse_enabled = (i == 2)
    if self.pulse_enabled then
      self.pulse:start(self)
    else
      self.pulse:stop()
    end
  end)

  params:add{ type = "control", id = "pulse_vol", name = "pulse volume", controlspec = controlspec.new(0, 1, 'lin', 0, self.pulse_volume, '') }
  params:set_action("pulse_vol", function(v)
    self.pulse_volume = v
    self.pulse:set_volume(v)
  end)

  if mxsamples_instruments ~= nil and #mxsamples_instruments > 0 then
    params:add{ type = "option", id = "pulse_mx_inst", name = "pulse mxsamples inst", options = mxsamples_instruments, default = 1 }
    params:set_action("pulse_mx_inst", function(idx)
      self.pulse:set_mx_instrument(mxsamples_instruments[idx])
    end)
  end

  params:add{ type = "number", id = "min_active_players", name = "min active players", min = 1, max = 8, default = self.min_active_players }
  params:set_action("min_active_players", function(v) self.min_active_players = v end)

  params:add{ type = "number", id = "rest_probability_pct", name = "rest probability %", min = 0, max = 100, default = self.rest_probability_pct }
  params:set_action("rest_probability_pct", function(v) self.rest_probability_pct = v end)

  params:add{ type = "number", id = "octave_disp_pct", name = "octave displacement %", min = 0, max = 100, default = self.octave_displacement_pct }
  params:set_action("octave_disp_pct", function(v) self.octave_displacement_pct = v end)

  params:add{ type = "option", id = "auto_catchup_enabled", name = "auto catch-up", options = { "off", "on" }, default = self.auto_catchup_enabled and 2 or 1 }
  params:set_action("auto_catchup_enabled", function(i) self.auto_catchup_enabled = (i == 2) end)

  params:add{ type = "number", id = "selected_player", name = "selected player (manual)", min = 1, max = 8, default = 1 }
  params:set_action("selected_player", function(v) self.selected_player = v end)

  params:add_trigger("semi_next_pattern", "Semi-auto: next pattern")
  params:set_action("semi_next_pattern", function()
    if self:get_mode() == "semi-autonomous" then
      self:advance_all_target()
    end
  end)
end

function Ensemble:get_mode()
  return MODE_OPTIONS[self.mode_index] or MODE_OPTIONS[1]
end

function Ensemble:is_playing_any()
  for _, s in ipairs(self.players) do if s.playing then return true end end
  return false
end

function Ensemble:start_all()
  for _, s in ipairs(self.players) do s.playing = true end
  if self.pulse_enabled then self.pulse:start(self) end
end

function Ensemble:stop_all()
  for _, s in ipairs(self.players) do s.playing = false; s:all_notes_off() end
  if self.pulse_enabled then self.pulse:stop() end
end

function Ensemble:reset_all()
  for _, s in ipairs(self.players) do s:reset() end
  self.user_pattern_target = 1
end

function Ensemble:advance_all_target()
  self.user_pattern_target = math.min(53, self.user_pattern_target + 1)
end

local function median(nums)
  local t = { table.unpack(nums) }
  table.sort(t)
  local n = #t
  if n == 0 then return 1 end
  if n % 2 == 1 then return t[(n + 1) / 2] end
  return math.floor((t[n/2] + t[n/2 + 1]) / 2)
end

function Ensemble:update_median()
  local ps = {}
  for _, s in ipairs(self.players) do table.insert(ps, s.phrase or 1) end
  self.median_pattern = median(ps)
  -- set allowed ranges per player based on median
  for _, s in ipairs(self.players) do
    s.allowed_min_phrase = math.max(1, self.median_pattern - 2)
    s.allowed_max_phrase = math.min(#phrases, self.median_pattern + 3)
  end
end

return Ensemble


