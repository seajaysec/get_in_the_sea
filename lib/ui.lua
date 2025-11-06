-- UI rendering for Get in the Sea

local UI = {}

function UI.draw(seafarers, any_playing, ensemble, ui_focus, header_index, ui_show_info)
  screen.clear()
  screen.font_face(12)
  screen.font_size(12)
  screen.level(15)

  -- title removed to declutter

  -- header
  screen.font_size(8)

  if ui_show_info and ensemble ~= nil then
    -- Info screen
    screen.font_size(8)
    screen.move(0, 10)
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

    screen.move(0, 20)
    screen.level(12)
    screen.text(string.format("Time %s  Complete %d%%", time_str, pct))

    screen.move(0, 30)
    screen.text(string.format("Median %d  Spread %d", median, spread))

    screen.move(0, 40)
    screen.text(string.format("Active %d  Resting %d  Ready %d", active, resting, ready))

    screen.move(0, 50)
    screen.level(10)
    screen.text(string.format("At53 %d  Ending %s", at53, ensemble.ending and "on" or "off"))

    -- final row: positions
    screen.move(0, 60)
    local pos = {}
    for i = 1, #seafarers do pos[i] = string.format("%02d", seafarers[i].phrase or 1) end
    screen.text("Pos: " .. table.concat(pos, " "))

    screen.update()
    return
  end

  if ensemble ~= nil then
    -- header selection
    local sel = header_index or 1
    local focus_header = (ui_focus == "header")

    local mode_str = (ensemble:get_mode() or "autonomous")
    local tempo_str = string.format("%dbpm", math.floor(ensemble.tempo_bpm or clock.get_tempo() or 120))
    local pulse_str = (ensemble.pulse_enabled and "on") or "off"

    local function draw_field(x, y, idx, label, value)
      screen.move(x, y)
      if focus_header and sel == idx then screen.level(15) else screen.level(10) end
      local text = label .. ": " .. value
      if focus_header and sel == idx then text = "[" .. text .. "]" end
      screen.text(text)
    end

    draw_field(0, 10, 1, "Mode", mode_str)
    draw_field(70, 10, 2, "Pulse", pulse_str)
    draw_field(0, 20, 3, "Tempo", tempo_str)
    draw_field(70, 20, 4, "Info", "")

    if ensemble.ending then
      screen.move(0, 30)
      screen.level(15)
      screen.text("Ending...")
    end
  end

  -- players grid
  screen.font_size(10)
  local x = 0
  local y = 36
  for s = 1, #seafarers do
    local is_selected = (ensemble ~= nil and ensemble.selected_player == s)
    local num = string.format("%02d", seafarers[s].phrase)
    if seafarers[s].ready_indicator then num = num .. "*" end
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

  -- bottom controls text removed; status is represented elsewhere

  screen.update()
end

return UI


