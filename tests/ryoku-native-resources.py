#!/usr/bin/env python3
"""Use pinned native files and the real CLI; no live session is required."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

class NativeResources(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        expr = 'let f=builtins.getFlake ("path:"+builtins.getEnv "RYOKU_TEST_REPO"); p=(import (builtins.getEnv "RYOKU_TEST_REPO"+"/nixos/profiles/ryoku/provider-compat.nix") {inputs=f.inputs; pkgs=f.nixosConfigurations.envy.pkgs; lib=f.inputs.nixpkgs.lib;}).packages; in [p.ryoku-desktop-data p.ryoku-cli]'
        packages = subprocess.check_output(["nix","build","--impure","--no-link","--print-out-paths","--expr",expr],env=dict(os.environ,RYOKU_TEST_REPO=str(ROOT)),text=True).splitlines()
        cls.data = next(Path(p) for p in packages if (Path(p)/"share/ryoku/config").is_dir())
        cls.cli = next(Path(p)/"bin/.ryoku-wrapped" for p in packages if (Path(p)/"bin/.ryoku-wrapped").exists())

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.config = self.home/".config"; self.config.mkdir()
        self.base = self.home/"base"; self.base.mkdir()
        self.bin = self.home/"bin"; self.bin.mkdir()
        self.env = dict(os.environ,HOME=str(self.home),XDG_CONFIG_HOME=str(self.config),XDG_STATE_HOME=str(self.home/"state"),XDG_DATA_HOME=str(self.home/"data"),RYOKU_CONFIG_BASE=str(self.base),WAYLAND_DISPLAY="",HYPRLAND_INSTANCE_SIGNATURE="",DBUS_SESSION_BUS_ADDRESS="unix:path="+str(self.home/"no-bus"))
        for command in ("systemctl", "hyprctl"):
            p=self.bin/command; p.write_text("#!/bin/sh\nexit 0\n");p.chmod(0o755)
        self.env["PATH"]=str(self.bin)+":"+os.environ["PATH"]

    def materialize(self):
        result=subprocess.run([str(self.cli),"materialize"],env=self.env,capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stderr)

    def write(self, root, relative, data):
        p=root/relative;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(data);return p

    def test_real_materializer_refuses_directory_links_before_any_copy(self):
        for relative in ("ryoku-terminal", "hypr/modules", "ryoku/user_edits/hypr"):
            with self.subTest(relative=relative):
                self.setUp()  # Each link case gets an independent configuration tree.
                self.write(self.base,"ryoku-terminal/env.sh","native runtime")
                self.write(self.base,"hypr/modules/env.lua","native runtime")
                target=self.config/relative;target.parent.mkdir(parents=True,exist_ok=True)
                outside_tmp=tempfile.TemporaryDirectory(prefix="ryoku-external-")
                self.addCleanup(outside_tmp.cleanup)
                outside=Path(outside_tmp.name)
                self.write(outside,"env.sh","personal environment")
                target.symlink_to(outside,target_is_directory=True)
                result=subprocess.run([str(self.cli),"materialize"],env=self.env,capture_output=True,text=True)
                self.assertNotEqual(result.returncode,0)
                self.assertIn("preserved personal directory link",result.stderr)
                self.assertTrue(target.is_symlink())
                self.assertEqual((outside/"env.sh").read_text(),"personal environment")
                self.assertEqual(sorted(p.name for p in outside.iterdir()),["env.sh"])
                target.unlink()

    def test_native_bash_environment_and_rashin_are_packaged(self):
        for name in ("bash/ryoku.bash","bash/rashin.bash","ryoku-terminal/env.sh"):
            self.assertTrue((self.data/"share/ryoku/config"/name).is_file(),name)

    def test_real_materializer_preserves_app_preferences_and_updates_runtime(self):
        prefs=("starship.toml","btop/btop.conf","btop/themes/personal.theme","fastfetch/config.jsonc")
        for rel in prefs:self.write(self.base,rel,"initial")
        runtime=self.write(self.base,"hypr/modules/env.lua","runtime v1")
        self.materialize()
        for rel in prefs:self.write(self.config,rel,"user edited")
        runtime.write_text("runtime v2")
        self.materialize()
        for rel in prefs:self.assertEqual((self.config/rel).read_text(),"user edited",rel)
        self.assertEqual((self.config/"hypr/modules/env.lua").read_text(),"runtime v2")
        # No frozen overlays may restore older values over a later Hub edit.
        for rel in prefs:self.write(self.config,rel,"later Hub edit")
        self.materialize()
        for rel in prefs:self.assertEqual((self.config/rel).read_text(),"later Hub edit",rel)

    def test_native_seed_slots_preserve_arbitrary_and_dangling_symlinks(self):
        for rel in ("starship.toml","btop/btop.conf"):
            self.write(self.base,rel,"shipped")
            target=self.config/rel;target.parent.mkdir(parents=True,exist_ok=True)
            target.symlink_to(self.home/"missing-user-file")
        self.materialize()
        for rel in ("starship.toml","btop/btop.conf"):
            self.assertTrue((self.config/rel).is_symlink(),rel)
        self.assertFalse((self.home/"missing-user-file").exists())

    def test_native_bash_banner_and_user_import_load_once_and_not_noninteractive(self):
        native=self.data/"share/ryoku/config/bash/ryoku.bash"
        self.assertTrue(native.is_file(),"native Bash missing")
        import shutil
        shutil.copytree(self.data/"share/ryoku/config/bash",self.config/"bash")
        shutil.copytree(self.data/"share/ryoku/config/ryoku-terminal",self.config/"ryoku-terminal")
        for directory in (self.config/"bash", self.config/"ryoku-terminal"):
            directory.chmod(0o755)
        self.write(self.config,"bash/user.bash",'printf "IMPORT\\n"\n')
        fastfetch=self.bin/"ryoku-fastfetch"; fastfetch.write_text('#!/bin/sh\nprintf "BANNER\\n"\n');fastfetch.chmod(0o755)
        env=dict(self.env,PATH=str(self.bin)+":/bin:/usr/bin",TERM="dumb")
        command='. "$1"; . "$1"'
        result=subprocess.run([shutil.which("bash"),"--noprofile","--norc","-ic",command,"_",str(self.config/"bash/ryoku.bash")],env=env,capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(result.stdout.count("BANNER"),1,result.stdout)
        self.assertEqual(result.stdout.count("IMPORT"),1,result.stdout)
        result=subprocess.run([shutil.which("bash"),"--noprofile","--norc","-c",command,"_",str(self.config/"bash/ryoku.bash")],env=env,capture_output=True,text=True)
        self.assertNotIn("BANNER",result.stdout);self.assertNotIn("IMPORT",result.stdout)

if __name__=="__main__":unittest.main()
