#!/usr/bin/env python3
"""Exercise removal of known artifacts while preserving personal files and data."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("cleanup", ROOT / "nixos/profiles/ryoku/cleanup.py")
cleanup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cleanup)


class Cleanup(unittest.TestCase):
    def test_archives_only_matching_wallpaper_script_and_preserves_modified_files(self):
        with tempfile.TemporaryDirectory() as temp:
            home = Path(temp) / "home"
            home.mkdir()
            state = Path(temp) / "state"
            source = ROOT / "dotfiles/config/profiles/hyprland/.local/share/nautilus/scripts/Set as Hyprland Wallpaper"
            relative = ".local/share/nautilus/scripts/Set as Hyprland Wallpaper"
            target = home / relative
            target.parent.mkdir(parents=True)
            target.write_bytes(source.read_bytes())
            manifest = {"files": [{"target": relative, "sources": [str(source)]}]}
            cleanup.cleanup(home, state, manifest)
            self.assertFalse(target.exists())
            self.assertEqual((state / "desktop-cleanup-v1" / relative).read_bytes(), source.read_bytes())
            target.write_text("personal wallpaper action\n")
            cleanup.cleanup(home, state, manifest)
            self.assertEqual(target.read_text(), "personal wallpaper action\n")

    def test_masks_replace_links_without_writing_store_targets_and_keep_original_backup(self):
        with tempfile.TemporaryDirectory() as temp:
            home = Path(temp) / "home"
            (home / ".config/autostart").mkdir(parents=True)
            state = Path(temp) / "state"
            source = Path(temp) / "package.desktop"
            source.write_text("[Desktop Entry]\nExec=nextcloud --background\n")
            target = home / ".config/autostart/Nextcloud.desktop"
            target.symlink_to(source)
            manifest = {"autostart": ["Nextcloud.desktop"]}
            cleanup.cleanup(home, state, manifest, apply_masks=True)
            self.assertFalse(target.is_symlink())
            self.assertIn("Hidden=true", target.read_text())
            self.assertIn("Exec=nextcloud", source.read_text())
            backup = state / "desktop-cleanup-v1/.config/autostart/Nextcloud.desktop"
            self.assertEqual(backup.read_text(), source.read_text())
            cleanup.cleanup(home, state, manifest, apply_masks=True)
            self.assertEqual(backup.read_text(), source.read_text())

    def test_package_unit_links_retire_before_hm_without_removing_personal_unit(self):
        with tempfile.TemporaryDirectory() as temp:
            home = Path(temp) / "home"
            units = home / ".config/systemd/user"
            (units / "default.target.wants").mkdir(parents=True)
            unit = units / "syncthing.service"
            unit.symlink_to("/nix/store/old-syncthing-2.0/share/systemd/user/syncthing.service")
            wanted = units / "default.target.wants/syncthing.service"
            wanted.symlink_to("../syncthing.service")
            manifest = {"packageUnits": [
                ".config/systemd/user/default.target.wants/syncthing.service",
                ".config/systemd/user/syncthing.service"]}
            state = Path(temp) / "state"
            cleanup.cleanup(home, state, manifest, keep_units=True)
            self.assertTrue(unit.is_symlink())
            cleanup.cleanup(home, state, manifest)
            self.assertFalse(unit.is_symlink())
            self.assertFalse(wanted.is_symlink())
            unit.write_text("personal service\n")
            cleanup.cleanup(home, state, manifest)
            self.assertEqual(unit.read_text(), "personal service\n")

    def test_external_autostart_directory_is_not_written_through(self):
        with tempfile.TemporaryDirectory() as temp:
            home = Path(temp) / "home"
            (home / ".config").mkdir(parents=True)
            outside = Path(temp) / "outside"
            outside.mkdir()
            (home / ".config/autostart").symlink_to(outside, target_is_directory=True)
            cleanup.cleanup(home, Path(temp) / "state", {"autostart": ["blueman.desktop"]}, apply_masks=True)
            self.assertEqual(list(outside.iterdir()), [])


if __name__ == "__main__":
    unittest.main()
