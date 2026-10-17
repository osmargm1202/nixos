#!/usr/bin/env python3
"""Exercise the generated CLI, replacing only external systemctl/manifest boundaries."""
import importlib.util,json,os,re,subprocess,tempfile,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('fixtures',ROOT/'tests/envy-windows-runtime.py')
fixtures=importlib.util.module_from_spec(spec);spec.loader.exec_module(fixtures)

class CLI(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  expr='''let f=builtins.getFlake ("path:"+builtins.getEnv "RYOKU_TEST_REPO"); c=f.nixosConfigurations.envy.config;
 in f.nixosConfigurations.envy.pkgs.writeText "envy-cli-test.json" (builtins.toJSON {
  controller=c.system.build.envyWindowsController; systemctl="${f.nixosConfigurations.envy.pkgs.systemd}/bin/systemctl";
 })'''
  output=subprocess.check_output(['nix','build','--impure','--no-link','--print-out-paths','--expr',expr],env=dict(os.environ,RYOKU_TEST_REPO=str(ROOT)),text=True).strip()
  cls.inventory=json.loads(Path(output).read_text())
 setUp=fixtures.Runtime.setUp
 data=fixtures.Runtime.data
 update=fixtures.Runtime.update
 seed_container=fixtures.Runtime.seed_container
 def command(self,action):
  ctl=self.root/'systemctl';ctl.write_text('#!/bin/sh\ncase "$*" in *show*) echo active ;; esac\nexit 0\n');ctl.chmod(0o755)
  manifest=self.root/'manifest.json';manifest.write_text(json.dumps(self.m))
  source=(Path(self.inventory['controller'])/'bin/envy-windows').read_text()
  source=source.replace(self.inventory['systemctl'],str(ctl))
  source=re.sub(r'--manifest /nix/store/[^\s]+','--manifest '+str(manifest),source)
  cli=self.root/'envy-windows';cli.write_text(source);cli.chmod(0o755)
  return subprocess.run([str(cli),action],env=self.env,capture_output=True,text=True,timeout=5)
 def test_stop_recovers_running_guest_after_service_crash(self):
  self.seed_container();r=self.command('stop')
  self.assertEqual(r.returncode,0,r.stderr)
  self.assertFalse(self.data()['containers']['envy-windows']['State']['Running'])
 def test_stop_refuses_foreign_container(self):
  self.seed_container(owner='alien');r=self.command('stop');self.assertNotEqual(r.returncode,0)
  self.assertTrue(self.data()['containers']['envy-windows']['State']['Running'])
 def test_orphan_stop_cannot_race_an_existing_lifetime_owner(self):
  import fcntl
  directory=Path(self.m['runtimeDir']);directory.mkdir(mode=0o700)
  with (directory/'supervisor.lock').open('a') as lock:
   fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
   self.seed_container();r=self.command('stop');self.assertNotEqual(r.returncode,0)
   self.assertTrue(self.data()['containers']['envy-windows']['State']['Running'])
 def test_start_never_reports_success_for_stopped_guest(self):
  self.seed_container(running=False);r=self.command('start');self.assertNotEqual(r.returncode,0,r.stdout)
 def test_start_confirms_live_guest(self):
  self.seed_container();r=self.command('start');self.assertEqual(r.returncode,0,r.stderr)
  self.assertTrue(json.loads(r.stdout)['running'])

if __name__=='__main__':unittest.main()
