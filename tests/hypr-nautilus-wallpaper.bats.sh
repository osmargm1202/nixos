#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$repo_dir/dotfiles/config/profiles/hyprland/.local/share/nautilus/scripts/Set as Hyprland Wallpaper"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

image="$tmp/selected image.png"
helper="$tmp/hypr-wallpaper"
received="$tmp/received"
printf 'image' >"$image"
cat >"$helper" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$RECEIVED"
EOF
chmod +x "$helper"

HOME="$tmp/home" \
PATH=/usr/bin:/bin \
RECEIVED="$received" \
HYPR_WALLPAPER_HELPER="$helper" \
NAUTILUS_SCRIPT_SELECTED_FILE_PATHS="$image" \
"$script"

[[ "$(<"$received")" == "set $image" ]]
printf '%s\n' 'hypr-nautilus-wallpaper: ok'
