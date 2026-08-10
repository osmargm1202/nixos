#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
guard="$repo_dir/nixos/hosts/lenovo/windows-vm-battery-guard.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/power/BAT0" "$tmp/run"
printf 'Discharging\n' >"$tmp/power/BAT0/status"

cat >"$tmp/bin/podman" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${MOCK_CONTAINER_RUNNING:-true}"
EOF
cat >"$tmp/bin/pgrep" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *looking-glass-client*) exit "${MOCK_LOOKING_GLASS_VIEWER:-1}" ;;
  *wlfreerdp*) exit "${MOCK_RDP_VIEWER:-1}" ;;
  *) exit 1 ;;
esac
EOF
cat >"$tmp/bin/ss" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
cat >"$tmp/bin/date" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$MOCK_NOW"
EOF
cat >"$tmp/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$HIBERNATE_LOG"
EOF
chmod +x "$tmp/bin/"*

run_guard() {
  PATH="$tmp/bin:$PATH" \
    XDG_RUNTIME_DIR="$tmp/run" \
    WINDOWS_VM_GUARD_POWER_SUPPLY_DIR="$tmp/power" \
    WINDOWS_VM_GUARD_ONESHOT=1 \
    WINDOWS_VM_GUARD_IDLE_SECONDS=60 \
    MOCK_NOW="$1" \
    MOCK_RDP_VIEWER="${MOCK_RDP_VIEWER:-1}" \
    MOCK_LOOKING_GLASS_VIEWER="${MOCK_LOOKING_GLASS_VIEWER:-1}" \
    HIBERNATE_LOG="$tmp/hibernate.log" \
    bash "$guard"
}

bash -n "$guard"
run_guard 100
[[ ! -e "$tmp/hibernate.log" ]]
run_guard 159
[[ ! -e "$tmp/hibernate.log" ]]
run_guard 160
[[ "$(<"$tmp/hibernate.log")" == "hibernate" ]]

# A viewer cancels the timer rather than hibernating an active remote session.
MOCK_LOOKING_GLASS_VIEWER=0 run_guard 220
[[ ! -e "$tmp/run/windows-vm-battery-guard.idle" ]]
MOCK_RDP_VIEWER=0 run_guard 220
[[ ! -e "$tmp/run/windows-vm-battery-guard.idle" ]]
printf 'windows-vm-battery-guard: ok\n'
