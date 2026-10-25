#!/usr/bin/env python3
"""Evaluate shared packages, backend ownership and absence of VNC firewall holes."""
import json
from pathlib import Path
import subprocess
ROOT=Path(__file__).resolve().parents[1]
projection=r'''builtins.mapAttrs (_: system: let c=system.config;
 desktop=c.environment.etc ? "orgm-dot/context.json";
 ctx=if desktop then builtins.fromJSON c.environment.etc."orgm-dot/context.json".text
     else { profile="multimedia"; user="media"; };
 service=c.systemd.user.services.orgm-remote-desktop or null;
 in { inherit desktop; inherit (ctx) profile; apps=map (p: p.appId) (c.services.flatpak.packages or []);
 service=if service == null then null else {
 inherit (service) wantedBy partOf;
 exec=service.serviceConfig.ExecStart;
 restrict=service.serviceConfig.RestrictAddressFamilies or [];
 restart=service.serviceConfig.Restart;
 };
 activation=c.home-manager.users.${ctx.user}.home.activation.remoteDesktopProfiles.data or "";
 ports=c.networking.firewall.allowedTCPPorts;
 tunnel=c.systemd.user.services."orgm-remote-tunnel@".serviceConfig.ExecStart or "";
 })'''
hosts=json.loads(subprocess.check_output(['nix','eval','--impure','--json',f'path:{ROOT}#nixosConfigurations','--apply',projection],text=True))
for host,c in hosts.items():
    if not c['desktop']:
        assert c['service'] is None and not c['activation'] and not c['tunnel'],(host,c)
        assert not any(5900<=port<=5999 for port in c['ports']),(host,c['ports'])
        print('PASS:',host,'appliance excludes desktop sharing and VNC ports')
        continue
    assert c['apps'].count('org.remmina.Remmina')==1,(host,c['apps'])
    assert c['service'] is not None,(host,'remote service missing')
    service=c['service']
    target='sway-session.target' if c['profile']=='sway' else 'orgm-hyprland-session.target' if c['profile']=='hyprland' else 'graphical-session.target'
    assert service['wantedBy']==[target] and service['partOf']==[target],(host,service)
    assert 'remote.py server' in service['exec'],(host,service)
    assert service['restrict']==['AF_UNIX'],(host,service)
    assert service['restart']=='always',(host,service)
    assert not any(5900<=port<=5999 for port in c['ports']),(host,c['ports'])
    assert 'xdg-run/orgm-remote-desktop:ro' in c['activation'],host
    assert 'orgm-remote-tunnel@' in c['activation'],host
    assert 'remote.py tunnel-service %i' in c['tunnel'],(host,'managed SSH tunnel missing')
    print('PASS:',host,'shared Remmina; private, session-owned backend; no TCP VNC ports')
for profile in ('sway','hyprland','i3'):
    output=subprocess.check_output(['orgm-dot','--repo',str(ROOT),'--user','jarq','--host','jarq','--profile',profile,'list'],text=True)
    assert 'remote-desktop' in output,profile
print('PASS: independent manifest ownership in all three desktop profiles')
