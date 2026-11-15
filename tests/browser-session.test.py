#!/usr/bin/env python3
"""Origin and its webapps must support both primary desktops and optional i3."""
import json
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[1]
projection = '''s: let c=s.config; in {
 package=toString c.orgm.browser.package;
 userBinary=toString c.home-manager.users.osmarg.home.file.".local/bin/brave-origin".source;
 userDesktop=toString c.home-manager.users.osmarg.home.file.".local/share/applications/brave-origin.desktop".source;
 launchers=map (p: p.text) (builtins.filter
  (p: builtins.match "orgm-webapp-.*" (p.name or "") != null)
  c.home-manager.users.osmarg.home.packages);
}'''
packages = set()
for host in ['orgm', 'x13']:
    r = subprocess.run(['nix', 'eval', '--impure', '--json',
                        f'path:{root}#nixosConfigurations.{host}', '--apply', projection],
                       capture_output=True, text=True, cwd=root, check=True)
    c = json.loads(r.stdout)
    assert c['userBinary'] == c['package']+'/bin/brave-origin'
    assert c['userDesktop'] == c['package']+'/share/applications/brave-origin.desktop'
    assert c['launchers'], host
    for launcher in c['launchers']:
        assert '--ozone-platform=' not in launcher, (host, launcher)
        assert '--profile-directory=Default' in launcher
        assert '--user-data-dir=' not in launcher
    packages.add(c['package'])
for package in packages:
    subprocess.run(['nix', 'build', '--no-link', package], check=True)
    wrapper = (Path(package)/'bin/brave-origin').read_text()
    assert '--ozone-platform=wayland' not in wrapper
    assert '--ozone-platform=x11' not in wrapper
    assert '--ozone-platform=auto' not in wrapper
print('PASS: Origin uses native session detection; webapps retain shared profile without forcing Wayland')
