#!/usr/bin/env python3
"""Validate shared wallpaper and GLib's actual GDM-only CSS resource overlay."""
import json
import os
from pathlib import Path
import subprocess
import sys

root=Path(__file__).resolve().parents[1]
if len(sys.argv)>2 and sys.argv[1]=='--config':
    c=json.loads(Path(sys.argv[2]).read_text())
else:
    flake=sys.argv[1] if len(sys.argv)>1 else str(root)
    projection=r'''s: let c=s.config; d=c.home-manager.users.osmarg.dconf.settings; in {
      desktop=d."org/gnome/desktop/background";
      lock=d."org/gnome/desktop/screensaver".picture-uri;
      service={inherit (c.systemd.user.services."org.gnome.Shell@gdm") overrideStrategy restartIfChanged serviceConfig environment;};
      userService=c.systemd.user.services."org.gnome.Shell@user" or null;
      serverService=c.specialisation.server.configuration.systemd.user.services."org.gnome.Shell@gdm" or null;
      origin=c.orgm.browser.enable;
      shell=toString s.pkgs.gnome-shell;
      glibDev=toString s.pkgs.glib.dev;
      gjs=toString s.pkgs.gjs;
    }'''
    r=subprocess.run(['nix','eval','--impure','--json',f'path:{flake}#nixosConfigurations.x13','--apply',projection],capture_output=True,text=True)
    assert r.returncode==0,r.stderr
    c=json.loads(r.stdout)
uri=c['desktop']['picture-uri']
assert uri==c['desktop']['picture-uri-dark']==c['lock']
assert uri.startswith('file:///nix/store/')
image=Path(uri.removeprefix('file://'))
assert image.read_bytes().startswith(b'\x89PNG\r\n\x1a\n')
service=c['service']
assert service['overrideStrategy']=='asDropin' and not service['restartIfChanged']
assert service['environment']=={}, 'preserve the greeter PATH and inherited environment'
assert c['userService'] is None and c['serverService'] is None
assert c['origin'],'Origin/webapp improvements must survive'
environment=service['serviceConfig']['Environment']
assert environment.startswith('G_RESOURCE_OVERLAYS=/org/gnome/shell/theme=/nix/store/')
overlay=environment.split('=',2)[2]
for variant in ('dark','light'):
    css=(Path(overlay)/f'gnome-shell-{variant}.css').read_text()
    assert len(css)>10000 and css.count('#lockDialogGroup')>=2
    assert f'background-image: url("{uri}")' in css
assert not (Path(overlay)/'gnome-shell-high-contrast.css').exists()
# Exercise the same global resource URI lookup that Shell uses; merely reading
# the overlay file would not prove that G_RESOURCE_OVERLAYS is honored.
js='''const Gio=imports.gi.Gio;
const bundle=Gio.Resource.load(ARGV[0]); bundle._register();
for (const variant of ['dark','light']) {
 const file=Gio.File.new_for_uri(`resource:///org/gnome/shell/theme/gnome-shell-${variant}.css`);
 const [ok,bytes]=file.load_contents(null);
 const css=new TextDecoder().decode(bytes);
 if (!ok || !css.includes('X13: same image as the desktop.')) throw new Error('overlay ignored');
}
print('PASS: actual Gio resource lookups use both patched CSS variants');'''
r=subprocess.run([c['gjs']+'/bin/gjs','-c',js,c['shell']+'/share/gnome-shell/gnome-shell-theme.gresource'],env=dict(os.environ,G_RESOURCE_OVERLAYS='/org/gnome/shell/theme='+overlay),capture_output=True,text=True)
assert r.returncode==0,(r.stdout,r.stderr)
print(r.stdout.strip())
print('PASS: shared PNG image, GDM-only drop-in, unchanged user/Server Shell and Origin retained')
