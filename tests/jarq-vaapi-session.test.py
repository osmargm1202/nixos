#!/usr/bin/env python3
"""Opt-in real GPU decode in a private compositor/browser, never the user profile."""
import http.server,json,os,pathlib,shutil,signal,subprocess,sys,tempfile,threading,time
from urllib.parse import parse_qs,urlsplit
if os.environ.get('ORGM_TEST_JARQ_VAAPI')!='1':
 print('SKIP: opt in on Jarq with explicit disposable H.264 fixture');raise SystemExit(0)
P=pathlib.Path;video=P(os.environ['ORGM_TEST_VIDEO']);assert video.is_file()
root=P(tempfile.mkdtemp(prefix='jarq-vaapi-private-'));run=root/'run';run.mkdir(mode=0o700)
(root/'sway.conf').write_text('xwayland disable\noutput HEADLESS-1 mode 1280x720\nseat seat0 fallback true\n')
profile=root/'profile';profile.mkdir()
prefs={'media.autoplay.default':0,'media.autoplay.blocking_policy':0,'media.ffmpeg.vaapi.enabled':True,'browser.shell.checkDefaultBrowser':False,'browser.startup.homepage_override.mstone':'ignore','browser.aboutwelcome.enabled':False,'browser.newtabpage.enabled':False,'datareporting.policy.dataSubmissionEnabled':False,'toolkit.telemetry.enabled':False,'browser.sessionstore.resume_from_crash':False}
(profile/'user.js').write_text(''.join('user_pref('+json.dumps(k)+', '+json.dumps(v)+');\n' for k,v in prefs.items()))
samples=[]
class Handler(http.server.BaseHTTPRequestHandler):
 def log_message(self,*args):pass
 def do_GET(self):
  if self.path.startswith('/sample?'):
   samples.append(self.path);body=b'OK';kind='text/plain'
  elif self.path=='/fixture.mp4':body=video.read_bytes();kind='video/mp4'
  else:
   body=b'<!doctype html><video id="v" muted autoplay loop src="/fixture.mp4"></video><script>setInterval(()=>fetch("/sample?t="+v.currentTime+"&frames="+v.getVideoPlaybackQuality().totalVideoFrames),500)</script>';kind='text/html'
  self.send_response(200);self.send_header('Content-Type',kind);self.send_header('Content-Length',str(len(body)));self.end_headers();self.wfile.write(body)
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),Handler);threading.Thread(target=server.serve_forever,daemon=True).start()
env=dict(os.environ,HOME=str(root),XDG_RUNTIME_DIR=str(run),XDG_CONFIG_HOME=str(root/'config'),XDG_DATA_HOME=str(root/'data'),XDG_CACHE_HOME=str(root/'cache'),XDG_STATE_HOME=str(root/'state'),DBUS_SESSION_BUS_ADDRESS='unix:path='+str(root/'no-user-bus'),WLR_BACKENDS='headless',WLR_RENDERER='gles2',WLR_RENDER_DRM_DEVICE='/dev/dri/renderD128',WLR_LIBINPUT_NO_DEVICES='1',MOZ_ENABLE_WAYLAND='1',MOZ_LOG='PlatformDecoderModule:5,FFmpegVideo:5,Dmabuf:5',MOZ_LOG_FILE=str(root/'decoder.log'))
for k in ('DISPLAY','WAYLAND_DISPLAY','WAYLAND_SOCKET','SWAYSOCK','HYPRLAND_INSTANCE_SIGNATURE','MOZ_DISABLE_RDD_SANDBOX','MOZ_DISABLE_CONTENT_SANDBOX'):env.pop(k,None)
children=[];log=(root/'process.log').open('w')
def start(args):
 p=subprocess.Popen(args,env=env,stdout=log,stderr=log,start_new_session=True);children.append(p);return p
try:
 sway=start([shutil.which('sway'),'--unsupported-gpu','-c',str(root/'sway.conf')])
 deadline=time.monotonic()+12
 while time.monotonic()<deadline and not any(p.is_socket() for p in run.glob('wayland-*')):
  assert sway.poll() is None, 'private GPU compositor exited; '+str(root);time.sleep(.1)
 display=next(p for p in run.glob('wayland-*') if p.is_socket());env['WAYLAND_DISPLAY']=display.name
 firefox=start([shutil.which('firefox'),'--no-remote','--profile',str(profile),'http://127.0.0.1:'+str(server.server_port)+'/'])
 deadline=time.monotonic()+25
 while time.monotonic()<deadline:
  text='\n'.join(p.read_text(errors='replace') for p in root.glob('decoder.log*'))
  progress=[(float(q['t'][0]),int(q['frames'][0])) for q in (parse_qs(urlsplit(v).query) for v in list(samples))]
  advances=sum(b[0]>a[0] and b[1]>a[1] for a,b in zip(progress,progress[1:]))
  if 'VA-API FFmpeg init successful' in text and text.count('VA-API frame pts=')>=90 and advances>=5:break
  assert firefox.poll() is None,'private Firefox exited; '+str(root)
  time.sleep(.3)
 else:raise AssertionError('hardware Firefox decode not confirmed; '+str(root))
 assert advances>=5 and progress[-1][1]>60, 'playback/frame counters stalled'
 assert 'IsHardwareAccelerated=true' in text, 'decoder did not report real hardware acceleration'
 assert 'IsHardwareAccelerated=false' not in text, 'decoder fell back to software'
 assert text.count('VA-API frame pts=')>=90, 'missing sustained VA-API frame output'
 print('PASS: private Firefox/Sway, sandbox intact,90+ VA-API frames and5+ advancing playback samples; evidence',root)
finally:
 for p in reversed(children):
  if p.poll() is None:
   os.killpg(p.pid,signal.SIGTERM)
   try:p.wait(timeout=5)
   except subprocess.TimeoutExpired:os.killpg(p.pid,signal.SIGKILL);p.wait()
 server.shutdown();log.close()
