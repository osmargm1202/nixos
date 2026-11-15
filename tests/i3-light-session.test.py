#!/usr/bin/env python3
"""Optional i3 on the laptops: primary desktops and console modes stay intact."""
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FLAKE = f"path:{ROOT}"
PROJECTION = '''s: let
 c=s.config;
 baseline=(s.extendModules { modules=[({lib,...}: { orgm.i3LightSession.enable=lib.mkForce false; })]; }).config;
 unchanged=x: {
  default=x.services.displayManager.defaultSession;
  gdm=x.services.displayManager.gdm.enable;
  sddm=x.services.displayManager.sddm.enable;
  gnome=x.services.desktopManager.gnome.enable;
  sway=x.programs.sway.enable;
  kernel=x.boot.kernelPackages.kernel.outPath;
  video=x.services.xserver.videoDrivers;
  prime=x.hardware.nvidia.prime.offload.enable;
  programs=x.orgm.user.programs;
  autostart=x.orgm.user.autostart;
  directory=x.xdg.mime.defaultApplications."inode/directory";
  specialisations=builtins.attrNames x.specialisation;
 };
 headless=x: {
  x11=x.services.xserver.enable;
  sessions=x.services.displayManager.sessionData.sessionNames or [];
  targets=builtins.attrNames x.systemd.user.targets;
 };
in {
 inherit (c.services.displayManager.sessionData) sessionNames;
 before=unchanged baseline; after=unchanged c;
 x11=c.services.xserver.enable;
 variables=c.environment.sessionVariables;
 portal=c.xdg.portal.config.i3.default;
 target=c.systemd.user.targets.orgm-i3-light-session.bindsTo;
 notifications={
  wantedBy=c.systemd.user.services.i3-light-notifications.wantedBy;
  busName=c.systemd.user.services.i3-light-notifications.serviceConfig.BusName;
 };
 oskTargets=if c.orgm.osk.enable then c.systemd.user.services.orgm-osk.wantedBy else [];
 server=headless c.specialisation.server.configuration;
 gaming=if c.specialisation ? gaming then headless c.specialisation.gaming.configuration else null;
 windows=if c.specialisation ? windows-vfio then c.specialisation.windows-vfio.configuration.services.displayManager.sessionData.sessionNames else [];
 assertions=map (a: a.message) (builtins.filter (a: !a.assertion) c.assertions);
}'''

def run(args, **kwargs):
    result = subprocess.run(args, cwd=ROOT, capture_output=True, text=True, **kwargs)
    assert result.returncode == 0, (args, result.stdout, result.stderr)
    return result.stdout

configs = []
for host, default in [('envy', 'sway'), ('x13', 'gnome')]:
    c = json.loads(run(['nix', 'eval', '--impure', '--json',
                        f'{FLAKE}#nixosConfigurations.{host}', '--apply', PROJECTION]))
    assert c['before'] == c['after'], (host, c['before'], c['after'])
    assert c['after']['default'] == default
    assert 'orgm-i3-light' in c['sessionNames'] and default in c['sessionNames']
    assert c['x11'] and c['portal'] in ('gtk', ['gtk']) and not c['assertions'], (host, c['x11'], c['portal'], c['assertions'])
    assert 'XDG_SESSION_TYPE' not in c['variables']
    assert c['notifications']['wantedBy'] == ['orgm-i3-light-session.target']
    assert 'orgm-i3-light-session.target' not in c['oskTargets']
    for mode in [c['server'], c['gaming']]:
        if mode is not None:
            assert not mode['x11'] and 'orgm-i3-light' not in mode['sessions']
            assert 'orgm-i3-light-session' not in mode['targets']
    if host == 'envy':
        assert 'orgm-i3-light' in c['windows']
    package = run(['nix', 'build', '--impure', '--no-link', '--print-out-paths', '--expr',
                   f'let s=(builtins.getFlake "{FLAKE}").nixosConfigurations.{host}; in '
                   's.pkgs.lib.findFirst (p: (p.name or "") == "i3-light-desktop") null s.config.services.displayManager.sessionPackages']).strip()
    desktop = (Path(package) / 'share/xsessions/orgm-i3-light.desktop').read_text()
    launcher = Path(re.search(r'^Exec=(.+)$', desktop, re.M)[1])
    config = Path(re.search(r'export I3_LIGHT_CONFIG=(\S+)', launcher.read_text())[1])
    content = config.read_text()
    assert not re.search(r'\b(picom|orgm-osk|feh|swaybg|dex|orgm-visual-profile)\b', content)
    assert 'include ' not in content and 'autotiling' not in content
    assert 'i3-light-status' in content and 'i3-caffeine-toggle' in content
    assert '@DEFAULT_SINK@' in content and '@DEFAULT_SOURCE@' in content
    assert '-show drun' in content and '-show window' in content
    assert not re.search(r'@[a-z][a-zA-Z]*@', content)
    run(['i3', '-C', '-c', str(config)])
    configs.append(str(config))
    print(f'PASS: {host}: optional i3, unchanged {default}/GPU/autostart, headless modes intact; real config parses')

# Execute the real launcher body against stubs; no user manager or display is touched.
with tempfile.TemporaryDirectory(prefix='i3-light-session-test-') as tmp:
    t = Path(tmp)
    commands = '''#!/usr/bin/env python3
import json,os,sys
from pathlib import Path
with open(os.environ['PROBE_LOG'],'a') as f: f.write(json.dumps([Path(sys.argv[0]).name,*sys.argv[1:]])+'\\n')
'''
    for name in ['systemctl', 'dbus-update-activation-environment', 'i3']:
        body = commands
        if name == 'i3':
            body += "assert os.environ['XDG_SESSION_TYPE']=='x11'\nassert os.environ['QT_QPA_PLATFORM']=='xcb'\nassert all(k not in os.environ for k in ['SWAYSOCK','WAYLAND_DISPLAY','HYPRLAND_INSTANCE_SIGNATURE'])\n"
        (t/name).write_text(body)
        (t/name).chmod(0o755)
    env = dict(os.environ, PATH=str(t)+':'+os.environ['PATH'], DISPLAY=':99',
               XAUTHORITY=str(t/'authority'), I3_LIGHT_CONFIG=configs[0],
               PROBE_LOG=str(t/'log'), WAYLAND_DISPLAY='old', SWAYSOCK='old',
               HYPRLAND_INSTANCE_SIGNATURE='old', XDG_SESSION_TYPE='wayland')
    run(['bash', '-euo', 'pipefail', str(ROOT/'nixos/profiles/i3/light-session.sh')], env=env)
    calls = [json.loads(line) for line in (t/'log').read_text().splitlines()]
    assert ['i3', '-c', configs[0]] in calls
    assert ['systemctl', '--user', 'start', 'orgm-i3-light-session.target'] in calls
    assert ['systemctl', '--user', 'stop', 'orgm-i3-light-session.target', 'graphical-session.target'] in calls
    cleared = next(i for i, call in enumerate(calls) if call[:3] == ['systemctl', '--user', 'unset-environment'])
    wayland = next(i for i, call in enumerate(calls) if call[:2] == ['dbus-update-activation-environment', 'WAYLAND_DISPLAY='])
    assert cleared > wayland
    assert not any('orgm-osk.service' in call or 'picom.service' in call for call in calls)
print('PASS: X11 environment isolation, session target and logout cleanup')
