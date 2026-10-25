#!/usr/bin/env python3
"""Ordered XDG defaults, atomic preservation and real GIO fallback (no app launch)."""
import configparser,importlib.util,json,os,subprocess,sys,tempfile,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
class Defaults(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  path=ROOT/'nixos/apps/artcraft-mime.py'
  spec=importlib.util.spec_from_file_location('mime_policy',path)
  cls.m=importlib.util.module_from_spec(spec);spec.loader.exec_module(cls.m)
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
  self.home=Path(self.tmp.name);self.path=self.home/'config/mimeapps.list'
  self.policy={'application/pdf':['ai.storyteller.pdfcraft.desktop','org.gnome.Evince.desktop']}
 def test_catalog_routes_expected_formats_and_leaves_web_code_and_directories_alone(self):
  policy=json.loads((ROOT/'nixos/apps/artcraft-mime-policy.json').read_text())
  for mime,app in [('image/vnd.dwg','cadcraft'),('image/vnd.dxf','cadcraft'),('application/pdf','pdfcraft'),('image/svg+xml','vectorcraft'),('image/png','photocraft'),('text/plain','wordcraft'),('text/csv','gridcraft'),('video/mp4','filmcraft'),('audio/flac','soundcraft')]:
   self.assertEqual(policy[mime]['artcraft'][0],'ai.storyteller.'+app+'.desktop')
  self.assertTrue(all(len(row['artcraft'])==1 for row in policy.values()),'one owner per format; absent owner must use native, not another Craft importer')
  for mime in ('text/html','text/x-python','text/x-lua','application/json','application/x-shellscript','inode/directory','x-scheme-handler/http','x-scheme-handler/https'):
   self.assertNotIn(mime,policy)
 def test_dry_run_and_invalid_policy_do_not_modify_existing_preferences(self):
  self.path.parent.mkdir();self.path.write_text('[Default Applications]\napplication/pdf=old.desktop;\n')
  saved=self.path.read_bytes();self.assertEqual(self.m.apply(self.path,self.policy,True),['application/pdf'])
  self.assertEqual(self.path.read_bytes(),saved)
  with self.assertRaises(ValueError):self.m.apply(self.path,{'application/pdf':['bad.desktop;injected.desktop']})
  self.assertEqual(self.path.read_bytes(),saved)

 def test_preserves_unrelated_preferences_and_is_idempotent_with_backup(self):
  self.path.parent.mkdir();original='[Default Applications]\napplication/pdf=old.desktop;\nx-scheme-handler/https=firefox.desktop;\n[Added Associations]\ntext/plain=mine.desktop;\n'
  self.path.write_text(original)
  self.assertEqual(self.m.apply(self.path,self.policy),['application/pdf'])
  c=configparser.ConfigParser();c.read(self.path)
  self.assertEqual(c['Default Applications']['application/pdf'],'ai.storyteller.pdfcraft.desktop;org.gnome.Evince.desktop;')
  self.assertEqual(c['Default Applications']['x-scheme-handler/https'],'firefox.desktop;')
  self.assertEqual(c['Added Associations']['text/plain'],'mine.desktop;')
  backups=list(self.path.parent.glob('mimeapps-artcraft-backup-*'))
  self.assertEqual(len(backups),1);self.assertEqual(backups[0].read_text(),original)
  self.assertEqual(self.m.apply(self.path,self.policy),[])
  self.assertEqual(len(list(self.path.parent.glob('mimeapps-artcraft-backup-*'))),1)
 def test_bad_or_symlinked_existing_preferences_are_not_overwritten(self):
  self.path.parent.mkdir();self.path.write_text('broken MIME preferences')
  with self.assertRaises(configparser.Error):self.m.apply(self.path,self.policy)
  self.assertEqual(self.path.read_text(),'broken MIME preferences')
  self.path.unlink();outside=self.home/'outside';outside.write_text('untouched');self.path.symlink_to(outside)
  with self.assertRaises(ValueError):self.m.apply(self.path,self.policy)
  self.assertEqual(outside.read_text(),'untouched')
 def test_real_gio_uses_first_installed_associated_app_and_falls_back_after_removal(self):
  apps=self.home/'data/applications';apps.mkdir(parents=True)
  env=dict(os.environ,HOME=str(self.home),XDG_CONFIG_HOME=str(self.path.parent),XDG_DATA_HOME=str(self.home/'data'),XDG_CONFIG_DIRS=str(self.home/'etc'),XDG_DATA_DIRS=str(self.home/'empty'),LC_ALL='C',LANG='C',DISPLAY='',WAYLAND_DISPLAY='',DBUS_SESSION_BUS_ADDRESS='unix:path='+str(self.home/'no-bus'))
  def install(name):
   p=apps/name;p.write_text('[Desktop Entry]\nType=Application\nName='+name+'\nExec='+sys.executable+' %F\nMimeType=application/pdf;\n');return p
  def selected():
   subprocess.run(['update-desktop-database',str(apps)],env=env,check=True,capture_output=True)
   return subprocess.check_output(['gio','mime','application/pdf'],env=env,text=True).splitlines()[0]
  row=json.loads((ROOT/'nixos/apps/artcraft-mime-policy.json').read_text())['application/pdf']
  self.policy={'application/pdf':row['artcraft']+row['fallback']}
  install('ai.storyteller.vectorcraft.desktop') # Importer is not the preferred PDF reader.
  install('org.gnome.Evince.desktop');self.m.apply(self.path,self.policy)
  self.assertTrue(selected().endswith('org.gnome.Evince.desktop'))
  craft=install('ai.storyteller.pdfcraft.desktop');self.assertTrue(selected().endswith(craft.name))
  craft.unlink();self.assertTrue(selected().endswith('org.gnome.Evince.desktop'))
  install('ai.storyteller.pdfcraft.desktop');self.assertTrue(selected().endswith(craft.name))
if __name__=='__main__':unittest.main()
