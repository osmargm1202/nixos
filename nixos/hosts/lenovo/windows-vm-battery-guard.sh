#!/usr/bin/env bash
set -euo pipefail

# Hibernates an unattended Lenovo VFIO Windows VM only while the laptop is
# discharging. A live RDP/Web Console connection or Looking Glass client keeps
# the machine awake; the QEMU process itself must not count as an active viewer.
container="${WINDOWS_VM_GUARD_CONTAINER:-lenovo-windows}"
power_supply_dir="${WINDOWS_VM_GUARD_POWER_SUPPLY_DIR:-/sys/class/power_supply}"
idle_seconds="${WINDOWS_VM_GUARD_IDLE_SECONDS:-60}"
poll_seconds="${WINDOWS_VM_GUARD_POLL_SECONDS:-5}"
state_file="${XDG_RUNTIME_DIR:-/tmp}/windows-vm-battery-guard.idle"

on_battery() {
  local status_file status

  for status_file in "$power_supply_dir"/BAT*/status; do
    [[ -r "$status_file" ]] || continue
    status="$(<"$status_file")"
    [[ "$status" == "Discharging" || "$status" == "Not charging" ]] && return 0
  done
  return 1
}

container_running() {
  podman inspect --format '{{.State.Running}}' "$container" 2>/dev/null | grep -qx true
}

has_active_viewer() {
  local uid
  uid="$(id -u)"

  # pgrep's process-name field is capped at 15 bytes. Match full command lines
  # so looking-glass-client is detected instead of treating it as unattended.
  pgrep -u "$uid" -f '(^|/)(wlfreerdp|xfreerdp|xfreerdp3|freerdp)( |$)' >/dev/null \
    || pgrep -u "$uid" -f '(^|/)looking-glass-client( |$)' >/dev/null \
    || ss -Htn state established | grep -Eq '(:3389|:8006)([[:space:]]|$)'
}

clear_idle_timer() {
  rm -f "$state_file"
}

hibernate_when_idle() {
  local now started
  now="$(date +%s)"

  if [[ ! -r "$state_file" ]]; then
    printf '%s\n' "$now" >"$state_file"
    return
  fi

  read -r started <"$state_file"
  if [[ ! "$started" =~ ^[0-9]+$ ]] || ((now - started < idle_seconds)); then
    return
  fi

  notify-send --urgency=normal "Windows VM en batería" \
    "Sin RDP, Looking Glass ni consola web durante ${idle_seconds}s; hibernando." || true
  clear_idle_timer
  # systemd honors existing sleep inhibitors. Reset the timer after resume or
  # a denied hibernation attempt so this never loops immediately.
  systemctl hibernate || true
}

while :; do
  if on_battery && container_running && ! has_active_viewer; then
    hibernate_when_idle
  else
    clear_idle_timer
  fi

  [[ "${WINDOWS_VM_GUARD_ONESHOT:-0}" == 1 ]] && exit 0
  sleep "$poll_seconds"
done
