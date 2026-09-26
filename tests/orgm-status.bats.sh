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

# Losing the query says nothing about the targets, so they must not claim an
# outage: this machine being offline used to paint every indicator red.
offline = module.Snapshot({}, "sin datos de Prometheus: boom")
offline_pango = module.pango_text(offline)
assert offline_pango.count(module.NO_DATA_COLOR) == 4
assert module.DOWN_COLOR not in offline_pango
assert module.UP_COLOR not in offline_pango
module.fetch_snapshot = lambda: offline
stdout = io.StringIO()
with contextlib.redirect_stdout(stdout):
    module.waybar()
offline_waybar = json.loads(stdout.getvalue())
assert offline_waybar["class"] == ["orgm-status", "no-data"]
assert "N Nextcloud: SIN DATOS" in offline_waybar["tooltip"]

unknown_watch = module.Snapshot({"nextcloud": "unknown"})
module.fetch_snapshot = lambda: unknown_watch
stdout = io.StringIO()
with contextlib.redirect_stdout(stdout):
    module.watch()
terminal_unknown = stdout.getvalue()
assert "\u2022 nextcloud: SIN DATOS" in terminal_unknown
assert "\033[38;2;107;114;128m" in terminal_unknown
assert "\033[38;2;248;113;113m" not in terminal_unknown

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




python3 - "$I3_WRAPPER" <<'PY'
from importlib.machinery import SourceFileLoader
import importlib.util
from types import SimpleNamespace
import sys

path = sys.argv[1]
loader = SourceFileLoader("i3status_profile", path)
spec = importlib.util.spec_from_loader(loader.name, loader)
module = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = module
loader.exec_module(module)

for profile, expected in (
    ("slc", "[SLC]"),
    ("orgm", "[ORGM]"),
    ("osmar", "[OSMAR]"),
):
    module.subprocess.run = lambda *args, profile=profile, **kwargs: SimpleNamespace(stdout=profile + "\n")
    block = module.visual_profile_block()
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
grep -Fq '"custom/orgm-status"' "$WAYBAR_CONFIG" || fail 'Waybar does not display ORGM status'
grep -Fq '"on-click": "orgm-status open"' "$WAYBAR_CONFIG" || fail 'Waybar status click does not open terminal watch'
python3 - "$WAYBAR_CONFIG" <<'PY'
import json
import sys

modules = json.load(open(sys.argv[1], encoding="utf-8"))[0]["modules-right"]
assert not any(module.startswith("custom/separator#") for module in modules)
PY
! grep -Fq 'custom/separator#' "$WAYBAR_CONFIG" || fail 'Waybar keeps status separators'
! grep -Fq '#custom-separator-' "$WAYBAR_STYLE" || fail 'Waybar keeps separator styling'
grep -Fq '#custom-orgm-status' "$WAYBAR_STYLE" || fail 'Waybar ORGM status lacks spacing style'
grep -Fq 'InfrastructureStatus' "$I3_WRAPPER" || fail 'i3 wrapper does not include ORGM status block'
grep -Fq 'click.get("name") == "orgm-status"' "$I3_WRAPPER" || fail 'i3 ORGM status is not clickable'

printf 'PASS: ORGM status and visual profiles render in i3, Waybar, and terminal\n'
