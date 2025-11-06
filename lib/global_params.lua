-- Global parameters for Get in the Sea

local GlobalParams = {}

function GlobalParams.setup()
  params:add_separator("PHRASING")
  params:add { type = "option", id = "grace_len_beats", name = "grace time", options = { "1/64", "1/32", "1/16" }, default = 2 }
  -- Randomization toggles
  params:add_separator("RANDOMIZATION")
  params:add { type = "option", id = "rand_instruments", name = "randomize instruments", options = { "off", "on" }, default = 2 }
  params:add { type = "option", id = "rand_engine_params", name = "randomize engine params", options = { "off", "on" }, default = 1 }
  params:add { type = "option", id = "rand_humanization", name = "randomize humanization", options = { "off", "on" }, default = 1 }
  params:add { type = "option", id = "rand_octaves", name = "randomize octaves", options = { "off", "on" }, default = 2 }
end

return GlobalParams
