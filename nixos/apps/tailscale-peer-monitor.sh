#!/usr/bin/env bash
set -euo pipefail

LOG_TAG=tailscale-peer-monitor
STATE_DIR="${STATE_DIRECTORY:-/var/lib/tailscale-peer-monitor}"
EVENT_FILE="$STATE_DIR/events-v3.tsv"
STATE_FILE="$STATE_DIR/peer-status-v3.tsv"
NETWORK_DOWN_FILE="$STATE_DIR/local-network-down"
DELIVERY_FLOOR="$STATE_DIR/delivery-floor"
LAST_POLL_FILE="$STATE_DIR/last-poll"
BOOT_FILE="$STATE_DIR/boot-id"
GRACE_SECONDS="${DISCONNECT_GRACE_SECONDS:-90}"
declare -A confirmed names pending seen

emit_event() {
  local ip="$1" state="$2" message
  if [[ $state == online ]]; then
    message="${names[$ip]} ($ip) volvió en línea"
  else
    message="${names[$ip]} ($ip) se desconectó"
  fi
  printf '%s\n' "$message" | systemd-cat -t "$LOG_TAG" -p info || true
  printf '%s\t%s\t%s\t%s\n' "$(date +%s%N)" "${names[$ip]}" "$ip" "$state" >> "$EVENT_FILE"
  if [[ $(wc -l < "$EVENT_FILE") -gt 1000 ]]; then
    local trimmed
    trimmed="$(mktemp "$STATE_DIR/events.XXXXXX")"
    tail -n 1000 "$EVENT_FILE" > "$trimmed"
    chmod 0644 "$trimmed"
    mv -- "$trimmed" "$EVENT_FILE"
  fi
}

observe() {
  local ip="$1" state="$2" since
  if [[ ${confirmed[$ip]+x} != x ]]; then
    confirmed["$ip"]="$state"
    pending["$ip"]=0
  elif [[ $state == online ]]; then
    if [[ ${confirmed[$ip]} == offline ]]; then emit_event "$ip" online; fi
    confirmed["$ip"]=online
    pending["$ip"]=0
  elif [[ ${confirmed[$ip]} == online ]]; then
    since="${pending[$ip]:-0}"
    if (( since == 0 || since > now )); then since="$now"; fi
    pending["$ip"]="$since"
    if (( now - since >= GRACE_SECONDS )); then
      emit_event "$ip" offline
      confirmed["$ip"]=offline
      pending["$ip"]=0
    fi
  fi
}

main() {
  local current status_json ip host state since snapshot boot_id last_poll=0 reset=false
  mkdir -p "$STATE_DIR"
  touch "$EVENT_FILE"
  chmod 0644 "$EVENT_FILE"
  if ! tailscale-local-ready; then
    touch "$NETWORK_DOWN_FILE"
    return
  fi
  if ! status_json="$(tailscale status --json 2>/dev/null)"; then
    touch "$NETWORK_DOWN_FILE"
    return
  fi
  # Names are labels only. Different devices may have the same HostName.
  if ! current="$(jq -r '
    (.Peer // {})
    | if type == "object" then [.[]] elif type == "array" then . else [] end
    | map(select((.Self // false) | not))
    | map({
        ip: (.TailscaleIPs[0] // ""),
        host: ([.HostName, .HostInfo.HostName, .DNSName]
          | map(select(type == "string" and length > 0)) | first // ""),
        state: (if (.Online // false) then "online" else "offline" end)
      })
    | map(select(.ip != "")) | unique_by(.ip) | sort_by(.ip)
    | .[] | [.ip, (if .host == "" then .ip else .host end), .state] | @tsv
  ' <<< "$status_json")"; then
    touch "$NETWORK_DOWN_FILE"
    return
  fi
  now="$(date +%s)"
  boot_id="$(cat /proc/sys/kernel/random/boot_id)"
  if [[ -r $LAST_POLL_FILE ]]; then read -r last_poll < "$LAST_POLL_FILE" || last_poll=0; fi
  # Boot, sleep, and loss of the local network start a fresh baseline. Never
  # report another computer's outage using observations from our own outage.
  if [[ ! -f $STATE_FILE || -f $NETWORK_DOWN_FILE || ! -r $BOOT_FILE ]] ||
      [[ $(cat "$BOOT_FILE") != "$boot_id" ]] ||
      (( now < last_poll || now - last_poll > 75 )); then
    reset=true
    date +%s%N > "$DELIVERY_FLOOR"
  fi
  if [[ $reset == false ]]; then
    while IFS=$'\t' read -r ip host state since; do
      [[ -n ${ip:-} ]] || continue
      confirmed["$ip"]="$state"
      names["$ip"]="$host"
      pending["$ip"]="${since:-0}"
    done < "$STATE_FILE"
  fi
  while IFS=$'\t' read -r ip host state; do
    [[ -n ${ip:-} ]] || continue
    names["$ip"]="$host"
    seen["$ip"]=1
    observe "$ip" "$state"
  done <<< "$current"
  for ip in "${!confirmed[@]}"; do
    if [[ ${seen[$ip]+x} != x ]]; then observe "$ip" offline; fi
  done
  snapshot="$(mktemp "$STATE_DIR/peers.XXXXXX")"
  for ip in "${!confirmed[@]}"; do
    printf '%s\t%s\t%s\t%s\n' "$ip" "${names[$ip]}" "${confirmed[$ip]}" "${pending[$ip]:-0}"
  done | sort > "$snapshot"
  chmod 0644 "$snapshot"
  mv -- "$snapshot" "$STATE_FILE"
  printf '%s\n' "$now" > "$LAST_POLL_FILE"
  printf '%s\n' "$boot_id" > "$BOOT_FILE"
  rm -f -- "$NETWORK_DOWN_FILE"
}

main
