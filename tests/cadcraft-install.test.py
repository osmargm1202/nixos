#!/usr/bin/env python3
"""Installer transactions and conditional desktop fallback."""
import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[1]
LIB=ROOT/"dotfiles/config/programs/flatpak/.local/lib/orgm-artcraft"

class Installer(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        assert (LIB/"install.py").is_file(),"CADCraft conditional installer is missing"
        sys.path.insert(0,str(LIB))
        spec=importlib.util.spec_from_file_location("cadcraft_install",LIB/"install.py")
        cls.module=importlib.util.module_from_spec(spec);spec.loader.exec_module(cls.module)
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.root=Path(self.tmp.name)
        self.env=patch.dict(os.environ,{"HOME":str(self.root),"XDG_DATA_HOME":str(self.root/"data"),"XDG_STATE_HOME":str(self.root/"state")},clear=False)
        self.env.start();self.addCleanup(self.env.stop)
        self.location=self.root/"flatpak/app/id/x86_64/stable/revision"
        desktop=self.location/"files/share/applications/ai.storyteller.cadcraft.desktop"
        desktop.parent.mkdir(parents=True)
        desktop.write_text("[Desktop Entry]\nName=CADCraft\nIcon=ai.storyteller.cadcraft\nType=Application\nExec=cadcraft %F\nMimeType=image/vnd.dwg;\n")
        active=self.location.parent/"active";active.symlink_to(self.location.name,target_is_directory=True)
        binary=self.location/"files/bin/cadcraft";binary.parent.mkdir();binary.write_text("x");binary.chmod(0o755)
        self.override=self.root/"data/flatpak/overrides/ai.storyteller.cadcraft"
        self.override.parent.mkdir(parents=True)
        self.override.write_text("[Context]\nfilesystems=xdg-data/fonts:ro;\n")
        self.original=self.override.read_bytes()
        self.desktop=self.root/"data/applications/ai.storyteller.cadcraft.desktop"
        self.calls=[]
    def fake_run(self,args,**kwargs):
        self.calls.append(args)
        if args[:2]==["flatpak","info"]:
            return subprocess.CompletedProcess(args,0,str(self.location)+"\n","")
        if args[:2]==["flatpak","override"]:
            self.override.write_text(self.override.read_text()+"[Environment]\nCADCRAFT_CONTROL_PORT=47835\n")
        return subprocess.CompletedProcess(args,0,"","")
    def test_preserves_vendor_and_existing_overrides_and_fallback(self):
        with patch.object(self.module,"run",side_effect=self.fake_run):self.module.install()
        text=self.desktop.read_text()
        self.assertIn("Name=CADCraft",text);self.assertIn("MimeType=image/vnd.dwg;",text)
        self.assertIn("orgm-cadcraft",text);self.assertIn(" %U",text)
        self.assertIn("TryExec="+str(self.location.parent/"active/files/bin/cadcraft"),text)
        self.assertIn("xdg-data/fonts:ro",self.override.read_text())
        self.assertTrue(any("--unshare=network" in c for c in self.calls))
        self.assertTrue(list((self.root/"state/orgm-cadcraft/backups").glob("*/override")))
        self.assertFalse("orgm-cadcraft" in (self.location/"files/share/applications/ai.storyteller.cadcraft.desktop").read_text())
    def test_absent_app_installs_no_handler_and_changes_no_permissions(self):
        def absent(args,**kwargs):raise subprocess.CalledProcessError(1,args)
        with patch.object(self.module,"run",side_effect=absent):self.module.install()
        self.assertFalse(self.desktop.exists());self.assertEqual(self.override.read_bytes(),self.original)
    def test_failed_install_rolls_back_override_and_desktop(self):
        self.desktop.parent.mkdir();self.desktop.write_text("old custom entry")
        def fail(args,**kwargs):
            result=self.fake_run(args,**kwargs)
            if args[:2]==["flatpak","override"]:raise subprocess.CalledProcessError(1,args)
            return result
        with patch.object(self.module,"run",side_effect=fail):
            with self.assertRaises(Exception):self.module.install()
        self.assertEqual(self.desktop.read_text(),"old custom entry")
        self.assertEqual(self.override.read_bytes(),self.original)
    def test_failed_desktop_rollback_still_restores_override(self):
        self.desktop.parent.mkdir();self.desktop.write_text("old entry")
        real_atomic=self.module.atomic
        def atomic(path,content,*args):
            if path==self.desktop:raise PermissionError("read-only applications")
            return real_atomic(path,content,*args)
        with patch.object(self.module,"run",side_effect=self.fake_run),patch.object(self.module,"atomic",side_effect=atomic):
            with self.assertRaises(Exception):self.module.install()
        self.assertEqual(self.override.read_bytes(),self.original)
    def test_valid_desktop_exec_escaping_with_percent_and_quotes(self):
        value='/home/a %u/"quoted"/orgm-cadcraft'
        quoted=self.module.exec_quote(value)
        self.assertIn("%%u",quoted)
    def test_real_gio_launch_handles_special_characters_in_helper_path(self):
        for special in ('$','`','"','%u'):
            with self.subTest(special=special):
                directory=self.root/('special'+special);directory.mkdir()
                program=directory/'helper';program.write_text('#!/bin/sh\nprintf ok > "$1"\n');program.chmod(0o755)
                # Use a real interpreter path, not /bin/sh (not present on NixOS).
                program.write_text('#!'+subprocess.check_output(['which','sh'],text=True).strip()+'\nprintf ok > "$1"\n')
                output=directory/'result'
                desktop=directory/'fixture.desktop'
                desktop.write_text('[Desktop Entry]\nType=Application\nName=Fixture\nExec=env '+self.module.exec_quote(str(program))+' '+self.module.exec_quote(str(output))+'\n')
                result=subprocess.run(['gio','launch',str(desktop)],capture_output=True,text=True)
                self.assertEqual(result.returncode,0,result.stderr)
                import time
                for _ in range(30):
                    if output.exists():break
                    time.sleep(.02)
                self.assertEqual(output.read_text(),'ok')
    def test_real_gio_ignores_shadow_after_flatpak_removal(self):
        with patch.object(self.module,"run",side_effect=self.fake_run):self.module.install()
        helper=self.root/".local/bin/orgm-cadcraft";helper.parent.mkdir(parents=True);helper.symlink_to(sys.executable)
        native=self.desktop.parent/"native.desktop"
        native.write_text("[Desktop Entry]\nType=Application\nName=Native\nExec="+sys.executable+" %F\nMimeType=image/vnd.dwg;\n")
        config=self.root/"config";config.mkdir()
        (config/"mimeapps.list").write_text("[Default Applications]\nimage/vnd.dwg=ai.storyteller.cadcraft.desktop;native.desktop;\n")
        env=dict(os.environ,XDG_CONFIG_HOME=str(config),XDG_CONFIG_DIRS=str(self.root/"empty-config"),XDG_DATA_DIRS=str(self.root/"empty-data"),LC_ALL="C",LANG="C",DBUS_SESSION_BUS_ADDRESS="unix:path="+str(self.root/"no-bus"))
        def selected():
            subprocess.run(["update-desktop-database",str(self.desktop.parent)],env=env,check=True,capture_output=True)
            return subprocess.check_output(["gio","mime","image/vnd.dwg"],env=env,text=True).splitlines()[0]
        self.assertTrue(selected().endswith("ai.storyteller.cadcraft.desktop"))
        (self.location.parent/"active").unlink()
        self.assertTrue(selected().endswith("native.desktop"))
        (self.location.parent/"active").symlink_to(self.location.name,target_is_directory=True)
        self.assertTrue(selected().endswith("ai.storyteller.cadcraft.desktop"))
    def test_symlink_override_rejected_without_changes(self):
        target=self.root/"other";target.write_text("private")
        self.override.unlink();self.override.symlink_to(target)
        with patch.object(self.module,"run",side_effect=self.fake_run):
            with self.assertRaises(Exception):self.module.install()
        self.assertEqual(target.read_text(),"private");self.assertFalse(self.desktop.exists())

    def test_cli_reports_installer_error_without_duplicate_module_traceback(self):
        bindir=self.root/"bin";bindir.mkdir()
        shell=subprocess.check_output(["which","sh"],text=True).strip()
        flatpak=bindir/"flatpak"
        flatpak.write_text("#!"+shell+"\nprintf '%s\\n' \"$HOME/missing-flatpak-installation\"\n");flatpak.chmod(0o755)
        notify=bindir/"notify-send";notify.write_text("#!"+shell+"\nexit 0\n");notify.chmod(0o755)
        result=subprocess.run([sys.executable,"-B",str(LIB/"cadcraft.py"),"install"],env=dict(os.environ,PATH=str(bindir)+":"+os.environ["PATH"]),capture_output=True,text=True)
        self.assertEqual(result.returncode,1)
        self.assertNotIn("Traceback",result.stderr)
        self.assertIn("CADCraft: Instalación",result.stderr)

if __name__=="__main__":unittest.main()
