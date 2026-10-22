local M = {}

local function state_file()
  local state_home = os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")
  return state_home .. "/hypr/game-mode"
end

local function activated(path)
  local file = io.open(path, "r")
  if not file then return false end
  -- Match shell command substitution: discard trailing LF, not extra content.
  local contents = file:read("*a")
  file:close()
  return contents ~= nil and contents:gsub("\n+$", "") == "activated"
end

function M.enabled()
  return activated(state_file())
end

-- Explicit user opt-ins; malformed or missing flags always stay disabled.
function M.preferences()
  local prefix = state_file():gsub("game%-mode$", "")
  return { vrr = activated(prefix .. "game-vrr"), tearing = activated(prefix .. "game-tearing") }
end

return M
