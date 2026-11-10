#!/usr/bin/env python3
"""Public evaluated X13 tray, service and shortcut contract."""
import json
from pathlib import Path
import subprocess
import runpy
import sys
from types import ModuleType, SimpleNamespace
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
projection = r'''s: let
  c = s.config; hm = c.home-manager.users.osmarg;
  names = ps: map (p: p.pname or (s.pkgs.lib.getName p)) ps;
in {
  masks = map (n: hm.xdg.configFile."autostart/${n}.desktop".text or "") [ "syncthingtray" "tailscale-systray" ];
  packages = names (c.environment.systemPackages ++ hm.home.packages);
  syncthing = hm.systemd.user.services.syncthing.Service.ExecStart or "";
  tailscale = c.services.tailscale.enable;
  close = hm.dconf.settings."org/gnome/desktop/wm/keybindings".close or [];
  extensions = map (p: p.extensionUuid) (builtins.filter (p: p ? extensionUuid) hm.home.packages);
  login = hm.systemd.user.services.x13-focus-shortcuts or {};
  extensionFiles = builtins.attrNames hm.xdg.dataFile;
}'''
r = subprocess.run(['nix', 'eval', '--impure', '--json', f'path:{root}#nixosConfigurations.x13', '--apply', projection], cwd=root, text=True, capture_output=True)
assert r.returncode == 0, r.stderr
c = json.loads(r.stdout)
assert all('Hidden=true' in text for text in c['masks']), c['masks']
assert 'syncthingtray' not in c['packages']
assert c['syncthing'] and c['tailscale'], 'trays are not background services'
assert c['close'] == "@as ['<Super>q']"
assert 'gnome-ui-tune@itstime.tech' not in c['extensions']
assert any('x13-focus-shortcuts' in f for f in c['extensionFiles'])
extension = root / 'nixos/hosts/x13/focus-shortcuts'
schema = ET.parse(extension / 'schemas/org.gnome.shell.extensions.x13-focus-shortcuts.gschema.xml')
assert {key.attrib['name']: key.findtext('default') for key in schema.findall('.//key')} == {
    'console': "['<Super>Return']", 'firefox': "['<Super>w']", 'files': "['<Super>e']"}
assert json.loads((extension / 'metadata.json').read_text())['shell-version'] == ['50']
assert c['login']['Install']['WantedBy'] == ['gnome-session.target']
assert c['login']['Unit']['PartOf'] == ['graphical-session.target']
assert c['login']['Service']['Type'] == 'oneshot'
# Run the shipped login entry point with the public Gio Settings API stubbed.
values = {'enabled-extensions': ['manual@example', 'gnome-ui-tune@itstime.tech'],
          'disabled-extensions': ['another@example', 'x13-focus-shortcuts@orgm.local']}
writes = []
class Settings:
    def get_strv(self, key):
        return list(values[key])
    def set_strv(self, key, value):
        values[key] = list(value)
        writes.append((key, list(value)))
settings = Settings()
gi = ModuleType('gi')
gi.require_version = lambda *args: None
repository = ModuleType('gi.repository')
repository.Gio = SimpleNamespace(Settings=SimpleNamespace(new=lambda schema: settings, sync=lambda: None))
sys.modules.update({'gi': gi, 'gi.repository': repository})
for _ in range(2):
    runpy.run_path(str(root / 'nixos/hosts/x13/focus-shortcuts/enable.py'), run_name='__main__')
    assert values == {'enabled-extensions': ['manual@example', 'x13-focus-shortcuts@orgm.local'],
                      'disabled-extensions': ['another@example']}
assert len(writes) == 2, 'second login must not rewrite unchanged settings'
print('PASS: X13 tray masks/packages, background services, native close and login extension merge')
# Preserve the existing shared consumers through their evaluated public config.
previous = r'''systems: builtins.listToAttrs (map (name: let
  s = systems.${name}; c = s.config; hm = c.home-manager.users.osmarg;
in { inherit name; value = {
  masks = map (n: hm.xdg.configFile."autostart/${n}.desktop".text or "") [ "syncthingtray" "tailscale-systray" ];
  trayPackage = builtins.any (p: (p.pname or "") == "syncthingtray") hm.home.packages;
  sync = hm.systemd.user.services.syncthing.Service.ExecStart or "";
  vpn = c.services.tailscale.enable;
}; }) [ "orgm" "envy" "orgm-ryoku" ])'''
r = subprocess.run(['nix', 'eval', '--impure', '--json', f'path:{root}#nixosConfigurations', '--apply', previous], cwd=root, text=True, capture_output=True)
assert r.returncode == 0, r.stderr
for name, host in json.loads(r.stdout).items():
    assert not host['trayPackage'] and host['sync'] and host['vpn'], (name, host)
    assert all(not text or 'Hidden=true' in text for text in host['masks']), (name, host)
print('PASS: existing ORGM, Envy and Ryoku tray/service policies preserved')
