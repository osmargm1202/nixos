#!/usr/bin/env python3
"""Copy/disable contracts use real host evaluation and the packaged Go CLI.

Run heavyweight native integration separately (it realizes desktop providers):
    python3 tests/dotfiles-copies.py NativeIntegration
The default suite and shell wrappers never build the Ryoku desktop closure.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class DotfileIntegration(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if hasattr(DotfileIntegration, "shared_inventory"):
            cls.inventory = DotfileIntegration.shared_inventory
            cls.binary = cls.inventory["helper"] + "/bin/orgm-dot"
            return
        cached = os.environ.get("ORGM_DOT_INVENTORY")
        if cached:
            cls.inventory = json.loads(Path(cached).read_text())
        else:
            expr = r'''let
 f=builtins.getFlake ("path:"+builtins.getEnv "ORGM_DOT_TEST_REPO");
 lib=f.inputs.nixpkgs.lib;
 describe = s: let c=s.config;
   ctx=builtins.fromJSON c.environment.etc."orgm-dot/context.json".text;
   h=c.home-manager.users.${ctx.user};
   normalize=n: lib.removePrefix (h.home.homeDirectory+"/") n;
 in {
   context=ctx;
   files=builtins.mapAttrs (_: v: toString v.source) h.home.file;
   metadata=lib.mapAttrs' (n: v: lib.nameValuePair (normalize n) {
     source=toString v.source; text=v.text;
   }) (lib.filterAttrs (n: _: lib.hasPrefix ".config/orgm-ryoku/" (normalize n)) h.home.file);
   bootstrap=h.home.activation.orgmDotBootstrap.data;
 };
 in { hosts=builtins.mapAttrs (_: describe) f.nixosConfigurations; }'''
            cls.inventory = json.loads(subprocess.check_output(
                ["nix", "eval", "--impure", "--json", "--expr", expr],
                env=dict(os.environ, ORGM_DOT_TEST_REPO=str(ROOT)), text=True))
            # Keep store references in evaluated metadata inert. Realize only
            # the small CLI needed to exercise copies, not all referenced files.
            helper_expr = r'''let
 f=builtins.getFlake ("path:"+builtins.getEnv "ORGM_DOT_TEST_REPO");
 in f.nixosConfigurations.envy.pkgs.callPackage
   (builtins.getEnv "ORGM_DOT_TEST_REPO"+"/nixos/orgm/orgm-dot.nix") {}'''
            cls.inventory["helper"] = subprocess.check_output(
                ["nix", "build", "--impure", "--no-link", "--print-out-paths", "--expr", helper_expr],
                env=dict(os.environ, ORGM_DOT_TEST_REPO=str(ROOT)), text=True).strip()
        DotfileIntegration.shared_inventory = cls.inventory
        cls.binary = cls.inventory["helper"] + "/bin/orgm-dot"

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="orgm-dot-test-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.repo = self.root / "repo"
        shutil.copytree(ROOT / "dotfiles", self.repo / "dotfiles")

    def context(self, host, profile=None):
        row = self.inventory["hosts"][host]
        home = self.root / (host + "-home")
        home.mkdir(exist_ok=True)
        context = dict(row["context"], repository=str(self.repo))
        if profile:
            context["profile"] = profile
        path = self.root / (host + ".json")
        path.write_text(json.dumps(context))
        return row, home, [self.binary, "--context", str(path), "--home", str(home)]

    def call(self, args, *cmd):
        result = subprocess.run(args + list(cmd), capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result.stdout

    def install_metadata(self, row, home):
        for rel, entry in row["metadata"].items():
            dst = home / rel
            dst.parent.mkdir(parents=True, exist_ok=True)
            # HM text sources are writeText derivations. Use their evaluated
            # contents instead of realizing unrelated metadata dependencies.
            if entry["text"] is not None:
                dst.write_text(entry["text"])
            else:
                shutil.copyfile(entry["source"], dst)

    def isolated_environment(self, home):
        run = home / "run"
        run.mkdir(mode=0o700, exist_ok=True)
        env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(home / ".config"),
                   XDG_STATE_HOME=str(home / ".local/state"), XDG_DATA_HOME=str(home / ".local/share"),
                   XDG_CACHE_HOME=str(home / "cache"), XDG_RUNTIME_DIR=str(run),
                   DBUS_SESSION_BUS_ADDRESS="unix:path=" + str(run / "no-bus"))
        for key in ("HYPRLAND_INSTANCE_SIGNATURE", "WAYLAND_DISPLAY", "DISPLAY", "GNOME_KEYRING_CONTROL"):
            env.pop(key, None)
        return env


class CopyIntegration(DotfileIntegration):
    def test_all_hosts_copy_dotfiles_without_home_manager_ownership(self):
        self.assertTrue({"lenovo", "orgm-ryoku"} <= self.inventory["hosts"].keys())
        for host in self.inventory["hosts"]:
            with self.subTest(host=host):
                row, home, args = self.context(host)
                self.assertTrue(all("-user-dotfiles/" not in s and "/dotfiles/config/" not in s for s in row["files"].values()))
                self.assertIn("orgm-dot", row["bootstrap"])
                self.call(args, "bootstrap")
                self.assertFalse(any(p.is_symlink() for p in home.rglob("*") if "backups" not in p.parts))
                self.assertTrue((home / ".bashrc").is_file())
                self.assertTrue((home / ".local/bin/timer").stat().st_mode & 0o111)
                if row["context"]["profile"] == "ryoku":
                    self.assertIn("ryoku.bash", (home / ".bashrc").read_text())
                    self.assertFalse((home / ".config/hypr/hyprland.lua").exists())
                    self.assertFalse((home / ".config/waybar-hypr").exists())
                    self.assertTrue((home / ".config/orgm-shell/fzf-widgets.bash").is_file())
                    for helper in ("hypr-pi-prompt", "hypr-rofi-ssh-host", "hypr-video-timer", "windows-rdp", "dunstify"):
                        self.assertTrue((home / ".local/bin" / helper).is_file(), helper)
                    self.assertFalse((home / ".local/bin/hypr-wallpaper").exists())
                    self.assertFalse((home / ".local/bin/hypr-tray-applets").exists())
                else:
                    self.assertNotIn("ryoku.bash", (home / ".bashrc").read_text())
                if host == "envy":
                    self.assertEqual(row["context"]["profile"], "sway")
                    self.assertTrue((home / ".config/sway/config").is_file())
                    self.assertFalse((home / ".config/orgm-ryoku").exists())
                    self.assertFalse((home / ".config/ryoku/desktop.json").exists())
                if host in ("lenovo", "orgm-ryoku"):
                    self.assertEqual(row["context"]["profile"], "ryoku")
                    self.assertTrue((home / ".config/orgm-ryoku/user.lua").is_file())
                if host == "lenovo":
                    self.assertTrue((home / ".config/orgm-ryoku/monitors_user.lua").is_file())
                if host != "jarq":
                    git = home / ".config/git/config"
                    self.assertTrue(git.is_file())
                    self.assertTrue(git.stat().st_mode & 0o200)

    def test_application_snapshots_replace_both_sides_and_restore(self):
        _, home, args = self.context("envy", profile="hyprland")
        self.call(args, "bootstrap")
        other = home / ".config/kitty/kitty.conf"
        before = other.read_bytes()
        bar = home / ".config/waybar-hypr"
        (bar / "new-local-file").write_text("local choice\n")
        (bar / "style.css").unlink()
        changes = json.loads(self.call(args, "diff", "waybar", "--json"))
        self.assertIn({"code": "D", "path": ".config/waybar-hypr/new-local-file"}, changes)
        self.call(args, "push", "waybar")
        snapshot = self.repo / "dotfiles/apps/waybar/osmarg/envy/hyprland/home/.config/waybar-hypr"
        self.assertTrue((snapshot / "new-local-file").is_file())
        (snapshot / "stale-repo-file").write_text("stale")
        self.call(args, "push", "waybar")
        self.assertFalse((snapshot / "stale-repo-file").exists())
        (bar / "delete-on-pull").write_text("old local data")
        result = self.call(args, "pull", "waybar")
        backup = result.strip().split("Backup: ", 1)[1]
        self.assertFalse((bar / "delete-on-pull").exists())
        self.assertFalse((bar / "style.css").exists(), "lower layers resurrected a deletion")
        self.assertEqual(other.read_bytes(), before)
        self.call(args, "restore", backup)
        self.assertEqual((bar / "delete-on-pull").read_text(), "old local data")

    def test_rebuild_seed_preserves_changes_and_user_removals(self):
        _, home, args = self.context("envy")
        self.call(args, "bootstrap")
        rc = home / ".bashrc"
        rc.write_text("my entirely editable bashrc\n")
        deleted = home / ".config/fastfetch/config.jsonc"
        deleted.unlink()
        self.call(args, "bootstrap")
        self.assertEqual(rc.read_text(), "my entirely editable bashrc\n")
        self.assertFalse(deleted.exists())

    def test_ryoku_prepares_native_desktop_and_keeps_user_choices(self):
        row, home, args = self.context("orgm-ryoku")
        self.assertEqual(row["context"]["profile"], "ryoku")
        self.call(args, "bootstrap")
        self.install_metadata(row, home)
        env = self.isolated_environment(home)
        for _ in range(2):
            result = subprocess.run(["bash", "-euo", "pipefail", str(ROOT / "nixos/profiles/ryoku/prepare.sh")], env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            store = home / ".config/ryoku/desktop.json"
            data = json.loads(store.read_text())
            if _ == 1:
                self.assertEqual(data["desktop"]["appearance"]["rounding"], 19)
            data["desktop"]["appearance"]["rounding"] = 19
            store.write_text(json.dumps(data))
        self.assertEqual(json.loads(store.read_text())["desktop"]["appearance"]["rounding"], 19)
        self.assertTrue((home / ".config/hypr/user.lua").is_file())
        self.assertFalse((home / ".config/hypr/user.lua").is_symlink())
        self.call(args, "push", "ryoku-hub")
        saved = self.repo / "dotfiles/apps/ryoku-hub/osmarg/orgm/ryoku/home/.config/ryoku/desktop.json"
        self.assertEqual(json.loads(saved.read_text())["desktop"]["appearance"]["rounding"], 19)


class DisableTransitionIntegration(DotfileIntegration):
    def test_removal_survives_bootstrap_and_restore_recovers_only_its_context(self):
        _, home, args = self.context("envy")
        self.call(args, "bootstrap")
        target = home / ".config/kitty/kitty.conf"
        target.write_text("font_size 19\n")
        self.call(args, "push", "kitty")
        snapshot = self.repo / "dotfiles/apps/kitty/osmarg/envy/sway"
        # Another profile's saved copy must not be disabled or overwritten.
        other = self.repo / "dotfiles/apps/kitty/osmarg/envy/hyprland/home/.config/kitty/kitty.conf"
        other.parent.mkdir(parents=True, exist_ok=True)
        other.write_text("other profile\n")
        result = self.call(args, "remove", "kitty")
        backup = result.strip().split("Backup: ", 1)[1]
        self.assertEqual(target.read_text(), "font_size 19\n")
        self.assertEqual(other.read_text(), "other profile\n")
        self.assertTrue((snapshot / "removed.json").is_file())
        self.assertFalse((snapshot / "snapshot.json").exists())
        for command in ("pull", "push", "diff"):
            result = subprocess.run(args + [command, "kitty"], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("removed", result.stderr)
        shutil.rmtree(target.parent)
        # Clear initial activation markers too, proving the tombstone (rather
        # than already-completed bootstrap state) prevents reintroduction.
        for marker in (home / ".local/state/orgm-dot").glob("bootstrap-*.json"):
            marker.unlink()
        self.call(args, "bootstrap")
        self.assertFalse(target.exists())
        self.call(args, "restore", backup)
        self.assertFalse(json.loads(self.call(args, "show", "kitty"))["disabled"])
        self.call(args, "pull", "kitty")
        self.assertEqual(target.read_text(), "font_size 19\n")
        self.assertEqual(other.read_text(), "other profile\n")


class NativeIntegration(DotfileIntegration):
    """Explicit build/materialization boundary; never selected by fast wrappers."""
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        expr = r'''let
 f=builtins.getFlake ("path:"+builtins.getEnv "ORGM_DOT_TEST_REPO");
 pkgs=f.nixosConfigurations.envy.pkgs;
 p=(import (builtins.getEnv "ORGM_DOT_TEST_REPO"+"/nixos/profiles/ryoku/provider-compat.nix")
   {inputs=f.inputs;pkgs=f.nixosConfigurations.lenovo.pkgs;lib=f.inputs.nixpkgs.lib;}).packages;
 in pkgs.writeText "orgm-dot-native-integration.json" (builtins.toJSON {
   nativeCompositor=toString pkgs.hyprland;
   materializer=toString p.ryoku-materialize;
 })'''
        inventory_path = subprocess.check_output(
            ["nix", "build", "--impure", "--no-link", "--print-out-paths", "--max-jobs", "1", "--cores", "2", "--expr", expr],
            env=dict(os.environ, ORGM_DOT_TEST_REPO=str(ROOT)), text=True).strip()
        cls.inventory.update(json.loads(Path(inventory_path).read_text()))

    def test_native_hyprland_parses_the_copied_envy_configuration(self):
        row, home, args = self.context("envy", profile="hyprland")
        self.call(args, "bootstrap")
        run = home / "run"
        run.mkdir(mode=0o700)
        env = dict(os.environ, HOME=str(home), HOSTNAME="envy", XDG_CONFIG_HOME=str(home / ".config"),
                   XDG_RUNTIME_DIR=str(run), XDG_DATA_HOME=str(home / "data"), XDG_STATE_HOME=str(home / "state"),
                   XDG_CACHE_HOME=str(home / "cache"), DBUS_SESSION_BUS_ADDRESS="unix:path=" + str(run / "no-bus"))
        for key in ("HYPRLAND_INSTANCE_SIGNATURE", "WAYLAND_DISPLAY", "DISPLAY", "GNOME_KEYRING_CONTROL"):
            env.pop(key, None)
        result = subprocess.run([self.inventory["nativeCompositor"] + "/bin/Hyprland", "--verify-config", "--config", str(home / ".config/hypr/hyprland.lua")],
                                env=env, capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("config ok", result.stdout.lower())

    def test_real_ryoku_materializer_preserves_hub_edits_and_exports_snapshot(self):
        for host in ("lenovo", "orgm-ryoku"):
            with self.subTest(host=host):
                row, home, args = self.context(host)
                self.assertEqual(row["context"]["profile"], "ryoku")
                self.call(args, "bootstrap")
                self.install_metadata(row, home)
                env = self.isolated_environment(home)
                store = home / ".config/ryoku/desktop.json"
                for _ in range(2):
                    result = subprocess.run(["bash", "-euo", "pipefail", str(ROOT / "nixos/profiles/ryoku/prepare.sh")],
                                            env=env, capture_output=True, text=True)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    result = subprocess.run([self.inventory["materializer"] + "/bin/ryoku-materialize"],
                                            env=env, capture_output=True, text=True, timeout=120)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    data = json.loads(store.read_text())
                    if _ == 1:
                        self.assertEqual(data["desktop"]["appearance"]["rounding"], 19)
                    data["desktop"]["appearance"]["rounding"] = 19
                    store.write_text(json.dumps(data))
                for rel in (".config/hypr/hyprland.lua", ".config/bash/ryoku.bash"):
                    self.assertTrue((home / rel).is_file(), rel)
                    self.assertFalse((home / rel).is_symlink(), rel)
                self.call(args, "push", "ryoku-hub")
                saved = (self.repo / "dotfiles/apps/ryoku-hub" / row["context"]["user"] /
                         row["context"]["host"] / "ryoku/home/.config/ryoku/desktop.json")
                self.assertEqual(json.loads(saved.read_text())["desktop"]["appearance"]["rounding"], 19)


if __name__ == "__main__":
    unittest.main(defaultTest=["CopyIntegration", "DisableTransitionIntegration"])
