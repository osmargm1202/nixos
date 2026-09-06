#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/config/profiles/hyprland/.local/bin/hypr-transition-menu"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/config/rofi"
CALLS="$TMP/calls.log"
: >"$CALLS"
fail() { echo "FAIL: $*" >&2; cat "$CALLS" >&2; exit 1; }

cat >"$TMP/bin/rofi" <<'SH'
#!/usr/bin/env bash
printf '%s\n' 'limefrenzy - HyDE vertical slide'
SH
chmod +x "$TMP/bin/rofi"
for cmd in hyprctl notify-send; do
  cat >"$TMP/bin/$cmd" <<'SH'
#!/usr/bin/env bash
echo "$(basename "$0") $*" >>"$CALLS"
SH
  chmod +x "$TMP/bin/$cmd"
done

export PATH="$TMP/bin:$PATH" XDG_CONFIG_HOME="$TMP/config" CALLS HYPR_ROFI_LIB="$TMP/missing-rofi-lib"
printf 'HYPR_ROFI_SCALE=1.25\nHYPR_WORKSPACE_ANIMATION=slide\nOTHER_SETTING=keepme\n' >"$TMP/config/rofi/hypr-menu.env"
bash "$SCRIPT"

grep -Fq 'HYPR_WORKSPACE_ANIMATION=limefrenzy' "$TMP/config/rofi/hypr-menu.env" || fail "preset not saved"
[ "$(grep -Fc 'HYPR_WORKSPACE_ANIMATION=' "$TMP/config/rofi/hypr-menu.env")" -eq 1 ] || fail "preset line should be replaced once"
grep -Fq 'HYPR_ROFI_SCALE=1.25' "$TMP/config/rofi/hypr-menu.env" || fail "existing rofi setting not preserved"
grep -Fq 'OTHER_SETTING=keepme' "$TMP/config/rofi/hypr-menu.env" || fail "other settings not preserved"
grep -Fq 'hyprctl setenv HYPR_WORKSPACE_ANIMATION limefrenzy' "$CALLS" || fail "hyprctl setenv not called"
grep -Fq 'hyprctl reload' "$CALLS" || fail "hyprctl reload not called"

echo "hypr transition menu test passed"
