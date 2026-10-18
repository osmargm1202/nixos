#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/bin"
cat >"$tmp/bin/windows-vm" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$VM_TEST_LOG"
exit "${VM_TEST_EXIT:-0}"
EOF
chmod +x "$tmp/bin/windows-vm"
export PATH="$tmp/bin:$PATH" VM_TEST_LOG="$tmp/calls"
bash "$ROOT/nixos/hosts/lenovo/windows-autostart.sh"
grep -Fxq start "$VM_TEST_LOG"
result=0
VM_TEST_EXIT=125 bash "$ROOT/nixos/hosts/lenovo/windows-autostart.sh" || result=$?
[[ "$result" == 125 ]]
[[ "$(wc -l <"$VM_TEST_LOG")" == 2 ]]
printf '%s\n' 'PASS: legacy Lenovo autostart delegates exclusively to windows-vm; lifecycle fixtures in lenovo-windows-runtime.py'
