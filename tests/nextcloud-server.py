#!/usr/bin/env python3
"""Exercise the sync wrapper without accessing Nextcloud or changing /etc."""

import fcntl
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[1] / "nixos/apps/nextcloud-server-sync.sh"


class ServerSyncTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.profile = self.root / "profile"
        self.profile.write_text("server\n")
        self.bin = self.root / "bin"
        self.bin.mkdir()
        (self.root / "Nextcloud").mkdir()
        (self.root / ".config/Nextcloud").mkdir(parents=True)
        (self.root / ".config/Nextcloud/sync-exclude.lst").write_text("*.tmp\n")
        self.script = self.root / "sync.sh"
        # Redirect only the machine's profile marker into the isolated fixture.
        self.script.write_text(
            "set -euo pipefail\n"
            + SOURCE.read_text().replace("/etc/orgm/desktop-profile", str(self.profile))
        )
        self.env = dict(
            os.environ,
            HOME=str(self.root),
            XDG_RUNTIME_DIR=str(self.root),
            PATH=str(self.bin) + os.pathsep + os.environ["PATH"],
            NC_URL="https://cloud.example.com",
            NC_USER="fixture-user",
            NC_PASSWORD="fixture-secret",
            TEST_PROFILE=str(self.profile),
            TEST_ARGS=str(self.root / "args"),
        )
        self.command("systemctl", 'exit "${MOCK_SERVICE:-1}"')
        self.command("pgrep", 'exit "${MOCK_GUI:-1}"')
        real_sleep = shlex.quote(shutil.which("sleep"))
        self.command("sleep", f"exec {real_sleep} 0.02")
        self.command(
            "nextcloudcmd",
            'printf "%s\\n" "$@" > "$TEST_ARGS"\n'
            'if [[ "${MOCK_SWITCH:-0}" == 1 ]]; then\n'
            '  printf "normal\\n" > "$TEST_PROFILE"\n'
            f"  exec {real_sleep} 30\n"
            "fi\n"
            f"{real_sleep} 0.03\n"
            'exit "${MOCK_RESULT:-0}"',
        )

    def command(self, name, body):
        path = self.bin / name
        path.write_text(f"#!{shutil.which('bash')}\n{body}\n")
        path.chmod(0o755)

    def run_sync(self, *args, **env):
        return subprocess.run(
            ["bash", str(self.script), *args],
            env=dict(self.env, **env),
            text=True,
            capture_output=True,
            timeout=5,
        )

    def test_only_server_profile_runs(self):
        for profile in ("normal", "windows", "battery", "gaming"):
            self.profile.write_text(profile + "\n")
            self.assertEqual(self.run_sync("--check").returncode, 1)
            self.assertEqual(self.run_sync().returncode, 0)
            self.assertFalse((self.root / "args").exists())

    def test_missing_profile_is_skipped(self):
        self.profile.unlink()
        self.assertEqual(self.run_sync("--check").returncode, 1)

    def test_graphical_service_and_direct_process_are_skipped(self):
        for env in ({"MOCK_SERVICE": "0"}, {"MOCK_GUI": "0"}):
            self.assertEqual(self.run_sync("--check", **env).returncode, 1)
            self.assertEqual(self.run_sync(**env).returncode, 0)
            self.assertFalse((self.root / "args").exists())

    def test_sync_uses_existing_folder_and_excludes_without_password_argument(self):
        result = self.run_sync()
        self.assertEqual(result.returncode, 0, result.stderr)
        args = (self.root / "args").read_text().splitlines()
        self.assertEqual(
            args,
            [
                "--non-interactive", "--silent", "--exclude",
                str(self.root / ".config/Nextcloud/sync-exclude.lst"),
                str(self.root / "Nextcloud"), "https://cloud.example.com",
            ],
        )
        self.assertNotIn(self.env["NC_PASSWORD"], " ".join(args))
        self.assertIn("completed successfully", result.stdout)

    def test_client_failure_is_reported(self):
        result = self.run_sync(MOCK_RESULT="42")
        self.assertEqual(result.returncode, 42, result.stderr)
        self.assertNotIn("completed successfully", result.stdout)

    def test_profile_switch_stops_only_own_worker(self):
        result = self.run_sync(MOCK_SWITCH="1")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Stopping server synchronization", result.stdout)
        self.assertNotIn("completed successfully", result.stdout)

    def test_lock_prevents_second_worker(self):
        with (self.root / "nextcloud-server.lock").open("w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            self.assertEqual(self.run_sync().returncode, 0)
            self.assertFalse((self.root / "args").exists())

    def test_missing_excludes_fails_without_starting_client(self):
        (self.root / ".config/Nextcloud/sync-exclude.lst").unlink()
        self.assertEqual(self.run_sync().returncode, 1)
        self.assertFalse((self.root / "args").exists())


if __name__ == "__main__":
    unittest.main()
