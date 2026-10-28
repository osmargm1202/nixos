#!/usr/bin/env python3
"""Private Xvfb/i3 fixture; provide ORGM_TEST_I3_BIN, XVFB, X11_PYTHON and X11_PID_BIN."""
import importlib.util,json,os,pathlib,select,subprocess,tempfile,time
required = ['ORGM_TEST_I3_BIN', 'ORGM_TEST_XVFB', 'ORGM_TEST_X11_PYTHON', 'ORGM_TEST_X11_PID_BIN']
if any(name not in os.environ for name in required):
    print('SKIP: provide private i3/Xvfb fixture paths via ORGM_TEST_*')
    raise SystemExit(0)
root=pathlib.Path(__file__).resolve().parents[1]
i3=os.environ['ORGM_TEST_I3_BIN'].rstrip('/')+'/'
xvfb=os.environ['ORGM_TEST_XVFB']
python=os.environ['ORGM_TEST_X11_PYTHON']
helper=os.environ['ORGM_TEST_X11_PID_BIN'].rstrip('/')+'/'
processes=[]
with tempfile.TemporaryDirectory() as temp:
 try:
  readfd,writefd=os.pipe()
  server=subprocess.Popen([xvfb,'-displayfd',str(writefd),'-screen','0','800x600x24','-nolisten','tcp','-ac'],pass_fds=[writefd],stdout=subprocess.DEVNULL,stderr=open(temp+'/x.log','w'))
  processes.append(server);os.close(writefd)
  assert select.select([readfd],[],[],10)[0], 'Xvfb startup timed out'
  display=':'+os.read(readfd,64).decode().strip();os.close(readfd)
  env=dict(os.environ,DISPLAY=display,XDG_CURRENT_DESKTOP='i3',PATH=helper+':'+i3+':'+os.environ['PATH'])
  for key in ['SWAYSOCK','HYPRLAND_INSTANCE_SIGNATURE','I3SOCK']:env.pop(key,None)
  pathlib.Path(temp+'/config').write_text('font pango:monospace 10\nfocus_follows_mouse no\nworkspace 1\n')
  manager=subprocess.Popen([i3+'i3','-c',temp+'/config'],env=env,stdout=open(temp+'/i3.log','w'),stderr=subprocess.STDOUT);processes.append(manager)
  time.sleep(1)
  code='''import os,sys\nfrom Xlib import X,display\nd=display.Display();w=d.screen().root.create_window(10,10,120,80,0,d.screen().root_depth,X.InputOutput,X.CopyFromParent,background_pixel=0)\nw.set_wm_class("cadcraft","CADCraft");w.set_wm_name("CADCraft fixture")\nw.change_property(d.intern_atom("_NET_WM_PID"),d.intern_atom("CARDINAL"),32,[2])\nw.map();d.sync();print(w.id,flush=True);sys.stdin.read();d.close()'''
  for n in range(2):
   child=subprocess.Popen([python,'-c',code],env=env,stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True);processes.append(child)
   xid=int(child.stdout.readline())
   if n==0:target=child;target_xid=xid
  def command(*args):return subprocess.check_output([i3+'i3-msg',*args],env=env,text=True)
  time.sleep(.3)
  command('[id='+str(target_xid)+'] move container to workspace 2')
  command('workspace 1')
  modulepath=root/'dotfiles/config/programs/flatpak/.local/lib/orgm-artcraft/cadcraft.py'
  spec=importlib.util.spec_from_file_location('cadcraft',modulepath);cad=importlib.util.module_from_spec(spec);spec.loader.exec_module(cad)
  os.environ.update(env)
  backend=cad.Backend();backend.rows=lambda:[['42',cad.APP,str(target.pid),str(target.pid)]]
  backend.focus('42')
  tree=json.loads(command('-t','get_tree'))
  def nodes(n):
   yield n
   for child in n.get('nodes',[])+n.get('floating_nodes',[]):yield from nodes(child)
  focused=[n for n in nodes(tree) if n.get('focused') and n.get('window')]
  assert len(focused)==1 and focused[0]['window']==target_xid,focused
  pid=subprocess.check_output([helper+'orgm-x11-client-pid',str(target_xid)],env=env,text=True).strip()
  assert pid==str(target.pid),(pid,target.pid)
  print('PASS: real i3/X11 focuses the exact hidden CADCraft window using the XRes host PID, despite sandbox _NET_WM_PID=2')
 finally:
  for process in reversed(processes):
   process.terminate()
  for process in reversed(processes):
   try:process.wait(timeout=5)
   except subprocess.TimeoutExpired:process.kill();process.wait()
