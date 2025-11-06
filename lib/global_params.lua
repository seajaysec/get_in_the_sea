-- Global parameters for Get in the Sea

local GlobalParams = {}

function GlobalParams.setup()
  params:add_separator("PHRASING")
  params:add { type = "option", id = "grace_len_beats", name = "grace time", options = { "1/64", "1/32", "1/16" }, default = 2 }
end

return GlobalParams
