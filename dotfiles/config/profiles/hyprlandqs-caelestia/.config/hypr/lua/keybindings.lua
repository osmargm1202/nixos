local M = {}

function M.setup(programs)
  local mainMod = "SUPER"

  local function program(name, fallback)
    return programs[name] or fallback
  end

  -- Caelestia global shortcuts.
  hl.bind(mainMod .. " + Space",          hl.dsp.global("caelestia:launcher"))
  hl.bind(mainMod .. " + Return",         hl.dsp.exec_cmd("kitty"))
  hl.bind(mainMod .. " + S",              hl.dsp.global("caelestia:controlCenter"))
  hl.bind(mainMod .. " + ALT + Space",    hl.dsp.global("caelestia:controlCenter"))
  hl.bind(mainMod .. " + D",              hl.dsp.global("caelestia:dashboard"))
  hl.bind(mainMod .. " + N",              hl.dsp.global("caelestia:sidebar"))
  hl.bind(mainMod .. " + M",              hl.dsp.global("caelestia:utilities"))
  hl.bind(mainMod .. " + CTRL + E",       hl.dsp.global("caelestia:emoji"))
  hl.bind(mainMod .. " + V",              hl.dsp.global("caelestia:clipboard"))
  hl.bind(mainMod .. " + Escape",         hl.dsp.global("caelestia:windowSwitcher"))
  hl.bind(mainMod .. " + slash",          hl.dsp.global("caelestia:keybinds"))
  hl.bind(mainMod .. " + B",              hl.dsp.global("caelestia:wallpaper"))
  hl.bind(mainMod .. " + T",             hl.dsp.global("caelestia:terminal"))
  hl.bind(mainMod .. " + ALT + E",        hl.dsp.global("caelestia:session"))

  -- Apps (Win+E and Win+W intentionally NOT mapped to caelestia).
  hl.bind(mainMod .. " + E",              hl.dsp.exec_cmd(programs.fileManager))
  hl.bind(mainMod .. " + W",              hl.dsp.exec_cmd("hypr-zen-new-window"))
  hl.bind(mainMod .. " + SHIFT + W",      hl.dsp.exec_cmd("chromium"))
  hl.bind(mainMod .. " + ALT + W",        hl.dsp.exec_cmd("orgm-wallpaper pick"))
  hl.bind(mainMod .. " + O",              hl.dsp.exec_cmd("hypr-obsidian-open-or-focus"))
  hl.bind(mainMod .. " + C",              hl.dsp.exec_cmd("gnome-calculator"))
  hl.bind(mainMod .. " + CTRL + slash",   hl.dsp.exec_cmd("kitty --hold -e dev -i -C tmuxls"))
  hl.bind(mainMod .. " + SHIFT + Return", hl.dsp.exec_cmd("env NO_DEV_SHELL=1 kitty"))
  hl.bind(mainMod .. " + SHIFT + R",      hl.dsp.exec_cmd("kitty -e dev -i -C 'orgmrnc find'"))
  hl.bind(mainMod .. " + SHIFT + P",      hl.dsp.exec_cmd(program("piPrompt", "kitty --hold -e pi")))
  hl.bind(mainMod .. " + SHIFT + T",      hl.dsp.exec_cmd("hypr-rofi-tmux-arch"))
  hl.bind(mainMod .. " + F10",            hl.dsp.exec_cmd("pavucontrol"))
  hl.bind(mainMod .. " + ALT + L",        hl.dsp.exec_cmd(program("lock", "loginctl lock-session")))
  hl.bind("CTRL + Space",                 hl.dsp.exec_cmd("hyprctl switchxkblayout all next"))

  -- Scratchpad / special workspace (moved from S to ALT+S).
  hl.bind(mainMod .. " + ALT + S",              hl.dsp.workspace.toggle_special("magic"))
  hl.bind(mainMod .. " + ALT + SHIFT + S",      hl.dsp.window.move({ workspace = "special:magic", follow = false }))
  hl.bind(mainMod .. " + ALT + CTRL + S",       hl.dsp.window.move({ workspace = "current" }))

  -- Media keys.
  hl.bind("XF86AudioRaiseVolume",      hl.dsp.exec_cmd("volume-osd up"),       { repeating = true, locked = true })
  hl.bind("XF86AudioLowerVolume",      hl.dsp.exec_cmd("volume-osd down"),     { repeating = true, locked = true })
  hl.bind("XF86AudioMute",             hl.dsp.exec_cmd("volume-osd mute"),     { locked = true })
  hl.bind("CTRL + XF86AudioRaiseVolume", hl.dsp.exec_cmd("mic-volume-osd up"),   { repeating = true })
  hl.bind("CTRL + XF86AudioLowerVolume", hl.dsp.exec_cmd("mic-volume-osd down"), { repeating = true })
  hl.bind("XF86AudioMicMute",          hl.dsp.exec_cmd("mic-volume-osd mute"), { locked = true })
  hl.bind("XF86AudioPlay",             hl.dsp.exec_cmd("playerctl play-pause"),{ locked = true })
  hl.bind("XF86AudioStop",             hl.dsp.exec_cmd("playerctl stop"),      { locked = true })
  hl.bind("XF86AudioPrev",             hl.dsp.exec_cmd("playerctl previous"),  { locked = true })
  hl.bind("XF86AudioNext",             hl.dsp.exec_cmd("playerctl next"),      { locked = true })
  hl.bind("XF86MonBrightnessUp",       hl.dsp.exec_cmd("brightness-osd up"),   { repeating = true, locked = true })
  hl.bind("XF86MonBrightnessDown",     hl.dsp.exec_cmd("brightness-osd down"), { repeating = true, locked = true })
  hl.bind("Print",                     hl.dsp.exec_cmd('grim -g "$(slurp)" - | swappy -f -'))
  hl.bind("CTRL + Print",              hl.dsp.exec_cmd("grim - | swappy -f -"))
  hl.bind("ALT + Print",               hl.dsp.exec_cmd('grim -g "$(slurp)" - | swappy -f -'))
  hl.bind(mainMod .. " + Print",       hl.dsp.exec_cmd("fish -c record_screen_mp4"))
  hl.bind(mainMod .. " + SHIFT + Print", hl.dsp.exec_cmd("fish -c record_screen_gif"))

  -- Window/session controls.
  hl.bind(mainMod .. " + Tab",           hl.dsp.focus({ last = true }))
  hl.bind(mainMod .. " + Q",             hl.dsp.window.close())
  hl.bind(mainMod .. " + SHIFT + Q",     hl.dsp.exec_cmd("hypr-kill-windows"))
  hl.bind(mainMod .. " + SHIFT + E",     hl.dsp.exit())
  hl.bind("CTRL + ALT + Delete",         hl.dsp.exit())
  hl.bind(mainMod .. " + F",             hl.dsp.window.fullscreen({ mode = 1 }))
  hl.bind(mainMod .. " + SHIFT + F",     hl.dsp.window.fullscreen({ mode = 0 }))
  hl.bind(mainMod .. " + SHIFT + Space", hl.dsp.window.float({ action = "toggle" }))
  hl.bind(mainMod .. " + G",             hl.dsp.group.toggle())
  hl.bind(mainMod .. " + R",             hl.dsp.layout("togglesplit"))
  hl.bind(mainMod .. " + CTRL + R",      hl.dsp.layout("togglesplit"))
  hl.bind(mainMod .. " + ALT + C",       hl.dsp.window.center())

  -- Group navigation.
  hl.bind(mainMod .. " + grave",         hl.dsp.group.next())
  hl.bind(mainMod .. " + SHIFT + grave", hl.dsp.group.prev())
  hl.bind(mainMod .. " + CTRL + minus",  hl.dsp.exec_cmd("hyprctl dispatch resizeactive -20 0"))
  hl.bind(mainMod .. " + CTRL + equal",  hl.dsp.exec_cmd("hyprctl dispatch resizeactive 20 0"))
  hl.bind(mainMod .. " + SHIFT + minus", hl.dsp.exec_cmd("hyprctl dispatch resizeactive 0 -20"))
  hl.bind(mainMod .. " + SHIFT + equal", hl.dsp.exec_cmd("hyprctl dispatch resizeactive 0 20"))

  -- Focus / move.
  local dirs    = { left = "left", down = "down", up = "up", right = "right", h = "left", j = "down", k = "up", l = "right" }
  local moveDirs = { left = "l", down = "d", up = "u", right = "r", h = "l", j = "d", k = "u", l = "r" }
  for key, dir in pairs(dirs) do
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ direction = dir }))
  end
  for key, dir in pairs(moveDirs) do
    hl.bind(mainMod .. " + CTRL + " .. key, hl.dsp.window.move({ direction = dir }))
  end

  -- Workspaces.
  hl.bind(mainMod .. " + Home",       hl.dsp.focus({ workspace = 1 }))
  hl.bind(mainMod .. " + End",        hl.dsp.focus({ workspace = 10 }))
  hl.bind(mainMod .. " + CTRL + Home", hl.dsp.window.move({ workspace = 1 }))
  hl.bind(mainMod .. " + CTRL + End",  hl.dsp.window.move({ workspace = 10 }))
  hl.bind(mainMod .. " + Page_Down",  hl.dsp.focus({ workspace = "r-1" }))
  hl.bind(mainMod .. " + Page_Up",    hl.dsp.focus({ workspace = "r+1" }))
  hl.bind(mainMod .. " + U",          hl.dsp.focus({ workspace = "r-1" }))
  hl.bind(mainMod .. " + I",          hl.dsp.focus({ workspace = "r+1" }))
  hl.bind(mainMod .. " + CTRL + Page_Down", hl.dsp.window.move({ workspace = "r-1" }))
  hl.bind(mainMod .. " + CTRL + Page_Up",   hl.dsp.window.move({ workspace = "r+1" }))
  hl.bind(mainMod .. " + CTRL + U",   hl.dsp.window.move({ workspace = "r-1" }))
  hl.bind(mainMod .. " + CTRL + I",   hl.dsp.window.move({ workspace = "r+1" }))

  for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
  end

  -- Mouse.
  hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
  hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
end

return M
