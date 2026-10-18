#!/usr/bin/env python3
"""Real Go CLI, declared host contexts and native compositor/materializer."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class CopyIntegration(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
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
   metadata=lib.mapAttrs' (n: v: lib.nameValuePair (normalize n) (toString v.source))
     (lib.filterAttrs (n: _: lib.hasPrefix ".config/orgm-ryoku/" (normalize n)) h.home.file);
   bootstrap=h.home.activation.orgmDotBootstrap.data;
   compositor=if ctx.profile=="hyprland" then toString c.programs.hyprland.package else "";
 };
 pkgs=f.nixosConfigurations.envy.pkgs;
 p=(import (builtins.getEnv "ORGM_DOT_TEST_REPO"+"/nixos/profiles/ryoku/provider-compat.nix")
   {inputs=f.inputs;pkgs=f.nixosConfigurations.lenovo.pkgs;inherit lib;}).packages;
 in pkgs.writeText "orgm-dot-integration.json" (builtins.toJSON {
   hosts=builtins.mapAttrs (_: describe) f.nixosConfigurations;
   helper=toString (pkgs.callPackage (builtins.getEnv "ORGM_DOT_TEST_REPO"+"/nixos/orgm/orgm-dot.nix") {});
   materializer=toString p.ryoku-materialize;
   nativeCompositor=toString pkgs.hyprland;
 })'''
            result = subprocess.check_output(
                ["nix", "build", "--impure", "--no-link", "--print-out-paths", "--max-jobs", "1", "--cores", "2", "--expr", expr],
                env=dict(os.environ, ORGM_DOT_TEST_REPO=str(ROOT)), text=True).strip()
            cls.inventory = json.loads(Path(result).read_text())
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

    def test_all_hosts_copy_dotfiles_without_home_manager_ownership(self):
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
                else:
                    self.assertNotIn("ryoku.bash", (home / ".bashrc").read_text())
                if host == "envy":
                    self.assertEqual(row["context"]["profile"], "ryoku")
                    self.assertFalse((home / ".local/bin/hypr-tray-applets").exists())
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

    def test_ryoku_prepares_native_desktop_and_keeps_user_choices(self):
        row, home, args = self.context("envy")
        self.call(args, "bootstrap")
        for rel, source in row["metadata"].items():
            dst = home / rel
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, dst)
        run = home / "run"
        run.mkdir(mode=0o700)
        env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(home / ".config"),
                   XDG_STATE_HOME=str(home / ".local/state"), XDG_DATA_HOME=str(home / ".local/share"),
                   XDG_CACHE_HOME=str(home / "cache"), XDG_RUNTIME_DIR=str(run),
                   DBUS_SESSION_BUS_ADDRESS="unix:path=" + str(run / "no-bus"),
                   WAYLAND_DISPLAY="", HYPRLAND_INSTANCE_SIGNATURE="", DISPLAY="")
        for _ in range(2):
            result = subprocess.run(["bash", str(ROOT / "nixos/profiles/ryoku/prepare.sh")], env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            result = subprocess.run([self.inventory["materializer"] + "/bin/ryoku-materialize"], env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            store = home / ".config/ryoku/desktop.json"
            data = json.loads(store.read_text())
            data["desktop"]["appearance"]["rounding"] = 19
            store.write_text(json.dumps(data))
        self.assertEqual(json.loads(store.read_text())["desktop"]["appearance"]["rounding"], 19)
        self.assertTrue((home / ".config/hypr/hyprland.lua").is_file())
        self.assertFalse((home / ".config/hypr/hyprland.lua").is_symlink())
        self.assertTrue((home / ".config/bash/ryoku.bash").is_file())
        self.call(args, "push", "ryoku-hub")
        saved = self.repo / "dotfiles/apps/ryoku-hub/osmarg/envy/ryoku/home/.config/ryoku/desktop.json"
        self.assertEqual(json.loads(saved.read_text())["desktop"]["appearance"]["rounding"], 19)


if __name__ == "__main__":
    unittest.main()
