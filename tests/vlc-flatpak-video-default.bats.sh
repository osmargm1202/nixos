#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
inventory="$(mktemp)"
trap 'rm -f "$inventory"' EXIT
nix eval --impure --json "path:$ROOT#nixosConfigurations" --apply '
  builtins.mapAttrs (_: system: {
    desktop = system.config.environment.etc ? "orgm-dot/context.json";
    apps = map (package: package.appId) (system.config.services.flatpak.packages or []);
    defaults = system.config.xdg.mime.defaultApplications or {};
    i3 = system.config.services.xserver.windowManager.i3.enable or false;
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
    return value if isinstance(value, list) else value.split(";") if value else []
for host, config in systems.items():
    if not config['desktop']:
        assert 'org.videolan.VLC' not in config['apps'], (host, 'desktop packages leaked into appliance')
        assert all(not handlers(config, mime) for mime in mimes), (host, 'desktop MIME defaults leaked into appliance')
        continue
    assert 'org.videolan.VLC' in config['apps'], (host, 'VLC Flatpak missing')
    for mime in mimes:
        if mime == 'video/ogg':
            # Not published by FilmCraft; retain the existing i3 policy.
            if config['i3']: assert handlers(config, mime) == ['org.videolan.VLC.desktop'], (host, mime)
            continue
        assert handlers(config, mime)[0] == 'ai.storyteller.filmcraft.desktop', (host, mime)
        assert 'org.videolan.VLC.desktop' in handlers(config, mime), (host, mime)
print('PASS: VLC installed for all desktop users; i3 keeps VLC fallback after preferred FilmCraft')
PY
