-- UI rendering for Get in the Sea

local UI = {}

function UI.draw(seafarers, any_playing, ensemble, ui_page_index, ui_element_index, ui_pages)
  screen.clear()
  screen.font_face(12)
  screen.font_size(12)
  screen.level(15)

  -- title removed to declutter

  -- header: page bar
  screen.font_size(8)
  if ui_pages ~= nil and #ui_pages > 0 then
    local x_start = 0
    local y_start = 8
    local step_x = 42
    for i, p in ipairs(ui_pages) do
      local col = ((i - 1) % 3)
      local row = math.floor((i - 1) / 3)
      local x = x_start + (col * step_x)
      local y = y_start + (row * 9)
      screen.move(x, y)
      if i == ui_page_index then
        screen.level(15)
        screen.text("[" .. (p.label or p.id or "?") .. "]")
      else
        screen.level(10)
        screen.text(p.label or p.id or "?")
      end
    end
  end

  -- content area
  local function draw_info_status()
    if ensemble == nil then return end
    -- Info: Status page (existing metrics)
    screen.font_size(8)
    screen.move(0, 28)
    screen.level(15)
    screen.text("Info")

    local median = ensemble.median_pattern or 1
    local min_p = 999
    local max_p = 1
    local active = 0
    local resting = 0
    local ready = 0
    local at53 = 0
    for i = 1, #seafarers do
      local s = seafarers[i]
      local p = s.phrase or 1
      if p < min_p then min_p = p end
      if p > max_p then max_p = p end
      if s.playing and not s.is_resting then active = active + 1 end
      if s.is_resting then resting = resting + 1 end
      if s.ready_indicator then ready = ready + 1 end
      if p >= #phrases then at53 = at53 + 1 end
    end
    local spread = math.max(0, max_p - min_p)

    local elapsed = 0
    if ensemble.get_elapsed_seconds ~= nil then elapsed = ensemble:get_elapsed_seconds() end
    local h = math.floor(elapsed / 3600)
    local m = math.floor((elapsed % 3600) / 60)
    local ssec = elapsed % 60
    local time_str = string.format("%02d:%02d:%02d", h, m, ssec)
    local total = math.max(1, #phrases)
    local pct = math.floor((median / total) * 100)

    screen.move(0, 38)
    screen.level(12)
    screen.text(string.format("Time %s  Complete %d%%", time_str, pct))

    screen.move(0, 48)
    screen.text(string.format("Median %d  Spread %d", median, spread))

    screen.move(0, 58)
    screen.text(string.format("Active %d  Resting %d  Ready %d", active, resting, ready))

    screen.move(0, 68)
    screen.level(10)
    screen.text(string.format("At53 %d  Ending %s", at53, ensemble.ending and "on" or "off"))

    -- final row: positions
    screen.move(0, 78)
    local pos = {}
    for i = 1, #seafarers do pos[i] = string.format("%02d", seafarers[i].phrase or 1) end
    screen.text("Pos: " .. table.concat(pos, " "))

    screen.update()
  end

  local function draw_seafarers_page()
    -- players grid
    screen.font_size(10)
    local x = 0
    local y = 36
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
      screen.move(0, 64)
      screen.level(15)
      screen.text("Ending...")
    end
  end

  local function draw_ensemble_page()
    if ensemble == nil then return end
    local items = {
      { label = "Mode", value = (ensemble:get_mode() or "autonomous") },
      { label = "Pulse", value = (ensemble.pulse_enabled and "on" or "off") },
      { label = "Tempo", value = string.format("%dbpm", math.floor(ensemble.tempo_bpm or clock.get_tempo() or 120)) },
    }
    screen.font_size(8)
    for i, it in ipairs(items) do
      screen.move(0, 28 + i * 10)
      screen.level(i == ui_element_index and 15 or 10)
      local txt = it.label .. ": " .. it.value
      if i == ui_element_index then txt = "[" .. txt .. "]" end
      screen.text(txt)
    end
  end

  local function draw_human_page()
    screen.font_size(8)
    local items = {
      { label = "Timing ms", value = params:get("human_timing_ms") },
      { label = "Vol drift %", value = params:get("human_volume_pct") },
      { label = "Adv delay ms", value = params:get("human_adv_ms") },
      { label = "Skip %", value = params:get("human_skip_pct") },
    }
    for i, it in ipairs(items) do
      screen.move(0, 28 + i * 10)
      screen.level(i == ui_element_index and 15 or 10)
      local txt = string.format("%s: %s", it.label, tostring(it.value))
      if i == ui_element_index then txt = "[" .. txt .. "]" end
      screen.text(txt)
    end
  end

  local function draw_engine_page()
    screen.font_size(8)
    local ae = engine.name or "?"
    local sel = (ensemble and ensemble.selected_player) or 1
    local rows = {}
    table.insert(rows, { label = "Engine", value = ae })
    local ael = string.lower(ae or "")
    if ael == "mxsamples" then
      if mxsamples_instruments ~= nil and #mxsamples_instruments > 0 then
        local idx = params:get(sel .. "_mxsamples_instrument") or 1
        local name = mxsamples_instruments[idx] or "?"
        table.insert(rows, { label = "S" .. sel .. " instr", value = name })
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
    for i, it in ipairs(rows) do
      screen.move(0, 28 + i * 10)
      screen.level(i == ui_element_index and 15 or 10)
      local val = (type(it.value) == "number") and util.round(it.value, 0.01) or tostring(it.value)
      local txt = string.format("%s: %s", it.label, val)
      if i == ui_element_index then txt = "[" .. txt .. "]" end
      screen.text(txt)
    end
  end

  local function draw_output_page()
    screen.font_size(8)
    local sel = (ensemble and ensemble.selected_player) or 1
    local items = {
      { label = "S" .. sel .. " output", value = params:get(sel .. "_output") },
      { label = "S" .. sel .. " midi dev", value = params:get(sel .. "midi_out_device") },
      { label = "S" .. sel .. " midi ch", value = params:get(sel .. "_midi_out_channel") },
    }
    for i, it in ipairs(items) do
      screen.move(0, 28 + i * 10)
      screen.level(i == ui_element_index and 15 or 10)
      local txt = string.format("%s: %s", it.label, tostring(it.value))
      if i == ui_element_index then txt = "[" .. txt .. "]" end
      screen.text(txt)
    end
  end

  local function draw_random_page()
    screen.font_size(8)
    local function onoff(id)
      local v = params:get(id) or 1
      return (v == 2) and "on" or "off"
    end
    local items = {
      { label = "Instruments", value = onoff("rand_instruments") },
      { label = "Engine params", value = onoff("rand_engine_params") },
      { label = "Humanization", value = onoff("rand_humanization") },
      { label = "Octaves", value = onoff("rand_octaves") },
    }
    for i, it in ipairs(items) do
      screen.move(0, 28 + i * 10)
      screen.level(i == ui_element_index and 15 or 10)
      local txt = string.format("%s: %s", it.label, tostring(it.value))
      if i == ui_element_index then txt = "[" .. txt .. "]" end
      screen.text(txt)
    end
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


