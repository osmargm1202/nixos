#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIR="$ROOT/nixos/containers/windows/hosts/envy"
[[ -f "$DIR/compose.yml" ]] || { echo 'FAIL: missing declared Envy Compose'; exit 1; }
# A standalone Compose binary avoids `docker` being a Podman compatibility shim.
if [[ -n "${DOCKER_COMPOSE:-}" ]]; then
 compose=("$DOCKER_COMPOSE")
elif command -v docker-compose >/dev/null; then
 compose=(docker-compose)
elif docker compose config --help 2>/dev/null | grep -q -- --format; then
 compose=(docker compose)
else
 # Envy can expose `docker` as a Podman shim, whose config has no JSON flag.
 compose_dir="$(RYOKU_TEST_REPO="$ROOT" nix build --impure --no-link --print-out-paths --expr '
  let f=builtins.getFlake ("path:"+builtins.getEnv "RYOKU_TEST_REPO");
  in f.nixosConfigurations.envy.pkgs.docker-compose
 ')"
 compose=("$compose_dir/bin/docker-compose")
fi
for mode in render vfio; do
 WINDOWS_PASSWORD=fixture-only "${compose[@]}" -f "$DIR/compose.yml" -f "$DIR/compose.$mode.yml" config --format json |
 MODE="$mode" python3 -c '''
import json,os,sys
s=json.load(sys.stdin)["services"]["windows"]
assert "@sha256:" in s["image"] and s["pull_policy"]=="never"
assert s["container_name"]=="envy-windows" and s["restart"]=="no"
assert not s.get("privileged",False) and not s.get("build")
assert all(p["host_ip"]=="127.0.0.1" for p in s["ports"])
expected=[("3389","tcp"),("3389","udp"),("8006","tcp")]
if os.environ["MODE"]=="vfio":expected.append(("5901","tcp"))
assert sorted((p["published"],p.get("protocol","tcp")) for p in s["ports"])==sorted(expected)
assert all(v["source"].startswith("/var/lib/windows/") for v in s["volumes"])
assert s["environment"]["CPU_CORES"]=="4" and s["environment"]["RAM_SIZE"]=="4G" and s["environment"]["DISK_SIZE"]=="96G"
if os.environ["MODE"]=="render":assert s["environment"]["GPU"]=="Y" and "keep-groups" in s["group_add"]
else:
 e=s["environment"];a=e["ARGUMENTS"]
 # qemus/qemu v7.50 attaches the generated Windows setup.img as USB storage:
 # disabling the controller makes a fresh web installation fail before boot.
 assert e["GPU"]=="N" and e["USB"]=="yes"
 assert e["MOUSE"]=="virtio-mouse-pci" and "usb-tablet" not in a
 assert "host=02:00.0" in a and "host=01:00.0" not in a
 assert "mem-path=/dev/kvmfr0,size=134217728,share=on" in a
 assert "-device ivshmem-plain,memdev=looking-glass" in a
 assert "-spice port=5901" in a and "-device virtio-keyboard-pci" in a
 assert "-device virtio-mouse-pci" not in a, "MOUSE already adds the relative mouse"
 assert "-vga none" not in a and e.get("VGA")!="none", "web bootstrap must keep its virtual display"
'''
 WINDOWS_PASSWORD=fixture-only podman-compose -f "$DIR/compose.yml" -f "$DIR/compose.$mode.yml" config -q
 done
printf 'PASS: declared Envy Compose validates for both engines, local ports and one pinned persistent VM\n'
