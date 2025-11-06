-- Randomization helpers for Get in the Sea

local Randomize = {}

local function pick(tbl)
  if tbl == nil or #tbl == 0 then return nil end
  return tbl[math.random(1, #tbl)]
end

local function frand(lo, hi)
  return lo + (hi - lo) * math.random()
end

function Randomize.apply(seafarers, ensemble)
  local function is_on(id)
    local v = params:get(id) or 1
    return v == 2
  end

  -- Instruments (MxSamples)
  if is_on("rand_instruments") and mxsamples_instruments ~= nil and #mxsamples_instruments > 0 then
    if params.lookup["mxsamples_randomize"] ~= nil or params:lookup_param("mxsamples_randomize") ~= nil then
      params:bang("mxsamples_randomize")
    else
      -- fallback: manual per seafarer random instrument
      for _, s in ipairs(seafarers or {}) do
        local idx = math.random(1, #mxsamples_instruments)
        params:set(s.id .. "_mxsamples_instrument", idx)
      end
    end
  end

  -- Engine params
  if is_on("rand_engine_params") then
    local ae = string.lower(engine.name or "")
    if ae == "polyperc" then
      params:set("amp", frand(0.3, 0.8))
      params:set("release", frand(0.4, 2.0))
      params:set("cutoff", frand(300, 3500))
      params:set("gain", frand(0.8, 2.0))
      params:set("pan", frand(-0.5, 0.5))
    elseif ae == "passersby" then
      params:set("pb_amp", frand(0.2, 0.9))
      params:set("pb_attack", frand(0.01, 0.3))
      params:set("pb_decay", frand(0.1, 1.5))
      params:set("pb_reverb_mix", frand(0.0, 0.5))
      params:set("pb_timbre_all", frand(0.0, 0.7))
    elseif ae == "odashodasho" then
      params:set("odash_attack", frand(0.01, 0.8))
      params:set("odash_decay", frand(0.1, 2.0))
      params:set("odash_index", frand(0.5, 3.0))
      params:set("odash_index_scale", frand(1.0, 6.0))
      params:set("odash_reverb_db", frand(-24.0, -6.0))
    else
      -- fm7 or unknown: skip
    end
  end

  -- Humanization
  if is_on("rand_humanization") then
    params:set("human_timing_ms", math.floor(frand(0, 20)))
    params:set("human_volume_pct", math.floor(frand(0, 8)))
    params:set("human_adv_ms", math.floor(frand(0, 200)))
    params:set("human_skip_pct", math.floor(frand(0, 3)))
  end

  -- Octaves
  if is_on("rand_octaves") then
    for _, s in ipairs(seafarers or {}) do
      params:set(s.id .. "_octave", pick({ -2, -1, 0, 1, 2 }))
    end
  end
end

return Randomize


