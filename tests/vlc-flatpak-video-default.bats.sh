#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
inventory="$(mktemp)"
trap 'rm -f "$inventory"' EXIT
nix eval --impure --json "path:$ROOT#nixosConfigurations" --apply '
  builtins.mapAttrs (_: system: {
    apps = map (package: package.appId) system.config.services.flatpak.packages;
    defaults = system.config.xdg.mime.defaultApplications;
    i3 = system.config.services.xserver.windowManager.i3.enable;
  })
' > "$inventory"
python3 - "$inventory" <<'PY'
import json
import sys
with open(sys.argv[1]) as source:
    systems = json.load(source)
mimes = ('video/mp4', 'video/x-matroska', 'video/webm', 'video/quicktime',
         'video/x-msvideo', 'video/mpeg', 'video/ogg')
assert any(config['i3'] for config in systems.values()), 'must exercise i3 profile defaults'
def handlers(config, mime):
    value = config['defaults'].get(mime)
    return value if isinstance(value, list) else [value]
for host, config in systems.items():
    assert 'org.videolan.VLC' in config['apps'], (host, 'VLC Flatpak missing')
    if config['i3']:
        for mime in mimes:
            assert handlers(config, mime) == ['org.videolan.VLC.desktop'], (host, mime)
    else:
        # Keep MIME ownership in the profile rather than the shared Flatpak list.
        assert all(handlers(config, mime) != ['org.videolan.VLC.desktop']
                   for mime in mimes), (host, 'i3 VLC defaults leaked to another profile')
print('PASS: VLC installed for all desktop users; i3 video defaults remain profile-local')
PY
