-- UI rendering for Get in the Sea

local UI = {}

function UI.draw(seafarers, any_playing, ensemble, ui_page_index, ui_element_index, ui_pages)
  screen.clear()
  screen.font_face(12)
  screen.font_size(12)
  screen.level(15)

  -- title removed to declutter

  -- No menubar; pages are implied and full-screen

  -- content area
  local function draw_page_title(title)
    screen.font_size(10)
    screen.move(0, 12)
    screen.level(12)
    screen.text(title)
  end

  local function draw_list(items, selected_index, start_y, line_h, capacity)
    local n = #items
    if n == 0 then return end
    local cap = math.max(1, capacity or 4)
    local start_idx = 1
    if n > cap then
      start_idx = math.min(math.max(1, selected_index - (cap - 1)), math.max(1, n - (cap - 1)))
    end
    local y = start_y
    for i = start_idx, math.min(n, start_idx + cap - 1) do
      local it = items[i]
      screen.move(0, y)
      screen.level(i == selected_index and 15 or 10)
      local txt = it
      if i == selected_index then txt = "[" .. txt .. "]" end
      screen.text(txt)
      y = y + line_h
    end
  end

  local function draw_info_status()
    if ensemble == nil then return end
    -- Info: streamlined, human-centered status
    draw_page_title("Info")

    local median = ensemble.median_pattern or 1
    local min_p = 999
    local max_p = 1
    local active = 0
    local resting = 0
    local ready = 0
    local hist = {}
    for i = 1, #seafarers do
      local s = seafarers[i]
      local p = s.phrase or 1
      if p < min_p then min_p = p end
      if p > max_p then max_p = p end
      if s.playing and not s.is_resting then active = active + 1 end
      if s.is_resting then resting = resting + 1 end
      if s.ready_indicator then ready = ready + 1 end
      hist[p] = (hist[p] or 0) + 1
    end
    local spread = math.max(0, max_p - min_p)
    local max_align = 0
    for _, c in pairs(hist) do if c > max_align then max_align = c end end

    local elapsed = 0
    if ensemble.get_elapsed_seconds ~= nil then elapsed = ensemble:get_elapsed_seconds() end
    local h = math.floor(elapsed / 3600)
    local m = math.floor((elapsed % 3600) / 60)
    local ssec = elapsed % 60
    local time_str = string.format("%02d:%02d:%02d", h, m, ssec)
    local tempo = math.floor(ensemble.tempo_bpm or clock.get_tempo() or 120)
    local pulse = ensemble.pulse_enabled and "on" or "off"

    local zone = "C Major"
    if median >= 14 and median <= 30 then zone = "F# tension"
    elseif median >= 31 and median <= 34 then zone = "F natural return"
    elseif median >= 35 and median <= 48 then zone = "Bb transform"
    elseif median >= 49 then zone = "Arrival"
    end

    local spread_txt = (spread <= 2) and "tight" or ((spread <= 4) and "healthy" or "wide")

    screen.move(0, 26)
    screen.level(12)
    screen.text(string.format("Time %s  %dbpm  Pulse %s", time_str, tempo, pulse))

    screen.move(0, 38)
    screen.text(string.format("Zone: %s", zone))

    screen.move(0, 50)
    screen.text(string.format("Active %d/8  Spread %s", active, spread_txt))

    screen.move(0, 62)
    screen.level(10)
    local align_txt = (max_align >= 3) and ("Align " .. tostring(max_align)) or "Align none"
    local ready_txt = (ready > 0) and ("  Ready " .. tostring(ready)) or ""
    screen.text(align_txt .. ready_txt)

    screen.update()
  end

  local function draw_seafarers_page()
    draw_page_title("Seafarers")
    -- mode-aware subheader
    if ensemble ~= nil then
      local mode = ensemble:get_mode()
      screen.font_size(10)
      screen.move(0, 20)
      local header_level = 10
      local blink_on = ((util.time() % 1) < 0.5)
      if mode == "semi-autonomous" then
        local target = ensemble.user_pattern_target or 1
        local ready = 0
        local max_cd = 0
        for i = 1, #seafarers do
          if seafarers[i].ready_indicator then ready = ready + 1 end
          local cd = seafarers[i].advance_cooldown_loops_remaining or 0
          if cd > max_cd then max_cd = cd end
        end
        local good_advise = (ready >= 6) and (max_cd <= 1)
        if good_advise and blink_on then header_level = 15 end
        screen.level(header_level)
        screen.text(string.format("Semi-auto  Target N: %d  Ready %d/8", target, ready))
        if good_advise then
          screen.move(0, 26)
          screen.level(blink_on and 15 or 10)
          screen.text("Advise +1")
        end
      elseif mode == "manual" then
        local min_p = 999
        local max_p = 1
        local hist = {}
        for i = 1, #seafarers do
          local p = seafarers[i].phrase or 1
          if p < min_p then min_p = p end
          if p > max_p then max_p = p end
          hist[p] = (hist[p] or 0) + 1
        end
        local spread = math.max(0, max_p - min_p)
        local spread_txt = (spread <= 2) and "tight" or ((spread <= 4) and "healthy" or "wide")
        local align = 0
        for _, c in pairs(hist) do if c > align then align = c end end
        local median = ensemble.median_pattern or 1
        if align >= 3 and blink_on then
          header_level = 15
        elseif spread > 4 then
          header_level = 12
        end
        screen.level(header_level)
        screen.text(string.format("Manual  Median %d  Spread %s  Align %d", median, spread_txt, align))
      else
        local median = ensemble.median_pattern or 1
        screen.text(string.format("Autonomous  Median %d", median))
      end
    end

    -- players grid
    screen.font_size(10)
    local x = 0
    local y = 30
    -- Precompute cluster pattern for manual highlight
    local cluster_pattern = nil
    local manual_wide = false
    local manual_median = nil
    if ensemble ~= nil and ensemble:get_mode() == "manual" then
      local hist2 = {}
      local best_p = nil
      local best_c = 0
      local min_p2 = 999
      local max_p2 = 1
      for i = 1, #seafarers do
        local p = seafarers[i].phrase or 1
        hist2[p] = (hist2[p] or 0) + 1
        if hist2[p] > best_c then best_c = hist2[p]; best_p = p end
        if p < min_p2 then min_p2 = p end
        if p > max_p2 then max_p2 = p end
      end
      if best_c >= 3 then cluster_pattern = best_p end
      manual_median = ensemble.median_pattern or 1
      manual_wide = (math.max(0, max_p2 - min_p2) > 4)
    end
    for s = 1, #seafarers do
      local is_selected = (ensemble ~= nil and ensemble.selected_player == s)
      local num = string.format("%02d", seafarers[s].phrase)
      if seafarers[s].ready_indicator then num = num .. "*" end
      -- show cooldown ^N when active
      local cd = seafarers[s].advance_cooldown_loops_remaining or 0
      if cd ~= nil and cd > 0 then
        num = num .. "^" .. tostring(cd)
      end
      if is_selected then
        num = "[" .. num .. "]"
        screen.level(15)
      else
        local level = 10
        if cluster_pattern ~= nil and (seafarers[s].phrase == cluster_pattern) then
          level = 12
        end
        if manual_wide and manual_median ~= nil then
          local p = seafarers[s].phrase or 1
          if p <= (manual_median - 2) then
            level = 13 -- brighten laggards: candidates to advance
          elseif p >= (manual_median + 3) then
            level = 8  -- dim leaders: candidates to hold
          end
        end
        screen.level(level)
      end
      screen.move(x, y)
      screen.text(num)

      x = x + 30
      if s == 4 then
        y = 54
        x = 0
      end
    end
    screen.level(15)
    if ensemble and ensemble.ending then
      screen.move(0, 62)
      screen.level(15)
      screen.text("Ending...")
    end
  end

  local function draw_ensemble_page()
    if ensemble == nil then return end
    draw_page_title("Ensemble")
    local items = {
      { label = "Mode", value = (ensemble:get_mode() or "autonomous") },
      { label = "Pulse", value = (ensemble.pulse_enabled and "on" or "off") },
      { label = "Tempo", value = string.format("%dbpm", math.floor(ensemble.tempo_bpm or clock.get_tempo() or 120)) },
    }
    if ensemble:get_mode() == "semi-autonomous" then
      table.insert(items, { label = "Target N", value = tostring(ensemble.user_pattern_target or 1) })
      local ready = 0
      for i = 1, #seafarers do if seafarers[i].ready_indicator then ready = ready + 1 end end
      table.insert(items, { label = "Ready", value = string.format("%d/8", ready) })
    end
    screen.font_size(10)
    local rows = {}
    for _, it in ipairs(items) do table.insert(rows, it.label .. ": " .. it.value) end
    draw_list(rows, ui_element_index, 26, 12, 4)
  end

  local function draw_human_page()
    draw_page_title("Humanize")
    screen.font_size(10)
    local items = {
      { label = "Timing ms", value = params:get("human_timing_ms") },
      { label = "Vol drift %", value = params:get("human_volume_pct") },
      { label = "Adv delay ms", value = params:get("human_adv_ms") },
      { label = "Skip %", value = params:get("human_skip_pct") },
    }
    local rows = {}
    for _, it in ipairs(items) do table.insert(rows, string.format("%s: %s", it.label, tostring(it.value))) end
    draw_list(rows, ui_element_index, 26, 12, 4)
  end

  local function draw_engine_page()
    screen.font_size(10)
    local ae = engine.name or "?"
    draw_page_title("Engine")
    -- Subheader: current engine
    screen.move(0, 20)
    screen.level(10)
    screen.text("Current: " .. ae)
    local sel = (ensemble and ensemble.selected_player) or 1
    -- Editable rows begin after header
    local rows = {}
    local ael = string.lower(ae or "")
    if ael == "mxsamples" then
      if mxsamples_instruments ~= nil and #mxsamples_instruments > 0 then
        local idx = params:get(sel .. "_mxsamples_instrument") or 1
        local name = mxsamples_instruments[idx] or "?"
        table.insert(rows, { label = "S" .. sel .. " instrument", value = name })
      end
    elseif ael == "polyperc" then
      for _, id in ipairs({ "amp", "release", "cutoff", "gain", "pan" }) do
        table.insert(rows, { label = id, value = params:get(id) })
      end
    elseif ael == "passersby" then
      for _, p in ipairs({ { "pb_amp", "amp" }, { "pb_attack", "attack" }, { "pb_decay", "decay" }, { "pb_reverb_mix", "reverb" }, { "pb_timbre_all", "timbre" } }) do
        table.insert(rows, { label = p[2], value = params:get(p[1]) })
      end
    elseif ael == "odashodasho" then
      for _, id in ipairs({ "odash_attack", "odash_decay", "odash_index", "odash_index_scale", "odash_reverb_db" }) do
        table.insert(rows, { label = id:gsub("odash_", ""), value = params:get(id) })
      end
    else
      -- FM7 or unknown: no additional params
    end
    local text_rows = {}
    for _, it in ipairs(rows) do
      local val = (type(it.value) == "number") and util.round(it.value, 0.01) or tostring(it.value)
      table.insert(text_rows, string.format("%s: %s", it.label, val))
    end
    draw_list(text_rows, ui_element_index, 28, 12, 4)
  end

  local function draw_output_page()
    screen.font_size(10)
    draw_page_title("Output & MIDI")
    local sel = (ensemble and ensemble.selected_player) or 1
    -- Subheader with selected seafarer
    screen.move(0, 20)
    screen.level(10)
    screen.text("S" .. sel)
    local out_idx = params:get(sel .. "_output") or 1
    local out_name = (options and options.OUTPUT and options.OUTPUT[out_idx]) and options.OUTPUT[out_idx] or tostring(out_idx)
    local dev = params:get(sel .. "midi_out_device") or 1
    local dev_name = (midi and midi.vports and midi.vports[dev] and midi.vports[dev].name) or ("dev " .. dev)
    local ch = params:get(sel .. "_midi_out_channel") or 1
    local rows = {
      string.format("Output: %s", out_name),
      string.format("MIDI dev: %s", dev_name),
      string.format("MIDI ch: %s", tostring(ch)),
    }
    draw_list(rows, ui_element_index, 28, 12, 4)
  end

  local function draw_random_page()
    screen.font_size(10)
    draw_page_title("Randomize")
    local function onoff(id)
      local v = params:get(id) or 1
      return (v == 2) and "on" or "off"
    end
    local rows = {
      string.format("Instruments: %s", onoff("rand_instruments")),
      string.format("Engine params: %s", onoff("rand_engine_params")),
      string.format("Humanization: %s", onoff("rand_humanization")),
      string.format("Octaves: %s", onoff("rand_octaves")),
    }
    draw_list(rows, ui_element_index, 26, 12, 4)
  end

  -- dispatch per page
  if ui_pages and ui_pages[ui_page_index] then
    local pid = ui_pages[ui_page_index].id
    if pid == "seafarers" then
      draw_seafarers_page()
    elseif pid == "ensemble" then
      draw_ensemble_page()
    elseif pid == "info" then
      draw_info_status()
    elseif pid == "human" then
      draw_human_page()
    elseif pid == "engine" then
      draw_engine_page()
    elseif pid == "output" then
      draw_output_page()
    elseif pid == "random" then
      draw_random_page()
    end
  end

  screen.update()
end

return UI


