-- Global parameters for Get in the Sea

local GlobalParams = {}

function GlobalParams.setup()
  params:add_separator("GLOBAL")
  params:add { type = "number", id = "max_drift", name = "max phrase drift", min = 1, max = 10, default = 3 }
  params:add { type = "number", id = "repeat_probability", name = "repeat probability", min = 0, max = 10, default = 5 }
  params:add { type = "control", id = "grace_len_beats", name = "grace time", controlspec = controlspec.new(0.0625, 0.5, 'lin', 0, 0.0625, 'beats') }
end

return GlobalParams
