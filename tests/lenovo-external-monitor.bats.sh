#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/bin"
export PATH="$tmp/bin:$PATH" OUTPUTS_FILE="$tmp/outputs" LAYOUT_FILE="$tmp/layout"
cat >"$tmp/bin/ryoku-hub" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  'outputs list') cat "$OUTPUTS_FILE" ;;
  *) [[ "$1 $2" == 'outputs apply' ]] || exit 99; printf '%s\n' "$3" >"$LAYOUT_FILE" ;;
esac
EOF
chmod +x "$tmp/bin/ryoku-hub"
cat >"$tmp/bin/hyprctl" <<'EOF'
#!/usr/bin/env bash
[[ "$*" == 'instances -j' ]] || exit 99
printf '%s\n' '[{"instance":"test-session"}]'
EOF
chmod +x "$tmp/bin/hyprctl"
cat >"$OUTPUTS_FILE" <<'EOF'
[{"name":"eDP-1","disabled":false,"focused":false,"mode":"1920x1080@60","scale":1,"x":0,"y":0},
 {"name":"DP-3","disabled":false,"focused":true,"mode":"1920x1080@144","scale":1,"x":1920,"y":0}]
EOF
bash -euo pipefail "$ROOT/nixos/hosts/lenovo/external-monitor.sh" --apply
jq -e '.[0].enabled == false and .[1].enabled == true and .[1].name == "DP-3" and .[1].mode == "1920x1080@144" and .[1].x == 0' "$LAYOUT_FILE" >/dev/null

printf '%s\n' '[{"name":"HDMI-A-1","disabled":true,"focused":false,"mode":"0x0@60","scale":1,"x":-1,"y":-1}]' >"$OUTPUTS_FILE"
bash -euo pipefail "$ROOT/nixos/hosts/lenovo/external-monitor.sh" --apply
jq -e '.[0].enabled and .[0].mode == "" and .[0].x == 0 and .[0].y == 0' "$LAYOUT_FILE" >/dev/null

rm "$LAYOUT_FILE"
printf '%s\n' '[{"name":"eDP-1","disabled":false}]' >"$OUTPUTS_FILE"
if bash -euo pipefail "$ROOT/nixos/hosts/lenovo/external-monitor.sh" --apply 2>/dev/null; then exit 1; fi
[[ ! -e "$LAYOUT_FILE" ]]
printf '%s\n' 'PASS: helper detects changing external connectors, preserves their mode, and refuses an empty layout'
