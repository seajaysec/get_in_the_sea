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
  end

  local x = 0
  local y = 24
  for s = 1, #seafarers do
    screen.move(x, y)
    screen.text(string.format("%02d", seafarers[s].phrase))

    x = x + 30
    if s == 4 then
      y = 44
      x = 0
    end
  end

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


