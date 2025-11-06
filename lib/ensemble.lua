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
    -- Runtime tracking
    is_running = false,
    run_start_time = nil,
    run_elapsed_sec = 0,
    user_pattern_target = 1,
    min_active_players = 3,
    rest_probability_pct = 15,
    octave_displacement_pct = 30,
    auto_catchup_enabled = true,
    selected_player = 1,
    pulse = nil,
    -- Humanization
    human_timing_ms = 30,
    human_volume_pct = 5,
    human_adv_delay_ms = 100,
    human_skip_pct = 2,
    -- Ending protocol
    ending = false,
    ending_cycles = 0,
    ending_runner = nil,
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
    if clock.set_tempo ~= nil then
      clock.set_tempo(v)
    end
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

  -- Humanization
  params:add_separator("HUMANIZATION")
  params:add{ type = "number", id = "human_timing_ms", name = "timing offset (ms)", min = 0, max = 30, default = self.human_timing_ms }
  params:set_action("human_timing_ms", function(v) self.human_timing_ms = v end)

  params:add{ type = "number", id = "human_volume_pct", name = "volume drift ±%", min = 0, max = 10, default = self.human_volume_pct }
  params:set_action("human_volume_pct", function(v) self.human_volume_pct = v end)

  params:add{ type = "number", id = "human_adv_ms", name = "advance delay (ms)", min = 0, max = 500, default = self.human_adv_delay_ms }
  params:set_action("human_adv_ms", function(v) self.human_adv_delay_ms = v end)

  params:add{ type = "number", id = "human_skip_pct", name = "skip pattern %", min = 0, max = 5, default = self.human_skip_pct }
  params:set_action("human_skip_pct", function(v) self.human_skip_pct = v end)

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
  if not self.is_running then
    self.is_running = true
    self.run_start_time = util.time()
  end
  if self.pulse_enabled then self.pulse:start(self) end
end

function Ensemble:stop_all()
  for _, s in ipairs(self.players) do s.playing = false; s:all_notes_off() end
  if self.is_running and self.run_start_time ~= nil then
    self.run_elapsed_sec = self.run_elapsed_sec + (util.time() - self.run_start_time)
    self.is_running = false
    self.run_start_time = nil
  end
  if self.pulse_enabled then self.pulse:stop() end
end

function Ensemble:reset_all()
  for _, s in ipairs(self.players) do s:reset() end
  self.user_pattern_target = 1
  -- reset timer; if currently running, restart count from now
  self.run_elapsed_sec = 0
  if self.is_running then
    self.run_start_time = util.time()
  else
    self.run_start_time = nil
  end
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

function Ensemble:get_elapsed_seconds()
  local acc = self.run_elapsed_sec or 0
  if self.is_running and self.run_start_time ~= nil then
    acc = acc + (util.time() - self.run_start_time)
  end
  if acc < 0 then acc = 0 end
  return math.floor(acc)
end

function Ensemble:maybe_start_ending(all_at_53)
  if self.ending or not all_at_53 then return end
  self.ending = true
  self.ending_cycles = math.random(3, 5)
  self.ending_runner = clock.run(function()
    local steps = 20
    for c = 1, self.ending_cycles do
      -- Up
      for i = 1, steps do
        local scale = util.linlin(1, steps, 0.7, 1.0, i)
        for _, s in ipairs(self.players) do s.velocity_scale = scale end
        clock.sleep((math.random(20, 30) / 2) / steps)
      end
      -- Down
      for i = 1, steps do
        local scale = util.linlin(1, steps, 1.0, 0.7, i)
        for _, s in ipairs(self.players) do s.velocity_scale = scale end
        clock.sleep((math.random(20, 30) / 2) / steps)
      end
    end
    -- Individual fade outs
    for _, s in ipairs(self.players) do
      local steps2 = 15
      local startv = s.velocity_scale or 1.0
      for i = 1, steps2 do
        s.velocity_scale = util.linlin(1, steps2, startv, 0, i)
        clock.sleep(2 / steps2)
      end
      s.playing = false
      s:all_notes_off()
    end
    -- Pulse fades last
    if self.pulse_enabled then self.pulse:begin_fade(3) end
  end)
end

return Ensemble


