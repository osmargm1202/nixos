#!/usr/bin/env python3
"""Native secure widget in private Qt window; dummy input, no authentication."""
import glob,json,os,shutil,signal,subprocess,tempfile,time
from pathlib import Path
from helpers.wayland_pointer import Pointer
ROOT=Path(__file__).resolve().parents[1]
SWAY=os.environ.get("ORGM_TEST_SWAY") or shutil.which("sway") or glob.glob("/nix/store/*-swayfx-0.5.3/bin/sway")[0]
with tempfile.TemporaryDirectory(prefix="auth-board-") as tmp:
 h=Path(tmp);r=h/"r";r.mkdir(mode=0o700)
 shutil.copytree(ROOT/"dotfiles/config/programs/shell/.config/quickshell/orgm-osk",h/"keyboard")
 (h/"sway.conf").write_text("output HEADLESS-1 mode 1200x800\nfont pango:monospace 10\nxwayland disable\ndefault_border none\n")
 fixture="""
import QtQuick
import Quickshell
import Quickshell.Io
import "keyboard"
FloatingWindow {
 id:win; width:1200; height:800; color:"#080e18"
 property int acceptedCount:0
 property bool allowed:true
 function doAction() { acceptedCount++; }
 TextInput { id:field; x:200;y:90;width:600;height:50; color:"white"; echoMode:TextInput.Password
  focus:true; onAccepted:win.acceptedCount++ }
 AuthKeyboard { id:auth; anchors.fill:parent }
 IpcHandler { target:"fixture"
  function block():void { win.allowed=false; }
  function disableField():void { field.enabled=false; }
  function state():string {
   var p=auth.mapToItem(win.contentItem,0,0);
   var b=auth.board.mapToItem(win.contentItem,0,0);
   return JSON.stringify({open:auth.open,ready:auth.ready,reserved:auth.reservedHeight,
    button:{x:auth.button.x+p.x,y:auth.button.y+p.y,width:auth.button.width,height:auth.button.height},
    board:{x:b.x,y:b.y,width:auth.board.width,height:auth.board.height},keys:auth.board.snapshot(),
    matches:field.text === "mañanacaféÑ@",cleared:field.text === "",accepted:win.acceptedCount});
  }
 }
}
"""
 handler=os.environ.get("ORGM_TEST_AUTH_HANDLER","accepted")
 handlers={"return":"Keys.onReturnPressed: win.doAction()", "guard":"Keys.onReturnPressed: (event) => { if (win.allowed) { win.doAction(); event.accepted=true; } }", "conditional":"Keys.onReturnPressed: if (win.allowed) win.doAction()"}
 if handler!="accepted":
  fixture=fixture.replace("onAccepted:win.acceptedCount++",handlers[handler])
  source=h/"theme-source";source.mkdir();(source/"Main.qml").write_text(fixture)
  subprocess.run(["python3",str(ROOT/"nixos/profiles/sway/qylock-keyboard-themes.py"),str(source),str(h/"themes"),str(h/"keyboard")],check=True)
  fixture=(h/"themes/OriginalMain.qml").read_text()
 (h/"shell.qml").write_text(fixture)
 env=dict(os.environ,HOME=tmp,XDG_CONFIG_HOME=tmp+"/.config",XDG_CACHE_HOME=tmp+"/.cache",XDG_STATE_HOME=tmp+"/.state",XDG_RUNTIME_DIR=str(r),DBUS_SESSION_BUS_ADDRESS="unix:path="+tmp+"/no-bus",WLR_BACKENDS="headless",WLR_RENDERER="pixman",WLR_LIBINPUT_NO_DEVICES="1",QT_QPA_PLATFORM="wayland")
 for k in ("DISPLAY","WAYLAND_DISPLAY","SWAYSOCK","HYPRLAND_INSTANCE_SIGNATURE","WAYLAND_SOCKET","QS_CONFIG_PATH","QS_CONFIG_NAME"):env.pop(k,None)
 children=[];pointer=None;log=(h/"session.log").open("w")
 def start(*args):
  p=subprocess.Popen(args,env=env,stdout=log,stderr=log,start_new_session=True);children.append(p);return p
 def cmd(*args):return subprocess.check_output(args,env=env,text=True,timeout=5)
 def wait(probe,label):
  deadline=time.monotonic()+10
  while time.monotonic()<deadline:
   try:
    v=probe()
    if v:return v
   except (subprocess.SubprocessError,ValueError):pass
   time.sleep(.08)
  raise AssertionError("timeout "+label)
 def state():return json.loads(cmd("qs","--path",str(h/"shell.qml"),"ipc","call","fixture","state"))
 def click(rect):
  pointer.move(rect["x"]+rect["width"]/2,rect["y"]+rect["height"]/2,1200,800);pointer.button(True);pointer.button(False);time.sleep(.07)
 def tap(code):
  s=state();k=next(k for k in s["keys"] if (k["kind"]==code if isinstance(code,str) else k["code"]==code))
  click(dict(k,x=k["x"]+s["board"]["x"],y=k["y"]+s["board"]["y"]))
 try:
  start(SWAY,"--unsupported-gpu","-c",str(h/"sway.conf"))
  display=wait(lambda:next((p for p in r.glob("wayland-*") if p.is_socket()),None),"Wayland")
  env["WAYLAND_DISPLAY"]=display.name;env["SWAYSOCK"]=str(wait(lambda:next(r.glob("sway-ipc.*.sock"),None),"IPC"))
  start("wtype","-s","180000");time.sleep(.2)
  shell=start("qs","--path",str(h/"shell.qml"));wait(lambda:state().get("ready"),"secure local field")
  pointer=Pointer(display);click(state()["button"]);wait(lambda:state()["open"],"keyboard button")
  assert state()["reserved"]>200
  for code in [50,30,39,30,49,30,46,30,33,26,18,"shift",39,"altgr",3,"altgr"]:tap(code)
  assert state()["matches"],"dummy Spanish text from real pointer taps"
  assert state()["accepted"]==0,"text keys do not submit"
  tap(28);assert state()["accepted"]==1,"Return emits existing local accepted signal only"
  cmd('wtype','-k','Return');time.sleep(.15)
  assert state()['accepted']==2,('physical Return must submit once, not twice after bridge',state()['accepted'])
  if handler in ('guard','conditional'):
   cmd('qs','--path',str(h/'shell.qml'),'ipc','call','fixture','block')
   tap(28);cmd('wtype','-k','Return');time.sleep(.15)
   assert state()['accepted']==2,'original guard must block virtual and physical Enter'
  for _ in range(12):tap(14)
  assert state()["cleared"],"Backspace removes dummy Unicode input"
  tap(1);assert not state()["open"],"Escape hides without submitting"
  assert state()["accepted"]==2
  cmd("qs","--path",str(h/"shell.qml"),"ipc","call","fixture","disableField")
  assert not state()["ready"],"disabled local auth field is not writable"
  click(state()["button"]);assert state()["open"]
  tap(28);assert state()["accepted"]==2,"no-ready target cannot submit"
  descendants=Path(f"/proc/{shell.pid}/task/{shell.pid}/children").read_text().strip()
  assert not descendants,"auth keyboard must not spawn global engine or input injector"
  if os.environ.get("ORGM_TEST_AUTH_SCREENSHOT"):cmd("grim",os.environ["ORGM_TEST_AUTH_SCREENSHOT"])
  print("PASS: actual secure button and Spanish keys; Return follows local accepted signal; Backspace/Escape; no subprocess")
 except Exception:
  log.flush();print((h/"session.log").read_text(errors="replace")[-4000:]);raise
 finally:
  if pointer:pointer.close()
  for p in reversed(children):
   if p.poll() is None:os.killpg(p.pid,signal.SIGTERM)
   try:p.wait(timeout=3)
   except subprocess.TimeoutExpired:os.killpg(p.pid,signal.SIGKILL);p.wait()
