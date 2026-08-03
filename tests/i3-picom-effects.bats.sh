#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/nixos/profiles/i3.nix"
STATUS_WRAPPER="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3status-localized"
CONFIG="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"

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
grep -Fq 'systemd.user.services.picom = {' "$PROFILE" ||
  fail 'Picom user service missing'
[[ -n "$picom_service" ]] || fail 'Picom user service is empty'
grep -Fq 'ExecStart = "${lib.getExe pkgs.picom-pijulius} --config ${picomConfig}";' <<<"$picom_service" ||
  fail 'Picom user service does not use animation-capable Picom with generated config'
grep -Fq 'pkgs."picom-pijulius"' "$PROFILE" ||
  fail 'Picom package missing from i3 profile'
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
grep -A1 -F 'rules = ({' <<<"$picom_config" | grep -Fq 'animations = ({' ||
  fail 'default Picom window rule does not animate every window'
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
  fail 'i3 must start the Picom user service'
grep -Fq 'bar {' "$CONFIG" || fail 'native i3bar configuration missing'
grep -Fq 'status_command ~/.local/bin/i3status-localized' "$CONFIG" ||
  fail 'native i3bar must use the localized i3status wrapper'
grep -Fq '["i3status", "-c", str(Path.home() / ".config" / "i3" / "i3status.conf")],' "$STATUS_WRAPPER" ||
  fail 'localized i3status wrapper must launch i3status'
! grep -Fqi 'i3blocks' "$PROFILE" "$CONFIG" ||
  fail 'i3blocks integration remains'
! grep -Eqi 'bumblebee|i3-nord-powerline' "$PROFILE" "$CONFIG" || fail 'obsolete Bumblebee theme integration remains'

printf 'PASS: i3 uses animated blurred translucent Picom visuals\n'
