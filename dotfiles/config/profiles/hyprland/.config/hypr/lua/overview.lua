-- Native plugin registration runs during every config evaluation, not exec-once.
local M = {}
local registered_path

local function readable(path)
  local file = io.open(path, "rb")
  if not file then return false end
  file:close()
  return true
end

function M.register()
  if registered_path then return registered_path end
  if not (hl.plugin and type(hl.plugin.load) == "function") then return nil end
  local state = os.getenv("XDG_STATE_HOME")
  if not state or state == "" then state = (os.getenv("HOME") or "") .. "/.local/state" end
  for _, path in ipairs({
    "/etc/scrolloverview.so",
    state .. "/orgm-hyprland-tools/scrolloverview/lib/libscrolloverview.so",
  }) do
    if readable(path) then
      hl.plugin.load(path)
      registered_path = path
      return path
    end
  end
  return nil
end

function M.toggle(fallback)
  return function()
    local plugin = hl.plugin and hl.plugin.scrolloverview
    if plugin and type(plugin.overview) == "function" then
      local ok, action = pcall(plugin.overview, "toggle")
      -- The pinned API executes directly inside a keybind, but returns a
      -- dispatcher callback outside it; support either without a silent no-op.
      if ok and type(action) == "function" then ok = pcall(action) end
      if ok then return end
    end
    hl.exec_cmd(fallback)
  end
end

return M
