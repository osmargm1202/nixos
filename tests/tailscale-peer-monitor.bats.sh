#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
build_helper() {
  nix build --impure --no-link --print-out-paths --expr "
    let flake = builtins.getFlake \"path:$ROOT\";
        exec = flake.nixosConfigurations.orgm-hyprland.config.$1;
    in builtins.dirOf (builtins.dirOf exec)
  "
}
monitor_root="$(build_helper 'systemd.services.tailscale-peer-monitor.serviceConfig.ExecStart')"
notifier_root="$(build_helper 'systemd.user.services.tailscale-peer-notifier.serviceConfig.ExecStart')"
monitor="$monitor_root/bin/tailscale-peer-monitor"
status_file="$TMP/status.json"
notify_log="$TMP/notifications.log"
cat > "$TMP/bash-env" <<'EOF'
tailscale() { cat "$MOCK_STATUS"; }
nmcli() { printf '%s\n' "$MOCK_NETWORK"; }
notify-send() { printf '%s\t%s\n' "$5" "$6" >> "$NOTIFY_LOG"; }
systemd-cat() { cat >/dev/null; }
date() {
  case "${1:-}" in
    +%s) printf '%s\n' "$MOCK_TIME" ;;
    +%s%N)
      local sequence=0
      [[ ! -r $DATE_SEQUENCE ]] || read -r sequence < "$DATE_SEQUENCE"
      sequence=$((sequence + 1))
      printf '%s\n' "$sequence" > "$DATE_SEQUENCE"
      printf '%s%09d\n' "$MOCK_TIME" "$sequence"
      ;;
    *) command date "$@" ;;
  esac
}
export -f tailscale nmcli notify-send systemd-cat date
EOF
export BASH_ENV="$TMP/bash-env" MOCK_STATUS="$status_file" NOTIFY_LOG="$notify_log"
export DATE_SEQUENCE="$TMP/date-sequence" STATE_DIRECTORY="$TMP/system-state"
export MOCK_NETWORK=connected:full MOCK_TIME=1000 DISCONNECT_GRACE_SECONDS=90
export XDG_STATE_HOME="$TMP/user-state"
events="$STATE_DIRECTORY/events-v3.tsv"
# Replace only the system-state directory in the notifier, not its logic.
sed "s|/var/lib/tailscale-peer-monitor|$STATE_DIRECTORY|g" "$notifier_root/bin/tailscale-peer-notifier" > "$TMP/notifier"
chmod +x "$TMP/notifier"
notifier="$TMP/notifier"

snapshot() {
  python3 - "$status_file" "$1" "$2" "${3:-orgm}" "${4:-true}" <<'JSON'
import json, sys
peers = {}
for index, value in enumerate(sys.argv[2:4], 1):
    if value != "missing":
        peers[str(index)] = {"HostName": "orgm" if index == 1 else sys.argv[4],
                            "TailscaleIPs": [f"100.64.0.{index}"], "Online": value == "online"}
with open(sys.argv[1], "w") as output:
    json.dump({"BackendState": "Running", "Self": {"Online": sys.argv[5] == "true"}, "Peer": peers}, output)
JSON
}
count() { wc -l < "$events"; }
expect_events() { [[ $(count) -eq $1 ]] || fail "$2 ($(count) events, expected $1)"; }

# Legacy hostname-indexed state is not reused or replayed on migration.
mkdir -p "$STATE_DIRECTORY"
printf 'orgm\t100.64.0.1\toffline\norgm\t100.64.0.2\tonline\n' > "$STATE_DIRECTORY/peer-status.tsv"
snapshot offline online
"$monitor"
"$monitor"
expect_events 0 'two devices with the same name must not fabricate transitions'

# A short loss followed by recovery produces neither offline nor online noise.
MOCK_TIME=1010; snapshot offline offline; "$monitor"
MOCK_TIME=1040; "$monitor"
MOCK_TIME=1050; snapshot offline online; "$monitor"
expect_events 0 'transient disconnection must stay silent'

# Four consecutive offline samples span the 90-second grace period.
MOCK_TIME=1070; snapshot offline offline; "$monitor"
MOCK_TIME=1100; "$monitor"
MOCK_TIME=1130; "$monitor"
expect_events 0 'offline notice must wait for the full grace period'
MOCK_TIME=1160; "$monitor"
MOCK_TIME=1165; "$monitor"
expect_events 1 'confirmed offline IP must notify exactly once'
grep -Eq '^[0-9]+[[:space:]]orgm[[:space:]]100\.64\.0\.2[[:space:]]offline$' "$events" || fail 'wrong peer IP/name'
[[ $(stat -c '%a' "$events") == 644 ]] || fail 'event stream must remain readable by the user notifier'
"$notifier"
[[ ! -s $notify_log ]] || fail 'first delivery must not replay history'

# Renaming a peer must not change its identity; display its current name.
MOCK_TIME=1170; snapshot offline online orgm-remote; "$monitor"; "$notifier"
expect_events 2 'recovery must remain a transition for the same IP after a rename'
grep -Fxq $'Tailscale: equipo en línea\torgm-remote (100.64.0.2) volvió en línea' "$notify_log" || fail 'notifier must use the display name'
"$notifier"
[[ $(wc -l < "$notify_log") -eq 1 ]] || fail 'event must not replay'

# A disappearing IP follows the same confirmation policy.
MOCK_TIME=1200; snapshot offline missing; "$monitor"
MOCK_TIME=1230; "$monitor"
MOCK_TIME=1260; "$monitor"
MOCK_TIME=1290; "$monitor"
expect_events 3 'missing peer must be confirmed once'

# An uplink failure suppresses collection AND queued delivery.
MOCK_TIME=1300; MOCK_NETWORK=disconnected:none; snapshot offline offline; "$monitor"; "$notifier"
expect_events 3 'no notices while our network is disconnected'
[[ $(wc -l < "$notify_log") -eq 1 ]] || fail 'queued notice must not deliver during local outage'
MOCK_TIME=1320; MOCK_NETWORK=connected:full; snapshot offline offline orgm false; "$monitor"
expect_events 3 'cached peers must not notify while our Tailscale client is offline'
MOCK_TIME=1340; snapshot offline offline; "$monitor"; "$notifier"
expect_events 3 'local recovery must take a fresh baseline'
[[ $(wc -l < "$notify_log") -eq 1 ]] || fail 'local recovery must not replay queued events'

# Normal transitions resume after the local connection recovers.
MOCK_TIME=1350; snapshot online offline; "$monitor"; "$notifier"
expect_events 4 'monitor must resume after local recovery'
[[ $(wc -l < "$notify_log") -eq 2 ]] || fail 'fresh post-recovery event was lost'

# Network can disappear between collection and delivery.
MOCK_TIME=1360; snapshot online online; "$monitor"
MOCK_NETWORK=connected:none; "$notifier"
[[ $(wc -l < "$notify_log") -eq 2 ]] || fail 'delivery must check the local network itself'
MOCK_NETWORK=connected:full; "$notifier"
[[ $(wc -l < "$notify_log") -eq 2 ]] || fail 'suppressed event must not replay after reconnecting'

# Boot/sleep gaps and repeated empty snapshots do not fabricate a mass outage.
MOCK_TIME=1700; snapshot offline offline; "$monitor"
expect_events 5 'a long sampling gap must reset the baseline'
MOCK_TIME=1710; snapshot missing missing; "$monitor"
MOCK_TIME=1740; "$monitor"
MOCK_TIME=1770; "$monitor"
expect_events 5 'repeated empty snapshots must be accepted'
MOCK_TIME=1800; "$monitor"
MOCK_TIME=1810; "$monitor"
expect_events 5 'already-offline peers must not repeat notices'
printf 'different-boot\n' > "$STATE_DIRECTORY/boot-id"
MOCK_TIME=1830; snapshot online online; "$monitor"
expect_events 5 'new boot must not replay old offline state'

# A notifier watching a fresh empty stream must deliver the first real outage.
export STATE_DIRECTORY="$TMP/fresh-system" XDG_STATE_HOME="$TMP/fresh-user"
export NOTIFY_LOG="$TMP/fresh-notifications.log"
events="$STATE_DIRECTORY/events-v3.tsv"
sed "s|/var/lib/tailscale-peer-monitor|$STATE_DIRECTORY|g" "$notifier_root/bin/tailscale-peer-notifier" > "$TMP/fresh-notifier"
chmod +x "$TMP/fresh-notifier"
MOCK_TIME=2000; snapshot online online; "$monitor"; "$TMP/fresh-notifier"
MOCK_TIME=2010; snapshot online offline; "$monitor"
MOCK_TIME=2040; "$monitor"
MOCK_TIME=2070; "$monitor"
MOCK_TIME=2100; "$monitor"; "$TMP/fresh-notifier"
grep -Fxq $'Tailscale: equipo desconectado\torgm (100.64.0.2) se desconectó' "$NOTIFY_LOG" ||
  fail 'the first real disconnect must be delivered after an empty baseline'
printf 'PASS: IP identity, 90-second confirmation, network gating, migration and notification cursor\n'
