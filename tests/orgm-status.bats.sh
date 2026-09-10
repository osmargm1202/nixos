#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER="$ROOT/dotfiles/config/shared/.local/bin/orgm-status"
I3_WRAPPER="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3status-localized"
WAYBAR_CONFIG="$ROOT/dotfiles/config/profiles/hyprland/.config/waybar-hypr/config"
WAYBAR_STYLE="$ROOT/dotfiles/config/profiles/hyprland/.config/waybar-hypr/style.css"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[ -x "$HELPER" ] || fail 'shared ORGM status helper missing or not executable'
python3 - "$HELPER" <<'PY'
import contextlib
import importlib.util
from importlib.machinery import SourceFileLoader
import io
import json
import sys

path = sys.argv[1]
loader = SourceFileLoader("orgm_status", path)
spec = importlib.util.spec_from_loader(loader.name, loader)
module = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = module
loader.exec_module(module)
snapshot = module.Snapshot({"nextcloud": "up", "fifrex": "down", "vilserver1": "up", "orgm": "down"})
module.fetch_snapshot = lambda: snapshot

pango = module.pango_text(snapshot)
for token in (" N", " F", " V", " O"):
    assert token in pango, token
assert pango.count(module.UP_COLOR) == 2
assert pango.count(module.DOWN_COLOR) == 2

stdout = io.StringIO()
with contextlib.redirect_stdout(stdout):
    module.waybar()
waybar = json.loads(stdout.getvalue())
assert "N Nextcloud: CONECTADO" in waybar["tooltip"]
assert "F Fifrex: DESCONECTADO" in waybar["tooltip"]
assert "V Villarpando: CONECTADO" in waybar["tooltip"]
assert "O ORGM: DESCONECTADO" in waybar["tooltip"]

stdout = io.StringIO()
with contextlib.redirect_stdout(stdout):
    module.i3bar()
i3block = json.loads(stdout.getvalue())
assert i3block["name"] == "orgm-status"
assert i3block["markup"] == "pango"
assert i3block["full_text"] == module.i3bar_text(snapshot)
assert i3block["separator"] is False

watch_snapshot = module.Snapshot({**snapshot.values, "mariana": "up"})
module.fetch_snapshot = lambda: watch_snapshot
stdout = io.StringIO()
with contextlib.redirect_stdout(stdout):
    module.watch()
terminal = stdout.getvalue()
assert "• nextcloud: CONECTADO" in terminal
assert "• fifrex: DESCONECTADO" in terminal
assert "• vilserver1: CONECTADO" in terminal
assert "• orgm: DESCONECTADO" in terminal
assert "• mariana: CONECTADO" in terminal
PY

python3 - "$HELPER" <<'PY'
import contextlib
import io
import json
from importlib.machinery import SourceFileLoader
import importlib.util
from pathlib import Path
import sys
import tempfile

path = sys.argv[1]
loader = SourceFileLoader("orgm_status_profile", path)
spec = importlib.util.spec_from_loader(loader.name, loader)
module = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = module
loader.exec_module(module)

with tempfile.TemporaryDirectory() as directory:
    profile_file = Path(directory) / "desktop-profile"
    module.DESKTOP_PROFILE_PATH = str(profile_file)
    for profile, expected in (
        ("normal", "[N]"),
        ("windows", "[W]"),
        ("gaming", "[G]"),
        ("battery", "[B]"),
        ("server", "[S]"),
    ):
        profile_file.write_text(profile + "\n", encoding="utf-8")
        stdout = io.StringIO()
        with contextlib.redirect_stdout(stdout):
            module.profile_waybar()
        profile_status = json.loads(stdout.getvalue())
        assert expected in profile_status["text"]
        assert profile_status["class"][-1] == profile
PY
python3 "$HELPER" profile-waybar | jq --exit-status '(.text | test("\\[(N|W|G|B|S)\\]")) and (.class[0] == "desktop-profile")' >/dev/null \
  || fail 'shared ORGM helper cannot execute profile-waybar mode'



python3 - "$I3_WRAPPER" <<'PY'
from importlib.machinery import SourceFileLoader
import importlib.util
from pathlib import Path
import sys
import tempfile

path = sys.argv[1]
loader = SourceFileLoader("i3status_profile", path)
spec = importlib.util.spec_from_loader(loader.name, loader)
module = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = module
loader.exec_module(module)

with tempfile.TemporaryDirectory() as directory:
    profile_file = Path(directory) / "desktop-profile"
    module.DESKTOP_PROFILE_PATH = profile_file
    for profile, expected in (
        ("normal", "[N]"),
        ("windows", "[W]"),
        ("gaming", "[G]"),
        ("battery", "[B]"),
        ("server", "[S]"),
    ):
        profile_file.write_text(profile + "\n", encoding="utf-8")
        block = module.desktop_profile_block()
        assert block["instance"] == profile
        assert expected in block["full_text"]
        assert block["separator"] is False
PY

python3 - "$I3_WRAPPER" <<'PY'
from importlib.machinery import SourceFileLoader
import importlib.util
import sys

path = sys.argv[1]
loader = SourceFileLoader("i3status_localized", path)
spec = importlib.util.spec_from_loader(loader.name, loader)
module = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = module
loader.exec_module(module)

calls = []
module.subprocess.Popen = lambda args, **kwargs: calls.append((args, kwargs))
module.click_action({"name": "orgm-status", "button": 1})
assert calls[0][0][-1] == "open"
assert calls[0][0][0].endswith("/.local/bin/orgm-status")
PY

jq --exit-status . "$WAYBAR_CONFIG" >/dev/null || fail 'Waybar config is not valid JSON'
grep -Fq '"custom/desktop-profile"' "$WAYBAR_CONFIG" || fail 'Waybar does not display the desktop profile'
grep -Fq '"exec": "orgm-status profile-waybar"' "$WAYBAR_CONFIG" || fail 'Waybar profile does not use the shared profile source'
grep -Fq '#custom-desktop-profile' "$WAYBAR_STYLE" || fail 'Waybar desktop profile lacks spacing style'
grep -Fq '"custom/orgm-status"' "$WAYBAR_CONFIG" || fail 'Waybar does not display ORGM status'
grep -Fq '"on-click": "orgm-status open"' "$WAYBAR_CONFIG" || fail 'Waybar status click does not open terminal watch'
python3 - "$WAYBAR_CONFIG" <<'PY'
import json
import sys

modules = json.load(open(sys.argv[1], encoding="utf-8"))[0]["modules-right"]
expected = [
    "hyprland/window",
    "custom/desktop-profile",
    "custom/orgm-status",
    "network",
]
start = modules.index("hyprland/window")
assert modules[start:start + len(expected)] == expected
assert not any(module.startswith("custom/separator#") for module in modules)
PY
! grep -Fq 'custom/separator#' "$WAYBAR_CONFIG" || fail 'Waybar keeps status separators'
! grep -Fq '#custom-separator-' "$WAYBAR_STYLE" || fail 'Waybar keeps separator styling'
grep -Fq '#custom-orgm-status' "$WAYBAR_STYLE" || fail 'Waybar ORGM status lacks spacing style'
grep -Fq 'InfrastructureStatus' "$I3_WRAPPER" || fail 'i3 wrapper does not include ORGM status block'
grep -Fq 'click.get("name") == "orgm-status"' "$I3_WRAPPER" || fail 'i3 ORGM status is not clickable'

printf 'PASS: ORGM status and desktop profiles render in i3, Waybar, and terminal\n'
