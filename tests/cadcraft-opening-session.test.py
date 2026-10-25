#!/usr/bin/env python3
"""Vendor CADCraft, real DWG and GIO, exclusively on an isolated Sway display.

Requires installed CADCraft and Sway. Test-only Flatpak routing hides non-test
instances, records each owned launch and gives only this fixture private state.
No user window/input/config/document is inspected, closed or changed.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parents[1]
INSTALLED = os.environ.get('ORGM_TEST_CADCRAFT_INSTALLED') == '1'
LIB = Path.home()/'.local/lib/orgm-artcraft' if INSTALLED else ROOT / 'dotfiles/config/programs/flatpak/.local/lib/orgm-artcraft'
APP = 'ai.storyteller.cadcraft'
FLATPAK = shutil.which('flatpak')
SWAY = shutil.which('sway')
if not FLATPAK or not SWAY or subprocess.run([FLATPAK, 'info', APP], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode:
    raise SystemExit('SKIP: vendor CADCraft Flatpak and Sway are required')
sys.path.insert(0, str(LIB))
import cadcraft

root = Path(tempfile.mkdtemp(prefix='orgm-cadcraft-fixture-', dir=Path.home()/'.cache'))
runtime = root/'sway-runtime'; runtime.mkdir(mode=0o700)
(root/'sway.conf').write_text('xwayland disable\noutput * resolution 1280x800\nseat seat0 fallback true\n')
env = dict(os.environ, XDG_RUNTIME_DIR=str(runtime), WLR_BACKENDS='headless', WLR_RENDERER='pixman', WLR_LIBINPUT_NO_DEVICES='1')
for key in ('DISPLAY','WAYLAND_DISPLAY','SWAYSOCK','I3SOCK','HYPRLAND_INSTANCE_SIGNATURE'):
    env.pop(key,None)
log = (root/'sway.log').open('w')
sway = subprocess.Popen([SWAY,'--unsupported-gpu','-c',str(root/'sway.conf')], env=env, stdout=log, stderr=log)
owned = None
portal = None

def wait(probe, label, timeout=35):
    deadline=time.monotonic()+timeout
    while time.monotonic()<deadline:
        found=probe()
        if found:return found
        assert sway.poll() is None, 'private compositor exited: '+str(root/'sway.log')
        time.sleep(.1)
    raise AssertionError(label+' timed out; logs: '+str(root))

def raw(instance, method, params=None):
    # Test-only inspection/save/engine calls: exact instance was started by THIS fixture.
    assert instance in cadcraft.Backend().discover(), 'not a test-owned instance'
    code='import socket,sys;s=socket.create_connection(("127.0.0.1",47835),2);s.settimeout(65);s.sendall(sys.stdin.buffer.read());print(s.makefile().readline())'
    result=subprocess.run([FLATPAK,'enter',instance,'/usr/bin/python3','-c',code], input=json.dumps({'id':'fixture','method':method,'params':params or {}})+'\n', text=True, capture_output=True, check=True, timeout=70)
    response=json.loads(result.stdout)
    assert response.get('id')=='fixture' and response.get('ok'), response
    return response['result']

def inspect():
    try:return raw(owned,'ui.inspect')['session']['documents']
    except (OSError,ValueError,subprocess.SubprocessError,AssertionError):return None

try:
    display=wait(lambda:next((p for p in runtime.glob('wayland-*') if not p.name.endswith('.lock')),None),'Wayland socket')
    sway_socket=wait(lambda:next(iter(runtime.glob('sway-ipc.*.sock')),None),'Sway socket')
    env=dict(os.environ, WAYLAND_DISPLAY=str(display), SWAYSOCK=str(sway_socket), XDG_CURRENT_DESKTOP='sway')
    env.pop('DISPLAY',None);env.pop('HYPRLAND_INSTANCE_SIGNATURE',None)
    env['DBUS_SESSION_BUS_ADDRESS']='unix:path=/run/user/'+str(os.getuid())+'/bus'
    bindir=root/'bin';bindir.mkdir()
    # This shim modifies ONLY test subprocesses. Production executable is untouched.
    shim='''#!/usr/bin/env python3
import os,subprocess,sys
from pathlib import Path
root=Path(ROOT)
args=sys.argv[1:]
if args and args[0]=='run':
 with (root/'pids').open('a') as f:f.write(str(os.getpid())+'\\n')
 args[1:1]=['--socket=wayland','--nosocket=x11','--nosocket=fallback-x11','--filesystem='+str(root),'--env=CADCRAFT_CONFIG_DIR='+str(root/'cad-config')]
elif args and args[0]=='ps':
 p=subprocess.run([REAL]+args,capture_output=True,text=True,check=True)
 ids=(root/'pids').read_text().splitlines() if (root/'pids').exists() else []
 for row in p.stdout.splitlines():
  fields=row.split()
  if len(fields)==4 and fields[1]==APP and fields[2] in ids:print(row)
 sys.exit(0)
os.execv(REAL,[REAL]+args)
'''.replace('ROOT',repr(str(root))).replace('REAL',repr(FLATPAK)).replace('APP',repr(APP))
    (bindir/'flatpak').write_text(shim);(bindir/'flatpak').chmod(0o755)
    env['PATH']=str(bindir)+':'+os.environ['PATH']
    # In-process backend and subprocesses see exactly the same isolated routing.
    os.environ.update(env)
    (root/'entry.py').write_text('import sys\nfrom pathlib import Path\nsys.path.insert(0,'+repr(str(LIB))+')\nfrom cadcraft import *\nopen_files(sys.argv[1:],Backend(),Path('+repr(str(root/'client-runtime'))+'))\n')
    entry=root/'test.desktop'
    entry.write_text('[Desktop Entry]\nType=Application\nName=CADCraft Fixture\nExec="'+sys.executable+'" "'+str(root/'entry.py')+'" %U\n')
    if INSTALLED:
        entry=Path.home()/'.local/share/applications'/ (APP+'.desktop')
        assert entry.is_file(), 'installed CADCraft desktop entry is missing'
    one=root/'first ñ.dxf';two=root/'second spaces.dxf'
    dxf='0\nSECTION\n2\nHEADER\n9\n$ACADVER\n1\nAC1015\n0\nENDSEC\n0\nSECTION\n2\nENTITIES\n0\nLINE\n8\n0\n10\n0\n20\n0\n11\n10\n21\n10\n0\nENDSEC\n0\nEOF\n'
    one.write_text(dxf);two.write_text(dxf.replace('11\n10','11\n20'))
    backend=cadcraft.Backend()
    cadcraft.open_files([str(one)],backend,root/'client-runtime')
    owned=backend.discover()[0]
    initial=backend.rows()[0]
    # Create two genuine DWGs with the installed vendor writer, not renamed DXFs.
    raw(owned,'app.save',{'path':str(one.with_suffix('.dwg'))})
    cadcraft.open_files([str(two)],backend,root/'client-runtime')
    raw(owned,'app.save',{'path':str(two.with_suffix('.dwg'))})
    assert one.with_suffix('.dwg').read_bytes().startswith(b'AC10')
    cadcraft.open_files([str(one.with_suffix('.dwg'))],backend,root/'client-runtime')
    raw(owned,'engine.execute',{'command':'circle','params':{'center':[30,30],'radius':5}})
    before=inspect();dirty=next(d for d in before if d['active'])
    assert dirty['dirty'] and dirty['entities']==2, before
    subprocess.run(['swaymsg','workspace','7'],env=env,check=True,capture_output=True)
    # A real desktop launch, helper exits, but CAD must stay and keep dirty state.
    subprocess.run(['gio','launch',str(entry),two.with_suffix('.dwg').as_uri()],env=env,check=True,capture_output=True,text=True,timeout=8)
    docs=wait(lambda:(d if (d:=inspect()) and len(d)>len(before) else None),'GIO second DWG')
    assert next(d for d in docs if d['index']==dirty['index'])=={**dirty,'active':False}, docs
    assert backend.rows()[0]==initial and len(backend.discover())==1, backend.rows()
    def focused_cad():
        tree=json.loads(subprocess.check_output(['swaymsg','-t','get_tree','-r'],env=env,text=True))
        def walk(node):
            yield node
            for child in node.get('nodes',[])+node.get('floating_nodes',[]):yield from walk(child)
        return any(n.get('focused') and n.get('app_id')==APP for n in walk(tree))
    wait(focused_cad,'targeted Sway focus',8)
    # Private network is actually different, not merely a declarative flag.
    private=subprocess.check_output([FLATPAK,'enter',owned,'/usr/bin/python3','-c','import os;print(os.readlink("/proc/self/ns/net"))'],text=True).strip()
    assert private!=os.readlink('/proc/self/ns/net')
    # A path NOT covered by test filesystem grants must use a scoped portal export.
    outside=Path(tempfile.mkdtemp(prefix='orgm-cadcraft-portal-',dir=Path.home()/'.cache'))
    portal=outside/'portal.dwg';shutil.copyfile(two.with_suffix('.dwg'),portal)
    results=cadcraft.open_files([str(portal)],backend,root/'client-runtime')
    assert results[0]['entities']==1 and '/doc/' in inspect()[-1]['path'], inspect()
    # Multiple concurrent file-manager requests still use one process.
    command=[str(Path.home()/'.local/bin/orgm-cadcraft'),'--'] if INSTALLED else [sys.executable,str(root/'entry.py')]
    children=[subprocess.Popen(command+[str(p)],env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True) for p in (one.with_suffix('.dwg'),two.with_suffix('.dwg'))]
    for child in children:
        out,err=child.communicate(timeout=90);assert child.returncode==0,(out,err)
    assert backend.rows()[0]==initial and len((root/'pids').read_text().splitlines())==1
    assert next(d for d in inspect() if d['index']==dirty['index'])['dirty']
    print('PASS: two genuine DWGs, GIO, same instance/PID, preserved unsaved drawing, scoped portal, concurrent opens, private network')
    print('EVIDENCE: '+str(root)+' instance='+owned+' child-pid='+initial[3])
finally:
    if owned and owned in cadcraft.Backend().discover():
        try:raw(owned,'app.quit') # ONLY fixture-owned unsaved test drawing.
        except Exception:pass
        wait(lambda:owned not in cadcraft.Backend().discover(),'fixture exit',10)
    if portal:
        subprocess.run([FLATPAK,'document-unexport',str(portal)],capture_output=True,timeout=10)
        shutil.rmtree(portal.parent)
    sway.terminate()
    try:sway.wait(timeout=5)
    except subprocess.TimeoutExpired:sway.kill();sway.wait()
    log.close()
