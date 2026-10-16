local name = "orgm-ryoku.shortcuts"
local config = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
if not package.loaded[name] then
  package.loaded[name] = assert(loadfile(config .. "/orgm-ryoku/shortcuts.lua"))()
end
package.loaded[name].install()

-- Native scrolling column presets: one third, one half and the whole viewport.
-- Keep the user's selected layout and default width under Hub ownership.
hl.config({ scrolling = {
  explicit_column_widths = "0.333, 0.5, 1.0",
  -- A lone column must also honor the selected width instead of forcing 100%.
  fullscreen_on_one_column = false,
} })

-- Personal placement rules belong to this user and this desktop profile.
assert(loadfile(config .. "/orgm-ryoku/window-rules.lua"))().setup()

-- Kitty owns the background alpha. Avoid multiplying it again by the desktop
-- inactive opacity, including the personal AI and native SSH terminal classes.
hl.window_rule({
  name = "orgm-kitty-opacity",
  match = { class = "^(kitty|orgmai-(chat|config)|ryoport-ssh)$" },
  opacity = "1 override 1 override 1 override",
})

-- Personal startup is stored in desktop.autostart (Hub → Session), shared
-- by Hyprland and Niri. No second compositor-specific launcher belongs here.
