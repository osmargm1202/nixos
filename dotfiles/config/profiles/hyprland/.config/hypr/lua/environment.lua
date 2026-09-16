local home = os.getenv("HOME") or ""
local path = os.getenv("PATH") or "/run/current-system/sw/bin"
if home ~= "" then
  -- Hyprland re-applies `env` on every config reload and reads back the PATH
  -- it already exported, so a blind prepend grows without bound and every
  -- process launched from the session inherits the copies.  Prepend the
  -- wanted directories and drop repeats instead.
  local entries = {}
  local seen = {}
  local function add(dir)
    if dir ~= "" and not seen[dir] then
      seen[dir] = true
      entries[#entries + 1] = dir
    end
  end
  add("/run/wrappers/bin")
  add(home .. "/.local/bin")
  for dir in string.gmatch(path, "[^:]+") do
    add(dir)
  end
  path = table.concat(entries, ":")
end

local env = {
  NIXOS_OZONE_WL = "1",
  MOZ_ENABLE_WAYLAND = "1",
  XDG_SESSION_TYPE = "wayland",
  XDG_SESSION_DESKTOP = "Hyprland",
  XDG_CURRENT_DESKTOP = "Hyprland",
  QT_QPA_PLATFORM = "wayland",
  QT_QPA_PLATFORMTHEME = "qt6ct",
  QT_QPA_PLATFORMTHEME_QT6 = "qt6ct",
  ELECTRON_OZONE_PLATFORM_HINT = "auto",
  GDK_BACKEND = "wayland,x11",
  CLUTTER_BACKEND = "wayland",
  TERMINAL = "kitty",
  -- Binds and Waybar invoke managed helpers by name.
  PATH = path,
}

for key, value in pairs(env) do
  hl.env(key, value)
end
