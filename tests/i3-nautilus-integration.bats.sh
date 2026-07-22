#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/nixos/profiles/i3.nix"
SCRIPT="$ROOT/dotfiles/config/profiles/i3/.local/share/nautilus/scripts/Set as Wallpaper"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

grep -Eq '^[[:space:]]+colloid-icon-theme[[:space:]]*$' "$PROFILE" ||
  fail 'i3 must install the Colloid icon theme selected by GTK/Nautilus'
grep -Eq '^[[:space:]]+catppuccin-gtk[[:space:]]*$' "$PROFILE" ||
  fail 'i3 must install the selected Catppuccin GTK theme'
grep -Fq 'helper="${I3_WALLPAPER_HELPER:-$HOME/.local/bin/i3-wallpaper}"' "$SCRIPT" ||
  fail 'Nautilus action must not depend on its restricted PATH'
grep -Fq 'exec "$helper" --set' "$SCRIPT" || fail 'Nautilus action does not call the absolute helper'

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/home/.local/bin" "$tmp/images"
image="$tmp/images/wall paper.png"
: >"$image"
cat >"$tmp/home/.local/bin/i3-wallpaper" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$WALLPAPER_CAPTURE"
STUB
chmod +x "$tmp/home/.local/bin/i3-wallpaper"
HOME="$tmp/home" PATH="/run/current-system/sw/bin" WALLPAPER_CAPTURE="$tmp/capture" \
  NAUTILUS_SCRIPT_SELECTED_FILE_PATHS="$image" "$SCRIPT"
mapfile -t args <"$tmp/capture"
[[ "${args[0]:-}" == --set ]] || fail 'Nautilus action omitted --set'
[[ "${args[1]:-}" == "$image" ]] || fail 'Nautilus action corrupted selected path'

printf 'PASS: Nautilus receives selected icons and PATH-independent wallpaper action\n'
