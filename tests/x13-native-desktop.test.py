#!/usr/bin/env python3
"""X13 package/service cleanup and strict host scope; no devices are accessed."""
import json
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
flake = sys.argv[1] if len(sys.argv) > 1 else str(root)
projection = r'''systems: let
  s=systems.x13; c=s.config; lib=s.pkgs.lib; h=c.home-manager.users.osmarg;
  names=ps: map lib.getName ps;
  owns=s: builtins.any (p: lib.hasSuffix "/hosts/x13/native-desktop.nix" (toString p))
    s.options.environment.systemPackages.declarations;
in {
  packages=names (c.environment.systemPackages ++ h.home.packages);
  scope=owns systems.x13;
  gdm=c.services.displayManager.gdm.enable;
  bluetooth=c.hardware.bluetooth.enable;
  blueman=c.services.blueman.enable;
  udiskie=c.systemd.user.services.udiskie.enable;
  udisks=c.services.udisks2.enable;
  gvfs=c.services.gvfs.enable;
  scanner=c.hardware.sane.enable;
  printing=c.services.printing.enable;
  automount=h.dconf.settings."org/gnome/desktop/media-handling".automount;
  flatpaks=map (p: if builtins.isString p then p else p.appId) c.services.flatpak.packages;
  server={gdm=c.specialisation.server.configuration.services.displayManager.gdm.enable;
    udiskie=c.specialisation.server.configuration.systemd.user.services.udiskie.enable;};
}'''
r = subprocess.run(['nix', 'eval', '--impure', '--json', f'path:{flake}#nixosConfigurations',
                    '--apply', projection], text=True, capture_output=True)
assert r.returncode == 0, r.stderr
c = json.loads(r.stdout)
names = set(c['packages'])
blocked = {'udiskie','blueman','totem','showtime','papers','simple-scan','gnome-connections','gnome-maps'}
assert not blocked & names, blocked & names
assert {'snapshot','gnome-sound-recorder','evince','nautilus','gnome-console','kitty'} <= names
assert c['scope']
importers = [p.relative_to(flake).as_posix() for p in Path(flake).glob('nixos/**/*.nix')
             if p.name != 'native-desktop.nix' and './native-desktop.nix' in p.read_text()]
assert importers == ['nixos/hosts/x13/gnome.nix'], importers
assert all(c[k] for k in ['gdm','bluetooth','udisks','gvfs','scanner','printing','automount'])
assert not c['udiskie'] and not c['blueman'] and not any(c['server'].values())
assert {'org.gnome.SimpleScan','org.videolan.VLC','org.remmina.Remmina','com.discordapp.Discord'} <= set(c['flatpaks'])
print('PASS: X13-only cleanup, native camera/audio recorder, preferred apps and hardware services preserved')
