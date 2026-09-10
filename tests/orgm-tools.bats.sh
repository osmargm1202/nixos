#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 - "$ROOT" <<'PY'
import json
import os
import subprocess
import sys

flake = f"path:{sys.argv[1]}"

def evaluate(attribute, expression):
    result = subprocess.run(
        ["nix", "eval", "--impure", "--json", f"{flake}#{attribute}", "--apply", expression],
        text=True, capture_output=True, check=True,
        env={**os.environ, "NIXPKGS_ALLOW_UNFREE": "1"},
    )
    return json.loads(result.stdout)

commands = {
    "orgmai": "orgmai",
    "orgm-organize": "orgm-organize",
    "orgm-rnc": "orgmrnc",
    "orgm-bt": "orgm-bt",
    "orgm-todo": "orgm-todo",
}
expected_packages = sorted(commands.values())
exports = evaluate("packages.x86_64-linux", '''packages: builtins.mapAttrs
  (_: package: package.meta.mainProgram)
  (builtins.intersectAttrs {
    orgmai = null; orgm-organize = null; orgm-rnc = null; orgm-bt = null; orgm-todo = null;
  } packages)''')
assert exports == commands, f"Missing or incorrect runnable tool exports: {exports}"

names = evaluate("nixosConfigurations", "builtins.attrNames")
# Separate Nix processes deliberately bound evaluation memory across hosts.
for name in names:
    tools = evaluate(f"nixosConfigurations.{name}.config.environment.systemPackages", '''packages:
      builtins.filter (name: builtins.elem name [ "orgmai" "orgm-organize" "orgmrnc" "orgm-bt" "orgm-todo" ])
        (map (package: package.pname or package.name) packages)''')
    assert sorted(tools) == expected_packages, f"{name}: tool set is incomplete or duplicated: {tools}"
    print(f"PASS: {name}: all five OrgM tools installed")
print(f"PASS: runnable exports and all {len(names)} NixOS configurations include the OrgM collection")
PY
