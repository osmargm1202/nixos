#!/usr/bin/env python3
"""Exercise PAM's keyring handoff on a private bus with disposable credentials."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]


def isolated_handoff(config):
    daemon = "/run/wrappers/bin/gnome-keyring-daemon"
    process = subprocess.Popen(
        [daemon, "--login", "--foreground"],
        stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
    )
    try:
        # A disposable login password, never a credential from the real session.
        process.stdin.write(b"disposable-keyring-test-password")
        process.stdin.close()
        control = Path(os.environ["XDG_RUNTIME_DIR"]) / "keyring/control"
        deadline = time.monotonic() + 10
        while not control.exists():
            assert process.poll() is None, "PAM-mode daemon exited before startup"
            assert time.monotonic() < deadline, "PAM-mode control socket did not appear"
            time.sleep(0.05)

        subprocess.run(["bash", "-e", "-c", config["startup"]], check=True, timeout=15)
        owner = subprocess.check_output([
            "busctl", "--user", "call", "org.freedesktop.DBus", "/org/freedesktop/DBus",
            "org.freedesktop.DBus", "GetConnectionUnixProcessID", "s", "org.freedesktop.secrets",
        ], text=True).strip()
        assert owner == f"u {process.pid}", "Secret Service replaced the PAM-unlocked daemon"
        locked = subprocess.check_output([
            "busctl", "--user", "get-property", "org.freedesktop.secrets",
            "/org/freedesktop/secrets/collection/login", "org.freedesktop.Secret.Collection", "Locked",
        ], text=True).strip()
        assert locked == "b false", "The login keyring lost PAM's unlock"
        # Reinitialization must reuse the same unlocked daemon as well.
        subprocess.run(["bash", "-e", "-c", config["startup"]], check=True, timeout=15)
        assert process.poll() is None, "Reinitialization terminated the login daemon"
    finally:
        process.terminate()
        process.wait(timeout=10)
        process.stderr.close()


class SwayKeyring(unittest.TestCase):
    def test_login_handoff(self):
        expression = '''
          let
            f = builtins.getFlake ("path:" + builtins.getEnv "SWAY_KEYRING_TEST_REPO");
            c = (f.lib.mkProfile {
              profileName = "sway";
              profile = f.outPath + "/nixos/profiles/sway/sway.nix";
            }).config;
          in {
            startup = c.programs.sway.extraSessionCommands;
            pam = f.inputs.nixpkgs.lib.genAttrs [ "sddm" "login" ]
              (name: c.security.pam.services.${name}.text);
            autologin = c.services.displayManager.autoLogin.enable;
          }
        '''
        config = json.loads(subprocess.check_output(
            ["nix", "eval", "--impure", "--json", "--expr", expression],
            env=dict(os.environ, SWAY_KEYRING_TEST_REPO=str(ROOT)), text=True,
        ))
        self.assertFalse(config["autologin"])

        def rules(service, phase):
            for line in config["pam"][service].splitlines():
                fields = line.split()
                if len(fields) < 3 or fields[0] != phase:
                    continue
                if fields[1] in {"include", "substack"}:
                    yield from rules(fields[2], phase)
                else:
                    yield fields[2:]

        self.assertTrue(any(r[0].endswith("/pam_gnome_keyring.so") for r in rules("sddm", "auth")))
        self.assertTrue(any(r[0].endswith("/pam_gnome_keyring.so") and "auto_start" in r
                            for r in rules("sddm", "session")))
        with tempfile.TemporaryDirectory(prefix="sway-keyring-test-") as temporary:
            base = Path(temporary)
            env = dict(os.environ)
            env.pop("GNOME_KEYRING_CONTROL", None)
            for name in ["HOME", "XDG_RUNTIME_DIR", "XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"]:
                folder = base / name.lower()
                folder.mkdir(mode=0o700)
                env[name] = str(folder)
            config_file = base / "config.json"
            config_file.write_text(json.dumps(config))
            subprocess.run([
                "dbus-run-session", "--", sys.executable, str(Path(__file__).resolve()),
                "--isolated", str(config_file),
            ], env=env, check=True, timeout=30)


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "--isolated":
        isolated_handoff(json.loads(Path(sys.argv[2]).read_text()))
    else:
        unittest.main()
