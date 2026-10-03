-- Osmarg's Ryoku shortcuts. Desktop actions use Ryoku's own controls;
-- personal applications remain independent of the standard Hyprland profile.
local M = {}


function M.setup()
  local mainMod = "SUPER"

  local workspace = (os.getenv("HOME") or "") .. "/.config/hypr/scripts/ryoku-workspace"
  local screenshot = "flock -n -o /tmp/ryoshot.lock qs -c ryoshot"
  local monitorShot = "flock -n -o /tmp/ryoshot.lock env RYOSHOT_MODE=monitor qs -c ryoshot"

  -- Help / launchers.
  hl.bind(mainMod .. " + slash", hl.dsp.exec_cmd("ryoku-shell hub open keybinds"))
  hl.bind(mainMod .. " + ALT + W", hl.dsp.exec_cmd("ryogami wallpaper ui"))
  hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("firefox-open-tab --focus"))
  hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd("ryoku-app terminal"))
  hl.bind(mainMod .. " + SHIFT + Return", hl.dsp.exec_cmd("ryoku-app terminal"))
  hl.bind(mainMod .. " + CTRL + Return", hl.dsp.exec_cmd("ryoku-app terminal -- tmux new-session -A -s main"))
  hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("ryoku-app files"))
  hl.bind(mainMod .. " + O", hl.dsp.exec_cmd("hypr-obsidian-open-or-focus"))
  hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("firefox-open-tab --restore-or-focus"))
  hl.bind(mainMod .. " + CTRL + W", hl.dsp.exec_cmd("windows-rdp toggle"))
  hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("kitty --class orgmai-chat -o remember_window_size=no -o initial_window_width=160c -o initial_window_height=42c -e orgmai new"))
  hl.bind(mainMod .. " + SHIFT + A", hl.dsp.exec_cmd("kitty --class orgmai-config -o remember_window_size=no -o initial_window_width=132c -o initial_window_height=38c -e orgmai prev"))
  hl.bind(mainMod .. " + CTRL + SHIFT + A", hl.dsp.exec_cmd("kitty --class orgmai-config -o remember_window_size=no -o initial_window_width=132c -o initial_window_height=38c -e orgmai config"))

  hl.bind(mainMod .. " + Z", hl.dsp.exec_cmd("woomer"))

  hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("hypr-pi-prompt --launcher rofi"))
  -- Launchers and control center.
  hl.bind(mainMod .. " + Space", hl.dsp.global("ryoku:launcher"))
  hl.bind(mainMod .. " + ALT + Space", hl.dsp.global("ryoku:quicksettings"))
  hl.bind(mainMod .. " + CTRL + R", hl.dsp.exec_cmd("ryoku wm act config.reload"))
  hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("firefox-open-tab --new-tab --prompt"))
  hl.bind(mainMod .. " + CTRL + M", hl.dsp.global("ryoku:launcher"))
  hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd("ryoku-app files"))
  hl.bind(mainMod .. " + CTRL + G", hl.dsp.exec_cmd("ryoku-shell hub open"))
  hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd("firefox-tabs"))
  hl.bind(mainMod .. " + C", hl.dsp.global("ryoku:launcher"))
  hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("hypr-rofi-ssh-host"))
  hl.bind(mainMod .. " + CTRL + period", hl.dsp.exec_cmd("rofi-symbols"))
  hl.bind(mainMod .. " + ALT + E", hl.dsp.global("ryoku:quicksettings"))
  hl.bind(mainMod .. " + CTRL + P", hl.dsp.global("ryoku:quicksettings"))
  hl.bind(mainMod .. " + ALT + L", hl.dsp.exec_cmd("ryoku-shell lock"))
  hl.bind(mainMod .. " + V", hl.dsp.global("ryoku:clipboard"))
  hl.bind(mainMod .. " + F10", hl.dsp.global("ryoku:quicksettings"))
  -- XKB owns Ctrl+Space through the Ryoku keyboard settings.

  -- Scratchpad equivalent: special workspace.
  hl.bind(mainMod .. " + S", hl.dsp.exec_cmd(workspace .. " scratch"))
  hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(workspace .. " hide"))
  hl.bind(mainMod .. " + CTRL + S", hl.dsp.window.move({ workspace = "current" }))

  -- Media keys.
  hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("ryoku-volume up"), { repeating = true, locked = true })
  hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("ryoku-volume down"), { repeating = true, locked = true })
  hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
  hl.bind("CTRL + XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 5%+"), { repeating = true })
  hl.bind("CTRL + XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 5%-"), { repeating = true })
  hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
  hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
  hl.bind("XF86AudioStop", hl.dsp.exec_cmd("playerctl stop"), { locked = true })
  hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
  hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
  hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("ryoku-cmd-brightness +5"), { repeating = true, locked = true })
  hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("ryoku-cmd-brightness -5"), { repeating = true, locked = true })
  hl.bind("Print", hl.dsp.exec_cmd(screenshot))
  hl.bind("CTRL + Print", hl.dsp.exec_cmd(monitorShot))
  hl.bind("ALT + Print", hl.dsp.exec_cmd(screenshot))
  hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd("ryoku-cmd-screenrecord"))
  hl.bind(mainMod .. " + SHIFT + Print", hl.dsp.exec_cmd("ryoku-shell menu screenshot"))

  -- Window/session controls.
  hl.bind(mainMod .. " + Tab", hl.dsp.focus({ last = true }))
  hl.bind(mainMod .. " + SHIFT + Tab", hl.dsp.exec_cmd("hypr-video-timer"))
  hl.bind("ALT + Tab", hl.dsp.global("ryoku:overview"))
  hl.bind(mainMod .. " + Q", hl.dsp.window.close())
  hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.global("ryoku:overview"))
  hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exit())
  hl.bind("CTRL + ALT + Delete", hl.dsp.exit())
  hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = 1 }))
  hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = 0 }))
  hl.bind(mainMod .. " + SHIFT + Space", hl.dsp.window.float({ action = "toggle" }))
  hl.bind(mainMod .. " + G", hl.dsp.group.toggle())
  hl.bind(mainMod .. " + T", hl.dsp.group.toggle())
  hl.bind(mainMod .. " + CTRL + C", hl.dsp.window.center())
  -- Win+R keeps Ryoku's native resize submap.

  -- Group navigation (tabbed windows): Win+` next, Win+Shift+` back
  hl.bind(mainMod .. " + grave", hl.dsp.group.next())
  hl.bind(mainMod .. " + SHIFT + grave", hl.dsp.group.prev())
  hl.bind(mainMod .. " + CTRL + minus", hl.dsp.window.resize({ x = -20, y = 0, relative = true }))
  hl.bind(mainMod .. " + CTRL + equal", hl.dsp.window.resize({ x = 20, y = 0, relative = true }))
  hl.bind(mainMod .. " + SHIFT + minus", hl.dsp.window.resize({ x = 0, y = -20, relative = true }))
  hl.bind(mainMod .. " + SHIFT + equal", hl.dsp.window.resize({ x = 0, y = 20, relative = true }))
  hl.bind(mainMod .. " + ALT + left", hl.dsp.window.resize({ x = -40, y = 0, relative = true }), { repeating = true })
  hl.bind(mainMod .. " + ALT + right", hl.dsp.window.resize({ x = 40, y = 0, relative = true }), { repeating = true })
  hl.bind(mainMod .. " + ALT + up", hl.dsp.window.resize({ x = 0, y = -40, relative = true }), { repeating = true })
  hl.bind(mainMod .. " + ALT + down", hl.dsp.window.resize({ x = 0, y = 40, relative = true }), { repeating = true })

  -- Focus / move: Win+H/J/K stay free; Win+L belongs to Ryoku lock.
  local dirs = { left = "left", down = "down", up = "up", right = "right" }
  local moveDirs = { left = "l", down = "d", up = "u", right = "r" }
  for key, dir in pairs(dirs) do
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ direction = dir }))
  end


  for key, dir in pairs(moveDirs) do
    hl.bind(mainMod .. " + CTRL + " .. key, hl.dsp.window.move({ direction = dir }))
  end

  -- Workspaces.
  hl.bind(mainMod .. " + Home", hl.dsp.exec_cmd(workspace .. " focus 1"))
  hl.bind(mainMod .. " + End", hl.dsp.exec_cmd(workspace .. " focus 10"))
  hl.bind(mainMod .. " + CTRL + Home", hl.dsp.exec_cmd(workspace .. " move 1"))
  hl.bind(mainMod .. " + CTRL + End", hl.dsp.exec_cmd(workspace .. " move 10"))
  hl.bind(mainMod .. " + Page_Down", hl.dsp.focus({ workspace = "r-1" }))
  hl.bind(mainMod .. " + Page_Up", hl.dsp.focus({ workspace = "r+1" }))
  hl.bind(mainMod .. " + U", hl.dsp.focus({ workspace = "r-1" }))
  hl.bind(mainMod .. " + I", hl.dsp.focus({ workspace = "r+1" }))
  hl.bind(mainMod .. " + CTRL + Page_Down", hl.dsp.window.move({ workspace = "r-1" }))
  hl.bind(mainMod .. " + CTRL + Page_Up", hl.dsp.window.move({ workspace = "r+1" }))
  hl.bind(mainMod .. " + CTRL + U", hl.dsp.window.move({ workspace = "r-1" }))
  hl.bind(mainMod .. " + CTRL + I", hl.dsp.window.move({ workspace = "r+1" }))

  for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key, hl.dsp.exec_cmd(workspace .. " focus " .. i))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.exec_cmd(workspace .. " movesilent " .. i))
  end

  -- Mouse.
  hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
  hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
  hl.bind(mainMod .. " + mouse:274", hl.dsp.focus({ workspace = "r-1" }))
  hl.bind(mainMod .. " + mouse:275", hl.dsp.focus({ workspace = "r+1" }))
end

return M
