"""Existing-session VNC, accessible ONLY via private Unix sockets and SSH.

No passwords, arbitrary SSH arguments, TCP VNC listeners or desktop creation.
The compositor owns the server lifetime; viewer disconnection never stops it.
"""
import argparse
import configparser
import errno
import fcntl
import io
import json
import os
from pathlib import Path
import re
import runpy
import socket
import stat
import subprocess
import sys
import tempfile
import time

APP = 'org.remmina.Remmina'


class Error(Exception):
    pass


def private_directory(path):
    path.mkdir(mode=0o700, parents=True, exist_ok=True)
    info=path.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid():
        raise Error('Directorio inseguro: '+str(path))
    path.chmod(0o700)


def runtime_directory():
    path=Path(os.environ.get('XDG_RUNTIME_DIR','/run/user/'+str(os.getuid()))) / 'orgm-remote-desktop'
    private_directory(path)
    return path


def config_directory():
    return Path(os.environ.get('XDG_CONFIG_HOME',Path.home()/'.config')) / 'orgm-remote-desktop'


def state_directory():
    return Path(os.environ.get('XDG_STATE_HOME',Path.home()/'.local/state')) / 'orgm-remote-desktop'


def server_command(env, runtime):
    endpoint=str(runtime/'server.sock')
    if env.get('WAYLAND_DISPLAY'):
        return ['wayvnc','-C','/dev/null','--disable-resizing','--render-cursor','-f','30','-S',str(runtime/'control.sock'),'unix:'+endpoint]
    if env.get('DISPLAY'):
        return ['x0vncserver','-display',env['DISPLAY'],'-rfbport=-1','-rfbunixpath='+endpoint,'-rfbunixmode=0600','-SecurityTypes=None','-AlwaysShared=1','-DisconnectClients=0','-AcceptSetDesktopSize=0']
    raise Error('Inicia una sesión gráfica antes de compartir su escritorio')


def clear_stale_socket(path):
    if not path.exists() and not path.is_symlink():
        return
    info=path.lstat()
    if not stat.S_ISSOCK(info.st_mode) or info.st_uid != os.getuid():
        raise Error('No se reemplazará una ruta ajena o especial: '+str(path))
    with socket.socket(socket.AF_UNIX) as probe:
        probe.settimeout(1)
        try:
            probe.connect(str(path))
        except OSError as exc:
            if exc.errno not in (errno.ECONNREFUSED,errno.ENOENT):
                raise Error('No se pudo verificar el socket: '+str(exc)) from exc
        else:
            raise Error('Ya hay un servidor/túnel atendiendo en '+str(path))
    path.unlink(missing_ok=True)


def run_server():
    runtime=runtime_directory()
    command=server_command(os.environ,runtime)
    fd=os.open(runtime/'server.lock',os.O_CREAT|os.O_RDWR|os.O_NOFOLLOW,0o600)
    try:
        fcntl.flock(fd,fcntl.LOCK_EX|fcntl.LOCK_NB)
    except BlockingIOError as exc:
        os.close(fd)
        raise Error('El escritorio ya está compartido por esta sesión') from exc
    clear_stale_socket(runtime/'server.sock')
    clear_stale_socket(runtime/'control.sock')
    os.fchmod(fd,0o600)
    os.set_inheritable(fd,True)  # The native server retains singleton ownership.
    os.umask(0o177)
    os.execvp(command[0],command)


def validate_peer(name,peer):
    if not re.fullmatch(r'[a-z][a-z0-9-]{0,31}',name):
        raise Error('Nombre de equipo inválido')
    if not isinstance(peer,dict) or set(peer) != {'host','user','uid'}:
        raise Error('Configuración de equipo inválida')
    if not isinstance(peer['host'],str) or not re.fullmatch(r'[a-zA-Z0-9][a-zA-Z0-9.-]{0,252}',peer['host']):
        raise Error('Dirección SSH inválida')
    if not isinstance(peer['user'],str) or not re.fullmatch(r'[a-z_][a-z0-9_-]{0,31}',peer['user']):
        raise Error('Usuario SSH inválido')
    if type(peer['uid']) is not int or not 0 < peer['uid'] < 2**31:
        raise Error('UID remoto inválido')
    return peer


def load_peers():
    path=config_directory()/'peers.json'
    if not path.exists():
        return {}
    peers=json.loads(path.read_text())
    if not isinstance(peers,dict):
        raise Error('Lista de equipos inválida')
    for name,peer in peers.items():
        validate_peer(name,peer)
    return peers


def destination(peer):
    return peer['user']+'@'+peer['host']


def tunnel_command(name,peer,runtime,config,state):
    validate_peer(name,peer)
    remote='/run/user/'+str(peer['uid'])+'/orgm-remote-desktop/server.sock'
    return ['ssh','-i',str(state/'id_ed25519'),'-o','IdentitiesOnly=yes','-o','BatchMode=yes',
            '-o','StrictHostKeyChecking=yes','-o','UserKnownHostsFile='+str(config/'known_hosts'),
            '-o','HostKeyAlias=orgm-remote-desktop-'+name,'-o','ConnectTimeout=8',
            '-o','ServerAliveInterval=30','-o','ServerAliveCountMax=3','-o','ExitOnForwardFailure=yes',
            '-o','StreamLocalBindMask=0177','-o','StreamLocalBindUnlink=yes',
            '-M','-S',str(runtime/(name+'.ctl')),'-NT','-L',str(runtime/(name+'.sock'))+':'+remote,destination(peer)]


def run(args,**kwargs):
    try:
        return subprocess.run(args,check=True,capture_output=True,text=True,timeout=20,**kwargs)
    except (OSError,subprocess.SubprocessError) as exc:
        raise Error(str(getattr(exc,'stderr',None) or exc).strip()) from exc


def control_running(name,peer,runtime):
    result=subprocess.run(['ssh','-S',str(runtime/(name+'.ctl')),'-O','check',destination(peer)],capture_output=True,text=True,timeout=5)
    return result.returncode == 0


def peer_context(name,peer):
    validate_peer(name,peer)
    runtime=runtime_directory()
    config=config_directory();state=state_directory()
    for path in (config/'known_hosts',state/'id_ed25519'):
        info=path.lstat()
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o077:
            raise Error('Archivo SSH inseguro: '+str(path))
    return runtime,config,state


def check_identity(name,peer,runtime):
    try:
        previous=json.loads((runtime/(name+'.json')).read_text())
    except (OSError,ValueError) as exc:
        raise Error('Identidad del túnel desconocida; desconéctalo antes de reintentar') from exc
    if previous != peer:
        raise Error('Cambió la identidad del equipo; desconecta el túnel anterior antes de continuar')


def tunnel(name,peer):
    runtime,config,state=peer_context(name,peer)
    fd=os.open(runtime/(name+'.lock'),os.O_CREAT|os.O_RDWR|os.O_NOFOLLOW|os.O_CLOEXEC,0o600)
    with os.fdopen(fd,'w') as lock:
        os.fchmod(lock.fileno(),0o600)
        fcntl.flock(lock,fcntl.LOCK_EX)
        if control_running(name,peer,runtime):
            check_identity(name,peer,runtime)
            if not (runtime/(name+'.sock')).is_socket():
                raise Error('El túnel existe pero perdió su socket; desconéctalo antes de reintentar')
            return runtime/(name+'.sock')
    # A foreground SSH main process gives systemd real failure/reconnect state.
    # Do not depend on Remmina 1.4.43 Flatpak precommands (silently dropped).
    run(['systemctl','--user','start','orgm-remote-tunnel@'+name+'.service'])
    deadline=time.monotonic()+15
    while time.monotonic()<deadline:
        if control_running(name,peer,runtime) and (runtime/(name+'.sock')).is_socket():
            check_identity(name,peer,runtime)
            return runtime/(name+'.sock')
        time.sleep(.1)
    raise Error('El túnel no está listo; comprueba Tailscale y el servicio del equipo')


def foreground_tunnel(name,peer):
    runtime,config,state=peer_context(name,peer)
    fd=os.open(runtime/(name+'.lock'),os.O_CREAT|os.O_RDWR|os.O_NOFOLLOW|os.O_CLOEXEC,0o600)
    with os.fdopen(fd,'w') as lock:
        os.fchmod(lock.fileno(),0o600)
        fcntl.flock(lock,fcntl.LOCK_EX)
        if control_running(name,peer,runtime):
            check_identity(name,peer,runtime)
            raise Error('Ya hay un túnel activo; no se creará otro')
        clear_stale_socket(runtime/(name+'.sock'))
        clear_stale_socket(runtime/(name+'.ctl'))
        atomic(runtime/(name+'.json'),json.dumps(peer,sort_keys=True)+'\n')
        os.umask(0o177)
        command=tunnel_command(name,peer,runtime,config,state)
        os.execvp(command[0],command)


def profile_text(name,peer,runtime,home):
    validate_peer(name,peer)
    profile=configparser.ConfigParser(interpolation=None)
    profile['remmina']={
        'name':name.capitalize()+' — Tailscale','group':'Mis equipos','protocol':'VNC',
        'server':'unix://'+str(runtime/(name+'.sock')),
        'ssh_tunnel_enabled':'0','disablepasswordstoring':'1','quality':'2','colordepth':'32',
        'scale':'2','viewonly':'0','disableclipboard':'0','orgm_managed':'1'}
    output=io.StringIO();profile.write(output,space_around_delimiters=False)
    return output.getvalue()


def atomic(path,text,mode=0o600):
    fd,name=tempfile.mkstemp(prefix='.remote-',dir=path.parent)
    try:
        with os.fdopen(fd,'w') as output:
            os.fchmod(output.fileno(),mode);output.write(text);output.flush();os.fsync(output.fileno())
        os.replace(name,path)
    finally:
        if os.path.exists(name):os.unlink(name)


def write_profiles(peers):
    runtime=runtime_directory()
    directory=Path.home()/'.var/app'/APP/'data/remmina'
    private_directory(directory)
    result={}
    for name,peer in peers.items():
        path=directory/('orgm-remote-'+name+'.remmina')
        if path.is_symlink() or path.exists() and 'orgm_managed=1' not in path.read_text():
            raise Error('No se reemplazará un perfil personalizado: '+str(path))
        atomic(path,profile_text(name,peer,runtime,Path.home()))
        result[name]=path
    return result


def connect_desktop(name,peers):
    tunnel(name,peers[name])
    path=write_profiles(peers)[name]
    subprocess.Popen(['flatpak','run',APP,'--connect',str(path)],stdin=subprocess.DEVNULL,start_new_session=True)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action',choices=['server','profiles','peers','connect','tunnel','tunnel-service','disconnect','status'])
    parser.add_argument('peer',nargs='?')
    args=parser.parse_args()
    try:
        if args.action=='server':
            run_server()
        elif args.action=='profiles':
            for name,path in write_profiles(load_peers()).items():print(name,path)
        elif args.action=='peers':
            print('\n'.join(load_peers()))
        elif args.action=='status':
            runtime=runtime_directory()
            print(json.dumps({'socket':str(runtime/'server.sock'),'available':(runtime/'server.sock').is_socket(),'peers':list(load_peers())}))
        elif args.action=='connect' and args.peer is None:
            peers=load_peers()
            client=runpy.run_path(str(Path(__file__).with_name('connections.py')))
            client['interactive'](peers,lambda name:connect_desktop(name,peers))
        else:
            peers=load_peers()
            name=args.peer
            if name is None:
                names=list(peers)
                if not names:raise Error('Todavía no hay equipos configurados')
                menu=run(['orgm-rofi','--','-dmenu','-p','Conectar a equipo'],input='\n'.join(names)+'\n').stdout.strip()
                name=menu
            if name not in peers:raise Error('Equipo no configurado: '+str(name))
            peer=peers[name]
            if args.action=='disconnect':
                run(['systemctl','--user','stop','orgm-remote-tunnel@'+name+'.service'])
            elif args.action=='tunnel-service':
                foreground_tunnel(name,peer)
            elif args.action=='connect':
                connect_desktop(name,peers)
            else:
                tunnel(name,peer)
        return 0
    except (Error,OSError,ValueError,subprocess.SubprocessError) as exc:
        print('Escritorio remoto: '+str(exc),file=sys.stderr)
        if args.action not in ('server','tunnel','tunnel-service'):
            try:subprocess.run(['notify-send','Escritorio remoto',str(exc)],timeout=3,capture_output=True)
            except (OSError,subprocess.SubprocessError):pass
        return 1


if __name__=='__main__':
    sys.exit(main())
