#!/usr/bin/env python3
"""Declared host ownership and real preparation/materialization integration."""
import json
import os
import hashlib
import shutil
import sys
import tempfile
from pathlib import Path
import subprocess
import unittest

ROOT=Path(__file__).resolve().parents[1]

class SeedIntegration(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        expr='''let
 f=builtins.getFlake ("path:"+builtins.getEnv "RYOKU_TEST_REPO");
 describe = host: user: let h=f.nixosConfigurations.${host}.config.home-manager.users.${user}; in {
   files=builtins.attrNames h.home.file;
   manifest=builtins.fromJSON (builtins.unsafeDiscardStringContext (h.xdg.configFile."orgm-ryoku/seed-manifest.json".text or "[]"));
   early=h.home.activation.ryokuFirstSeed.data or "";
   cleanup=h.home.activation.removeConflictingDotfiles.data;
 };
 c=f.nixosConfigurations.envy.config;
 h=c.home-manager.users.osmarg;
 lib=f.inputs.nixpkgs.lib;
 p=(import (builtins.getEnv "RYOKU_TEST_REPO"+"/nixos/profiles/ryoku/provider-compat.nix") {inputs=f.inputs;pkgs=f.nixosConfigurations.envy.pkgs;inherit lib;}).packages;
 normalize = name: lib.removePrefix (h.home.homeDirectory+"/") name;
 sources=lib.mapAttrs' (name: file: lib.nameValuePair (normalize name) (toString file.source))
   (lib.filterAttrs (name: _: lib.hasPrefix ".config/orgm-ryoku/" (normalize name) || lib.hasPrefix ".config/orgm-shell/" (normalize name)) h.home.file);
 serverHome=f.nixosConfigurations.lenovo.config.specialisation.server.configuration.home-manager.users.osmarg;
 returnCleanup=serverHome.home.activation.removeConflictingDotfiles.data;
 serverRc=toString serverHome.home.file.".bashrc".source;
 in f.nixosConfigurations.envy.pkgs.writeText "ryoku-seed-test-inventory.json" (builtins.toJSON { _runtime={inherit sources returnCleanup serverRc;generation=toString h.home.activationPackage;cleanup=h.home.activation.removeConflictingDotfiles.data;materializer=toString p.ryoku-materialize;data=toString p.ryoku-desktop-data;hub=toString p.ryoku-hub;}; envy=describe "envy" "osmarg";lenovo=describe "lenovo" "osmarg";orgm=describe "orgm" "osmarg";ero=describe "ero" "osmarg";jarq=describe "jarq" "jarq";})'''
        # Realize exactly this expression's runtime, scripts and manifests; raw
        # eval reports paths without building their dependencies.
        inventory=subprocess.check_output(["nix","build","--impure","--no-link","--print-out-paths","--expr",expr],env=dict(os.environ,RYOKU_TEST_REPO=str(ROOT)),text=True).strip()
        cls.inventory=json.loads(Path(inventory).read_text())

    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.home=Path(self.tmp.name);self.config=self.home/".config";self.config.mkdir()
        self.state=self.home/"state";self.bin=self.home/"bin";self.bin.mkdir()
        runtime=self.home/"run";runtime.mkdir(mode=0o700)
        self.env=dict(os.environ,HOME=str(self.home),XDG_CONFIG_HOME=str(self.config),
            XDG_STATE_HOME=str(self.state),XDG_DATA_HOME=str(self.home/"data"),
            XDG_RUNTIME_DIR=str(runtime),DBUS_SESSION_BUS_ADDRESS="unix:path="+str(runtime/"no-bus"),
            WAYLAND_DISPLAY="",HYPRLAND_INSTANCE_SIGNATURE="",DISPLAY="",DRY_RUN_CMD="",
            PATH=str(self.bin)+":"+os.environ["PATH"],TERM="xterm-kitty")
        for key in ("ORGM_ETC_BASHRC","ORGM_HM_SESSION_VARS"):
            file=self.home/key;file.write_text("# isolated Nix env fixture\n");self.env[key]=str(file)
        # These are pure command-boundary stubs. No real prompt or WM runs.
        for command in ("starship","zoxide","mise","fzf","fnm","ryoku-rashin","systemctl","hyprctl"):
            file=self.bin/command;file.write_text("#!/bin/sh\nexit 0\n");file.chmod(0o755)

    def populate_runtime(self):
        for relative,source in self.inventory["_runtime"]["sources"].items():
            target=self.home/relative;target.parent.mkdir(parents=True,exist_ok=True)
            if target.is_symlink():target.unlink()
            if not target.exists():target.symlink_to(source)

    def early(self):
        result=subprocess.run(["bash","-c",self.inventory["envy"]["early"]],env=self.env,capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stderr)

    def prepare(self):
        result=subprocess.run(["bash",str(ROOT/"nixos/profiles/ryoku/prepare.sh")],env=self.env,capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stderr)

    def materialize(self):
        result=subprocess.run([self.inventory["_runtime"]["materializer"]+"/bin/ryoku-materialize"],env=self.env,capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)

    def test_editable_preferences_are_seeds_not_home_manager_links(self):
        for host in ("envy","lenovo","orgm"):
            record=self.inventory[host]
            self.assertNotIn(".bashrc",record["files"],host)
            self.assertNotIn(".blerc",record["files"],host)
            self.assertNotIn(".config/orgm-ryoku/osmarg-keybindings.lua",record["files"],host)
            targets={row["target"] for row in record["manifest"]}
            self.assertTrue({".bashrc",".config/bash/user.bash",".config/fastfetch/config.jsonc",".config/starship.toml",".config/nvim/init.lua",".config/orgm-ryoku/osmarg-keybindings.lua"} <= targets,(host,targets))
            self.assertIn("seed.py",record["early"])
        for host in ("ero","jarq"):
            self.assertIn(".bashrc",self.inventory[host]["files"])
            self.assertEqual(self.inventory[host]["manifest"],[])

    def test_non_ryoku_cleanup_does_not_gain_niri_directory_ownership(self):
        for host in ("ero","jarq"):
            loop=self.inventory[host]["cleanup"].split("for old_dir in",1)[1].split("; do",1)[0]
            self.assertNotIn(".config/niri",loop,host)

    def test_cleanup_preserves_unknown_native_directory_link_and_fails_safely(self):
        outside=self.home/"personal-config";outside.mkdir()
        (outside/"keep").write_text("untouched")
        target=self.config/"hypr";target.symlink_to(outside,target_is_directory=True)
        result=subprocess.run(["bash","-c",self.inventory["_runtime"]["cleanup"]],env=self.env,capture_output=True,text=True)
        self.assertNotEqual(result.returncode,0)
        self.assertTrue(target.is_symlink())
        self.assertEqual((outside/"keep").read_text(),"untouched")
        self.assertIn("preserved personal directory link",result.stderr)

    def test_legacy_directory_migration_never_unlinks_through_a_parent_link(self):
        row=next(row for row in self.inventory["envy"]["manifest"] if row["target"]==".config/orgm-ryoku/user.lua")
        source=row["source"].split("-user-dotfiles/",1)[0]+"-user-dotfiles/profiles/hyprland/.config/hypr"
        self.config.rmdir()
        outside_tmp=tempfile.TemporaryDirectory(prefix="ryoku-external-config-")
        self.addCleanup(outside_tmp.cleanup)
        outside=Path(outside_tmp.name)
        self.config.symlink_to(outside,target_is_directory=True)
        target=outside/"hypr";target.symlink_to(source,target_is_directory=True)
        result=subprocess.run(["bash","-c",self.inventory["_runtime"]["cleanup"]],env=self.env,capture_output=True,text=True)
        self.assertNotEqual(result.returncode,0)
        self.assertIn("preserved personal directory link",result.stderr)
        self.assertTrue(target.is_symlink())
        self.assertTrue(self.config.is_symlink())

    def test_cleanup_preserves_arbitrary_store_directory_link(self):
        row=next(row for row in self.inventory["envy"]["manifest"] if row["target"]==".bashrc")
        source=Path(row["legacySources"][0]).parent/".config/bash"
        self.assertTrue(source.is_dir())
        target=self.config/"hypr";target.symlink_to(source,target_is_directory=True)
        result=subprocess.run(["bash","-c",self.inventory["_runtime"]["cleanup"]],env=self.env,capture_output=True,text=True)
        self.assertNotEqual(result.returncode,0)
        self.assertIn("preserved personal directory link",result.stderr)
        self.assertTrue(target.is_symlink())
        self.assertEqual(target.resolve(),source)

    def test_cleanup_backs_up_known_legacy_directory_without_merging_desktops(self):
        row=next(row for row in self.inventory["envy"]["manifest"] if row["target"]==".config/orgm-ryoku/user.lua")
        source=row["source"].split("-user-dotfiles/",1)[0]+"-user-dotfiles/profiles/hyprland/.config/hypr"
        self.assertTrue(Path(source).is_dir())
        target=self.config/"hypr";target.symlink_to(source,target_is_directory=True)
        result=subprocess.run(["bash","-c",self.inventory["_runtime"]["cleanup"]],env=self.env,capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertFalse(target.exists())
        backup=self.state/"orgm-ryoku/legacy-directories-v1/.config/hypr"
        self.assertTrue(backup.is_dir())
        self.assertEqual(sorted(p.name for p in backup.iterdir()),sorted(p.name for p in Path(source).iterdir()))
        metadata_path=backup.with_name(backup.name+".metadata.json")
        self.assertTrue(metadata_path.is_file(),"directory migration needs link provenance")
        metadata=json.loads(metadata_path.read_text())
        self.assertEqual(metadata["link"],source)
        self.assertEqual(metadata["resolved"],source)
        self.assertEqual(metadata["target"],".config/hypr")
        self.assertEqual(backup.parent.stat().st_mode & 0o777,0o700)

    def test_known_older_directory_generation_keeps_bytes_and_provenance(self):
        old=self.home/"old-directory-source"
        relative="profiles/hyprland/.config/hypr"
        source=old/relative;source.mkdir(parents=True)
        (source/"old.lua").write_text("old generation bytes")
        expr='builtins.path {path=builtins.toPath (builtins.getEnv "RYOKU_OLD_SOURCE");name="user-dotfiles";}'
        copied=subprocess.check_output(["nix","eval","--impure","--raw","--expr",expr],env=dict(os.environ,RYOKU_OLD_SOURCE=str(old)),text=True).strip()
        expected=str(Path(copied)/relative)
        target=self.config/"hypr";target.symlink_to(expected,target_is_directory=True)
        result=subprocess.run(["bash","-c",self.inventory["_runtime"]["cleanup"]],env=self.env,capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertFalse(target.is_symlink())
        backup=self.state/"orgm-ryoku/legacy-directories-v1/.config/hypr"
        self.assertEqual((backup/"old.lua").read_text(),"old generation bytes")
        metadata=json.loads(backup.with_name("hypr.metadata.json").read_text())
        self.assertEqual(metadata["link"],expected)
        self.assertEqual(metadata["resolved"],expected)

    def test_old_store_generation_links_are_proven_by_registered_relative_source(self):
        records={row["target"]:row for row in self.inventory["envy"]["manifest"]}
        old=self.home/"old-source";old.mkdir()
        names=(".bashrc",".config/orgm-ryoku/shortcuts.lua")
        for name in names:
            source=records[name]["legacySources"][0]
            relative=source.split("-user-dotfiles/",1)[1]
            file=old/relative;file.parent.mkdir(parents=True,exist_ok=True);file.write_text("old-generation preferences")
        expr='builtins.path {path=builtins.toPath (builtins.getEnv "RYOKU_OLD_SOURCE");name="user-dotfiles";}'
        copied=subprocess.check_output(["nix","eval","--impure","--raw","--expr",expr],env=dict(os.environ,RYOKU_OLD_SOURCE=str(old)),text=True).strip()
        for name in names:
            target=self.home/name;target.parent.mkdir(parents=True,exist_ok=True)
            relative=records[name]["legacySources"][0].split("-user-dotfiles/",1)[1]
            target.symlink_to(Path(copied)/relative)
        self.early()
        self.assertIn("ryoku.bash",(self.home/".bashrc").read_text())
        helper=self.config/"orgm-ryoku/shortcuts.lua"
        self.assertFalse(helper.is_symlink());self.assertEqual(helper.read_text(),"old-generation preferences")

    def test_ryoku_console_roundtrip_restores_editable_bootstrap_and_preferences(self):
        self.early();self.populate_runtime();self.prepare();self.materialize()
        rc=self.home/".bashrc";rc.write_text(rc.read_text()+"\n# my preserved bootstrap edit\n")
        starship=self.config/"starship.toml";starship.write_text("# my preserved prompt\n")
        before={".bashrc":rc.read_bytes(),".config/starship.toml":starship.read_bytes()}
        result=subprocess.run(["bash","-c",self.inventory["_runtime"]["returnCleanup"]],env=self.env,capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertFalse(rc.exists(),"console profile would conflict with a regular Ryoku .bashrc")
        records={row["target"]:row for row in self.inventory["envy"]["manifest"]}
        for name in before:
            target=self.home/name;target.parent.mkdir(parents=True,exist_ok=True)
            if target.exists() or target.is_symlink():
                continue  # This console mode does not replace every GUI preference.
            source=self.inventory["_runtime"]["serverRc"] if name==".bashrc" else records[name]["legacySources"][0]
            target.symlink_to(source)
        self.early();self.populate_runtime();self.prepare();self.materialize()
        for name,content in before.items():
            self.assertFalse((self.home/name).is_symlink(),name)
            self.assertEqual((self.home/name).read_bytes(),content,name)

    def test_existing_fastfetch_and_mutable_preferences_survive_real_lifecycle(self):
        runtime=self.inventory["_runtime"]
        old_rc=next(row for row in self.inventory["envy"]["manifest"] if row["target"]==".bashrc")["legacySources"][0]
        (self.home/".bashrc").symlink_to(old_rc)
        existing=self.config/"fastfetch/config.jsonc";existing.parent.mkdir()
        existing.write_text(json.dumps({"logo":{"type":"none"},"display":{"separator":"user existing"},"modules":["title"]}))
        before=hashlib.sha256(existing.read_bytes()).hexdigest()
        self.early()
        self.assertFalse((self.home/".bashrc").is_symlink())
        self.populate_runtime();self.prepare();self.materialize()
        self.assertEqual(hashlib.sha256(existing.read_bytes()).hexdigest(),before)
        self.assertEqual(json.loads(existing.read_text())["display"]["separator"],"user existing")
        for relative in ("orgm-ryoku/user.lua","orgm-ryoku/osmarg-keybindings.lua","orgm-ryoku/shortcuts.lua","orgm-ryoku/window-rules.lua"):
            target=self.config/relative;self.assertFalse(target.is_symlink(),relative)
            target.write_text(target.read_text()+"\n-- personal edit preserved\n")
        imports=self.config/"bash/user.bash";imports.write_text("# user removed imports\n")
        self.early();self.prepare();self.materialize()
        self.assertEqual(imports.read_text(),"# user removed imports\n")
        for relative in ("orgm-ryoku/user.lua","orgm-ryoku/osmarg-keybindings.lua","orgm-ryoku/shortcuts.lua","orgm-ryoku/window-rules.lua"):
            self.assertIn("personal edit preserved",(self.config/relative).read_text())
        self.assertEqual(hashlib.sha256(existing.read_bytes()).hexdigest(),before)
        # Actual Hub Save and a NEW native Bash use the same Fastfetch file.
        hub=runtime["hub"]+"/bin/ryoku-hub"
        model=json.loads(subprocess.check_output([hub,"fastfetch","get"],env=self.env,text=True))
        model.setdefault("display",{})["separator"]="saved in Hub"
        subprocess.run([hub,"fastfetch","save",json.dumps(model)],env=self.env,check=True,capture_output=True,text=True)
        self.assertEqual(json.loads(existing.read_text())["display"]["separator"],"saved in Hub")
        (self.bin/"ryoku-fastfetch").symlink_to(runtime["data"]+"/bin/ryoku-fastfetch")
        capture=self.home/"fetch-capture.jsonl";self.env["FETCH_CAPTURE"]=str(capture)
        stub=self.bin/"fastfetch"
        stub.write_text("#!"+sys.executable+"\nimport json,os,sys\np=sys.argv[sys.argv.index('--config')+1]\nwith open(os.environ['FETCH_CAPTURE'],'a') as f:f.write(json.dumps({'path':p,'config':json.load(open(p))})+'\\n')\nprint('BANNER')\n")
        stub.chmod(0o755)
        # Re-enable only the default imports in this isolated test, not production.
        source=next(row["source"] for row in self.inventory["envy"]["manifest"] if row["target"]==".config/bash/user.bash")
        imports.write_bytes(Path(source).read_bytes())
        result=subprocess.run([shutil.which("bash"),"--noprofile","--norc","-ic",'. "$HOME/.bashrc"; declare -F omp; . "$HOME/.bashrc"'],env=self.env,capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(result.stdout.count("BANNER"),1,result.stdout)
        self.assertIn("omp",result.stdout)
        rows=[json.loads(row) for row in capture.read_text().splitlines()]
        self.assertEqual(len(rows),1)
        self.assertEqual(rows[0]["path"],str(existing))
        self.assertEqual(rows[0]["config"]["display"]["separator"],"saved in Hub")
        # Noninteractive Bash must not initialize a banner/imports.
        result=subprocess.run([shutil.which("bash"),"--noprofile","--norc","-c",'. "$HOME/.bashrc"'],env=self.env,capture_output=True,text=True)
        self.assertNotIn("BANNER",result.stdout)
        self.assertEqual(len(capture.read_text().splitlines()),1)

if __name__=="__main__":unittest.main()
