#!/usr/bin/env python3
"""No real VM/devices: sysfs fixtures and an actual isolated fake Podman process."""
import copy, importlib.util, json, os, subprocess, sys, tempfile, time, unittest, unittest.mock
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
SCRIPT=ROOT/"nixos/hosts/envy/windows-runtime.py"

ENGINE = r'''#!/usr/bin/env python3
import json,os,sys,time
from pathlib import Path
p=Path(os.environ['FAKE_ENGINE_STATE']); s=json.loads(p.read_text()); a=sys.argv[1:]
with open(os.environ['FAKE_ENGINE_LOG'],'a') as f:f.write(json.dumps(a)+'\n')
if s.get('error'):sys.exit(125)
def save():p.write_text(json.dumps(s))
if '--podman-path' in a:
 if s.get('fail_before_create'):sys.exit(125)
 files=[a[i+1] for i,x in enumerate(a) if x=='-f']; h=json.loads(Path(files[-1]).read_text())['services']['windows']
 s['containers']['envy-windows']={'Id':'envy-windows','State':{'Running':True},'Config':{'Labels':h['labels']},'Mounts':[{'Source':s['storage'],'Destination':'/storage'}]};save();sys.exit(125 if s.get('fail_after_create') else 0)
if a[:2]==['container','exists']:sys.exit(0 if a[-1] in s['containers'] else 1)
if a[:2]==['image','exists']:sys.exit(0 if s.get('image',True) else 1)
if a[0]=='inspect':
 if a[-1] not in s['containers']:sys.exit(125)
 print(json.dumps(s['containers'][a[-1]]));sys.exit(0)
if a[0]=='ps':print('\n'.join(s['containers']));sys.exit(0)
if a[0]=='rm':
 if s['containers'][a[-1]]['State']['Running']:sys.exit(125)
 del s['containers'][a[-1]];save();sys.exit(0)
if a[0]=='start':s['containers'][a[-1]]['State']['Running']=True;save();sys.exit(0)
if a[0]=='stop':
 if s.get('stop_hangs'):time.sleep(60)
 s['containers'][a[-1]]['State']['Running']=False;save();sys.exit(0)
sys.exit(125)
'''

class Runtime(unittest.TestCase):
 def test_readiness_notification(self):
  import socket
  sock=socket.socket(socket.AF_UNIX,socket.SOCK_DGRAM);self.addCleanup(sock.close)
  address=self.root/'notify';sock.bind(str(address));sock.settimeout(1)
  with unittest.mock.patch.dict(os.environ,{'NOTIFY_SOCKET':str(address)}):
   self.mod.notify_ready()
  self.assertEqual(sock.recv(1024),b'READY=1')
 def setUp(self):
  self.assertTrue(SCRIPT.is_file(),'Envy Windows controller not implemented')
  spec=importlib.util.spec_from_file_location('envy_windows',SCRIPT);self.mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(self.mod)
  tmp=tempfile.TemporaryDirectory();self.addCleanup(tmp.cleanup);self.root=Path(tmp.name)
  self.sys=self.root/'sys'; self.dev=self.root/'dev'; self.proc=self.root/'proc'
  self.gpu=self.sys/'devices/pci/bridge/0000:02:00.0';self.gpu.mkdir(parents=True)
  pci=self.sys/'bus/pci/devices';pci.mkdir(parents=True);(pci/'0000:02:00.0').symlink_to(self.gpu)
  (self.gpu/'vendor').write_text('0x10de');(self.gpu/'device').write_text('0x1d13');(self.gpu/'reset_method').write_text('bus')
  self.driver=self.sys/'bus/pci/drivers/nvidia';self.driver.mkdir(parents=True);(self.gpu/'driver').symlink_to(self.driver)
  (self.gpu/'drm/renderD173').mkdir(parents=True)
  node=self.dev/'dri/renderD173';node.parent.mkdir(parents=True);node.symlink_to('/dev/null')
  self.dev.mkdir(exist_ok=True);(self.dev/'kvm').symlink_to('/dev/null');(self.dev/'net').mkdir();(self.dev/'net/tun').symlink_to('/dev/null')
  self.proc.mkdir();(self.proc/'kernel').write_text('6.18.39');(self.proc/'cpuinfo').write_text('flags : ss sse')
  (self.sys/'module/nvidia').mkdir(parents=True);(self.sys/'module/nvidia/version').write_text('580.173.02')
  (self.sys/'module/nvidia_drm/parameters').mkdir(parents=True);(self.sys/'module/nvidia_drm/parameters/modeset').write_text('Y')
  self.storage=self.root/'windows';self.storage.mkdir()
  for n in ['storage','shared','oem']:(self.storage/n).mkdir()
  self.password=self.root/'password';self.password.write_text('fixture-quote$"#secret');self.password.chmod(0o600)
  self.cdi=self.root/'cdi.json';self.cdi.write_text(json.dumps({'kind':'nvidia.com/gpu','devices':[{'name':'all'}]}))
  self.engine=self.root/'podman';self.engine.write_text(ENGINE);self.engine.chmod(0o755)
  self.state=self.root/'engine.json';self.log=self.root/'engine.log'
  self.state.write_text(json.dumps({'containers':{},'image':True,'storage':str(self.storage/'storage')}))
  self.env=dict(os.environ,FAKE_ENGINE_STATE=str(self.state),FAKE_ENGINE_LOG=str(self.log))
  self.oldenv=os.environ.copy();os.environ.update(self.env);self.addCleanup(lambda:(os.environ.clear(),os.environ.update(self.oldenv)))
  self.mounts=[{'target':str(self.storage),'fstype':'btrfs','fsroot':'/@windows','label':'ENVY_ROOT'}]
  helper=self.root/'probe';helper.write_text('#!/usr/bin/env python3\nimport json,sys\na=sys.argv[1:]\nif a and a[0]=="--json": print('+repr(json.dumps({'filesystems':self.mounts}))+')\nelse: print("---------------C------ path")\n');helper.chmod(0o755)
  self.m={'mode':'render','container':'envy-windows','bdf':'0000:02:00.0','vendor':'0x10de','device':'0x1d13','storageRoot':str(self.storage),'passwordFile':str(self.password),'runtimeDir':str(self.root/'runtime'),'sysfsRoot':str(self.sys),'devRoot':str(self.dev),'kernelFile':str(self.proc/'kernel'),'cpuinfo':str(self.proc/'cpuinfo'),'cdiFile':str(self.cdi),'image':'docker.io/dockurr/windows@sha256:'+'a'*64,'generation':'one','compose':[str(ROOT/'nixos/containers/windows/hosts/envy/compose.yml'),str(ROOT/'nixos/containers/windows/hosts/envy/compose.render.yml')],'commands':{'podman':str(self.engine),'compose':str(self.engine),'findmnt':str(helper),'lsattr':str(helper)}}
  self.c=self.mod.Controller(self.m)
 def data(self):return json.loads(self.state.read_text())
 def update(self,**kw):s=self.data();s.update(kw);self.state.write_text(json.dumps(s))
 def vfio(self):
  self.m['mode']='vfio';(self.gpu/'driver').unlink();d=self.sys/'bus/pci/drivers/vfio-pci';d.mkdir();(self.gpu/'driver').symlink_to(d)
  g=self.sys/'kernel/iommu_groups/71';(g/'devices').mkdir(parents=True);(g/'devices/0000:02:00.0').symlink_to(self.gpu);(self.gpu/'iommu_group').symlink_to(g)
  (self.dev/'vfio').mkdir();(self.dev/'vfio/71').symlink_to('/dev/null');(self.dev/'vfio/vfio').symlink_to('/dev/null')
  return g
 def seed_container(self,running=True,generation='old',mode='render',owner='envy'):
  labels={'org.orgm.windows.owner':owner,'org.orgm.windows.mode':mode,'org.orgm.windows.generation':generation}
  self.update(containers={'envy-windows':{'Id':'envy-windows','State':{'Running':running},'Config':{'Labels':labels},'Mounts':[{'Source':str(self.storage/'storage'),'Destination':'/storage'}]}})
 def test_render_resolves_bdf_not_index(self):
  h=self.c.preflight();self.assertEqual(h['render'],str(self.dev/'dri/renderD173'));self.assertEqual(h['mode'],'render')
 def test_vfio_group_is_dynamic_and_host_gpu_not_claimed(self):
  self.vfio();h=self.c.preflight();self.assertEqual(h['group'],'71')
 def test_wrong_device_and_driver_refused(self):
  (self.gpu/'device').write_text('0x1fbb')
  with self.assertRaises(self.mod.Refused):self.c.preflight()
 def test_vfio_missing_group_refused(self):
  self.m['mode']='vfio'
  with self.assertRaises(self.mod.Refused):self.c.preflight()
 def test_vfio_group_neighbor_refused(self):
  g=self.vfio();(g/'devices/0000:02:00.1').symlink_to(self.gpu)
  with self.assertRaises(self.mod.Refused):self.c.preflight()
 def test_bus_reset_neighbor_refused(self):
  self.vfio();(self.gpu.parent/'0000:02:01.0').mkdir()
  with self.assertRaises(self.mod.Refused):self.c.preflight()
 def test_render_wrong_kernel_cdi_or_kvm_refused(self):
  for path,bad in [(self.proc/'kernel','6.12.96'),(self.cdi,'{}')]:
   old=path.read_text();path.write_text(bad)
   with self.assertRaises(self.mod.Refused):self.c.preflight()
   path.write_text(old)
  (self.dev/'kvm').unlink()
  with self.assertRaises(self.mod.Refused):self.c.preflight()
 def test_missing_and_world_readable_password_refused(self):
  self.password.chmod(0o644)
  with self.assertRaises(self.mod.Refused):self.c.preflight()
  self.password.unlink()
  with self.assertRaises(self.mod.Refused):self.c.preflight()
 def test_missing_image_does_not_pull_or_create(self):
  self.update(image=False)
  with self.assertRaises(self.mod.Refused):self.c.reconcile()
  self.assertEqual(self.data()['containers'],{});self.assertNotIn('pull',self.log.read_text())
 def test_podman_failure_not_treated_as_absent(self):
  self.update(error=True)
  with self.assertRaises(self.mod.Refused):self.c.reconcile()
  self.assertNotIn('rm',self.log.read_text())
 def test_disabled_mode_blocks_before_engine(self):
  self.m['mode']='disabled'
  with self.assertRaises(self.mod.Refused):self.c.reconcile()
  self.assertFalse(self.log.exists())
 def test_storage_mount_and_symlink_checks(self):
  bad=copy.deepcopy(self.mounts);bad[0]['label']='OTHER'
  with self.assertRaises(self.mod.Refused):self.mod.validate_storage(self.m,bad)
  (self.storage/'storage').rmdir();(self.storage/'storage').symlink_to(self.root/'outside')
  with self.assertRaises(self.mod.Refused):self.mod.validate_storage(self.m,self.mounts)
 def test_runtime_parent_link_is_refused_without_external_write(self):
  external=self.root/'outside';external.mkdir();Path(self.m['runtimeDir']).symlink_to(external)
  with self.assertRaises(self.mod.Refused):self.c.reconcile()
  self.assertEqual(list(external.iterdir()),[])
 def test_new_container_uses_declared_compose_no_secret_in_overlay(self):
  self.c.reconcile();s=self.data()['containers']['envy-windows'];self.assertTrue(s['State']['Running'])
  overlay=Path(self.m['runtimeDir'])/'hardware.json';text=overlay.read_text()
  self.assertNotIn(self.password.read_text(),text);self.assertNotIn(self.password.read_text(),self.log.read_text())
  self.assertEqual(s['Config']['Labels']['org.orgm.windows.owner'],'envy')
 def test_active_stale_runtime_preserved_and_adopted_without_password(self):
  self.seed_container();self.password.unlink();result=self.c.reconcile()
  self.assertTrue(result['pending']);self.assertTrue(self.data()['containers']['envy-windows']['State']['Running'])
  self.assertFalse(any(a in self.log.read_text() for a in ['"rm"','"start"','--podman-path']))
 def test_wrong_owner_or_active_other_mode_refused(self):
  self.seed_container(owner='other')
  with self.assertRaises(self.mod.Refused):self.c.reconcile()
  self.seed_container(mode='vfio')
  with self.assertRaises(self.mod.Refused):self.c.reconcile()
 def test_stopped_stale_runtime_reconciles_without_deleting_disk(self):
  disk=self.storage/'storage/data.img';disk.write_text('persistent fixture')
  self.seed_container(running=False);self.c.reconcile()
  self.assertEqual(disk.read_text(),'persistent fixture');self.assertIn('"rm"',self.log.read_text());self.assertNotIn('"-f"',self.log.read_text().split('"rm"')[1].split('\n')[0])
 def test_other_running_container_same_storage_refused(self):
  self.update(containers={'alien':{'Id':'alien','State':{'Running':True},'Config':{'Labels':{}},'Mounts':[{'Source':str(self.storage/'storage'),'Destination':'/storage'}]}})
  with self.assertRaises(self.mod.Refused):self.c.reconcile()
 def test_real_container_ids_do_not_hide_another_disk_owner(self):
  self.seed_container();state=self.data();state['containers']['envy-windows']['Id']='a'*64
  state['containers']['alien']={'Id':'b'*64,'State':{'Running':True},'Config':{'Labels':{}},'Mounts':[{'Source':str(self.storage/'storage'),'Destination':'/storage'}]};self.update(containers=state['containers'])
  with self.assertRaises(self.mod.Refused):self.c.reconcile()
 def test_null_labels_are_refused_without_traceback(self):
  self.seed_container();state=self.data();state['containers']['envy-windows']['Config']['Labels']=None;self.update(containers=state['containers'])
  with self.assertRaises(self.mod.Refused):self.c.reconcile()
 def test_symlinked_guest_disk_is_not_written_through(self):
  outside=self.root/'external-disk';outside.write_text('unmodified');(self.storage/'storage/data.img').symlink_to(outside)
  with self.assertRaises(self.mod.Refused):self.c.preflight()
  self.assertEqual(outside.read_text(),'unmodified')
 def test_failed_create_without_guest_is_a_service_failure(self):
  self.update(fail_before_create=True)
  manifest=self.root/'manifest.json';manifest.write_text(json.dumps(self.m))
  r=subprocess.run([sys.executable,str(SCRIPT),'--manifest',str(manifest),'supervise'],env=self.env,capture_output=True,text=True,timeout=5)
  self.assertNotEqual(r.returncode,0);self.assertFalse(self.data()['containers']);self.assertNotIn(self.password.read_text(),r.stderr)
 def test_supervisor_never_stops_a_replaced_unowned_container(self):
  manifest=self.root/'manifest.json';manifest.write_text(json.dumps(self.m))
  p=subprocess.Popen([sys.executable,str(SCRIPT),'--manifest',str(manifest),'supervise'],env=self.env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
  self.addCleanup(lambda:p.poll() is not None or p.kill())
  deadline=time.monotonic()+5
  while time.monotonic()<deadline and not self.data()['containers']:time.sleep(.05)
  state=self.data();state['containers']['envy-windows']['Config']['Labels']['org.orgm.windows.owner']='alien';self.update(containers=state['containers'])
  p.terminate();time.sleep(.5);self.assertIsNone(p.poll());self.assertNotIn('"stop"',self.log.read_text())
  state=self.data();state['containers']['envy-windows']['State']['Running']=False;self.update(containers=state['containers']);p.communicate(timeout=5)
 def test_compose_error_after_guest_start_retains_lifetime_owner(self):
  self.update(fail_after_create=True)
  manifest=self.root/'manifest.json';manifest.write_text(json.dumps(self.m));cmd=[sys.executable,str(SCRIPT),'--manifest',str(manifest),'supervise']
  p=subprocess.Popen(cmd,env=self.env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True);self.addCleanup(lambda:p.poll() is not None or p.kill())
  deadline=time.monotonic()+5
  while time.monotonic()<deadline and not self.data()['containers']:time.sleep(.05)
  time.sleep(.3);self.assertIsNone(p.poll(),'partial compose failure left a running guest without its lifetime owner')
  state=self.data();state['containers']['envy-windows']['State']['Running']=False;self.update(containers=state['containers'])
  out,err=p.communicate(timeout=5);self.assertEqual(p.returncode,0,err);self.assertNotIn(self.password.read_text(),out+err)
 def test_supervisor_stop_signal_waits_for_guest_without_force_kill(self):
  self.update(stop_hangs=True)
  manifest=self.root/'manifest.json';manifest.write_text(json.dumps(self.m));cmd=[sys.executable,str(SCRIPT),'--manifest',str(manifest),'supervise']
  p=subprocess.Popen(cmd,env=self.env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
  self.addCleanup(lambda:p.poll() is not None or p.kill())
  deadline=time.monotonic()+5
  while time.monotonic()<deadline and not self.data()['containers']:time.sleep(.05)
  p.terminate();time.sleep(.5);self.assertIsNone(p.poll(),'supervisor released the lock while shutdown was pending')
  second=subprocess.run(cmd,env=self.env,capture_output=True,text=True,timeout=5);self.assertNotEqual(second.returncode,0)
  state=self.data();state['containers']['envy-windows']['State']['Running']=False;self.update(containers=state['containers'])
  # Its fake stop process may still be waiting; kill only that isolated fixture.
  import signal
  children=Path('/proc/'+str(p.pid)+'/task/'+str(p.pid)+'/children').read_text().split()
  for child in children:os.kill(int(child),signal.SIGTERM)
  out,err=p.communicate(timeout=5);self.assertEqual(p.returncode,0,err)
  self.assertIn('--time=-1',self.log.read_text());self.assertNotIn('"kill"',self.log.read_text())
 def test_digest_excludes_credentials(self):
  a=self.mod.config_digest(self.m,{'mode':'render'});self.password.write_text('changed-secret')
  self.assertEqual(a,self.mod.config_digest(self.m,{'mode':'render'}))
  self.m['generation']='two';self.assertNotEqual(a,self.mod.config_digest(self.m,{'mode':'render'}))
 def test_graceful_stop_never_forces(self):
  self.seed_container();self.c.stop();self.assertIn('"--time=-1"',self.log.read_text());self.assertNotIn('kill',self.log.read_text())
 def test_status_does_not_expose_environment(self):
  self.seed_container();text=json.dumps(self.c.status());self.assertNotIn(self.password.read_text(),text);self.assertNotIn('Config',text)
 def test_real_supervisors_exclude_each_other_and_hold_lock_until_exit(self):
  manifest=self.root/'manifest.json';manifest.write_text(json.dumps(self.m))
  cmd=[sys.executable,str(SCRIPT),'--manifest',str(manifest),'supervise']
  p=subprocess.Popen(cmd,env=self.env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True);self.addCleanup(lambda:p.poll() is not None or p.kill())
  deadline=time.monotonic()+5
  while time.monotonic()<deadline and not self.data()['containers']:time.sleep(.05)
  self.assertIsNone(p.poll())
  second=subprocess.run(cmd,env=self.env,capture_output=True,text=True,timeout=5)
  self.assertNotEqual(second.returncode,0);self.assertIn('supervisor',second.stderr)
  # Guest exits independently; its owner may now release its lifetime lock.
  s=self.data();s['containers']['envy-windows']['State']['Running']=False;self.state.write_text(json.dumps(s))
  out,err=p.communicate(timeout=5);self.assertEqual(p.returncode,0,err);self.assertNotIn(self.password.read_text(),out+err)

class Storage(unittest.TestCase):
 def setUp(self):
  self.script=ROOT/'nixos/hosts/envy/windows-storage.sh';self.assertTrue(self.script.is_file(),'storage preparation not implemented')
  temp=tempfile.TemporaryDirectory();self.addCleanup(temp.cleanup);self.root=Path(temp.name);self.mount=self.root/'mount';self.mount.mkdir();self.bin=self.root/'bin';self.bin.mkdir()
  self.flags=self.root/'flags';self.flags.write_text('')
  for cmd,text in {'findmnt':'printf "ENVY_ROOT btrfs /@windows %s\\n" "$FIXTURE_MOUNT"','lsattr':'printf "%s %s\\n" "$(cat "$FIXTURE_FLAGS")" "$3"','chattr':'printf C > "$FIXTURE_FLAGS"'}.items():
   file=self.bin/cmd;file.write_text('#!/bin/bash\n'+text+'\n');file.chmod(0o755)
  self.env=dict(os.environ,PATH=str(self.bin)+':'+os.environ['PATH'],FIXTURE_MOUNT=str(self.mount),FIXTURE_FLAGS=str(self.flags))
 def run_helper(self):return subprocess.run(['bash',str(self.script),str(self.mount),str(os.getuid()),str(os.getgid())],env=self.env,capture_output=True,text=True)
 def test_fresh_storage_is_prepared_once_without_guest(self):
  r=self.run_helper();self.assertEqual(r.returncode,0,r.stderr);self.assertEqual(self.flags.read_text(),'C')
  self.assertEqual(sorted(p.name for p in self.mount.iterdir()),['oem','shared','storage']);self.assertEqual(self.run_helper().returncode,0)
 def test_wrong_filesystem_aborts_without_changes(self):
  (self.bin/'findmnt').write_text('#!/bin/bash\nprintf "OTHER ext4 / %s\\n" "$FIXTURE_MOUNT"\n')
  r=self.run_helper();self.assertNotEqual(r.returncode,0);self.assertEqual(list(self.mount.iterdir()),[])
 def test_existing_unprepared_disk_is_not_converted(self):
  d=self.mount/'storage';d.mkdir();(d/'disk.img').write_text('disk')
  r=self.run_helper();self.assertNotEqual(r.returncode,0);self.assertEqual(self.flags.read_text(),'');self.assertEqual((d/'disk.img').read_text(),'disk')
 def test_symlink_storage_is_preserved(self):
  outside=self.root/'outside';outside.mkdir();(self.mount/'storage').symlink_to(outside)
  self.assertNotEqual(self.run_helper().returncode,0);self.assertEqual(list(outside.iterdir()),[])
 def test_prepared_nonempty_storage_preserves_disk(self):
  d=self.mount/'storage';d.mkdir();(d/'disk.img').write_text('disk');self.flags.write_text('C')
  r=self.run_helper();self.assertEqual(r.returncode,0,r.stderr);self.assertEqual((d/'disk.img').read_text(),'disk')

if __name__=='__main__':unittest.main()
