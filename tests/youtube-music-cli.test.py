#!/usr/bin/env python3
"""Check the packaged player and its MPRIS integration without network or sound."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
projection = '''systems: builtins.mapAttrs (_: s: {
  enabled = s.config.orgm.youtubeMusicCli.enable;
  packages = map (p: p.outPath) (builtins.filter (p: (p.pname or "") == "youtube-music-cli") s.config.environment.systemPackages);
}) systems'''
systems = json.loads(subprocess.check_output([
    'nix', 'eval', '--json', f'path:{root}#nixosConfigurations', '--apply', projection,
], text=True))
assert all(x['enabled'] and len(x['packages']) == 1 for x in systems.values()), systems
packages = {x['packages'][0] for x in systems.values()}
assert len(packages) == 1, packages
package = Path(packages.pop())
with tempfile.TemporaryDirectory(prefix='orgm-ymc-test-') as home:
    env = dict(os.environ, HOME=home, XDG_CONFIG_HOME=home+'/.config', XDG_STATE_HOME=home+'/.local/state')
    assert subprocess.check_output([package/'bin/ymc', '--version'], env=env, text=True).strip() == '0.3.6'
    help_text = subprocess.check_output([package/'bin/youtube-music-cli', '--help'], env=env, text=True)
    assert 'search' in help_text and 'playlist' in help_text
    subprocess.run(['desktop-file-validate', str(package/'share/applications/orgm-youtube-music-cli.desktop')], check=True)
    mpv = subprocess.check_output([
        'nix', 'eval', '--impure', '--raw', '--expr',
        'let f = builtins.getFlake ("path:" + toString ./.); in (f.nixosConfigurations.orgm.pkgs.callPackage ./nixos/packages/youtube-music-cli.nix {}).mpvWithMpris.outPath',
    ], cwd=root, text=True).strip() + '/bin/mpv'
    script = '''set -eu
"$1" --ao=null --no-video --no-terminal --length=20 av://lavfi:sine=frequency=440 >/dev/null 2>&1 &
pid=$!
trap 'kill "$pid" 2>/dev/null || true' EXIT
for i in {1..50}; do
  if playerctl -a status 2>/dev/null | grep -qx Playing; then exit 0; fi
  sleep 0.1
done
exit 1
'''
    subprocess.run(['dbus-run-session', '--', 'bash', '-c', script, '_', mpv], env=env, check=True, timeout=15)
print('PASS: all hosts select YouTube Music CLI; CLI and silent MPRIS playback work')
