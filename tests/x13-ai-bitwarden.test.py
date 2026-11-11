#!/usr/bin/env python3
"""Native AI binding and trusted Bitwarden/Origin bridge without opening a vault."""
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

root=Path(__file__).resolve().parents[1]
flake=sys.argv[1] if len(sys.argv)>1 else str(root)
projection=r'''s: let c=s.config; h=c.home-manager.users.osmarg; in {
 ai=h.dconf.settings."org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/x13-orgmai";
 grid=h.dconf.settings."org/gnome/shell/keybindings".toggle-application-view;
 manifest=h.xdg.configFile."BraveSoftware/Brave-Origin/NativeMessagingHosts/com.8bit.bitwarden.json".text;
 package=toString s.pkgs.bitwarden-desktop;
 python=toString (s.pkgs.python3.withPackages (ps: [ps.pygobject3]));
 typelib="${s.pkgs.glib.out}/lib/girepository-1.0";
 schema="${s.pkgs.gnome-settings-daemon}/share/gsettings-schemas/${s.pkgs.gnome-settings-daemon.name}/glib-2.0/schemas";
}'''
r=subprocess.run(['nix','eval','--impure','--json',f'path:{flake}#nixosConfigurations.x13','--apply',projection],capture_output=True,text=True)
assert r.returncode==0,r.stderr
c=json.loads(r.stdout)
assert c['ai']['binding']=='<Super>a' and c['ai']['name']=='ORGM AI'
assert c['grid']=="@as []",c['grid']
launcher=Path(c['ai']['command']).read_text()
# Compare the meaningful invocation with the existing Hyprland binding.
expected=['--class orgmai-chat','remember_window_size=no','initial_window_width=160c','initial_window_height=42c','/bin/orgmai new']
assert all(arg in launcher for arg in expected),launcher
assert '/bin/kitty' in launcher
subprocess.run(['bash','-n',c['ai']['command']],check=True)
manifest=json.loads(c['manifest'])
assert manifest['name']=='com.8bit.bitwarden' and manifest['type']=='stdio'
assert manifest['allowed_origins']==['chrome-extension://nngceckbapebfimnlniiiahkandclblb/']
assert manifest['path']==c['package']+'/libexec/desktop_proxy'
assert os.access(manifest['path'],os.X_OK)
policy=ET.parse(c['package']+'/share/polkit-1/actions/com.bitwarden.Bitwarden.policy')
action=policy.find("./action[@id='com.bitwarden.Bitwarden.unlock']")
assert action is not None
assert action.findtext('./defaults/allow_active')=='auth_self'
assert action.findtext('./defaults/allow_inactive')=='no'
# Use real Gio/GSettings with a memory backend: test preservation/idempotence
# without touching any of the current user's custom shortcuts.
probe=r'''
import gi,runpy,sys
gi.require_version('Gio','2.0')
from gi.repository import Gio
settings=Gio.Settings.new('org.gnome.settings-daemon.plugins.media-keys')
existing='/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/keep-me/'
settings.set_strv('custom-keybindings',[existing])
for _ in range(2):runpy.run_path(sys.argv[1])
paths=settings.get_strv('custom-keybindings')
assert paths==[existing,'/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/x13-orgmai/'],paths
'''
env=dict(os.environ,GSETTINGS_BACKEND='memory',GSETTINGS_SCHEMA_DIR=c['schema'],GI_TYPELIB_PATH=c['typelib'])
r=subprocess.run([c['python']+'/bin/python3','-c',probe,str(Path(flake)/'nixos/hosts/x13/ai-shortcut-enable.py')],env=env,capture_output=True,text=True)
assert r.returncode==0,(r.stdout,r.stderr)
print('PASS: Super+A matches Hyprland AI command; real GSettings merge preserves shortcuts; trusted Origin host and auth_self policy')
