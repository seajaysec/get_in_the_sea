-- Global parameters for Get in the Sea

local GlobalParams = {}

function GlobalParams.setup()
  params:add_separator("GLOBAL")
  params:add { type = "number", id = "max_drift", name = "max phrase drift", min = 1, max = 10, default = 3 }
  params:add { type = "number", id = "repeat_probability", name = "repeat probability", min = 0, max = 10, default = 5 }
  params:add { type = "option", id = "grace_len_beats", name = "grace time", options = { "1/64", "1/32", "1/16" }, default = 2 }
end

return GlobalParams
