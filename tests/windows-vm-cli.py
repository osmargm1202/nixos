#!/usr/bin/env python3
"""The generated common CLI with both real adapters and isolated fake engines."""
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]

def load(name, file):
    spec = importlib.util.spec_from_file_location(name, ROOT / "tests" / file)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

LENOVO = load("lenovo_cli_fixtures", "lenovo-windows-runtime.py")
ENVY = load("envy_cli_fixtures", "envy-windows-runtime.py")

class CLI(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        expr = '''let f=builtins.getFlake ("path:"+builtins.getEnv "RYOKU_TEST_REPO");
          describe = c: { controller=c.system.build.windowsVmController;
            manifest=c.system.build.windowsVmManifest;
            systemctl="${f.nixosConfigurations.envy.pkgs.systemd}/bin/systemctl";
            podman="${c.virtualisation.podman.package}/bin/podman"; };
          l=f.nixosConfigurations.lenovo.config;
        in f.nixosConfigurations.envy.pkgs.writeText "windows-vm-cli-tests.json" (builtins.toJSON {
          envy=describe f.nixosConfigurations.envy.config;
          lenovo=describe l;
          vfio=describe l.specialisation.windows-vfio.configuration;
        })'''
        result = subprocess.check_output(
            ["nix", "build", "--impure", "--no-link", "--print-out-paths", "--expr", expr],
            env=dict(os.environ, RYOKU_TEST_REPO=str(ROOT)), text=True).strip()
        cls.inventory = json.loads(Path(result).read_text())

    def fixture(self, host):
        fixture = (ENVY if host == "envy" else LENOVO).Runtime(methodName="runTest")
        fixture.setUp()
        self.addCleanup(fixture.doCleanups)
        return fixture

    def command(self, fixture, host, action):
        info = self.inventory[host]
        ctl = fixture.root / "systemctl"
        ctl.write_text('#!/bin/sh\ncase "$*" in *show*) echo active ;; esac\nexit 0\n')
        ctl.chmod(0o755)
        manifest = fixture.root / "manifest.json"
        manifest.write_text(json.dumps(fixture.m))
        text = (Path(info["controller"]) / "bin/windows-vm").read_text()
        text = text.replace(info["systemctl"], str(ctl)).replace(info["podman"], str(fixture.engine))
        text = re.sub(r'--manifest /nix/store/[^\s]+', '--manifest '+str(manifest), text)
        cli = fixture.root / "windows-vm"
        cli.write_text(text)
        cli.chmod(0o755)
        return subprocess.run([str(cli), action], env=fixture.env, capture_output=True, text=True, timeout=5)

    def test_both_hosts_install_same_interface_and_envy_alias(self):
        for host, info in self.inventory.items():
            cli = Path(info["controller"]) / "bin/windows-vm"
            result = subprocess.run([str(cli), "--help"], capture_output=True, text=True, timeout=5)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("{start|stop|status|preflight|prepare-image}", result.stdout)
            manifest = json.loads(Path(info["manifest"]).read_text())
            self.assertEqual(manifest["container"], "envy-windows" if host == "envy" else "lenovo-windows" if host == "vfio" else "windows")
        base = Path(self.inventory["envy"]["controller"]) / "bin"
        self.assertTrue((base / "envy-windows").is_symlink())
        self.assertEqual((base / "envy-windows").resolve(), (base / "windows-vm").resolve())

    def test_lenovo_existing_legacy_lifecycle(self):
        f = self.fixture("lenovo")
        f.seed(legacy=True)
        for action in ("status", "start", "preflight"):
            result = self.command(f, "lenovo", action)
            self.assertEqual(result.returncode, 0, result.stderr)
        result = self.command(f, "lenovo", "stop")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(f.data()["containers"]["windows"]["State"]["Running"])
        self.assertTrue(f.disk.exists())
        f.no_destructive_calls()

    def test_lenovo_vfio_start_confirms_owned_guest(self):
        f = self.fixture("vfio")
        f.vfio()
        f.seed(legacy=True)
        result = self.command(f, "vfio", "start")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(json.loads(result.stdout)["running"])
        f.no_destructive_calls()

    def test_lenovo_prepare_image_uses_common_explicit_builder_without_guest_access(self):
        f = self.fixture("lenovo")
        f.envfile.unlink()
        fake = f.root / "build-engine"
        fake.write_text('#!/bin/sh\nprintf "%s\\n" "$@" >"$BUILD_ARGS"\n')
        fake.chmod(0o755)
        f.engine = fake
        f.env["BUILD_ARGS"] = str(f.root / "build-args")
        result = self.command(f, "lenovo", "prepare-image")
        self.assertEqual(result.returncode, 0, result.stderr)
        args = (f.root / "build-args").read_text().splitlines()
        self.assertEqual(args[:3], ["build", "--pull=never", "--tag"])
        self.assertRegex(args[3], r'^localhost/lenovo-windows-spice:[0-9a-f]{64}$')
        recipe = (Path(args[4]) / "Containerfile").read_text()
        self.assertIn("FROM docker.io/dockurr/windows@sha256:", recipe)
        self.assertNotIn(":latest", recipe)
        self.assertIn("COPY refuse-install.py", recipe)
        self.assertIn("RUN python3 /tmp/windows-vm-install-guard.py", recipe)
        self.assertTrue((Path(args[4]) / "refuse-install.py").is_file())
        self.assertFalse(f.data()["containers"])

if __name__ == "__main__":
    unittest.main()
