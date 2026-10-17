#!/usr/bin/env python3
"""Initializer contract, including ownership boundaries and repeat activation."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
SEED=ROOT/"nixos/profiles/ryoku/seed.py"

class InitialSeed(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.home=Path(self.tmp.name)/"home";self.home.mkdir()
        self.config=self.home/".config";self.config.mkdir()
        self.state=self.home/"state"
        self.source=Path(self.tmp.name)/"source";self.source.write_text("initial")
        self.manifest=Path(self.tmp.name)/"manifest.json"

    def run_seed(self, records, ok=True):
        self.manifest.write_text(json.dumps(records))
        result=subprocess.run(["python3",str(SEED),str(self.config),str(self.state),str(self.home),str(self.manifest)],text=True,capture_output=True)
        if ok:self.assertEqual(result.returncode,0,result.stderr)
        else:self.assertNotEqual(result.returncode,0)
        return result

    def record(self, target=".config/app/user.conf", **kw):
        return dict(source=str(self.source),target=target,**kw)

    def test_missing_files_seed_as_writable_regular_files_and_preserve_edits(self):
        record=self.record();self.run_seed([record])
        target=self.config/"app/user.conf"
        self.assertTrue(target.is_file());self.assertFalse(target.is_symlink())
        self.assertTrue(target.stat().st_mode & 0o200)
        target.write_text("user edit");self.source.write_text("changed default")
        self.run_seed([record]);self.assertEqual(target.read_text(),"user edit")

    def test_new_files_seed_individually_after_previous_initialization(self):
        self.run_seed([self.record()])
        self.run_seed([self.record(),self.record(".config/app/added.conf")])
        self.assertEqual((self.config/"app/added.conf").read_text(),"initial")

    def test_existing_regular_bootstrap_and_removed_import_are_preserved(self):
        target=self.home/".bashrc";target.write_text("# personal, import deliberately removed\n")
        result=self.run_seed([self.record(".bashrc",replaceLegacy=True)])
        self.assertEqual(target.read_text(),"# personal, import deliberately removed\n")
        self.assertIn("ryoku.bash",result.stderr)

    def test_arbitrary_and_dangling_links_are_never_followed_or_replaced(self):
        outside=Path(self.tmp.name)/"outside";outside.write_text("outside")
        link=self.home/".bashrc";link.symlink_to(outside)
        self.run_seed([self.record(".bashrc",replaceLegacy=True)])
        self.assertTrue(link.is_symlink());self.assertEqual(outside.read_text(),"outside")
        link.unlink();link.symlink_to(Path(self.tmp.name)/"missing")
        self.run_seed([self.record(".bashrc",replaceLegacy=True)])
        self.assertTrue(link.is_symlink());self.assertFalse(link.exists())

    def test_proven_legacy_bootstrap_migrates_once_with_private_content_and_provenance(self):
        old=Path(self.tmp.name)/"known-old-source";old.write_text("known legacy")
        target=self.home/".bashrc";target.symlink_to(old)
        record=self.record(".bashrc",legacySources=[str(old)],replaceLegacy=True)
        self.run_seed([record])
        self.assertFalse(target.is_symlink());self.assertEqual(target.read_text(),"initial")
        metadata=list(self.state.rglob("*.metadata.json"));self.assertEqual(len(metadata),1)
        meta=json.loads(metadata[0].read_text())
        self.assertEqual(meta["link"],str(old));self.assertEqual(meta["resolved"],str(old))
        backup=metadata[0].with_name(metadata[0].name.replace(".metadata.json",".before"))
        self.assertEqual(backup.read_text(),"known legacy")
        self.assertEqual(backup.stat().st_mode & 0o777,0o600)
        self.assertEqual(metadata[0].stat().st_mode & 0o777,0o600)
        # An intentional subsequent link to the old file is now the user's choice.
        target.unlink();target.symlink_to(old);self.run_seed([record])
        self.assertTrue(target.is_symlink());self.assertEqual(target.read_text(),"known legacy")

    def test_failed_legacy_replacement_can_be_retried_without_false_completion(self):
        import importlib.util
        from unittest.mock import patch
        spec=importlib.util.spec_from_file_location("ryoku_seed",SEED)
        module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
        old=Path(self.tmp.name)/"known-old-source";old.write_text("original")
        target=self.home/".bashrc";target.symlink_to(old)
        record=self.record(".bashrc",legacySources=[str(old)],replaceLegacy=True)
        real=module.atomic_file
        def fail_replace(path,data,mode,replace=False):
            if replace:raise OSError("simulated replacement failure")
            return real(path,data,mode,replace)
        with patch.object(module,"atomic_file",side_effect=fail_replace):
            with self.assertRaises(OSError):module.seed(self.config,self.state,self.home,[record])
        self.assertTrue(target.is_symlink())
        self.assertEqual(list(self.state.rglob("*.metadata.json")),[])
        self.run_seed([record]);self.assertFalse(target.is_symlink())
        self.assertEqual(target.read_text(),"initial")

    def test_legacy_preference_links_detach_preserving_current_bytes_not_new_defaults(self):
        old=Path(self.tmp.name)/"known-old-source";old.write_text("old chosen preferences")
        target=self.config/"personal.lua";target.symlink_to(old)
        self.run_seed([self.record(".config/personal.lua",legacySources=[str(old)])])
        self.assertFalse(target.is_symlink())
        self.assertEqual(target.read_text(),"old chosen preferences")
        target.write_text("new Hub edit");self.run_seed([self.record(".config/personal.lua",legacySources=[str(old)])])
        self.assertEqual(target.read_text(),"new Hub edit")

    def test_traversal_and_absolute_targets_fail_without_partial_seeding(self):
        for target in ("../outside", "/tmp/unsafe", ".config/../../outside"):
            result=self.run_seed([self.record(),self.record(target)],ok=False)
            self.assertFalse((self.config/"app/user.conf").exists())

    def test_parent_symlink_is_preserved_and_cannot_write_outside_config(self):
        outside=Path(self.tmp.name)/"outside-dir";outside.mkdir()
        (self.config/"app").symlink_to(outside,target_is_directory=True)
        self.run_seed([self.record()])
        self.assertTrue((self.config/"app").is_symlink());self.assertFalse((outside/"user.conf").exists())

    def test_xdg_location_is_respected_and_legacy_only_records_do_not_seed_absent_files(self):
        self.config=Path(self.tmp.name)/"custom-xdg";self.config.mkdir()
        self.run_seed([self.record(),self.record(".config/old-shell.bash",seed=False)])
        self.assertTrue((self.config/"app/user.conf").exists())
        self.assertFalse((self.config/"old-shell.bash").exists())
        self.assertFalse((self.home/".config/app/user.conf").exists())

if __name__=="__main__":unittest.main()
