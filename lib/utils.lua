-- Utility helpers for Get in the Sea

local Utils = {}

-- Returns true if a lua file (without .lua suffix) exists in the common norns library paths
function Utils.lib_installed(file)
  local dirs = { norns.state.path, _path.code, _path.extn }
  for _, dir in ipairs(dirs) do
    local p = dir .. file .. '.lua'
    if util.file_exists(p) then
      return true
    end
  end
  return false
end

return Utils


