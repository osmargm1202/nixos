#!/usr/bin/env python3
"""Manual, session-scoped tablet presentation. No sensors or keyboard daemon."""
import copy
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile


def preferences_path():
    return Path(os.environ.get('XDG_STATE_HOME',Path.home()/'.local/state'))/'orgm-tablet/preferences.json'


def load_policy():
    try:
        path=preferences_path()
        data=json.loads(path.read_text()) if not path.is_symlink() and path.stat().st_size<4096 else {}
    except (OSError,ValueError):
        data={}
    # Old auto preferences must not keep any automatic behavior alive.
    return {'mode':'on' if isinstance(data,dict) and data.get('mode')=='on' else 'off'}


def private_directory(path):
    path.mkdir(mode=0o700,parents=True,exist_ok=True)
    if path.is_symlink() or path.stat().st_uid!=os.getuid():
        raise ValueError('Directorio tablet no válido')


def set_policy(mode):
    if mode not in ('on','off','toggle'):
        raise ValueError('El modo automático se eliminó; usa on, off o toggle')
    path=preferences_path();private_directory(path.parent)
    with os.fdopen(os.open(path.parent/'policy.lock',os.O_CREAT|os.O_RDWR|os.O_NOFOLLOW,0o600),'w') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        if path.is_symlink():raise ValueError('Preferencia tablet enlazada no válida')
        if mode=='toggle':mode='off' if load_policy()['mode']=='on' else 'on'
        fd,name=tempfile.mkstemp(prefix='.policy-',dir=path.parent)
        try:
            with os.fdopen(fd,'w') as output:json.dump({'schema':2,'mode':mode},output);output.write('\n')
            os.replace(name,path)
        finally:Path(name).unlink(missing_ok=True)
    return mode


def compositor():
    forced=os.environ.get('ORGM_DESKTOP_COMPOSITOR','').lower()
    desktop=os.environ.get('XDG_CURRENT_DESKTOP','').lower()
    if forced in ('sway','hyprland'):return forced
    if 'hyprland' in desktop:return 'hyprland'
    if 'sway' in desktop:return 'sway'
    if os.environ.get('SWAYSOCK') and not os.environ.get('HYPRLAND_INSTANCE_SIGNATURE'):return 'sway'
    if os.environ.get('HYPRLAND_INSTANCE_SIGNATURE') and not os.environ.get('SWAYSOCK'):return 'hyprland'
    raise RuntimeError('Se requiere una sesión Sway o Hyprland identificada')


def keyboard_state():
    try:
        result=subprocess.run(['orgm-osk','status'],capture_output=True,text=True,timeout=2,check=True)
        value=json.loads(result.stdout)
        return value if isinstance(value,dict) else {}
    except (OSError,ValueError,subprocess.SubprocessError):return {}


def state():
    try:available=bool(os.environ.get('WAYLAND_DISPLAY') and compositor())
    except RuntimeError:available=False
    keyboard=keyboard_state() if available else {}
    mode=load_policy()['mode']
    return dict(available=available,mode=mode,active=mode=='on',source='manual',detected=None,
                keyboardAvailable=bool(keyboard.get('ready')),keyboardRunning=bool(keyboard.get('ready')),
                keyboardVisible=bool(keyboard.get('open')))


def apply_profile():
    comp=compositor()
    result=subprocess.run(['systemctl','--user','show-environment'],check=True,capture_output=True,text=True,timeout=3)
    manager=dict(line.split('=',1) for line in result.stdout.splitlines() if '=' in line)
    identity='SWAYSOCK' if comp=='sway' else 'HYPRLAND_INSTANCE_SIGNATURE'
    if (not os.environ.get(identity) or manager.get(identity)!=os.environ[identity]
            or not os.environ.get('WAYLAND_DISPLAY') or manager.get('WAYLAND_DISPLAY')!=os.environ['WAYLAND_DISPLAY']):
        raise RuntimeError('No se reinician barras/docks de otra sesión o pantalla')
    subprocess.run(['systemctl','--user','restart','orgm-'+comp+'-waybar.service','orgm-'+comp+'-dock.service'],check=True,timeout=15)


def bar_profile(source,comp,active):
    value=copy.deepcopy(source)
    if not active:return value
    if comp not in ('sway','hyprland'):raise ValueError('Compositor inválido')
    for bar in value if isinstance(value,list) else [value]:
        if not isinstance(bar,dict):raise ValueError('Barra inválida')
        bar.update(height=52,spacing=8)
        bar['modules-left']=['battery'] if 'battery' in bar else []
        bar['modules-center']=['clock']
        # A hidden module must remain instantiated: the CC controls its real
        # Wayland idle inhibitor, not just the persisted caffeine flag.
        bar['modules-right']=['idle_inhibitor','custom/control'] if 'idle_inhibitor' in bar else ['custom/control']
        if 'idle_inhibitor' in bar:
            bar['idle_inhibitor'].update(format='',tooltip=False)
        bar['custom/control']={'format':'󰒓','on-click':'orgm-'+comp+' control','tooltip-format':'Centro de control · modo tablet'}
    return value


def read_jsonc(text):
    quoted=r'"(?:\\.|[^"\\])*"'
    text=re.sub(quoted+r'|//[^\n]*|/\*[\s\S]*?\*/',lambda m:m[0] if m[0].startswith('"') else ' ',text)
    return json.loads(re.sub(quoted+r'|,\s*(?=[}\]])',lambda m:m[0] if m[0].startswith('"') else '',text))


def cache_file(source,kind):
    identity=str(source)+'\0'+os.environ.get('WAYLAND_DISPLAY','')
    root=Path(os.environ.get('XDG_CACHE_HOME',Path.home()/'.cache'))/'orgm-tablet'
    private_directory(root)
    return root/(hashlib.sha256(identity.encode()).hexdigest()[:20]+'.'+kind)


def atomic_text(path,text):
    fd,name=tempfile.mkstemp(prefix='.profile-',dir=path.parent)
    try:
        with os.fdopen(fd,'w') as output:output.write(text)
        os.replace(name,path)
    finally:Path(name).unlink(missing_ok=True)


def bar_config(path,comp):
    source=Path(path)
    if load_policy()['mode']!='on':return str(source)
    value=bar_profile(read_jsonc(source.read_text()),comp,True)
    target=cache_file(source,'json');atomic_text(target,json.dumps(value));return str(target)


def bar_style(path):
    source=Path(path)
    if load_policy()['mode']!='on':return str(source)
    target=cache_file(source,'css')
    css='@import url('+json.dumps(source.resolve().as_uri())+');\n'
    css+='* { font-size: 18px; }\nwindow#waybar { min-height: 52px; }\n'
    css+='#custom-control { min-width: 56px; min-height: 48px; padding: 0 12px; }\n'
    css+='#clock { font-size: 22px; padding: 0 12px; }\n#battery { padding: 0 12px; }\n'
    atomic_text(target,css);return str(target)


def main(args):
    action=args[0] if args else 'state'
    if action=='daemon':return  # Old automatic unit may briefly invoke this during migration.
    if action=='active':return 0 if load_policy()['mode']=='on' else 1
    if action=='state':print(json.dumps(state()))
    elif action=='mode' and len(args)==2:
        previous=load_policy()['mode'];set_policy(args[1])
        try:apply_profile()
        except Exception:
            set_policy(previous)
            try:apply_profile()
            except (OSError,RuntimeError,subprocess.SubprocessError):pass
            raise
        print(json.dumps(state()))
    elif action=='apply':apply_profile()
    elif action=='keyboard' and len(args)==2 and args[1] in ('show','hide','toggle'):
        subprocess.run(['orgm-osk',args[1]],check=True,timeout=3)
    elif action=='bar-config' and len(args)==3:print(bar_config(args[1],args[2]))
    elif action=='bar-style' and len(args)==2:print(bar_style(args[1]))
    else:raise ValueError('Uso: orgm-tablet [state|active|mode on/off/toggle|keyboard show/hide/toggle]')
