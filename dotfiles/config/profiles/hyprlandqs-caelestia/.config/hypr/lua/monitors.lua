-- Monitor layout loader.
-- Host-specific layouts live in lua/monitors/<hostname>.lua.
-- If no host file exists, this generated fallback lets Hyprland choose connected outputs safely.

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

local function load_host_monitors()
  local host = read_hostname()
  if not host or host == "" then
    return false
  end

  host = host:gsub("[^%w_-]", "_")
  local home = os.getenv("HOME") or ""
  if home == "" then
    return false
  end

  local path = home .. "/.config/hypr/lua/monitors/" .. host .. ".lua"
  local file = io.open(path, "r")
  if not file then
    return false
  end
  file:close()
  dofile(path)
  return true
end

if not load_host_monitors() then
  hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
end
