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
  nix build --impure --no-link --print-out-paths --expr "
    let
      flake = builtins.getFlake \"path:$ROOT\";
      exec = flake.nixosConfigurations.orgm-hyprland.config.systemd.services.tailscale-magicdns.serviceConfig.ExecStart;
    in
      builtins.dirOf (builtins.dirOf exec)
  "
}

magicdns_root="$(build_helper)"
magicdns="$magicdns_root/bin/tailscale-magicdns"
bash_env="$TMP/bash-env"
resolver_log="$TMP/resolvectl.log"
status_calls="$TMP/status-calls"
printf '0\n' > "$status_calls"

cat > "$bash_env" <<'EOF'
tailscale() {
  status_calls="$(<"$STATUS_CALLS")"
  status_calls=$((status_calls + 1))
  printf '%s\n' "$status_calls" > "$STATUS_CALLS"
  if ((status_calls == 1)); then
    return 1
  elif ((status_calls == 2)); then
    printf '%s\n' '{"BackendState":"Starting"}'
  else
    printf '%s\n' '{"BackendState":"Running","MagicDNSSuffix":"tailb870fa.ts.net"}'
  fi
}
ip() {
  [ "$1" = link ] && [ "$2" = show ] && [ "$3" = dev ] && [ "$4" = tailscale0 ]
}
resolvectl() { printf '%s\n' "$*" >> "$RESOLVER_LOG"; }
sleep() { :; }
export -f tailscale ip resolvectl sleep
EOF

export BASH_ENV="$bash_env"
export RESOLVER_LOG="$resolver_log"
export STATUS_CALLS="$status_calls"
"$magicdns"

[ "$(wc -l < "$resolver_log")" -eq 2 ] || fail 'unready status must not configure resolved'
grep -Fxq 'dns tailscale0 100.100.100.100' "$resolver_log" ||
  fail 'MagicDNS must configure the Tailscale resolver'
grep -Fxq 'domain tailscale0 ~tailb870fa.ts.net tailb870fa.ts.net' "$resolver_log" ||
  fail 'MagicDNS must configure route-only and search domains'
[ "$(cat "$status_calls")" -eq 3 ] || fail 'readiness loop must retry after status failure and the Starting state'

[ "$(nix eval --raw "path:$ROOT#nixosConfigurations.orgm-hyprland.config.systemd.services.tailscale-magicdns.serviceConfig.TimeoutStartSec")" = '90s' ] ||
  fail 'MagicDNS unit must allow the bounded readiness wait'

printf 'PASS: MagicDNS waits for Tailscale readiness before configuring resolved\n'
