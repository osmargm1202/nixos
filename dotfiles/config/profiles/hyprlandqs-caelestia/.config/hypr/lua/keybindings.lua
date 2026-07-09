local M = {}

function M.setup(programs)
  local mainMod = "SUPER"

  local function program(name, fallback)
    return programs[name] or fallback
  end

  -- Caelestia global shortcuts.
  hl.bind(mainMod .. " + Space",          hl.dsp.global("caelestia:launcher"),      { description = "Launcher" })
  hl.bind(mainMod .. " + Return",         hl.dsp.exec_cmd("kitty"),                 { description = "Terminal (kitty)" })
  hl.bind(mainMod .. " + ALT + S",        hl.dsp.global("caelestia:nexus"),         { description = "Control center" })
  hl.bind(mainMod .. " + ALT + Space",    hl.dsp.global("caelestia:nexus"),         { description = "Control center" })
  hl.bind(mainMod .. " + D",              hl.dsp.global("caelestia:dashboard"),     { description = "Dashboard" })
  hl.bind(mainMod .. " + N",              hl.dsp.global("caelestia:sidebar"),       { description = "Sidebar" })
  hl.bind(mainMod .. " + M",              hl.dsp.global("caelestia:utilities"),     { description = "Utilities" })
  hl.bind(mainMod .. " + CTRL + E",       hl.dsp.global("caelestia:emoji"),         { description = "Emoji picker" })
  hl.bind(mainMod .. " + V",              hl.dsp.global("caelestia:clipboard"),     { description = "Clipboard history" })
  hl.bind(mainMod .. " + Escape",         hl.dsp.global("caelestia:windowSwitcher"),{ description = "Window switcher" })
  hl.bind(mainMod .. " + slash",          hl.dsp.global("caelestia:keybinds"),      { description = "Keybinds cheatsheet" })
  hl.bind(mainMod .. " + B",              hl.dsp.global("caelestia:wallpaper"),     { description = "Wallpaper picker" })
  hl.bind(mainMod .. " + ALT + E",        hl.dsp.global("caelestia:session"),       { description = "Session menu" })

  -- Apps (Win+E and Win+W intentionally NOT mapped to caelestia).
  hl.bind(mainMod .. " + E",              hl.dsp.exec_cmd(programs.fileManager),           { description = "File manager" })
  hl.bind(mainMod .. " + W",              hl.dsp.exec_cmd("hypr-zen-new-window"),           { description = "Zen Browser (new window)" })
  hl.bind(mainMod .. " + SHIFT + W",      hl.dsp.exec_cmd("chromium"),                     { description = "Chromium" })
  hl.bind(mainMod .. " + ALT + W",        hl.dsp.exec_cmd("orgm-wallpaper pick"),           { description = "Set wallpaper" })
  hl.bind(mainMod .. " + O",              hl.dsp.exec_cmd("hypr-obsidian-open-or-focus"),   { description = "Obsidian" })
  hl.bind(mainMod .. " + C",              hl.dsp.exec_cmd("gnome-calculator"),              { description = "Calculator" })
  hl.bind(mainMod .. " + SHIFT + Return", hl.dsp.exec_cmd("kitty"),                         { description = "Terminal" })
  hl.bind(mainMod .. " + SHIFT + P",      hl.dsp.exec_cmd("hypr-pi-prompt"), { description = "AI prompt (pi/claude/codex/opencode)" })
  hl.bind(mainMod .. " + F10",            hl.dsp.exec_cmd("pavucontrol"),                   { description = "Audio mixer" })
  hl.bind(mainMod .. " + ALT + L",        hl.dsp.exec_cmd(program("lock", "loginctl lock-session")), { description = "Lock screen" })
  hl.bind(mainMod .. " + ALT + P",        hl.dsp.exec_cmd("systemctl suspend"),                       { description = "Sleep / suspend" })
  hl.bind("CTRL + Space",                 hl.dsp.exec_cmd("hyprctl switchxkblayout all next"), { description = "Next keyboard layout" })

  -- Scratchpad / special workspace.
  hl.bind(mainMod .. " + S",              hl.dsp.workspace.toggle_special("magic"),                            { description = "Toggle scratchpad" })
  hl.bind(mainMod .. " + SHIFT + S",      hl.dsp.window.move({ workspace = "special:magic", follow = false }), { description = "Move to scratchpad" })

  -- Media keys.
  hl.bind("XF86AudioRaiseVolume",           hl.dsp.exec_cmd("volume-osd up"),       { repeating = true, locked = true, description = "Volume up" })
  hl.bind("XF86AudioLowerVolume",           hl.dsp.exec_cmd("volume-osd down"),     { repeating = true, locked = true, description = "Volume down" })
  hl.bind("XF86AudioMute",                  hl.dsp.exec_cmd("volume-osd mute"),     { locked = true, description = "Mute audio" })
  hl.bind("CTRL + XF86AudioRaiseVolume",    hl.dsp.exec_cmd("mic-volume-osd up"),   { repeating = true, description = "Mic volume up" })
  hl.bind("CTRL + XF86AudioLowerVolume",    hl.dsp.exec_cmd("mic-volume-osd down"), { repeating = true, description = "Mic volume down" })
  hl.bind("XF86AudioMicMute",               hl.dsp.exec_cmd("mic-volume-osd mute"), { locked = true, description = "Mute mic" })
  hl.bind("XF86AudioPlay",                  hl.dsp.exec_cmd("playerctl play-pause"),{ locked = true, description = "Play/pause media" })
  hl.bind("XF86AudioStop",                  hl.dsp.exec_cmd("playerctl stop"),      { locked = true, description = "Stop media" })
  hl.bind("XF86AudioPrev",                  hl.dsp.exec_cmd("playerctl previous"),  { locked = true, description = "Previous track" })
  hl.bind("XF86AudioNext",                  hl.dsp.exec_cmd("playerctl next"),      { locked = true, description = "Next track" })
  hl.bind("XF86MonBrightnessUp",            hl.dsp.exec_cmd("brightness-osd up"),   { repeating = true, locked = true, description = "Brightness up" })
  hl.bind("XF86MonBrightnessDown",          hl.dsp.exec_cmd("brightness-osd down"), { repeating = true, locked = true, description = "Brightness down" })
  hl.bind("Print",                          hl.dsp.exec_cmd('grim -g "$(slurp)" - | swappy -f -'), { description = "Screenshot region" })
  hl.bind("CTRL + Print",                   hl.dsp.exec_cmd("grim - | swappy -f -"),               { description = "Screenshot full screen" })
  hl.bind("ALT + Print",                    hl.dsp.exec_cmd('grim -g "$(slurp)" - | swappy -f -'), { description = "Screenshot region (alt)" })
  hl.bind(mainMod .. " + Print",            hl.dsp.exec_cmd("fish -c record_screen_mp4"),           { description = "Record screen (mp4)" })
  hl.bind(mainMod .. " + SHIFT + Print",    hl.dsp.exec_cmd("fish -c record_screen_gif"),           { description = "Record screen (gif)" })

  -- Window/session controls.
  hl.bind(mainMod .. " + Tab",           hl.dsp.focus({ last = true }),                    { description = "Switch to last window" })
  hl.bind("ALT + Tab", function()
    hl.plugin.scrolloverview.overview("toggle")
  end, { description = "Toggle scroll overview" })
  hl.bind(mainMod .. " + Q",             hl.dsp.window.close(),                            { description = "Close window" })
  hl.bind(mainMod .. " + SHIFT + Q",     hl.dsp.exec_cmd("hypr-kill-windows"),             { description = "Kill all windows" })
  hl.bind(mainMod .. " + SHIFT + E",     hl.dsp.exit(),                                    { description = "Exit Hyprland" })
  hl.bind("CTRL + ALT + Delete",         hl.dsp.exit(),                                    { description = "Exit Hyprland" })
  hl.bind(mainMod .. " + F",             hl.dsp.window.fullscreen({ mode = 1 }),           { description = "Fullscreen (maximized)" })
  hl.bind(mainMod .. " + SHIFT + F",     hl.dsp.window.fullscreen({ mode = 0 }),           { description = "Fullscreen (true)" })
  hl.bind(mainMod .. " + SHIFT + Space", hl.dsp.window.float({ action = "toggle" }),       { description = "Toggle floating" })
  hl.bind(mainMod .. " + G",             hl.dsp.group.toggle(),                            { description = "Toggle group" })
  hl.bind(mainMod .. " + R",             hl.dsp.layout("togglesplit"),                     { description = "Toggle split" })
  hl.bind(mainMod .. " + CTRL + R",      hl.dsp.layout("togglesplit"),                     { description = "Toggle split" })
  hl.bind(mainMod .. " + ALT + C",       hl.dsp.window.center(),                           { description = "Center window" })

  -- Group navigation.
  hl.bind(mainMod .. " + grave",         hl.dsp.group.next(),                                          { description = "Next window in group" })
  hl.bind(mainMod .. " + SHIFT + grave", hl.dsp.group.prev(),                                          { description = "Prev window in group" })
  hl.bind(mainMod .. " + CTRL + minus",  hl.dsp.exec_cmd("hyprctl dispatch resizeactive -20 0"),       { description = "Resize: shrink width" })
  hl.bind(mainMod .. " + CTRL + equal",  hl.dsp.exec_cmd("hyprctl dispatch resizeactive 20 0"),        { description = "Resize: grow width" })
  hl.bind(mainMod .. " + SHIFT + minus", hl.dsp.exec_cmd("hyprctl dispatch resizeactive 0 -20"),       { description = "Resize: shrink height" })
  hl.bind(mainMod .. " + SHIFT + equal", hl.dsp.exec_cmd("hyprctl dispatch resizeactive 0 20"),        { description = "Resize: grow height" })

  -- Focus / move.
  local dirs    = { left = "left", down = "down", up = "up", right = "right", h = "left", j = "down", k = "up", l = "right" }
  local moveDirs = { left = "l", down = "d", up = "u", right = "r", h = "l", j = "d", k = "u", l = "r" }
  for key, dir in pairs(dirs) do
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ direction = dir }), { description = "Focus " .. dir })
  end
  for key, dir in pairs(moveDirs) do
    hl.bind(mainMod .. " + CTRL + " .. key, hl.dsp.window.move({ direction = dir }), { description = "Move window " .. dir })
  end

  -- Workspaces.
  hl.bind(mainMod .. " + Home",            hl.dsp.focus({ workspace = 1 }),           { description = "Workspace 1" })
  hl.bind(mainMod .. " + End",             hl.dsp.focus({ workspace = 10 }),          { description = "Workspace 10" })
  hl.bind(mainMod .. " + CTRL + Home",     hl.dsp.window.move({ workspace = 1 }),     { description = "Move to workspace 1" })
  hl.bind(mainMod .. " + CTRL + End",      hl.dsp.window.move({ workspace = 10 }),    { description = "Move to workspace 10" })
  hl.bind(mainMod .. " + Page_Down",       hl.dsp.focus({ workspace = "r-1" }),       { description = "Previous workspace" })
  hl.bind(mainMod .. " + Page_Up",         hl.dsp.focus({ workspace = "r+1" }),       { description = "Next workspace" })
  hl.bind(mainMod .. " + U",               hl.dsp.focus({ workspace = "r-1" }),       { description = "Previous workspace" })
  hl.bind(mainMod .. " + I",               hl.dsp.focus({ workspace = "r+1" }),       { description = "Next workspace" })
  hl.bind(mainMod .. " + CTRL + Page_Down",hl.dsp.window.move({ workspace = "r-1" }), { description = "Move to previous workspace" })
  hl.bind(mainMod .. " + CTRL + Page_Up",  hl.dsp.window.move({ workspace = "r+1" }), { description = "Move to next workspace" })
  hl.bind(mainMod .. " + CTRL + U",        hl.dsp.window.move({ workspace = "r-1" }), { description = "Move to previous workspace" })
  hl.bind(mainMod .. " + CTRL + I",        hl.dsp.window.move({ workspace = "r+1" }), { description = "Move to next workspace" })

  for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }),       { description = "Workspace " .. i })
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }), { description = "Move to workspace " .. i })
  end

  -- Mouse.
  hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true, description = "Drag window" })
  hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Resize window" })
end

return M
