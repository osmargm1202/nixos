-- Daily-use rules shared in intent with Sway's window-rules.conf.
-- Hyprland class is the Wayland app_id or XWayland class. Monitor fractions
-- approximate Sway workspace percentages (reserved bar areas may differ).
local opaque = "1.0 override 1.0 override 1.0 override"

-- Restore the browser/PWA startup widths from the retained Ryoku profile.
-- Full column width is not fullscreen: keep the bar/dock and scrolling tape.
for _, class in ipairs({
  "(?i)^(firefox|firefox-esr|firefox-bin|org\\.mozilla\\.firefox|chromium|chromium-browser|org\\.chromium\\.Chromium|google-chrome(-stable|-beta|-unstable)?|com\\.google\\.Chrome|brave-browser(-beta|-nightly)?|brave-origin|com\\.brave\\.Browser|opera|vivaldi(-stable)?)$",
  "^(chrome-.*\\..*-Default|orgm-webapp-[a-z0-9-]+)$",
}) do
  hl.window_rule({ match = { class = class, modal = false }, scrolling_width = 1.0 })
end

-- ArtCraft suite + launcher: verified Flatpak app_ids and binary aliases.
-- Catalog: storytold/craft-launcher crates/core/src/catalog.rs; printcraft is
-- PdfCraft's former name. Exact identities only, never arbitrary *craft titles.
hl.window_rule({
  name = "orgm-artcraft-column-width",
  match = {
    class = "(?i)^(ai\\.storyteller\\.)?(artcraft-launcher|cadcraft|photocraft|vectorcraft|filmcraft|lightcraft|pdfcraft|printcraft|effectcraft|designcraft|figcraft|wordcraft|soundcraft|deckcraft|gridcraft)$",
    modal = false,
  },
  scrolling_width = 1.0,
})

local function utility(match, size)
  local rule = { match = match, float = true, center = true }
  if size then rule.size = size end
  hl.window_rule(rule)
end

local utilities = {
  { "(?i)^(org\\.gnome\\.Nautilus|nautilus)$", "monitor_w*0.78 monitor_h*0.78" },
  { "(?i)^(org\\.gnome\\.Loupe|loupe)$" },
  { "(?i)^(org\\.videolan\\.VLC|vlc)$" },
  { "(?i)^(org\\.gnome\\.Calculator|qalculate-gtk|qalculate-qt)$", "monitor_w*0.22 monitor_h*0.6" },
  { "(?i)^(pavucontrol|org\\.pulseaudio\\.pavucontrol|blueman-manager)$", "monitor_w*0.4 monitor_h*0.48" },
  { "(?i)^(bluetui|nmtui|nm-connection-editor|org\\.gnome\\.FileRoller|file-roller)$", "monitor_w*0.44 monitor_h*0.52" },
  { "^orgmai-chat$", "monitor_w*0.71 monitor_h*0.76" },
  { "^orgmai-config$", "monitor_w*0.58 monitor_h*0.69" },
  { "(?i)^(swappy|satty|com\\.gabm\\.satty)$", "monitor_w*0.8 monitor_h*0.8" },
  { "(?i)^(nwg-displays|nwg-look|org\\.gnome\\.OnlineAccounts|gnome-online-accounts-gtk)$", "monitor_w*0.65 monitor_h*0.75" },
  { "(?i)^(ghosttype-app|ryotunes)$" },
  { "^ryoport-ssh$", "monitor_w*0.47 monitor_h*0.52" },
  { "^(Spicy|spicy|looking-glass-client|[Qq]emu.*)$", "monitor_w*0.83 monitor_h*0.83" },
}
for _, rule in ipairs(utilities) do utility({ class = rule[1] }, rule[2]) end
utility({ class = "^org\\.quickshell$", title = "^Ryotunes$" })
hl.window_rule({ match = { class = "^windows-rdp$" }, fullscreen = true })

-- Placement does not autostart tray clients. Preferences keep client geometry.
local nextcloud = "(?i)^(com\\.nextcloud\\.desktopclient\\.nextcloud|nextcloud)$"
utility({ class = nextcloud })
hl.window_rule({
  match = { class = nextcloud, title = "^Nextcloud$" },
  size = "monitor_w*0.3 monitor_h*0.63", center = true,
})
utility({
  class = "(?i)^(|com\\.github\\.martchus\\.syncthingtray|syncthingtray)$",
  title = "^Syncthing Tray$",
}, "monitor_w*0.4 monitor_h*0.56")

-- Identity AND extension-specific title: ordinary Bitwarden browser tabs tile.
utility({
  class = "(?i)^(firefox|org\\.mozilla\\.firefox)$",
  title = "^(Extension:|Extensión:) \\(Bitwarden Password Manager\\) - .*$",
}, "monitor_w*0.25 monitor_h*0.63")
utility({ class = "^chrome-nngceckbapebfimnlniiiahkandclblb-.+$" }, "monitor_w*0.25 monitor_h*0.63")

-- Modal rules in windows-workspaces.lua also cover native modal file pickers.
-- Keep geometry for non-modal file/auth dialogs and remove parent glass tags.
local function dialog(match)
  utility(match)
  hl.window_rule({ match = match, opacity = opaque })
  hl.window_rule({ match = match, tag = "-hyprglass_enabled" })
  hl.window_rule({ match = match, tag = "-hyprglass_preset_glass" })
end
dialog({ title = "^(Open File|Save File|Save As|Choose Files|Open Folder|Abrir archivo|Guardar archivo|Guardar como|Elegir archivos|Abrir carpeta)$" })
dialog({ class = "(?i)^(polkit-gnome-authentication-agent-1|org\\.kde\\.polkit-kde-authentication-agent-1|hyprpolkitagent|xdg-desktop-portal-gtk)$" })

-- Client windows are not games: they must not steal focus or render hidden.
local games = { class = "^(steam_app_[0-9]+|dota2|gamescope|EtG\\.x86_64)$" }
local desktop_and_games = { class = "^(steam|steam_app_[0-9]+|dota2|gamescope|EtG\\.x86_64)$" }
hl.window_rule({ match = desktop_and_games, opacity = opaque, no_blur = true, no_shadow = true, idle_inhibit = "fullscreen" })
hl.window_rule({ match = desktop_and_games, tag = "-hyprglass_enabled" })
hl.window_rule({ match = desktop_and_games, tag = "-hyprglass_preset_glass" })
hl.window_rule({ name = "orgm-game-activation", match = games, focus_on_activate = true })

local game_mode = require("lua.game-mode")
if game_mode.enabled() then
  local fullscreen_game = { class = games.class, fullscreen = true }
  hl.window_rule({ name = "orgm-game-background", match = fullscreen_game, render_unfocused = true })
  if game_mode.preferences().tearing then
    hl.window_rule({ name = "orgm-game-immediate", match = fullscreen_game, immediate = true })
  end
end

-- Native-rule limitations in 0.55: no X11 window_type/window_role matcher.
-- Therefore no generic role=pop-up rule (would float Chromium PWA main windows),
-- or notification-title rule (would float ordinary browser tabs). Swaync handles
-- Wayland notifications; Hyprland handles native transients/X11 types itself.
-- float/size/center are map-time effects: a Firefox extension supplying its title
-- only after mapping cannot be recovered by a static title rule alone.
