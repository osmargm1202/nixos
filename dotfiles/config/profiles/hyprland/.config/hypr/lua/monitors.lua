-- Monitor layout loader.
-- NWG Displays owns ~/.config/hypr/monitors.lua at runtime.
-- Tracked host layouts are recovery fallbacks when no runtime layout exists.

local function read_hostname()
  local host = os.getenv("HOSTNAME")
  if host and host ~= "" then
    return host
  end

  local file = io.open("/etc/hostname", "r")
  if not file then
    return nil
  end
  host = file:read("*l")
  file:close()
  return host
end

local function load_lua(path)
  local file = io.open(path, "r")
  if not file then
    return false
  end
  file:close()
  dofile(path)
  return true
end

local function load_host_monitors(home)
  local host = read_hostname()
  if not host or host == "" then
    return false
  end

  host = host:gsub("[^%w_-]", "_")
  return load_lua(home .. "/.config/hypr/lua/monitors/" .. host .. ".lua")
end

local home = os.getenv("HOME") or ""
local loaded = false

if home ~= "" then
  loaded = load_lua(home .. "/.config/hypr/monitors.lua")
  if not loaded then
    loaded = load_host_monitors(home)
  end
end

if not loaded then
  hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
end
