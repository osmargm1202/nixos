#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/nixos/profiles/i3/i3.nix"
HELPER="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-picom-effects"
WRAPPER="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3status-localized"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[ -x "$HELPER" ] || fail 'Picom effects helper missing or not executable'
grep -Fq 'picom-pijulius' "$PROFILE" || fail 'i3 must install Picom with animation support'
grep -Fq 'systemd.user.services.picom' "$PROFILE" || fail 'i3 must supervise Picom as a user service'
grep -Fq 'corner-radius = 12;' "$PROFILE" || fail 'Picom normal mode must restore rounded corners'
grep -Fq 'blur-method = "dual_kawase";' "$PROFILE" || fail 'Picom normal mode must restore blur'
grep -Fq 'triggers = [ "open", "show" ];' "$PROFILE" || fail 'Picom normal mode must restore open animation'
grep -Fq 'class_g = '\''i3lock'\''' "$PROFILE" || fail 'i3lock must keep instant Picom transitions'

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/home"
cat >"$tmp/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$PICOM_CALLS"
EOF
cat >"$tmp/bin/notify-send" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$PICOM_NOTIFICATIONS"
EOF
chmod +x "$tmp/bin/systemctl" "$tmp/bin/notify-send"

HOME="$tmp/home" PATH="$tmp/bin:$PATH" PICOM_CALLS="$tmp/calls" PICOM_NOTIFICATIONS="$tmp/notifications" "$HELPER" status | grep -Fxq enabled
HOME="$tmp/home" PATH="$tmp/bin:$PATH" PICOM_CALLS="$tmp/calls" PICOM_NOTIFICATIONS="$tmp/notifications" "$HELPER" toggle
[ -f "$tmp/home/.local/state/i3/picom-effects-disabled" ] || fail 'disabling effects must persist across Picom restarts'
grep -Fxq -- '--user stop picom' "$tmp/calls" || fail 'disabling effects must stop Picom'
HOME="$tmp/home" PATH="$tmp/bin:$PATH" PICOM_CALLS="$tmp/calls" PICOM_NOTIFICATIONS="$tmp/notifications" "$HELPER" status | grep -Fxq disabled
HOME="$tmp/home" PATH="$tmp/bin:$PATH" PICOM_CALLS="$tmp/calls" PICOM_NOTIFICATIONS="$tmp/notifications" "$HELPER" toggle
[ ! -e "$tmp/home/.local/state/i3/picom-effects-disabled" ] || fail 'enabling effects must clear persisted disabled state'
grep -Fxq -- '--user restart picom' "$tmp/calls" || fail 'enabling effects must restart Picom'

python3 - "$WRAPPER" <<'PY'
import importlib.machinery
import importlib.util
import sys
from pathlib import Path

loader = importlib.machinery.SourceFileLoader("i3status_localized", sys.argv[1])
spec = importlib.util.spec_from_loader(loader.name, loader)
wrapper = importlib.util.module_from_spec(spec)
loader.exec_module(wrapper)
state = Path("/tmp/i3-picom-effects-test")
state.unlink(missing_ok=True)
wrapper.PICOM_EFFECTS_STATE = state
assert wrapper.picom_effects_block()["name"] == "picom-effects"
assert wrapper.picom_effects_block()["instance"] == "enabled"
state.touch()
assert wrapper.picom_effects_block()["instance"] == "disabled"
calls = []
wrapper.subprocess.Popen = lambda command, **_kwargs: calls.append(command)
wrapper.click_action({"name": "picom-effects", "button": 1})
assert calls[0][-1] == "toggle"

# The lightweight variation retains the shared status presentation without an
# effects control for a compositor which is deliberately absent.
wrapper.SHOW_PICOM_EFFECTS = False
calls.clear()
wrapper.click_action({"name": "picom-effects", "button": 1})
assert calls == []
wrapper.keyboard_block = lambda: {"name": "keyboard", "full_text": " US", "color": wrapper.NORMAL}
wrapper.system_battery = lambda: None
cpu = type("Cpu", (), {"percent": lambda self: 20})()
blocks = wrapper.decorate([
    {"name": "wireless", "full_text": "10.0.0.63"},
    {"name": "ethernet", "full_text": "down"},
    {"name": "battery all", "full_text": "BAT 87%"},
    {"name": "tztime", "full_text": "Wednesday 28 - October - 2026 / 28-10-26 | 3:45 AM"},
], cpu)
assert [block["name"] for block in blocks] == [
    "wireless", "ethernet", "battery all", "keyboard", "caffeine", "cpu", "memory", "disk", "tztime"
]
assert blocks[0]["color"] == wrapper.NETWORK and blocks[0]["full_text"] == f"{wrapper.ICON_WIFI} 10.0.0.63"
assert blocks[2]["color"] == wrapper.NORMAL
assert blocks[-1]["full_text"] == "Miércoles 28 - Octubre - 2026 / 28-10-26 | 3:45 AM"
PY

bash -n "$HELPER"
printf '%s\n' 'i3-picom-effects: ok'
