#!/usr/bin/env python3
"""Run real preparation; catch missing migration, duplicates and lost Hub edits."""
import json
import fcntl
import time
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

class NativeSession(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.config = self.home / ".config"
        self.state = self.home / ".local/state/orgm-ryoku"
        self.seed = self.config / "orgm-ryoku"
        shutil.copytree(ROOT / "dotfiles/config/profiles/ryoku/.config/orgm-ryoku", self.seed)
        shutil.copy(ROOT / "nixos/profiles/ryoku/native-session.py", self.seed)
        (self.config / "ryoku").mkdir()
        self.store = self.config / "ryoku/desktop.json"
        self.defaults = {
            "required": ["tailscale systray --theme light", "syncthingtray --single-instance --wait"],
            "optional": ["nextcloud --background", "firefox"],
            "desktop": {
                "keybindRebinds": {"SUPER + H": "SUPER + CTRL + ALT + SHIFT + H", "SUPER + S": "SUPER + H"},
                "keybinds": [{"keys": "SUPER + H", "action": "exec", "value": "ryoku-shell stash"}],
                "unbinds": ["SUPER + H"],
            },
        }
        (self.seed / "native-session.json").write_text(json.dumps(self.defaults))
        self.env = dict(os.environ, HOME=str(self.home), XDG_CONFIG_HOME=str(self.config),
                        XDG_STATE_HOME=str(self.home / ".local/state"),
                        XDG_DATA_HOME=str(self.home / ".local/share"))

    def prepare(self):
        subprocess.run(["bash", str(ROOT / "nixos/profiles/ryoku/prepare.sh")],
                       env=self.env, check=True, capture_output=True)
        return json.loads(self.store.read_text())

    def test_prepare_refuses_nested_override_directory_links_without_mutations(self):
        for relative in ("ryoku/user_edits/hypr", "ryoku/user_edits/hypr/modules", "ryoku/user_edits/matugen", "ryoku-terminal"):
            with self.subTest(relative=relative):
                self.setUp()  # Each link case gets an independent configuration tree.
                target=self.config/relative
                target.parent.mkdir(parents=True,exist_ok=True)
                outside_tmp=tempfile.TemporaryDirectory(prefix="ryoku-external-")
                self.addCleanup(outside_tmp.cleanup)
                outside=Path(outside_tmp.name)
                (outside/"personal").write_text("untouched")
                target.symlink_to(outside,target_is_directory=True)
                result=subprocess.run(["bash",str(ROOT/"nixos/profiles/ryoku/prepare.sh")],env=self.env,capture_output=True,text=True)
                self.assertNotEqual(result.returncode,0)
                self.assertIn("preserved personal directory link",result.stderr)
                self.assertTrue(target.is_symlink())
                self.assertEqual(sorted(p.name for p in outside.iterdir()),["personal"])
                target.unlink()

    def test_prepare_preserves_personal_overrides_and_removed_kitty_import(self):
        (self.seed / "matugen-config.toml").write_text("initial palette hook")
        self.prepare()
        values = {
            "hypr/user.lua": "-- user edited Lua",
            "ryoku/user_edits/hypr/modules/rebind.lua": "-- user edited rebind",
            "ryoku/user_edits/matugen/config.toml": "user edited palette hook",
            "kitty/orgm-ryoku.conf": "background_opacity 0.55",
            "kitty/user.conf": "# include deliberately removed",
            "ryoku/keyring.json": '{"mode":"ask"}',
        }
        for name, value in values.items():
            (self.config / name).write_text(value)
        self.prepare()
        for name, value in values.items():
            self.assertEqual((self.config / name).read_text(), value, name)

    def test_keyring_alias_selected_after_initial_prepare_is_not_retired_later(self):
        self.prepare()
        keyrings=self.home/".local/share/keyrings";keyrings.mkdir(parents=True)
        (keyrings/"login.keyring").write_text("private fixture")
        alias=keyrings/"default";alias.write_text("orgm-never-ask\n")
        self.prepare()
        self.assertEqual(alias.read_text(),"orgm-never-ask\n")

    def test_already_seeded_store_gets_native_startup_and_preserves_unrelated_data(self):
        self.state.mkdir(parents=True)
        (self.state / "desktop-defaults.seeded").touch()
        original = {"desktop": {"appearance": {"rounding": 19}}, "future": {"unknown": [1, 2]}}
        self.store.write_text(json.dumps(original))
        result = self.prepare()
        self.assertEqual(result["desktop"].get("autostart"), [
            {"command": "tailscale systray --theme light"},
            {"command": "syncthingtray --single-instance --wait"},
            {"command": "nextcloud --background"}, {"command": "firefox"}])
        self.assertEqual(result["future"], original["future"])
        self.assertEqual(result["desktop"]["appearance"], original["desktop"]["appearance"])
        backup = json.loads((self.state / "desktop.before-native-session-v1.json").read_text())
        self.assertEqual(backup, original)
        self.assertEqual(self.prepare(), result)

    def test_explicit_empty_optional_selection_survives_and_hub_edits_survive_reactivation(self):
        self.store.write_text(json.dumps({"desktop": {"autostart": []}}))
        result = self.prepare()
        self.assertEqual(result["desktop"].get("autostart"), [
            {"command": "tailscale systray --theme light"},
            {"command": "syncthingtray --single-instance --wait"}])
        result["desktop"]["autostart"].append({"command": "personal-app", "future": True})
        self.store.write_text(json.dumps(result))
        self.assertEqual(self.prepare(), result)

    def test_duplicate_commands_collapse_without_losing_metadata_or_kde_indicator(self):
        self.store.write_text(json.dumps({"desktop": {"autostart": [
            {"command": "firefox", "user": True}, {"command": "firefox"},
            {"command": "kdeconnect-indicator"}, {"command": "tailscale systray --theme light"}]}}))
        result = self.prepare()["desktop"]["autostart"]
        self.assertEqual(result, [{"command": "firefox", "user": True},
            {"command": "kdeconnect-indicator"}, {"command": "tailscale systray --theme light"},
            {"command": "syncthingtray --single-instance --wait"}])

    def test_native_shortcuts_seed_once_and_preserve_custom_binding_conflicts(self):
        result = self.prepare()["desktop"]
        self.assertIn({"keys": "SUPER + H", "action": "exec", "value": "ryoku-shell stash"}, result.get("keybinds", []))
        self.assertEqual(result["keybindRebinds"]["SUPER + S"], "SUPER + H")
        self.assertIn("SUPER + H", result["unbinds"])
        result["keybinds"][0]["value"] = "personal-stash"
        self.store.write_text(json.dumps({"desktop": result}))
        self.assertEqual(self.prepare()["desktop"], result)

    def test_existing_custom_h_or_rebind_is_not_overwritten(self):
        original = {"keybinds": [{"keys": "super+h", "action": "exec", "value": "personal"}],
                    "keybindRebinds": {"SUPER + K": "SUPER + F8"}, "unbinds": ["SUPER + X"]}
        self.store.write_text(json.dumps({"desktop": original}))
        result = self.prepare()["desktop"]
        self.assertEqual(result["keybinds"], original["keybinds"])
        self.assertEqual(result["keybindRebinds"].get("SUPER + K"), "SUPER + F8")
        self.assertEqual(result["keybindRebinds"].get("SUPER + H"), "SUPER + CTRL + ALT + SHIFT + H")
        self.assertEqual(result["unbinds"], original["unbinds"])

    def test_existing_custom_k_keeps_ownership_and_native_help_is_preserved_elsewhere(self):
        self.store.write_text(json.dumps({"desktop": {"keybinds": [
            {"keys": "SUPER + K", "action": "exec", "value": "personal-help"},
            {"keys": "SUPER + CTRL + ALT + SHIFT + K", "action": "exec", "value": "personal-other"}]}}))
        result = self.prepare()["desktop"]
        target = result.get("keybindRebinds", {}).get("SUPER + K")
        self.assertIsNotNone(target, "native K would collide with existing custom K")
        self.assertNotIn(target, ["SUPER + K", "SUPER + CTRL + ALT + SHIFT + K"])
        self.assertEqual(result["keybinds"][:2], [
            {"keys": "SUPER + K", "action": "exec", "value": "personal-help"},
            {"keys": "SUPER + CTRL + ALT + SHIFT + K", "action": "exec", "value": "personal-other"}])

    def test_occupied_scratchpad_target_does_not_receive_the_default_stash_bundle(self):
        original = {"keys": "SUPER + CTRL + ALT + SHIFT + H", "action": "exec", "value": "personal"}
        self.store.write_text(json.dumps({"desktop": {"keybinds": [original]}}))
        result = self.prepare()["desktop"]
        self.assertEqual(result["keybinds"], [original])
        self.assertNotIn("SUPER + S", result.get("keybindRebinds", {}))

    def test_configuration_delta_updates_only_managed_rows_not_hub_deletions(self):
        result = self.prepare()
        result["desktop"]["autostart"] = [row for row in result["desktop"]["autostart"]
                                           if row["command"] != "firefox"]
        result["desktop"]["autostart"].append({"command": "personal"})
        self.store.write_text(json.dumps(result))
        self.defaults["optional"] = ["firefox", "new-app"]
        (self.seed / "native-session.json").write_text(json.dumps(self.defaults))
        actual = self.prepare()["desktop"]["autostart"]
        self.assertEqual(actual, [{"command": "tailscale systray --theme light"},
            {"command": "syncthingtray --single-instance --wait"},
            {"command": "personal"}, {"command": "new-app"}])

    def test_retired_trays_and_envy_nextcloud_are_removed_once_without_losing_hub_edits(self):
        before = self.prepare()
        before["desktop"]["autostart"].append({"command": "personal-app", "future": True})
        before["desktop"]["appearance"]["rounding"] = 27
        self.store.write_text(json.dumps(before))
        self.defaults["required"] = []
        self.defaults["optional"] = ["firefox"]
        self.defaults["retired"] = ["tailscale systray --theme light",
                                    "syncthingtray --single-instance --wait", "nextcloud --background"]
        (self.seed / "native-session.json").write_text(json.dumps(self.defaults))
        result = self.prepare()
        self.assertEqual(result["desktop"]["autostart"], [
            {"command": "firefox"}, {"command": "personal-app", "future": True}])
        self.assertEqual(result["desktop"]["appearance"]["rounding"], 27)
        self.assertEqual(json.loads((self.state / "desktop.before-retired-startup-v1.json").read_text()), before)
        # A later deliberate Session edit is not overwritten on each activation.
        result["desktop"]["autostart"].append({"command": "tailscale systray --theme light", "personal": True})
        self.store.write_text(json.dumps(result))
        self.assertEqual(self.prepare(), result)

    def test_hub_file_lock_prevents_clobbering_concurrent_edits(self):
        self.prepare()
        with (self.config / "ryoku/.desktop.lock").open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            process = subprocess.Popen(["bash", str(ROOT / "nixos/profiles/ryoku/prepare.sh")],
                                       env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            try:
                time.sleep(0.3)
                self.assertIsNone(process.poll(), "migration ignored Hub's desktop lock")
                current = json.loads(self.store.read_text())
                current["concurrent"] = "saved by Hub"
                self.store.write_text(json.dumps(current))
            finally:
                fcntl.flock(lock, fcntl.LOCK_UN)
                process.communicate(timeout=10)
        self.assertEqual(process.returncode, 0)
        self.assertEqual(json.loads(self.store.read_text())["concurrent"], "saved by Hub")

    def test_invalid_json_is_not_replaced_or_marked_migrated(self):
        self.state.mkdir(parents=True)
        (self.state / "desktop-defaults.seeded").touch()
        self.store.write_text("{broken")
        process = subprocess.run(["bash", str(ROOT / "nixos/profiles/ryoku/prepare.sh")],
                                 env=self.env, capture_output=True)
        self.assertNotEqual(process.returncode, 0)
        self.assertEqual(self.store.read_text(), "{broken")
        self.assertFalse((self.state / "native-session-v1.applied.json").exists())

    def test_host_audio_boost_enables_ui_and_keeps_unrelated_shell_data_then_hub_choice(self):
        (self.seed / "audio-defaults.json").write_text('{"audioBoost":true}')
        shell = self.config / "ryoku/shell.json"
        original = {"barStyle": "qsbar", "qsbar": {"audioBoost": False, "layout": {"left": ["clock"]}},
                    "dock": {"enabled": True}, "future": [1, 2]}
        before = json.dumps(original)
        shell.write_text(before)
        self.prepare()
        actual = json.loads(shell.read_text())
        expected = json.loads(before)
        expected["qsbar"]["audioBoost"] = True
        self.assertEqual(actual, expected)
        backup = self.state / "shell.before-audio-boost-v1.json"
        self.assertEqual(backup.read_text(), before)
        self.assertEqual(backup.stat().st_mode & 0o777, 0o600)
        actual["qsbar"]["audioBoost"] = False  # Explicit later Hub choice must win.
        shell.write_text(json.dumps(actual))
        self.prepare()
        self.assertEqual(json.loads(shell.read_text()), actual)
        self.assertEqual(backup.read_text(), before)

    def test_host_audio_boost_seeds_fresh_shell_and_shares_native_shell_lock(self):
        (self.seed / "audio-defaults.json").write_text('{"audioBoost":true}')
        shell = self.config / "ryoku/shell.json"
        with (self.config / "ryoku/shell.json.lock").open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            process = subprocess.Popen(["bash", str(ROOT / "nixos/profiles/ryoku/prepare.sh")],
                                       env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            try:
                time.sleep(0.3)
                self.assertIsNone(process.poll(), "audio seed ignored native shell lock")
                shell.write_text('{"concurrent":"preserve"}')
            finally:
                fcntl.flock(lock, fcntl.LOCK_UN)
                process.communicate(timeout=10)
        self.assertEqual(process.returncode, 0)
        self.assertEqual(json.loads(shell.read_text()), {"concurrent": "preserve", "qsbar": {"audioBoost": True}})
        self.assertTrue((self.state / "audio-boost-v1.applied.json").exists())

    def test_host_audio_boost_creates_missing_shell_without_fake_backup(self):
        (self.seed / "audio-defaults.json").write_text('{"audioBoost":true}')
        self.prepare()
        shell = self.config / "ryoku/shell.json"
        self.assertEqual(json.loads(shell.read_text()), {"qsbar": {"audioBoost": True}})
        self.assertEqual(shell.stat().st_mode & 0o777, 0o600)
        self.assertFalse((self.state / "shell.before-audio-boost-v1.json").exists())
        self.assertEqual((self.state / "audio-boost-v1.applied.json").stat().st_mode & 0o777, 0o600)

    def test_invalid_shell_is_not_replaced_or_marked_audio_migrated(self):
        (self.seed / "audio-defaults.json").write_text('{"audioBoost":true}')
        shell = self.config / "ryoku/shell.json"
        shell.write_text('{broken')
        process = subprocess.run(["bash", str(ROOT / "nixos/profiles/ryoku/prepare.sh")],
                                 env=self.env, capture_output=True)
        self.assertNotEqual(process.returncode, 0)
        self.assertEqual(shell.read_text(), '{broken')
        self.assertFalse((self.state / "audio-boost-v1.applied.json").exists())

    def test_window_defaults_seed_once_keep_hub_data_and_derive_hypr_widths(self):
        defaults = {"windowRules": [
            {"class": "^firefox$", "action": "columnwidth", "value": "1"},
            {"class": "^windows-rdp$", "action": "fullscreen", "value": ""},
        ]}
        (self.seed / "window-defaults.json").write_text(json.dumps(defaults))
        existing = {"class": "^kitty$", "action": "float", "value": "", "future": True}
        original = {"desktop": {"windowRules": [existing]}, "unrelated": {"keep": [1]}}
        self.store.write_text(json.dumps(original))
        result = self.prepare()
        self.assertEqual(result["desktop"]["windowRules"], [existing, *defaults["windowRules"]])
        self.assertEqual(result["unrelated"], original["unrelated"])
        backup = self.state / "desktop.before-window-defaults-v1.json"
        self.assertEqual(backup.stat().st_mode & 0o777, 0o600)
        self.assertEqual(json.loads(backup.read_text())["desktop"]["windowRules"], [existing])
        derived = self.seed / "native-window-widths.lua"
        self.assertIn('scrolling_width = 1.0', derived.read_text())
        self.assertNotIn('fullscreen', derived.read_text(), 'native provider owns fullscreen')
        # Hub changes after seeding win, including deleting the Windows rule.
        result["desktop"]["windowRules"] = [{"class": "^firefox$", "action": "columnwidth", "value": "0.75"}]
        self.store.write_text(json.dumps(result))
        self.assertEqual(self.prepare(), result)
        self.assertIn('scrolling_width = 0.75', derived.read_text())
        self.assertNotIn('scrolling_width = 1.0', derived.read_text())

    def test_window_defaults_do_not_duplicate_existing_native_rule(self):
        rule = {"class": "^firefox$", "action": "columnwidth", "value": "1"}
        (self.seed / "window-defaults.json").write_text(json.dumps({"windowRules": [rule]}))
        self.store.write_text(json.dumps({"desktop": {"windowRules": [rule]}}))
        self.assertEqual(self.prepare()["desktop"]["windowRules"], [rule])
        self.assertTrue((self.state / "window-defaults-v1.applied.json").exists())

    def test_hub_blank_columnwidth_uses_native_fallback_without_blocking_prepare(self):
        (self.seed / "window-defaults.json").write_text('{"windowRules":[]}')
        self.prepare()
        for value in ("", "not-yet-a-number"):
            original = {"desktop": {"windowRules": [
                {"class": "^personal$", "action": "columnwidth", "value": value}]}}
            self.store.write_text(json.dumps(original))
            self.assertEqual(self.prepare()["desktop"]["windowRules"], original["desktop"]["windowRules"])
            self.assertIn('scrolling_width = 0.5', (self.seed / "native-window-widths.lua").read_text())

    def test_out_of_range_hub_width_does_not_block_other_rules_or_change_store(self):
        (self.seed / "window-defaults.json").write_text('{"windowRules":[]}')
        self.prepare()
        for value in ("NaN", "inf", "0", "-1", "1.5"):
            rules = [{"class": "^personal$", "action": "columnwidth", "value": value},
                     {"class": "^firefox$", "action": "columnwidth", "value": "1"}]
            self.store.write_text(json.dumps({"desktop": {"windowRules": rules}}))
            self.assertEqual(self.prepare()["desktop"]["windowRules"], rules)
            derived = (self.seed / "native-window-widths.lua").read_text()
            self.assertNotIn('^personal$', derived)
            self.assertIn('scrolling_width = 1.0', derived)

    def test_invalid_window_defaults_do_not_mark_migration_or_replace_rules(self):
        (self.seed / "window-defaults.json").write_text('{"windowRules":"broken"}')
        self.store.write_text('{"desktop":{"windowRules":[]}}')
        process = subprocess.run(["bash", str(ROOT / "nixos/profiles/ryoku/prepare.sh")],
                                 env=self.env, capture_output=True)
        self.assertNotEqual(process.returncode, 0)
        self.assertEqual(json.loads(self.store.read_text())["desktop"]["windowRules"], [])
        self.assertFalse((self.state / "window-defaults-v1.applied.json").exists())

if __name__ == "__main__":
    unittest.main()
