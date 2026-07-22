#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/nixos/profiles/i3.nix"
MODULE="$ROOT/nixos/common-dotfiles.nix"
SCRIPT="$ROOT/dotfiles/config/profiles/i3/.local/share/nautilus/scripts/Set as Wallpaper"
I3_CONFIG="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"

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
grep -Fq 'exec "$helper" --set-active' "$SCRIPT" ||
  fail 'Nautilus action does not target the pointer/focused monitor'
[[ -x "$SCRIPT" ]] || fail 'Nautilus wallpaper action source is not executable'
! grep -Eq 'for_window \[class="org\.gnome\.Nautilus"\].*floating enable' "$I3_CONFIG" ||
  fail 'Nautilus must use normal i3 tiling'
activation="$(awk '
  /home\.activation\.installI3NautilusScripts =/ { active = 1 }
  active { print }
  active && /^      # / { exit }
' "$MODULE")"
grep -Fq 'entryAfter [ "linkGeneration" ]' <<<"$activation" || fail 'Nautilus action installs before Home Manager links'
grep -Fq '+ lib.optionalString (profileName == "i3")' <<<"$activation" || fail 'Nautilus action copy is not i3-only'
grep -Fq 'rm -f "$target"' <<<"$activation" || fail 'Nautilus action does not replace unsupported/stale deployment'
grep -Fq 'install -Dm755 "$source" "$target"' <<<"$activation" || fail 'Nautilus action is not installed as a real executable file'
cleanup_line="$(grep -n 'rm -f "$target"' <<<"$activation" | cut -d: -f1)"
i3_guard_line="$(grep -n '+ lib.optionalString (profileName == "i3")' <<<"$activation" | cut -d: -f1)"
[[ "$cleanup_line" -lt "$i3_guard_line" ]] || fail 'non-i3 profile switch does not remove stale wallpaper action'

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
[[ "${args[0]:-}" == --set-active ]] || fail 'Nautilus action omitted --set-active'
[[ "${args[1]:-}" == "$image" ]] || fail 'Nautilus action corrupted selected path'

printf 'PASS: Nautilus receives selected icons and PATH-independent wallpaper action\n'
