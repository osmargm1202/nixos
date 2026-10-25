"""Tailnet selector: configured VNC desktops or ordinary authorized SSH.

Discovery is read-only. SSH never uses this feature's restricted VNC key.
"""
import getpass
import json
import re
import subprocess


def valid_host(host):
    return isinstance(host,str) and re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9.-]{0,252}',host) is not None


def aliases(node):
    if not isinstance(node,dict):return set()
    values=[node.get('DNSName','')]+(node.get('TailscaleIPs',[]) if isinstance(node.get('TailscaleIPs'),list) else [])
    return {v.rstrip('.').lower() for v in values if valid_host(v)}


def merge_targets(peers,status):
    running=isinstance(status,dict) and status.get('BackendState')=='Running'
    own=status.get('Self',{}) if running else {}
    own_aliases=aliases(own);own_id=own.get('ID') if isinstance(own,dict) else None
    nodes=status.get('Peer',{}) if running else {}
    rows=[];hosts=set()
    for node in nodes.values() if isinstance(nodes,dict) else []:
        if not isinstance(node,dict):continue
        # Only current visible online Linux peers qualify, regardless of owner.
        if node.get('OS')!='linux' or node.get('Online') is not True:continue
        names=aliases(node)
        if (own_id and node.get('ID')==own_id) or names & own_aliases:continue
        dns=node.get('DNSName','').rstrip('.') if isinstance(node.get('DNSName'),str) else ''
        host=dns if valid_host(dns) else next(iter(sorted(names)),None)
        if not host or host.lower() in hosts:continue
        prepared=next((name for name,peer in peers.items() if peer['host'].rstrip('.').lower() in names),None)
        raw_name=node.get('HostName',host)
        label_name=' '.join(str(raw_name).split())[:80] or host
        rows.append(dict(name=label_name,host=host,online=node.get('Online') is True,
                         desktop=prepared,user=peers[prepared]['user'] if prepared else ''))
        hosts.add(host.lower())
    return sorted(rows,key=lambda row:(row['name'].lower(),row['host']))


def discover(peers):
    try:
        result=subprocess.run(['tailscale','status','--json'],capture_output=True,text=True,check=True,timeout=5)
        status=json.loads(result.stdout)
    except (OSError,ValueError,subprocess.SubprocessError):status=None
    return merge_targets(peers,status)


def choose(prompt,labels):
    result=subprocess.run(['orgm-rofi','--','-dmenu','-p',prompt,'-format','i','-no-custom'],
                          input='\n'.join(labels)+'\n',capture_output=True,text=True)
    if result.returncode==1:return None
    if result.returncode!=0:raise ValueError('No se pudo abrir el selector de equipos')
    selected=result.stdout.strip()
    if not selected.isdecimal() or not 0<=int(selected)<len(labels):raise ValueError('Selección de equipo inválida')
    return int(selected)


def ask_user(target):
    default=target['user'] or getpass.getuser()
    result=subprocess.run(['orgm-rofi','--','-dmenu','-p','Usuario SSH en '+target['name'],'-filter',default],
                          input=default+'\n',capture_output=True,text=True)
    if result.returncode==1:return None
    if result.returncode!=0:raise ValueError('No se pudo pedir el usuario SSH')
    user=result.stdout.strip()
    # Pass login as a separate -l argument (also supports user@realm/DOMAIN\user).
    ssh_command(target['host'],user)
    return user


def ssh_command(host,user):
    if not valid_host(host) or not isinstance(user,str) or not re.fullmatch(r'[A-Za-z0-9_][A-Za-z0-9_.@\\-]{0,127}',user):
        raise ValueError('Dirección o usuario SSH inválido')
    return ['kitty','-e','ssh','-o','StrictHostKeyChecking=ask','-o','ConnectTimeout=10','-l',user,host]


def interactive(peers,desktop):
    targets=discover(peers)
    if not targets:raise ValueError('No hay equipos Linux conectados visibles en Tailscale')
    labels=[row['name']+' · '+row['host']+' · '+'Linux conectado' for row in targets]
    index=choose('Conectar a equipo',labels)
    if index is None:return
    target=targets[index]
    protocols=(['Escritorio'] if target['desktop'] else [])+['Terminal SSH']
    index=choose('Conexión a '+target['name'],protocols)
    if index is None:return
    if protocols[index]=='Escritorio':desktop(target['desktop']);return
    user=ask_user(target)
    if user is None:return
    subprocess.Popen(ssh_command(target['host'],user),stdin=subprocess.DEVNULL,start_new_session=True)
