#!/usr/bin/env python3
"""OSK engine boundary contracts; no live desktop or user state."""
import importlib.util
from pathlib import Path
import unittest
import subprocess
import re
import json,os,tempfile
ROOT=Path(__file__).resolve().parents[1]
class Engine(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        path=ROOT/'nixos/osk/engine.py'
        assert path.exists(), 'shared OSK engine not implemented'
        spec=importlib.util.spec_from_file_location('osk_engine',path)
        cls.engine=importlib.util.module_from_spec(spec);spec.loader.exec_module(cls.engine)
    def test_validation(self):
        for code in (-1,256,True,'30',None):
            with self.assertRaises(ValueError):self.engine.validate({'action':'tap','code':code})
        for mods in (-1,256,True,'4'):
            with self.assertRaises(ValueError):self.engine.validate({'action':'tap','code':30,'modifiers':mods})
        for text in ('a'*9,'a\n','\x00'):
            with self.assertRaises(ValueError):self.engine.validate({'action':'tap','code':30,'text':text})
        with self.assertRaises(ValueError):self.engine.validate({'action':'exec','command':'bad'})
        self.assertEqual(self.engine.validate({'action':'tap','code':39,'text':'ñ','modifiers':1})['text'],'ñ')
    def test_atomic_modifiers(self):
        events=[]
        class Keyboard:
            def modifiers(self,m):events.append(('mods',m))
            def key(self,c,p):events.append(('key',c,p))
        backend=self.engine.WaylandBackend.__new__(self.engine.WaylandBackend)
        backend.keyboard=Keyboard()
        backend.tap({'code':39,'modifiers':1,'text':'Ñ'})
        self.assertEqual(events,[('mods',1),('key',39,True),('key',39,False),('mods',0)])
    def test_release_on_error(self):
        events=[]
        class Keyboard:
            def modifiers(self,m):events.append(m)
            def key(self,c,p):
                if p:raise RuntimeError('lost connection')
        backend=self.engine.WaylandBackend.__new__(self.engine.WaylandBackend);backend.keyboard=Keyboard()
        with self.assertRaises(RuntimeError):backend.tap({'code':39,'modifiers':1})
        self.assertEqual(events[-1],0)
    def test_manifest_has_no_overlapping_owner(self):
        result=subprocess.run(["orgm-dot","--repo",str(ROOT),"--user","jarq","--host","jarq","--profile","i3","list"],capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stderr)

    def test_shortcut_preserves_movement_bindings(self):
        snippet=(ROOT/'dotfiles/config/profiles/i3/.config/i3/config.d/18-osk.conf').read_text()
        shortcut=re.search(r'bindsym ([^ ]+) .*orgm-osk toggle',snippet)[1]
        for profile in ('i3','sway'):
            base=(ROOT/f'dotfiles/config/profiles/{profile}/.config/{profile}/config').read_text()
            bindings=re.findall(r'^bindsym ([^ ]+) ',base,re.M)
            self.assertNotIn(shortcut.lower(),[b.lower() for b in bindings],profile+' binding collision')
        # Hyprland emits Ctrl+h/j/k/l movement bindings from its direction map.
        self.assertNotIn(shortcut.lower().split('+')[-1],('h','j','k','l'))

    def test_helper_disambiguates_show_from_qs_inspection_subcommand(self):
        with tempfile.TemporaryDirectory() as tmp:
            fake=Path(tmp)/'qs'
            fake.write_text('#!/usr/bin/env python3\nimport json,sys\nprint(json.dumps(sys.argv[1:]))\n')
            fake.chmod(0o755)
            env=dict(os.environ,ORGM_OSK_QS=str(fake),ORGM_OSK_UI='/private/osk/shell.qml')
            helper=ROOT/'dotfiles/config/programs/shell/.local/bin/orgm-osk'
            for action in ('show','hide','toggle','status','retry'):
                args=json.loads(subprocess.check_output([str(helper),action],env=env,text=True))
                self.assertEqual(args,['--path','/private/osk/shell.qml','ipc','call','--','osk',action])

    def test_ui_has_attribution(self):
        ui=ROOT/'dotfiles/config/programs/shell/.config/quickshell/orgm-osk'
        self.assertTrue((ui/'UPSTREAM.md').exists())
        self.assertTrue((ui/'LICENSE').exists())
if __name__=='__main__':unittest.main()
