local M = {}

local function state_file()
  local state_home = os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")
  return state_home .. "/hypr/game-mode"
end

function M.enabled()
  local file = io.open(state_file(), "r")
  if not file then
    return false
  end
  local enabled = file:read("*l") == "activated"
  file:close()
  return enabled
end

return M
