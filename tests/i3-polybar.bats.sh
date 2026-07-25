#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/nixos/profiles/i3.nix"
I3="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
DOTFILES="$ROOT/nixos/common-dotfiles.nix"
LAUNCHER="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-polybar"
SELECTOR="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-polybar-theme"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[[ -x "$LAUNCHER" ]] || fail 'Polybar launcher missing or not executable'
[[ -x "$SELECTOR" ]] || fail 'Polybar theme selector missing or not executable'
bash -n "$LAUNCHER"
bash -n "$SELECTOR"
! grep -Fqi 'eww' "$PROFILE" "$I3" "$DOTFILES" || fail 'Eww integration remains'
grep -Eq '^[[:space:]]+polybar[[:space:]]*$' "$PROFILE" || fail 'Polybar package missing'
grep -Eq '^[[:space:]]+networkmanager_dmenu[[:space:]]*$' "$PROFILE" ||
  fail 'networkmanager_dmenu dependency missing'
grep -Fq 'pkill -x eww' "$LAUNCHER" || fail 'Polybar migration does not stop the Eww daemon'
grep -Fq 'https://github.com/adi1090x/polybar-themes.git' "$LAUNCHER" ||
  fail 'Polybar themes do not use the requested upstream repository'
grep -Fq 'git clone --depth 1 --branch master' "$LAUNCHER" ||
  fail 'Polybar upstream is not cloned directly'
grep -Fq 'tray-position = right' "$LAUNCHER" || fail 'Zorin tray is not enabled'
grep -Fq 'i3-polybar-theme select' "$LAUNCHER" || fail 'Zorin style control does not open the theme selector'
grep -Fq 'current' "$LAUNCHER" || fail 'selected theme is not persisted'
grep -Fq 'Polybar theme' "$SELECTOR" || fail 'selector does not use the existing Rofi UI'
grep -Fq 'Zorin (Panels)' "$SELECTOR" || fail 'Zorin is not the default Panels choice'

for theme in blocks colorblocks cuts docky forest grayblocks hack material panels pwidgets shades shapes; do
  grep -Fq "$theme" "$LAUNCHER" || fail "$theme is not launchable"
done

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/home/.local/bin"
cat >"$TMP/bin/i3-rofi" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "${THEME_CHOICE:-Material}"
STUB
cat >"$TMP/home/.local/bin/i3-polybar" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$POLYBAR_ARGS"
STUB
chmod +x "$TMP/bin/i3-rofi" "$TMP/home/.local/bin/i3-polybar"
while IFS='|' read -r label theme; do
  THEME_CHOICE="$label" HOME="$TMP/home" XDG_STATE_HOME="$TMP/state" PATH="$TMP/bin:$PATH" POLYBAR_ARGS="$TMP/args" \
    "$SELECTOR" select
  [[ "$(<"$TMP/state/polybar-themes/current")" == "$theme" ]] ||
    fail "$label selection was not persisted as $theme"
  [[ "$(<"$TMP/args")" == 'start --no-sync' ]] ||
    fail "$label selection did not relaunch Polybar"
done <<'THEMES'
Zorin (Panels)|panels
Blocks|blocks
Colorblocks|colorblocks
Cuts|cuts
Docky|docky
Forest|forest
Grayblocks|grayblocks
Hack|hack
Material|material
Pwidgets|pwidgets
Shades|shades
Shapes|shapes
THEMES

printf 'PASS: i3 uses persistent, selectable upstream Polybar themes with Zorin tray\n'
