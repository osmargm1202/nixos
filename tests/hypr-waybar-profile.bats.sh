#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

attr='.#nixosConfigurations.lenovo-hyprland.config.home-manager.users.osmarg.home.file'
paths=(
  '.config/waybar-hypr'
  '.config/nwg-dock-hyprland/style.css'
  '.config/nwg-dock-hyprland/pinned'
  '.local/bin/waybar-date-es'
  '.local/bin/waybar-day-month-es'
  '.local/bin/waybar-time-ampm'
  '.local/bin/waybar-watch'
  '.local/bin/waybar-caffeine-state'
  '.local/bin/hypr-game-mode'
  '.local/bin/hypr-reload-after-switch'
  '.local/bin/hypr-nwg-dock'
  '.local/bin/hypr-nwg-dock-reload'
)

for path in "${paths[@]}"; do
  [[ -e "dotfiles/config/profiles/hyprland/$path" ]]
  nix eval --raw "$attr.\"$path\".source" >/dev/null
done

! nix eval --raw "$attr.\".config/nwg-dock-hyprland/orgm-current.css\".source" >/dev/null 2>&1
[[ ! -e 'dotfiles/config/profiles/hyprland/.config/nwg-dock-hyprland/orgm-current.css' ]]

config='dotfiles/config/profiles/hyprland/.config/waybar-hypr/config'
jq -e '
  length == 1
  and .[0]["modules-left"] == [
    "custom/menu", "custom/ws_1", "custom/ws_2", "custom/ws_3",
    "custom/ws_4", "custom/ws_5", "custom/ws_6", "custom/ws_7",
    "custom/ws_8", "custom/ws_9", "custom/ws_10", "custom/ws_special",
    "backlight", "battery", "pulseaudio", "pulseaudio#microphone",
    "idle_inhibitor", "custom/game_mode", "custom/kbd_layout", "custom/wallpaper",
    "custom/keybindings_help"
  ]
  and .[0]["modules-center"] == ["custom/day_month", "custom/time", "custom/date"]
  and .[0]["modules-right"] == ["hyprland/window", "mpris", "custom/power", "tray"]
  and .[0]["custom/power"]["on-click"] == "hypr-power-menu"
' "$config" >/dev/null

caffeine_helper='dotfiles/config/profiles/hyprland/.local/bin/waybar-caffeine-state'
[[ -x "$caffeine_helper" ]]
grep -Fq '"on-click": "~/.local/bin/waybar-caffeine-state toggle"' "$config"
jq -e '.[0].idle_inhibitor.signal == 8' "$config" >/dev/null
game_mode_helper='dotfiles/config/profiles/hyprland/.local/bin/hypr-game-mode'
[[ -x "$game_mode_helper" ]]
jq -e '.[0]["custom/game_mode"].exec == "~/.local/bin/hypr-game-mode waybar"
  and .[0]["custom/game_mode"]["on-click"] == "~/.local/bin/hypr-game-mode toggle"
  and .[0]["custom/game_mode"].signal == 9
  and (.[0]["custom/game_mode"] | has("interval") | not)' "$config" >/dev/null
grep -Fq 'waybarWithCaffeineSignal' 'nixos/profiles/hyprland.nix'
grep -Fq 'auto refresh(int) -> void override;' 'nixos/profiles/hyprland.nix'
grep -Fq 'kill -s 42 "$caffeine_waybar_pid"' 'dotfiles/config/profiles/hyprland/.local/bin/waybar-watch'
grep -Fq '#custom-ws_1.empty' 'dotfiles/config/profiles/hyprland/.config/waybar-hypr/style.css'
grep -Fq 'color: #8087a2;' 'dotfiles/config/profiles/hyprland/.config/waybar-hypr/style.css'
grep -Fq '#custom-ws_1.active' 'dotfiles/config/profiles/hyprland/.config/waybar-hypr/style.css'
grep -Fq 'color: #8aadf4;' 'dotfiles/config/profiles/hyprland/.config/waybar-hypr/style.css'

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/bin"
cat >"$tmp/bin/notify-send" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${CAFFEINE_NOTIFICATIONS:?}"
EOF
chmod +x "$tmp/bin/notify-send"
export CAFFEINE_NOTIFICATIONS="$tmp/caffeine-notifications"

XDG_STATE_HOME="$tmp/state" PATH="$tmp/bin:$PATH" "$caffeine_helper" toggle
[[ "$(XDG_STATE_HOME="$tmp/state" PATH="$tmp/bin:$PATH" "$caffeine_helper" status)" == activated ]]

XDG_STATE_HOME="$tmp/state" PATH="$tmp/bin:$PATH" "$caffeine_helper" toggle
[[ "$(XDG_STATE_HOME="$tmp/state" PATH="$tmp/bin:$PATH" "$caffeine_helper" status)" == deactivated ]]
grep -Fq 'Caffeine activado' "$CAFFEINE_NOTIFICATIONS"
grep -Fq 'Caffeine desactivado' "$CAFFEINE_NOTIFICATIONS"
printf '%s\n' 'hypr-waybar-profile: ok'
