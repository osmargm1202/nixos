#!/usr/bin/env bash
set -euo pipefail

# A cached peer list is not evidence that this machine can still reach the
# tailnet. Gate both collection and delivery on the local uplink and client.
network="$(LC_ALL=C nmcli -t -f STATE,CONNECTIVITY general 2>/dev/null)" || exit 1
case "$network" in
  connected*:full|connected*:unknown) ;;
  *) exit 1 ;;
esac
tailscale status --json 2>/dev/null | jq -e '
  .BackendState == "Running" and .Self.Online == true
' >/dev/null
