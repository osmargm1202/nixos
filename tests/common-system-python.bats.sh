#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
inventory="$(mktemp)"
trap 'rm -f "$inventory"' EXIT
# Package availability is the contract; ordering and source whitespace are not.
nix eval --impure --json "path:$ROOT#nixosConfigurations" --apply '
  builtins.mapAttrs (_: system: let
    config = system.config;
    user = system._module.specialArgs.userName;
  in {
    development = builtins.elem "development" config.orgm.user.programs;
    packages = map (package: package.pname or package.name)
      (config.environment.systemPackages ++ config.users.users.${user}.packages
       ++ config.home-manager.users.${user}.home.packages);
  })
' > "$inventory"
python3 - "$inventory" <<'PY'
import json
import sys
with open(sys.argv[1]) as source:
    systems = json.load(source)
for host, config in systems.items():
    assert 'python3' in config['packages'], (host, 'Python 3 unavailable')
    if config['development']:
        assert 'uv' in config['packages'], (host, 'selected development tools lack uv')
print('PASS: Python 3 and selected development tools are available in effective desktop profiles')
PY
