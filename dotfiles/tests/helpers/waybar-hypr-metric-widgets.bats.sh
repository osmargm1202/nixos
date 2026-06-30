#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG="$ROOT/config/shared/.config/waybar-hypr/config"
STYLE="$ROOT/config/shared/.config/waybar-hypr/style.css"
SCRIPT="$ROOT/config/shared/.local/bin/waybar-metric-widget"
TMP="$ROOT/.tmp-waybar-metric-test-$$"
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[ -f "$CONFIG" ] || fail "missing waybar hypr config"
[ -f "$STYLE" ] || fail "missing waybar hypr style"
[ -f "$SCRIPT" ] || fail "missing waybar-metric-widget"
[ -x "$SCRIPT" ] || fail "waybar-metric-widget must be executable"

python3 - "$CONFIG" <<'PY'
import json
import sys
from pathlib import Path

cfg = json.loads(Path(sys.argv[1]).read_text())
expected_usage = [
    "custom/metric_cpu",
    "custom/metric_gpu",
    "custom/metric_ram",
    "custom/metric_ssd",
    "custom/metric_swap",
]

bars = {bar.get("name"): bar for bar in cfg if isinstance(bar, dict) and "name" in bar}
bottom = bars.get("bottom_bar")
if bottom is None:
    raise SystemExit("bottom bar config missing")

top = bars.get("top_bar")
if top is None:
    raise SystemExit("top bar config missing")

mods = bottom.get("modules-right", [])
if "group/usage" not in mods:
    raise SystemExit("bottom group/usage missing")

usage_group = bottom.get("group/usage", {})
if usage_group.get("modules") != expected_usage:
    raise SystemExit("bottom group/usage modules mismatch")

for key in expected_usage:
    mod = bottom.get(key)
    if mod is None:
        raise SystemExit(f"module missing: {key}")
    if mod.get("return-type") != "json":
        raise SystemExit(f"{key} return-type not json")
    if mod.get("escape") is not False:
        raise SystemExit(f"{key} escape not false")
    if mod.get("markup") != "pango":
        raise SystemExit(f"{key} markup not pango")
    metric = key.rsplit("_", 1)[-1]
    if mod.get("exec") != f"waybar-metric-widget {metric}":
        raise SystemExit(f"{key} exec invalid: {mod.get('exec')}")
    interval = mod.get("interval")
    if not isinstance(interval, int) or interval <= 0:
        raise SystemExit(f"{key} interval invalid")

orgm_logo_format = None
for bar in cfg:
    if "custom/orgm_logo" in bar:
        orgm_logo_format = bar.get("custom/orgm_logo", {}).get("format", "")
if not orgm_logo_format or "NixOS" not in orgm_logo_format:
    raise SystemExit("orgm_logo format missing NixOS label")

print("CONFIG_OK")
PY

python3 - "$STYLE" <<'PY' || fail "custom metric CSS margin should be non-zero"
import re
import sys
from pathlib import Path

content = Path(sys.argv[1]).read_text()
selectors = [
    "#group-usage #custom-metric_cpu",
    "#group-usage #custom-metric_gpu",
    "#group-usage #custom-metric_ram",
    "#group-usage #custom-metric_ssd",
    "#group-usage #custom-metric_swap",
    "#usage #custom-metric_cpu",
    "#usage #custom-metric_gpu",
    "#usage #custom-metric_ram",
    "#usage #custom-metric_ssd",
    "#usage #custom-metric_swap",
]

rules = [
    (match.group(1), match.group(2))
    for match in re.finditer(r"([^\{]+)\{([^}]*)\}", content, re.S)
]

for selector in selectors:
    def has_nonzero_margin():
        for sel_block, body in rules:
            selector_list = " ".join(sel_block.split())
            token = rf"(?:^|,)\s*{re.escape(selector)}\s*(?:,|$)"
            if not re.search(token, selector_list):
                continue

            match = re.search(r"margin\s*:\s*([^;]+);", body)
            if not match:
                continue

            values = [v.strip() for v in match.group(1).split()]
            if not values:
                continue

            if len(values) == 1:
                horiz = values[0]
            elif len(values) >= 2:
                horiz = values[1]

            if not horiz.endswith("px"):
                continue

            try:
                px = int(horiz[:-2])
            except ValueError:
                continue
            return px > 0

        return False

    if not has_nonzero_margin():
        raise SystemExit(f"missing non-zero horizontal margin for {selector}")

print("METRIC_MARGIN_OK")
PY

for metric in cpu gpu ram ssd swap; do
  output="$TMP/$metric.json"
  WAYBAR_METRIC_CACHE_DIR="$TMP/cache" "$SCRIPT" "$metric" >"$output"
  python3 - "$metric" "$output" <<'PY'
import json
import sys
from pathlib import Path

name_map = {
    "cpu": "CPU",
    "gpu": "GPU",
    "ram": "RAM",
    "ssd": "SSD",
    "swap": "SWAP",
}
metric = sys.argv[1]
name = name_map[metric]
data = json.loads(Path(sys.argv[2]).read_text())
for key in ("text", "tooltip", "class", "percentage"):
    if key not in data:
        raise SystemExit(f"missing key {key}")
if not isinstance(data["class"], list):
    raise SystemExit("class must be json array")
if not data["class"]:
    raise SystemExit("class array empty")
if data["class"][0] != "metric-widget":
    raise SystemExit(f"first class must be metric-widget, got {data['class'][0]}")
if not all(isinstance(item, str) for item in data["class"]):
    raise SystemExit("class array contains non-string values")
text = data["text"]
if "<span class='" in text or '<span class="' in text:
    raise SystemExit(f"literal class attribute found in text for {name}")
print(f"{name}_JSON_OK")
PY
 done

for metric in cpu gpu ram ssd swap; do
  output="$TMP/${metric}_two_lines.json"
  WAYBAR_METRIC_CACHE_DIR="$TMP/cache" "$SCRIPT" "$metric" >"$output"
  python3 - "$metric" "$output" <<'PY'
import json
import sys
from pathlib import Path

name_map = {
    "cpu": "CPU",
    "gpu": "GPU",
    "ram": "RAM",
    "ssd": "SSD",
    "swap": "SWAP",
}
metric = sys.argv[1]
name = name_map[metric]
data = json.loads(Path(sys.argv[2]).read_text())
lines = data["text"].split("\n")
if len(lines) != 2:
    raise SystemExit(f"{name} text expected 2 lines, got {len(lines)}")
line1, line2 = lines
if "%" not in line1:
    raise SystemExit(f"{name} first line missing %: {line1}")
if name not in line1:
    raise SystemExit(f"{name} first line missing name: {line1}")
if not line2.strip():
    raise SystemExit(f"{name} second line empty")
print(f"{name}_TEXT_FORMAT_OK")
PY
done

# Swap total zero should show empty-swap state and never warn critical
SWAP_ZERO_MEMINFO="$TMP/meminfo-no-swap"
cat > "$SWAP_ZERO_MEMINFO" <<'EOF'
SwapTotal:       0 kB
SwapFree:        0 kB
EOF
WAYBAR_METRIC_CACHE_DIR="$TMP/cache" WAYBAR_METRIC_MEMINFO_PATH="$SWAP_ZERO_MEMINFO" "$SCRIPT" swap >"$TMP/swap_zero.json"
python3 - "$TMP/swap_zero.json" <<'PY'
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text())
percentage = data["percentage"]
if percentage > 100:
    raise SystemExit(f"swap percentage invalid: {percentage}")
if percentage != 0:
    raise SystemExit(f"swap percentage expected 0 for zero total, got {percentage}")
if "metric-critical" in data.get("class", []):
    raise SystemExit("swap total zero classified critical")
import re
text = data["text"]
meta = data["text"].split("\n")[1]
meta = re.sub(r"<[^>]+>", "", meta)
if meta not in {"0.0 / 0.0 G", "sin swap"}:
    raise SystemExit(f"swap meta unexpected: {meta}")
print("SWAP_ZERO_OK")
PY

# Swap near 4 GiB used should format as 4.0 / 4.0 G and report 100
SWAP_NEAR_4G_MEMINFO="$TMP/meminfo-near-4g"
cat > "$SWAP_NEAR_4G_MEMINFO" <<'EOF'
SwapTotal:       4194300 kB
SwapFree:        16 kB
EOF
WAYBAR_METRIC_CACHE_DIR="$TMP/cache" WAYBAR_METRIC_MEMINFO_PATH="$SWAP_NEAR_4G_MEMINFO" "$SCRIPT" swap >"$TMP/swap_near_4g.json"
python3 - "$TMP/swap_near_4g.json" <<'PY'
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text())
if data["percentage"] != 100:
    raise SystemExit(f"swap percentage expected 100, got {data['percentage']}")
import re
text = data["text"]
meta = data["text"].split("\n")[1]
meta = re.sub(r"<[^>]+>", "", meta)
if meta != "4.0 / 4.0 G":
    raise SystemExit(f"swap meta unexpected: {meta}")
print("SWAP_NEAR_4G_OK")
PY

echo "PASS: waybar-hypr metric widgets test passed"