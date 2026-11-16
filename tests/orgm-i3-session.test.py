#!/usr/bin/env python3
"""The normal i3 profile must coexist with Hyprland without a gaming variant."""
import importlib.machinery,importlib.util,json,os,re,subprocess,tempfile
from types import SimpleNamespace
from pathlib import Path
root=Path(__file__).resolve().parents[1]
projection='''s: let c=s.config; r=c.specialisation.server.configuration; in {
 x11=c.services.xserver.enable; hypr=c.programs.hyprland.enable;
 default=c.services.displayManager.defaultSession;
 sunshine=c.services.sunshine.enable; tailscale=c.services.tailscale.enable;
 dropins=builtins.attrNames c.home-manager.users.osmarg.xdg.configFile;
 greeter=c.services.displayManager.sddm.wayland.enable;
 sessions=c.services.displayManager.sessionData.sessionNames;
 variables=c.environment.sessionVariables;
 pamEnvironment=c.environment.etc."pam/environment".text;
 specialisations=builtins.attrNames c.specialisation;
 clipcat=c.systemd.user.services.i3-clipcat.wantedBy;
 picom=c.systemd.user.services ? picom;
 oskTargets=c.systemd.user.services.orgm-osk.wantedBy;
 oskCondition=c.systemd.user.services.orgm-osk.unitConfig.ConditionEnvironment;
 minimalConfig=toString c.home-manager.users.osmarg.xdg.configFile."i3/orgm-minimal.conf".source;
 autorandr=c.services.autorandr.enable;
 dunst=c.home-manager.users.osmarg.systemd.user.services.orgm-i3-dunst;
 gameTargets=c.orgm.i3GameActivation.targets;
 gameService=c.home-manager.users.osmarg.systemd.user.services.orgm-i3-game-activation.Unit;
 guards=map (unit: c.home-manager.users.osmarg.xdg.configFile."systemd/user/${unit}.d/90-orgm-session.conf".text)
 [ "picom.service" "orgm-osk.service" "orgm-hyprland-notifications.service" "xdg-desktop-portal-hyprland.service" ];
 bootstrap=c.home-manager.users.osmarg.home.activation.orgmI3Dotfiles.data;
 server={x11=r.services.xserver.enable;hypr=r.programs.hyprland.enable;
 packages=map toString r.services.displayManager.sessionPackages;
 gameTargets=r.orgm.i3GameActivation.targets;};
}'''
r=subprocess.run(['nix','eval','--impure','--json',f'path:{root}#nixosConfigurations.orgm','--apply',projection],capture_output=True,text=True)
assert r.returncode==0,r.stderr
c=json.loads(r.stdout)
assert c['x11'] and c['hypr'] and c['greeter']
assert c['default']=='hyprland' and c['specialisations']==['server']
assert 'orgm-i3' in c['sessions'] and 'hyprland' in c['sessions'] and 'orgm-gaming' not in c['sessions']
assert c['sunshine'] and c['tailscale']
assert not any('90-orgm-gaming' in p for p in c['dropins'])
assert c['clipcat']==['orgm-i3-session.target'] and not c['picom']
assert c['oskTargets']==['orgm-hyprland-session.target']
assert c['oskCondition']=='XDG_SESSION_TYPE=wayland'
assert c['guards']==['[Unit]\nConditionEnvironment=!XDG_CURRENT_DESKTOP=i3\n']+['[Unit]\nConditionEnvironment=XDG_SESSION_TYPE=wayland\n']*3
assert not c['autorandr']
assert 'XDG_SESSION_TYPE' not in c['variables']
# SDDM reads PAM before starting the X server or the session launcher. A
# Wayland value here makes it run an X11 desktop through wayland-session.
assert not re.search(r'^XDG_SESSION_TYPE\s',c['pamEnvironment'],re.M)
assert c['variables']['QT_QPA_PLATFORM']=='wayland'
assert '--profile i3 bootstrap' in c['bootstrap']
assert not c['server']['x11'] and not c['server']['hypr']
assert not any('orgm-i3-x11-session' in p for p in c['server']['packages'])
base=(root/'dotfiles/config/profiles/i3/.config/i3/config').read_text()
assert 'bindsym $mod+space exec --no-startup-id $run i3-rofi --drun' in base
assert 'bar {' in base and 'include ~/.config/i3/config.d/*.conf' in base
rofi=(root/'dotfiles/config/profiles/i3/.local/bin/i3-rofi').read_text()
assert '-show drun' in rofi and '-drun-categories' not in rofi
build=subprocess.run(['nix','build','--no-link','--print-out-paths',
 f'path:{root}#nixosConfigurations.orgm.config.home-manager.users.osmarg.xdg.configFile."i3/orgm-minimal.conf".source'],capture_output=True,text=True)
assert build.returncode==0,build.stderr
minimal=Path(c['minimalConfig']).read_text()
assert '18-osk.conf' not in minimal and '90-osmarg.conf' not in minimal
assert 'i3-monitor-profile --apply' not in minimal
assert '/bin/orgm-i3-status' in minimal
assert '/bin/rofi -show drun' in minimal and '/bin/rofi -show window' in minimal
assert 'exec_always --no-startup-id autotiling' in minimal
assert 'bindsym $mod+l exec --no-startup-id /nix/store/' in minimal
assert '/bin/i3lock -c 000000' in minimal and 'bindsym $mod+l focus right' not in minimal
assert 'for_window [class="(?i)^rofi$"] floating enable' in minimal
browserConfig=next(Path(line.removeprefix('include ')) for line in minimal.splitlines()
 if line.startswith('include /nix/store/') and line.endswith('orgm-i3-browser.conf')).read_text()
assert 'orgm-browser --restore-or-focus' in browserConfig
assert 'bindsym $mod+w exec --no-startup-id $browser' in browserConfig
assert 'firefox' not in browserConfig
personal=next(Path(line.removeprefix('include ')) for line in minimal.splitlines()
 if line.startswith('include /nix/store/') and line.endswith('orgm-i3-personal.conf')).read_text()
assert 'exec steam -silent' in personal
assert 'orgm-visual-profile' not in personal and 'set $status_command' not in personal
assert c['dunst']['Install']['WantedBy']==['orgm-i3-session.target']
assert c['dunst']['Service']['BusName']=='org.freedesktop.Notifications'
assert c['gameTargets']==['orgm-i3-session.target']
assert c['gameService']['ConditionEnvironment']=='XDG_CURRENT_DESKTOP=i3'
assert c['server']['gameTargets']==[]
# The personal bar keeps the detailed status and caffeine without visual
# selectors that could start effects or restore a wallpaper.
statusSource=root/'dotfiles/config/users/osmarg/profiles/i3/.local/bin/i3status-personal'
saved={key:os.environ.get(key) for key in ['I3_STATUS_PICOM','I3_STATUS_VISUAL_PROFILE','I3_STATUS_SERVERS']}
os.environ.update(I3_STATUS_PICOM='0',I3_STATUS_VISUAL_PROFILE='0',I3_STATUS_SERVERS='0')
loader=importlib.machinery.SourceFileLoader('orgm_i3_status',str(statusSource))
spec=importlib.util.spec_from_loader(loader.name,loader)
bar=importlib.util.module_from_spec(spec);loader.exec_module(bar)
for key,value in saved.items():
 if value is None:os.environ.pop(key,None)
 else:os.environ[key]=value
bar.keyboard_block=lambda: {'name':'keyboard','full_text':'US'}
bar.memory_sample=lambda: (1000000,500000)
bar.disk_available_bytes=lambda: 1024**3
bar.caffeine_enabled=lambda: True
bar.visual_profile_block=lambda: (_ for _ in ()).throw(AssertionError('Visual profile queried'))
blocks=bar.decorate([{'name':'tztime','full_text':'clock'}],SimpleNamespace(percent=lambda:10),None)
assert {b['name'] for b in blocks}=={'keyboard','caffeine','cpu','memory','disk','tztime'}
assert next(b for b in blocks if b['name']=='caffeine')['full_text']==bar.ICON_CAFFEINE_ON
clicks=[];originalPopen=bar.subprocess.Popen
bar.subprocess.Popen=lambda cmd,**kw:clicks.append(cmd)
bar.click_action({'name':'caffeine','button':1})
bar.click_action({'name':'picom-effects','button':1})
bar.click_action({'name':'visual-profile','button':1})
bar.click_action({'name':'orgm-status','button':1})
assert len(clicks)==1 and clicks[0][-1]=='toggle'
bar.subprocess.Popen=originalPopen
parsed=subprocess.run(['i3','-C','-c',c['minimalConfig']],capture_output=True,text=True)
assert parsed.returncode==0,(parsed.stdout,parsed.stderr)
# A companion session must undo the global Wayland defaults, without pausing
# the three explicitly required services or touching a real user manager.
with tempfile.TemporaryDirectory(prefix='orgm-i3-test-') as tmp:
 t=Path(tmp);b=t/'bin';b.mkdir()
 common='''#!/usr/bin/env python3
import json,os,sys
from pathlib import Path
with open(os.environ['PROBE_LOG'],'a') as f:f.write(json.dumps([Path(sys.argv[0]).name,*sys.argv[1:]])+'\\n')
'''
 for name in ['systemctl','dbus-update-activation-environment','i3']:
  body=''
  if name=='i3':body="assert os.environ['XDG_SESSION_TYPE']=='x11' and os.environ['XDG_CURRENT_DESKTOP']=='i3'\nassert os.environ['QT_QPA_PLATFORM']=='xcb' and os.environ['GDK_BACKEND']=='x11'\nassert 'WAYLAND_DISPLAY' not in os.environ\n"
  p=b/name;p.write_text(common+body);p.chmod(0o700)
 env=dict(os.environ,PATH=str(b)+':'+os.environ['PATH'],PROBE_LOG=str(t/'log'),DISPLAY=':99',XAUTHORITY=str(t/'authority'),XDG_SESSION_TYPE='wayland',WAYLAND_DISPLAY='old-wayland',ORGM_I3_CONFIG=c['minimalConfig'])
 r=subprocess.run(['bash','-euo','pipefail',str(root/'nixos/hosts/orgm/i3-session.sh')],env=env,capture_output=True,text=True)
 assert r.returncode==0,(r.stdout,r.stderr)
 calls=[json.loads(s) for s in (t/'log').read_text().splitlines()]
 assert ['systemctl','--user','start','orgm-i3-session.target'] in calls
 assert ['i3','-c',c['minimalConfig']] in calls
 assert not any(any(unit in call for unit in ['syncthing.service','sunshine.service','tailscaled.service']) for call in calls)
print('PASS: i3 startup/bindings and Steam preserved; detailed bar and caffeine; no OSK, Picom or wallpaper startup; X11 and headless Server preserved')
