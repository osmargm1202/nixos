#!/usr/bin/env python3
"""Evaluate OSK for both users, lifecycle, backend and non-desktop boundaries."""
import json,subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[1]
expr="""let f=builtins.getFlake "path:__ROOT__";
 describe = c: {enabled=c.orgm.osk.enable or false;
 service=c.systemd.user.services ? orgm-osk;
 wanted=c.systemd.user.services.orgm-osk.wantedBy or [];
 partOf=c.systemd.user.services.orgm-osk.partOf or [];
 backend=c.systemd.user.services.orgm-osk.environment.ORGM_OSK_BACKEND or "";
 platform=c.systemd.user.services.orgm-osk.environment.QT_QPA_PLATFORM or "";
 start=c.systemd.user.services.orgm-osk.serviceConfig.ExecStart or "";
 package=builtins.any (p: (p.name or "") == "orgm-osk-engine") c.environment.systemPackages;
};in {
 envy=describe f.nixosConfigurations.envy.config;
 jarq=describe f.nixosConfigurations.jarq.config;
 orgm=describe f.nixosConfigurations.orgm.config;
 server=describe f.nixosConfigurations.envy.config.specialisation.server.configuration;
 terminal=describe (f.lib.mkSystem {hostName="osk-console";role="terminal";}).config;
}"""
data=json.loads(subprocess.check_output(['nix','eval','--impure','--json','--expr',expr.replace('__ROOT__',str(root))],text=True))
for name,target,backend,platform,user in [
 ('envy','sway-session.target','wayland','wayland','osmarg'),
 ('jarq','graphical-session.target','x11','xcb','jarq'),
 ('orgm','orgm-hyprland-session.target','wayland','wayland','osmarg')]:
 c=data[name]
 assert c['enabled'] and c['service'] and c['package'],name+': OSK missing'
 assert c['wanted']==[target] and c['partOf']==[target],c
 assert c['backend']==backend and c['platform']==platform,c
 assert c['start']=='/home/'+user+'/.local/bin/orgm-osk daemon',c
for name in ('server','terminal'):
 assert not data[name]['enabled'] and not data[name]['service'] and not data[name]['package'],name+': OSK leaked'
print('PASS: both users, 3 compositor lifecycles/backends; server and terminal excluded')
