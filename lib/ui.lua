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
    -- Performance page: concise, human-centric dashboard
    draw_page_title("Performance")

    local median = ensemble.median_pattern or 1
    local min_p = 999
    local max_p = 1
    local active = 0
    local counts = {}
    local max_bucket = { pattern = median, count = 0 }
    for i = 1, #seafarers do
      local s = seafarers[i]
      local p = s.phrase or 1
      if p < min_p then min_p = p end
      if p > max_p then max_p = p end
      if s.playing and not s.is_resting then active = active + 1 end
      counts[p] = (counts[p] or 0) + 1
      if counts[p] > max_bucket.count then
        max_bucket.pattern = p
        max_bucket.count = counts[p]
      end
    end
    local spread = math.max(0, max_p - min_p)

    local function harmonic_zone(n)
      if n >= 1 and n <= 13 then return "C Major"
      elseif n >= 14 and n <= 30 then return "F# Tension"
      elseif n >= 31 and n <= 34 then return "F Natural (Relief)"
      elseif n == 35 then return "B♭ Transformation"
      elseif n >= 36 and n <= 48 then return "B♭ World"
      else return "Resolution" end
    end

    local elapsed = 0
    if ensemble.get_elapsed_seconds ~= nil then elapsed = ensemble:get_elapsed_seconds() end
    local h = math.floor(elapsed / 3600)
    local m = math.floor((elapsed % 3600) / 60)
    local ssec = elapsed % 60
    local time_str = string.format("%02d:%02d:%02d", h, m, ssec)

    local tempo = math.floor(ensemble.tempo_bpm or clock.get_tempo() or 120)
    local pulse = (ensemble.pulse_enabled and "on" or "off")

    screen.move(0, 26)
    screen.level(12)
    screen.text(string.format("Where P%d  Spread %d", median, spread))

    screen.move(0, 38)
    screen.text(string.format("Active %d/8  Tempo %d  Pulse %s", active, tempo, pulse))

    screen.move(0, 50)
    screen.text(string.format("Zone %s", harmonic_zone(median)))

    screen.move(0, 62)
    screen.level(10)
    local conv_pct = math.floor(((max_bucket.count or 0) / math.max(1, #seafarers)) * 100)
    screen.text(string.format("Converge %d on P%d  %d%%   %s", max_bucket.count or 0, max_bucket.pattern or median, conv_pct, time_str))

    screen.update()
  end

  local function draw_seafarers_page()
    draw_page_title("Seafarers")
    -- players grid
    screen.font_size(10)
    local x = 0
    local y = 30
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
        screen.level(10)
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
    local sel = (ensemble and ensemble.selected_player) or 1
    -- Editable rows begin after header
    local rows = {}
    -- Header: current engine (non-interactive)
    screen.move(0, 20)
    screen.level(10)
    screen.text("Current: " .. tostring(ae))
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


