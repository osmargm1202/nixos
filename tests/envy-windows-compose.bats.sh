#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIR="$ROOT/nixos/containers/windows/hosts/envy"
[[ -f "$DIR/compose.yml" ]] || { echo 'FAIL: missing declared Envy Compose'; exit 1; }
for mode in render vfio; do
 WINDOWS_PASSWORD=fixture-only docker compose -f "$DIR/compose.yml" -f "$DIR/compose.$mode.yml" config --format json |
 MODE="$mode" python3 -c '''
import json,os,sys
s=json.load(sys.stdin)["services"]["windows"]
assert "@sha256:" in s["image"] and s["pull_policy"]=="never"
assert s["container_name"]=="envy-windows" and s["restart"]=="no"
assert not s.get("privileged",False) and not s.get("build")
assert all(p["host_ip"]=="127.0.0.1" for p in s["ports"])
assert sorted((p["published"],p.get("protocol","tcp")) for p in s["ports"])==[("3389","tcp"),("3389","udp"),("8006","tcp")]
assert all(v["source"].startswith("/var/lib/windows/") for v in s["volumes"])
assert s["environment"]["CPU_CORES"]=="4" and s["environment"]["RAM_SIZE"]=="4G" and s["environment"]["DISK_SIZE"]=="96G"
if os.environ["MODE"]=="render":assert s["environment"]["GPU"]=="Y" and "keep-groups" in s["group_add"]
else:assert s["environment"]["GPU"]=="N" and "host=02:00.0" in s["environment"]["ARGUMENTS"] and "host=01:00.0" not in s["environment"]["ARGUMENTS"]
'''
 WINDOWS_PASSWORD=fixture-only podman-compose -f "$DIR/compose.yml" -f "$DIR/compose.$mode.yml" config -q
 done
printf 'PASS: declared Envy Compose validates for both engines, local ports and one pinned persistent VM\n'
