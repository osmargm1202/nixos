#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/nixos/profiles/i3.nix"
CONFIG="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
THEME="$ROOT/dotfiles/config/profiles/i3/.config/bumblebee-status/themes/i3-nord-powerline.json"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

picom_config="$(awk '
  /picomConfig = pkgs\.writeText/ { active = 1 }
  active { print }
  active && /^  '\''\{2\};$/ { exit }
' "$PROFILE")"
picom_service="$(awk '
  /systemd\.user\.services\.picom = \{/ { active = 1 }
  active { print }
  active && /^  \};$/ { exit }
' "$PROFILE")"

[[ -n "$picom_config" ]] || fail 'declarative Picom config missing'
[[ -n "$picom_service" ]] || fail 'Picom user service missing'
grep -Fq 'ExecStart = "${lib.getExe pkgs.picom-pijulius} --config ${picomConfig}";' <<<"$picom_service" ||
  fail 'service does not use animation-capable Picom with generated config'
grep -Eq '^[[:space:]]+picom-pijulius[[:space:]]*$' "$PROFILE" || fail 'Picom package missing'
grep -Fq 'backend = "glx";' <<<"$picom_config" || fail 'GLX backend missing'
grep -Fq 'vsync = true;' <<<"$picom_config" || fail 'Picom VSync missing'
grep -Fq 'shadow = true;' <<<"$picom_config" || fail 'window shadows missing'
grep -Fq 'corner-radius = 12;' <<<"$picom_config" || fail 'rounded corners missing'
grep -Fq 'blur-method = "dual_kawase";' <<<"$picom_config" || fail 'dual Kawase blur missing'
grep -Fq 'blur-background = true;' <<<"$picom_config" || fail 'background blur missing'

# This nixpkgs pin serializes Nix lists as libconfig arrays. Composite groups
# must therefore be emitted directly with parentheses or Picom cannot parse them.
grep -Fq 'animations = ({' <<<"$picom_config" || fail 'animations are not a libconfig group list'
grep -Fq 'rules = ({' <<<"$picom_config" || fail 'rules are not a libconfig group list'
! grep -Eq '^[[:space:]]+(animations|rules) = \[$' <<<"$picom_config" ||
  fail 'composite Picom lists use invalid square-bracket serialization'
for preset in appear disappear geometry-change; do
  grep -Fq "preset = \"$preset\";" <<<"$picom_config" || fail "$preset animation missing"
done

grep -Fq 'match = "!focused && !group_focused";' <<<"$picom_config" ||
  fail 'inactive transparency rule missing'
grep -A1 -F 'match = "!focused && !group_focused";' <<<"$picom_config" | grep -Fq 'opacity = 0.84;' ||
  fail 'inactive transparency is not visibly translucent'
grep -Fq 'match = "focused || group_focused";' <<<"$picom_config" || fail 'active transparency rule missing'
grep -A1 -F 'match = "focused || group_focused";' <<<"$picom_config" | grep -Fq 'opacity = 0.92;' ||
  fail 'active transparency is not visibly translucent'
! grep -Eq 'activeOpacity|inactiveOpacity|active-opacity|inactive-opacity' "$PROFILE" ||
  fail 'legacy opacity options are ineffective when Picom rules are enabled'

grep -Fq 'match = "window_type = '\''dock'\''";' <<<"$picom_config" || fail 'dock/i3bar rule missing'
fullscreen_rule="$(awk '
  /match = "fullscreen";/ { active = 1 }
  active { print }
  active && /match = "window_type = '\''desktop'\''";/ { exit }
' <<<"$picom_config")"
for setting in 'opacity = 1.0;' 'corner-radius = 0;' 'shadow = false;' 'blur-background = false;'; do
  grep -Fq "$setting" <<<"$fullscreen_rule" || fail "fullscreen safety rule lacks $setting"
done

grep -Fq 'match = "class_g = '\''i3lock'\''";' <<<"$picom_config" || fail 'secure lock exception missing'
lock_rule="$(awk '
  /match = "class_g = '\''i3lock'\''";/ { active = 1 }
  active { print }
  active && /match = "window_type = '\''tooltip'\''/ { exit }
' <<<"$picom_config")"
for setting in 'opacity = 1.0;' 'corner-radius = 0;' 'shadow = false;' 'blur-background = false;' 'fade = false;'; do
  grep -Fq "$setting" <<<"$lock_rule" || fail "lock safety rule lacks $setting"
done
[[ "$(grep -Fc 'duration = 0.001;' <<<"$lock_rule")" -eq 2 ]] ||
  fail 'both lock open and close animations must remain effectively instant'

grep -Fq 'exec --no-startup-id systemctl --user start picom.service' "$CONFIG" ||
  fail 'i3 does not explicitly start Picom'
grep -Fq 'i3bar_command i3bar --transparency' "$CONFIG" || fail 'i3bar transparency mode missing'
grep -Fq 'background #1a1b268f' "$CONFIG" || fail 'i3bar background is not sufficiently translucent'
! grep -Eq 'for_window \[class="org\.gnome\.Nautilus"\].*floating enable' "$CONFIG" ||
  fail 'Nautilus is still forced floating'

[[ -f "$THEME" ]] || fail 'translucent Bumblebee theme missing'
jq -e '
  (.cycle | length) > 0 and
  all(.cycle[]; (.bg | test("^#[0-9A-Fa-f]{6}B3$"))) and
  .defaults.warning.bg == "#D08770B3" and
  .defaults.critical.bg == "#BF616AB3" and
  .defaults["separator-block-width"] == 0
' "$THEME" >/dev/null || fail 'Bumblebee theme backgrounds are not translucent RGBA colors'

grep -Fq 'i3TranslucentTheme = ' "$PROFILE" || fail 'Bumblebee package does not embed translucent theme'
grep -Fq 'i3-nord-powerline.json' "$PROFILE" || fail 'translucent theme is not packaged'

printf 'PASS: i3 tiles Nautilus and uses animated blurred translucent Picom visuals\n'
