#!/usr/bin/env python3
"""Exercise the actual pinned provider without a real compositor or display."""
import json
import os
from pathlib import Path
import re
import socket
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

class DisplayPower(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.provider = os.environ.get("RYOKU_DPMS_PROVIDER")
        if not cls.provider:
            expr = 'let f = builtins.getFlake ("path:" + builtins.getEnv "RYOKU_TEST_REPO"); in (import (builtins.getEnv "RYOKU_TEST_REPO" + "/nixos/profiles/ryoku/provider-compat.nix") { inputs=f.inputs; pkgs=f.nixosConfigurations.envy.pkgs; lib=f.inputs.nixpkgs.lib; }).packages.ryoku-wm-hyprland'
            package = subprocess.check_output(["nix", "build", "--impure", "--no-link", "--print-out-paths", "--expr", expr],
                env=dict(os.environ, RYOKU_TEST_REPO=str(ROOT)), text=True).strip()
            cls.provider = package + "/bin/ryoku-wm-hyprland"

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        root = Path(self.tmp.name)
        runtime = root / "hypr/offline-test"
        runtime.mkdir(parents=True)
        self.server = socket.socket(socket.AF_UNIX)
        self.addCleanup(self.server.close)
        self.server.bind(str(runtime / ".socket.sock"))
        self.server.listen(128)
        self.capture = root / "commands.jsonl"
        stub = root / "hyprctl"
        stub.write_text("#!" + sys.executable + "\nimport os,json,sys\nwith open(os.environ['DPMS_CAPTURE'],'a') as f: f.write(json.dumps(sys.argv[1:])+'\\n')\nprint('ok')\n")
        stub.chmod(0o755)
        self.env = dict(os.environ, PATH=str(root)+":"+os.environ["PATH"],
            DPMS_CAPTURE=str(self.capture), XDG_RUNTIME_DIR=str(root),
            HYPRLAND_INSTANCE_SIGNATURE="offline-test", WAYLAND_DISPLAY="", DISPLAY="")

    def act(self, *args):
        return subprocess.run([self.provider, "act", "output.power", *args],
            env=self.env, capture_output=True, text=True)

    def test_repeated_on_off_are_explicit_and_idempotent_with_optional_monitor(self):
        for monitor in ((), ("eDP-1",)):
            for state in ("on", "on", "off", "off"):
                result = self.act(state, *monitor)
                self.assertEqual(result.returncode, 0, result.stderr)
        commands = [json.loads(row) for row in self.capture.read_text().splitlines()]
        self.assertEqual(len(commands), 8)
        for i, argv in enumerate(commands):
            expected = ("on", "on", "off", "off")[i % 4]
            self.assertEqual(argv[0], "dispatch")
            self.assertIn('action = "' + expected + '"', argv[1])
            self.assertNotIn("state =", argv[1])
            if i >= 4:
                self.assertIn('monitor = "eDP-1"', argv[1])
            else:
                self.assertNotIn("monitor =", argv[1])
        # The real Lua API defaults to toggle only when action is absent.
        power, statuses = True, []
        for argv in commands:
            action = re.search(r'action = "(on|off)"', argv[1])
            power = (action.group(1) == "on") if action else not power
            statuses.append(power)
        self.assertEqual(statuses, [True, True, False, False] * 2)

    def test_invalid_state_never_dispatches(self):
        result = self.act("toggle")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("state must be on or off", result.stderr)
        self.assertFalse(self.capture.exists())

if __name__ == "__main__":
    unittest.main()
