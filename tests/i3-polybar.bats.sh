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
grep -Fq 'type = internal/tray' "$LAUNCHER" || fail 'all themes require the Polybar tray module'
grep -Fq 'enable_tray_module()' "$LAUNCHER" || fail 'theme tray configuration missing'
grep -Fq 'enable_tray_module panels "$config_root/panels"' "$LAUNCHER" ||
  fail 'rendered panel variants do not receive the tray module'
grep -Fq 'pkill -x polybar 2>/dev/null || true' "$LAUNCHER" ||
  fail 'Pwidgets must use the available process controller'
grep -Fq 'prepare_theme()' "$LAUNCHER" || fail 'theme runtime preparation missing'
grep -Fq 'panel_styles=(' "$LAUNCHER" || fail 'upstream panel styles are not launchable'
grep -Fq 'i3-polybar-theme select' "$LAUNCHER" || fail 'panel style control does not open the theme selector'
grep -Fq 'current' "$LAUNCHER" || fail 'selected theme is not persisted'
grep -Fq 'themes_runtime="$state_root/themes"' "$LAUNCHER" ||
  fail 'scaled runtime Polybar theme tree missing'
grep -Fq 'scale_font_file()' "$LAUNCHER" || fail 'Polybar font scaling is not applied'
grep -Fq 'BASH_REMATCH[3] + 2' "$LAUNCHER" || fail 'Polybar font increase must be two points'
grep -Fq 'render-version' "$LAUNCHER" || fail 'render changes do not rebuild runtime themes'
grep -Fq 'Polybar theme' "$SELECTOR" || fail 'selector does not use the existing Rofi UI'
for style in budgie deepin elementary elementary_dark gnome kde kde_dark liri mint ubuntu_gnome ubuntu_unity xubuntu zorin; do
  grep -Fq "panels:$style" "$SELECTOR" || fail "panel style missing from selector: $style"
done

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
Zorin (Panels)|panels:zorin
Budgie (Panels)|panels:budgie
Deepin (Panels)|panels:deepin
Elementary (Panels)|panels:elementary
Elementary Dark (Panels)|panels:elementary_dark
GNOME (Panels)|panels:gnome
KDE (Panels)|panels:kde
KDE Dark (Panels)|panels:kde_dark
Liri (Panels)|panels:liri
Mint (Panels)|panels:mint
Ubuntu GNOME (Panels)|panels:ubuntu_gnome
Ubuntu Unity (Panels)|panels:ubuntu_unity
Xubuntu (Panels)|panels:xubuntu
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
