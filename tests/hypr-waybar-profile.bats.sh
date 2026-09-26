#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

attr="path:$repo_dir#nixosConfigurations.lenovo-hyprland.config.home-manager.users.osmarg.home.file"
paths=(
  '.config/waybar-hypr/config'
  '.config/waybar-hypr/style.css'
  '.local/bin/orgm-visual-profile'
  '.local/bin/waybar-date-es'
  '.local/bin/waybar-day-month-es'
  '.local/bin/waybar-time-ampm'
  '.local/bin/waybar-watch'
  '.local/bin/waybar-caffeine-state'
  '.local/bin/hypr-game-mode'
  '.local/bin/hypr-reload-after-switch'
  '.local/bin/hypr-session-refresh'
)

for path in "${paths[@]}"; do
  source_layer='profiles/hyprland'
  [[ "$path" == '.local/bin/orgm-visual-profile' ]] && source_layer='shared'
  [[ -e "dotfiles/config/$source_layer/$path" ]]
  nix eval --raw "$attr.\"$path\".source" >/dev/null
done

home_files="$(nix eval --json "$attr")"
jq -e 'has(".config/waybar-hypr/orgm-current.css") | not' <<<"$home_files" >/dev/null
grep -Fxq '@import "orgm-current.css";' \
  'dotfiles/config/profiles/hyprland/.config/waybar-hypr/style.css'


caffeine_helper='dotfiles/config/profiles/hyprland/.local/bin/waybar-caffeine-state'
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
printf '%s\n' 'hypr-waybar-profile: ok'
