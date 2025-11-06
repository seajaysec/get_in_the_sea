-- UI rendering for Get in the Sea

local UI = {}

function UI.draw(seafarers, any_playing, ensemble, ui_focus, header_index)
  screen.clear()
  screen.font_face(12)
  screen.font_size(12)
  screen.level(15)

  -- title removed to declutter

  -- header
  screen.font_size(8)

  if ensemble ~= nil then
    -- header selection
    local sel = header_index or 1
    local focus_header = (ui_focus == "header")

    local mode_str = (ensemble:get_mode() or "autonomous")
    local tempo_str = string.format("%dbpm", math.floor(ensemble.tempo_bpm or clock.get_tempo() or 120))
    local pulse_str = (ensemble.pulse_enabled and "on") or "off"
    local median_str = tostring(ensemble.median_pattern or 1)

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
    draw_field(70, 20, 4, "Median", median_str)

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


