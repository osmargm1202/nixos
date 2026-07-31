#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$repo_dir/dotfiles/config/profiles/hyprland/.local/bin/hypr-wallpaper"
current_script="$repo_dir/dotfiles/config/profiles/hyprland/.local/bin/hypr-current-wallpaper"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

bin="$tmp/bin"
home="$tmp/home"
runtime="$tmp/runtime"
state="$tmp/state"
mkdir -p "$bin" "$home/Pictures/Wallpapers" "$runtime" "$state"
printf 'fallback' >"$home/Pictures/Wallpapers/xnm1-background.png"

cat >"$bin/hyprpaper" <<'EOF'
#!/usr/bin/env bash
touch "$HYPRPAPER_READY"
EOF
cat >"$bin/hyprctl" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == 'hyprpaper listactive' ]]; then
  [[ -f "$HYPRPAPER_READY" ]] || exit 1
  exit 0
fi
printf '%s\n' "$*" >>"$HYPRPAPER_CALLS"
EOF
chmod +x "$bin/hyprpaper" "$bin/hyprctl"

export HOME="$home"
export XDG_RUNTIME_DIR="$runtime"
export XDG_STATE_HOME="$state"
export PATH="$bin:$PATH"
export HYPRPAPER_READY="$tmp/hyprpaper-ready"
export HYPRPAPER_CALLS="$tmp/hyprpaper-calls"
export HYPRCTL_BIN="$bin/hyprctl"
export HYPRPAPER_BIN="$bin/hyprpaper"

"$script" restore
fallback="$home/Pictures/Wallpapers/xnm1-background.png"
[[ "$(<"$state/hypr-wallpaper/current")" == "$fallback" ]]
[[ "$(readlink "$runtime/hypr-current-wallpaper")" == "$fallback" ]]
grep -Fq ", $fallback, cover" "$HYPRPAPER_CALLS"
rm "$state/hypr-wallpaper/current"
"$current_script" >/dev/null
[[ "$(readlink "$runtime/hypr-current-wallpaper")" == "$fallback" ]]

custom_dir="$home/Custom-Wallpapers"
mkdir -p "$custom_dir"
printf 'custom' >"$custom_dir/custom.webp"
"$script" random "$custom_dir"
custom="$custom_dir/custom.webp"
[[ "$(<"$state/hypr-wallpaper/current")" == "$custom" ]]
[[ "$(readlink "$runtime/hypr-current-wallpaper")" == "$custom" ]]
grep -Fq ", $custom, cover" "$HYPRPAPER_CALLS"

default_dir="$home/Pictures/Wallpapers"
"$script" random
default="$default_dir/xnm1-background.png"
[[ "$(<"$state/hypr-wallpaper/current")" == "$default" ]]
grep -Fq ", $default, cover" "$HYPRPAPER_CALLS"

printf '%s\n' 'hypr-minimal-wallpaper: ok'
