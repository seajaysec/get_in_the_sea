-- UI rendering for Get in the Sea

local UI = {}

function UI.draw(seafarers, any_playing, ensemble)
  screen.clear()
  screen.font_face(12)
  screen.font_size(12)
  screen.level(15)

  screen.move(0, 10)
  screen.text("Get in the sea!")

  screen.font_size(10)

  if ensemble ~= nil then
    screen.move(0, 20)
    screen.text("Mode: " .. (ensemble:get_mode() or "autonomous"))
    screen.move(120, 20)
    screen.text_right(string.format("%dbpm", math.floor(ensemble.tempo_bpm or clock.get_tempo() or 120)))
    screen.move(0, 32)
    screen.text("Median: " .. tostring(ensemble.median_pattern or 1))
    screen.move(120, 32)
    screen.text_right("Pulse " .. ((ensemble.pulse_enabled and "on") or "off"))
    if ensemble.ending then
      screen.move(0, 52)
      screen.text("Ending...")
    end
  end

  local x = 0
  local y = 24
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
      y = 44
      x = 0
    end
  end
  screen.level(15)

  screen.font_size(8)
  screen.move(0, 60)
  if any_playing then
    screen.text("Stop   Reset")
  else
    screen.text("Start  Reset")
  end

  screen.update()
end

return UI


