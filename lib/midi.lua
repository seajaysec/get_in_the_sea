-- MIDI helpers for Get in the Sea

local Midi = {}

function Midi.register_transport(m, seafarers)
  -- External: norns MIDI transport start/stop/continue messages control all seafarers
  m.event = function(data)
    local d = midi.to_msg(data)
    if d.type == "start" or d.type == "stop" or d.type == "continue" then
      for s = 1, #seafarers do
        if d.type == "start" then
          seafarers[s]:reset()
        elseif d.type == "stop" then
          seafarers[s]:all_notes_off()
        end
        seafarers[s].playing = d.type == "start" or d.type == "continue"
      end
    end
  end
end

return Midi


