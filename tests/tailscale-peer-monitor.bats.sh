#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

build_helper() {
  local attr="$1"
  nix build --impure --no-link --print-out-paths --expr "
    let
      flake = builtins.getFlake \"path:$ROOT\";
      exec = flake.nixosConfigurations.orgm-hyprland.config.$attr;
    in
      builtins.dirOf (builtins.dirOf exec)
  "
}

monitor_root="$(build_helper 'systemd.services.tailscale-peer-monitor.serviceConfig.ExecStart')"
notifier_root="$(build_helper 'systemd.user.services.tailscale-peer-notifier.serviceConfig.ExecStart')"
monitor="$monitor_root/bin/tailscale-peer-monitor"
notifier="$notifier_root/bin/tailscale-peer-notifier"

status_file="$TMP/tailscale-status.json"
notify_log="$TMP/notifications.log"
bash_env="$TMP/bash-env"
cat > "$bash_env" <<'EOF'
tailscale() { cat "$MOCK_STATUS"; }
notify-send() { printf '%s\t%s\n' "$5" "$6" >> "$NOTIFY_LOG"; }
export -f tailscale notify-send
EOF

export BASH_ENV="$bash_env"
export MOCK_STATUS="$status_file"
export NOTIFY_LOG="$notify_log"
export STATE_DIRECTORY="$TMP/system-state"

cat > "$status_file" <<'EOF'
{"Peer":{"peer-1":{"HostName":"jarq","TailscaleIPs":["100.64.0.2"],"Online":true}}}
EOF
"$monitor"

cat > "$status_file" <<'EOF'
{"Peer":{"peer-1":{"HostName":"jarq","TailscaleIPs":["100.64.0.2"],"Online":false}}}
EOF
"$monitor"

events="$STATE_DIRECTORY/events-v2.tsv"
[ "$(stat -c '%a' "$events")" = "644" ] || fail 'event stream must remain readable by user services'
grep -Eq '^[0-9]+[[:space:]]jarq[[:space:]]100\.64\.0\.2[[:space:]]offline$' "$events" ||
  fail 'online-to-offline transition must produce a peer event'

notifier_test="$TMP/tailscale-peer-notifier"
sed "s|/var/lib/tailscale-peer-monitor/events-v2.tsv|$events|" "$notifier" > "$notifier_test"
chmod +x "$notifier_test"
export XDG_STATE_HOME="$TMP/user-state"

"$notifier_test"
[ ! -e "$notify_log" ] || [ ! -s "$notify_log" ] ||
  fail 'first notifier start must not replay historic events'

cat > "$status_file" <<'EOF'
{"Peer":{"peer-1":{"HostName":"jarq","TailscaleIPs":["100.64.0.2"],"Online":true}}}
EOF
"$monitor"
grep -Eq '^[0-9]+[[:space:]]jarq[[:space:]]100\.64\.0\.2[[:space:]]online$' "$events" ||
  fail 'offline-to-online transition must produce a peer event'

IFS=$'\t' read -r latest_event_id _ < <(tail -n 1 "$events")
"$notifier_test"

grep -Fxq $'Tailscale: equipo en línea\tjarq (100.64.0.2) volvió en línea' "$notify_log" ||
  fail 'new online event must produce a desktop notification'
[ "$(cat "$XDG_STATE_HOME/tailscale-peer-monitor/last-event-id")" = "$latest_event_id" ] ||
  fail 'notifier cursor must advance only after notifying'

printf 'PASS: Tailscale peer events persist and notify only new transitions\n'
