#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLAKE="$ROOT/flake.nix"
LOCK="$ROOT/flake.lock"
PROFILE="$ROOT/nixos/profiles/hyprland.nix"

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	exit 1
}

grep -Fq 'skwd-wall = {' "$FLAKE" || fail "missing skwd-wall flake input"
grep -Fq 'url = "github:osmargm1202/skwd-wall";' "$FLAKE" || fail "skwd-wall input must use Osmar fork"
wall_node="$(jq -r '.nodes.root.inputs["skwd-wall"]' "$LOCK")"
daemon_node="$(jq -r --arg wall "$wall_node" '.nodes[$wall].inputs["skwd-daemon"]' "$LOCK")"
jq -e --arg daemon "$daemon_node" \
  '.nodes[$daemon].locked.owner == "osmargm1202" and .nodes[$daemon].locked.repo == "skwd-daemon"' \
  "$LOCK" >/dev/null || fail "skwd-wall must lock Osmar's patched daemon fork"
grep -Fq 'inputs.skwd-wall.nixosModules.default' "$PROFILE" || fail "Hyprland profile must import Skwd module"
grep -Fq 'programs.skwd-wall.enable = true;' "$PROFILE" || fail "Hyprland profile must enable Skwd"
grep -Fq 'systemd.user.targets.graphical-session.wants = [ "skwd-daemon.service" ];' "$PROFILE" ||
	fail "graphical session must start Skwd daemon declaratively"
if grep -Eq '^[[:space:]]+waytrogen([[:space:]]|$)' "$PROFILE"; then
	fail "Hyprland profile must not install Waytrogen"
fi

printf 'PASS: Skwd profile contract\n'
