#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/dotfiles/config/shared/.local/bin/orgm-visual-profile"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[[ -x "$PROFILE" ]] || fail 'visual profile CLI missing or not executable'

HOME="$TMP/home"
XDG_STATE_HOME="$TMP/state"
XDG_CONFIG_HOME="$HOME/.config"
PICTURES="$TMP/pictures"
RUNTIME="$TMP/runtime"
CALLS="$TMP/calls"
DOCK_RELOAD_MARKER="$TMP/dock-reloaded"
mkdir -p "$TMP/bin" "$HOME" "$XDG_CONFIG_HOME" "$PICTURES" "$RUNTIME"
: >"$CALLS"

cat >"$TMP/bin/hypr-wallpaper" <<'EOF'
#!/usr/bin/env bash
printf 'hypr-wallpaper <dir:%s>' "${HYPR_WALLPAPER_DIR:-}" >>"$ORGM_VISUAL_PROFILE_TEST_CALLS"
printf ' <%s>' "$@" >>"$ORGM_VISUAL_PROFILE_TEST_CALLS"
printf '\n' >>"$ORGM_VISUAL_PROFILE_TEST_CALLS"
[[ "${ORGM_VISUAL_PROFILE_TEST_BACKEND_FAIL:-0}" != 1 ]] || exit 1
case "${1:-}" in
  set) selected="${2:?}" ;;
  random) selected="$(find "${2:?}" -type f -print -quit)" ;;
  *) exit 2 ;;
esac
mkdir -p "$XDG_STATE_HOME/hypr-wallpaper"
printf '%s\n' "$selected" >"$XDG_STATE_HOME/hypr-wallpaper/current"
EOF
cat >"$TMP/bin/i3-wallpaper" <<'EOF'
#!/usr/bin/env bash
printf 'i3-wallpaper <dir:%s>' "${I3_WALLPAPER_DIR:-}" >>"$ORGM_VISUAL_PROFILE_TEST_CALLS"
printf ' <%s>' "$@" >>"$ORGM_VISUAL_PROFILE_TEST_CALLS"
printf '\n' >>"$ORGM_VISUAL_PROFILE_TEST_CALLS"
[[ "${ORGM_VISUAL_PROFILE_TEST_BACKEND_FAIL:-0}" != 1 ]] || exit 1
case "${1:-}" in
  --set) selected="${2:?}" ;;
  --random) selected="$(find "${I3_WALLPAPER_DIR:?}" -type f -print -quit)" ;;
  *) exit 2 ;;
esac
mkdir -p "$XDG_STATE_HOME/i3"
printf '%s\n' "$selected" >"$XDG_STATE_HOME/i3/wallpaper"
EOF
cat >"$TMP/bin/gsettings" <<'EOF'
#!/usr/bin/env bash
printf 'gsettings' >>"$ORGM_VISUAL_PROFILE_TEST_CALLS"
printf ' <%s>' "$@" >>"$ORGM_VISUAL_PROFILE_TEST_CALLS"
printf '\n' >>"$ORGM_VISUAL_PROFILE_TEST_CALLS"
EOF
cat >"$TMP/bin/i3-msg" <<'EOF'
#!/usr/bin/env bash
printf 'i3-msg' >>"$ORGM_VISUAL_PROFILE_TEST_CALLS"
printf ' <%s>' "$@" >>"$ORGM_VISUAL_PROFILE_TEST_CALLS"
printf '\n' >>"$ORGM_VISUAL_PROFILE_TEST_CALLS"
EOF
cat >"$TMP/bin/rofi" <<'EOF'
#!/usr/bin/env bash
printf 'rofi' >>"$ORGM_VISUAL_PROFILE_TEST_CALLS"
printf ' <%s>' "$@" >>"$ORGM_VISUAL_PROFILE_TEST_CALLS"
printf '\n' >>"$ORGM_VISUAL_PROFILE_TEST_CALLS"
printf '%s\n' "${ORGM_VISUAL_PROFILE_TEST_ROFI_CHOICE:-}"
EOF
cat >"$TMP/bin/kitty" <<'EOF'
#!/usr/bin/env bash
printf 'kitty' >>"$ORGM_VISUAL_PROFILE_TEST_CALLS"
printf ' <%s>' "$@" >>"$ORGM_VISUAL_PROFILE_TEST_CALLS"
printf '\n' >>"$ORGM_VISUAL_PROFILE_TEST_CALLS"
EOF
cat >"$TMP/bin/hypr-nwg-dock-reload" <<'EOF'
#!/usr/bin/env bash
printf 'hypr-nwg-dock-reload\n' >>"$ORGM_VISUAL_PROFILE_TEST_CALLS"
: >"$ORGM_VISUAL_PROFILE_TEST_DOCK_MARKER"
EOF
cat >"$TMP/bin/dunstctl" <<'EOF'
#!/usr/bin/env bash
printf 'dunstctl' >>"$ORGM_VISUAL_PROFILE_TEST_CALLS"
printf ' <%s>' "$@" >>"$ORGM_VISUAL_PROFILE_TEST_CALLS"
printf '\n' >>"$ORGM_VISUAL_PROFILE_TEST_CALLS"
EOF
cat >"$TMP/bin/pgrep" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
cat >"$TMP/bin/pkill" <<'EOF'
#!/usr/bin/env bash
printf 'pkill' >>"$ORGM_VISUAL_PROFILE_TEST_CALLS"
printf ' <%s>' "$@" >>"$ORGM_VISUAL_PROFILE_TEST_CALLS"
printf '\n' >>"$ORGM_VISUAL_PROFILE_TEST_CALLS"
exit 1
EOF
chmod +x "$TMP/bin/"*

run_profile() {
  HOME="$HOME" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_STATE_HOME="$XDG_STATE_HOME" \
    XDG_RUNTIME_DIR="$RUNTIME" XDG_CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-Hyprland}" \
    ORGM_VISUAL_PROFILE_BACKEND="${ORGM_VISUAL_PROFILE_BACKEND:-hyprland}" \
    ORGM_VISUAL_PROFILE_PICTURES_ROOT="$PICTURES" \
    ORGM_VISUAL_PROFILE_TEST_CALLS="$CALLS" ORGM_VISUAL_PROFILE_TEST_DOCK_MARKER="$DOCK_RELOAD_MARKER" \
    PATH="$TMP/bin:$PATH" "$PROFILE" "$@"
}

# The first invocation establishes the stable default and all profile directories.
[[ "$(run_profile current)" == orgm ]] || fail 'default profile is not orgm'
for id in slc orgm osmar; do
  [[ -d "$PICTURES/$id" ]] || fail "picture directory for $id was not created"
done
[[ "$(<"$XDG_STATE_HOME/orgm-visual-profile/current")" == orgm ]] || fail 'current profile state missing'

# The visible profile identifier must agree with the Waybar class.
waybar_json="$(run_profile waybar)"
jq -e '.class == "orgm" and (.text | test("(^|[^A-Z])ORGM([^A-Z]|$)"))' <<<"$waybar_json" >/dev/null ||
  fail 'Waybar JSON does not visibly identify the selected profile'

# Every fixed profile generates a distinct runtime palette for all consumers.
declare -A palettes
for id in slc orgm osmar; do
  run_profile set "$id"
  [[ "$(run_profile current)" == "$id" ]] || fail "set did not select $id"
  for output in \
    "$XDG_CONFIG_HOME/waybar-hypr/orgm-current.css" \
    "$XDG_CONFIG_HOME/kitty/current-theme.conf" \
    "$XDG_CONFIG_HOME/nwg-dock-hyprland/current-theme.css" \
    "$XDG_CONFIG_HOME/dunst/dunstrc.d/90-visual-profile.conf" \
    "$XDG_CONFIG_HOME/gtk-3.0/settings.ini" \
    "$XDG_CONFIG_HOME/gtk-4.0/settings.ini"; do
    [[ -s "$output" && ! -L "$output" ]] || fail "$id did not generate runtime output $output"
  done
  grep -Fq 'frame_width = 0' "$XDG_CONFIG_HOME/dunst/dunstrc.d/90-visual-profile.conf" ||
    fail "$id generated a bordered Dunst profile"
  ! grep -Fq 'border: 1px' "$XDG_CONFIG_HOME/nwg-dock-hyprland/current-theme.css" ||
    fail "$id generated a bordered dock profile"
  palettes[$id]="$(cat "$XDG_CONFIG_HOME/waybar-hypr/orgm-current.css" "$XDG_CONFIG_HOME/kitty/current-theme.conf" "$XDG_CONFIG_HOME/nwg-dock-hyprland/current-theme.css" "$XDG_CONFIG_HOME/dunst/dunstrc.d/90-visual-profile.conf")"
  jq -e --arg id "$id" '.class == $id and (.text | test("(^|[^A-Z])" + ($id | ascii_upcase) + "([^A-Z]|$)"))' <<<"$(run_profile waybar)" >/dev/null ||
    fail "Waybar label and class do not agree with the selected profile $id"
done
[[ "${palettes[slc]}" != "${palettes[orgm]}" ]] || fail 'slc and orgm palettes are identical'
[[ "${palettes[orgm]}" != "${palettes[osmar]}" ]] || fail 'orgm and osmar palettes are identical'
[[ "${palettes[slc]}" != "${palettes[osmar]}" ]] || fail 'slc and osmar palettes are identical'

rm -f "$DOCK_RELOAD_MARKER"
mkdir -p "$XDG_STATE_HOME/nwg-dock-hyprland"
printf 'fixture\n' >"$XDG_STATE_HOME/nwg-dock-hyprland/dock.pid"
run_profile apply
for _ in {1..20}; do
  [[ -e "$DOCK_RELOAD_MARKER" ]] && break
  sleep 0.01
done
[[ -e "$DOCK_RELOAD_MARKER" ]] || fail 'Hyprland profile apply did not request a dock reload'
grep -Fq 'dunstctl <reload>' "$CALLS" ||
  fail 'profile apply did not reload Dunst'

# GTK mode is durable and scoped to each profile.
run_profile set slc
[[ "$(<"$XDG_STATE_HOME/orgm-visual-profile/profiles/slc/mode")" == dark ]] || fail 'new profile does not default to dark mode'
run_profile toggle-mode
[[ "$(<"$XDG_STATE_HOME/orgm-visual-profile/profiles/slc/mode")" == light ]] || fail 'toggle did not persist slc light mode'
grep -Fq 'gsettings <set> <org.gnome.desktop.interface> <color-scheme> <prefer-light>' "$CALLS" ||
  fail 'toggle did not apply the persisted GTK light mode through gsettings'
run_profile set orgm
[[ "$(<"$XDG_STATE_HOME/orgm-visual-profile/profiles/orgm/mode")" == dark ]] || fail 'mode leaked from slc to orgm'
run_profile set slc
[[ "$(<"$XDG_STATE_HOME/orgm-visual-profile/profiles/slc/mode")" == light ]] || fail 'slc mode was not restored'

# Recording wallpaper is profile-local and a subsequent selection restores it through its backend.
slc_wallpaper="$PICTURES/slc/slc.png"
orgm_wallpaper="$PICTURES/orgm/orgm.png"
printf 'slc' >"$slc_wallpaper"
printf 'orgm' >"$orgm_wallpaper"
run_profile record-wallpaper "$slc_wallpaper"
[[ "$(<"$XDG_STATE_HOME/orgm-visual-profile/profiles/slc/wallpaper")" == "$slc_wallpaper" ]] ||
  fail 'slc wallpaper was not recorded'
run_profile set orgm
run_profile record-wallpaper "$orgm_wallpaper"
run_profile set slc
[[ "$(<"$XDG_STATE_HOME/hypr-wallpaper/current")" == "$slc_wallpaper" ]] ||
  fail 'selecting slc did not restore its recorded wallpaper through Hyprland'

# Switching repeatedly must preserve each target's wallpaper, not replace it
# with the previously active profile's wallpaper. Exercise both backends.
osmar_wallpaper="$PICTURES/osmar/osmar.png"
printf 'osmar' >"$osmar_wallpaper"
for backend in hyprland i3; do
  case "$backend" in
    hyprland) wallpaper_state="$XDG_STATE_HOME/hypr-wallpaper/current" ;;
    i3) wallpaper_state="$XDG_STATE_HOME/i3/wallpaper" ;;
  esac
  for id in osmar orgm slc osmar orgm slc; do
    ORGM_VISUAL_PROFILE_BACKEND="$backend" run_profile set "$id"
    expected="$PICTURES/$id/$id.png"
    [[ "$(<"$wallpaper_state")" == "$expected" ]] ||
      fail "$backend did not apply $id's own wallpaper"
    for saved_id in slc orgm osmar; do
      [[ "$(<"$XDG_STATE_HOME/orgm-visual-profile/profiles/$saved_id/wallpaper")" == "$PICTURES/$saved_id/$saved_id.png" ]] ||
        fail "$backend overwrote $saved_id's saved wallpaper while selecting $id"
    done
  done
done

# i3bar must follow the persisted selection made by the real profile helper,
# not a mocked return value or a fixed display label.
mkdir -p "$HOME/.local/bin"
ln -s "$PROFILE" "$HOME/.local/bin/orgm-visual-profile"
HOME="$HOME" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_STATE_HOME="$XDG_STATE_HOME" \
  ORGM_VISUAL_PROFILE_BACKEND=i3 ORGM_VISUAL_PROFILE_PICTURES_ROOT="$PICTURES" \
  ORGM_VISUAL_PROFILE_TEST_CALLS="$CALLS" PATH="$TMP/bin:$PATH" \
  PYTHONDONTWRITEBYTECODE=1 python3 - "$ROOT/dotfiles/config/profiles/i3/.local/bin/i3status-localized" "$PROFILE" <<'PY'
from importlib.machinery import SourceFileLoader
import importlib.util
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

loader = SourceFileLoader("i3_profile_selection", sys.argv[1])
spec = importlib.util.spec_from_loader(loader.name, loader)
bar = importlib.util.module_from_spec(spec)
loader.exec_module(bar)
for selected in ("orgm", "osmar", "slc"):
    subprocess.run([sys.argv[2], "set", selected], check=True)
    block = bar.visual_profile_block()
    assert block["name"] == "visual-profile"
    assert block["instance"] == selected, "i3bar does not reflect the persisted selection"
    visible = "".join(ET.fromstring("<label>" + block["full_text"] + "</label>").itertext())
    visible_profiles = set(re.findall(r"\b(?:SLC|ORGM|OSMAR)\b", visible))
    assert visible_profiles == {selected.upper()}, "i3bar visibly identifies a different profile"
PY

# Random wallpaper delegates to the active profile folder on both supported desktops.
: >"$CALLS"
run_profile random-wallpaper
grep -Fq "$PICTURES/slc" "$CALLS" || fail 'Hyprland random wallpaper did not use slc folder'
: >"$CALLS"
XDG_CURRENT_DESKTOP=i3 ORGM_VISUAL_PROFILE_BACKEND=i3 run_profile random-wallpaper
grep -Fq 'i3-wallpaper' "$CALLS" || fail 'i3 random wallpaper did not use i3 backend'
grep -Fq "$PICTURES/slc" "$CALLS" || fail 'i3 random wallpaper did not use slc folder'

XDG_CURRENT_DESKTOP=i3 ORGM_VISUAL_PROFILE_BACKEND=i3 run_profile apply
grep -Fq 'i3-msg <reload>' "$CALLS" || fail 'i3 profile apply did not request a best-effort reload'

# The visual selector uses Rofi and only accepts the fixed allowlist.
: >"$CALLS"
ORGM_VISUAL_PROFILE_TEST_ROFI_CHOICE=osmar run_profile menu
[[ "$(run_profile current)" == osmar ]] || fail 'menu selection did not set osmar'
grep -Fq 'rofi' "$CALLS" || fail 'menu did not open Rofi'

# Invalid input must fail before changing an existing state file.
state_before="$(find "$XDG_STATE_HOME/orgm-visual-profile" -type f -print -exec cat {} \;)"
if run_profile set '../../not-a-profile' >/dev/null 2>&1; then
  fail 'invalid profile unexpectedly succeeded'
fi
state_after="$(find "$XDG_STATE_HOME/orgm-visual-profile" -type f -print -exec cat {} \;)"
[[ "$state_after" == "$state_before" ]] || fail 'failed profile change truncated or altered state'
# An invalid backend must fail before a profile transition mutates state.
state_before="$(find "$XDG_STATE_HOME/orgm-visual-profile" -type f -print -exec cat {} \;)"
if ORGM_VISUAL_PROFILE_BACKEND=invalid run_profile set slc >/dev/null 2>&1; then
  fail 'unsupported backend unexpectedly succeeded'
fi
state_after="$(find "$XDG_STATE_HOME/orgm-visual-profile" -type f -print -exec cat {} \;)"
[[ "$state_after" == "$state_before" ]] ||
  fail 'unsupported backend altered persisted profile state'


# Backend failure must leave current and every saved wallpaper unchanged.
# Exercise the same transaction boundary on Hyprland and i3.
for backend in hyprland i3; do
  state_before="$(find "$XDG_STATE_HOME/orgm-visual-profile" -type f -print -exec cat {} \;)"
  if ORGM_VISUAL_PROFILE_BACKEND="$backend" ORGM_VISUAL_PROFILE_TEST_BACKEND_FAIL=1 run_profile set orgm >/dev/null 2>&1; then
    fail "$backend profile selection unexpectedly succeeded after wallpaper backend failure"
  fi
  state_after="$(find "$XDG_STATE_HOME/orgm-visual-profile" -type f -print -exec cat {} \;)"
  [[ "$state_after" == "$state_before" ]] ||
    fail "$backend wallpaper backend failure altered persisted profile state"
done

printf 'PASS: visual profiles persist fixed palettes, modes, and profile wallpapers safely\n'
