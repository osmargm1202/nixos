#!/usr/bin/env python3
"""Exercise the in-image no-install branch with a harmless shell fixture."""
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("install_guard", ROOT / "nixos/containers/windows/refuse-install.py")
GUARD = importlib.util.module_from_spec(spec)
spec.loader.exec_module(GUARD)

SOURCE = '''#!/bin/bash
set -euo pipefail
error() { printf '%s\\n' "$*" >&2; }
needsInstall() { return "${NEEDS_INSTALL:-0}"; }
startInstall() { touch "$MUTATION"; }
bootWindows() { printf 'boot-existing\\n'; }
startWindows() {
  if needsInstall; then

    startInstall || exit $?
  else
    bootWindows || exit $?
    return 0
  fi
}
startWindows
'''

class Guard(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.script = self.root / "install.sh"
        self.script.write_text(SOURCE)

    def run_script(self, needs_install):
        return subprocess.run(["bash", str(self.script)], capture_output=True, text=True,
                              env=dict(os.environ, NEEDS_INSTALL=str(needs_install), MUTATION=str(self.root / "mutation")))

    def test_fixture_would_install_without_guard(self):
        self.assertEqual(self.run_script(0).returncode, 0)
        self.assertTrue((self.root / "mutation").exists())

    def test_guard_blocks_before_installation_or_cleanup(self):
        GUARD.patch_install(self.script)
        result = self.run_script(0)
        self.assertEqual(result.returncode, 78)
        self.assertIn("installation/reinstallation is disabled", result.stderr)
        self.assertFalse((self.root / "mutation").exists())

    def test_completed_existing_installation_still_boots(self):
        GUARD.patch_install(self.script)
        result = self.run_script(1)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "boot-existing")
        self.assertFalse((self.root / "mutation").exists())

    def test_unknown_upstream_source_is_not_patched(self):
        source = SOURCE.replace("if needsInstall; then", "if changedUpstream; then")
        self.script.write_text(source)
        with self.assertRaises(RuntimeError):
            GUARD.patch_install(self.script)
        self.assertEqual(self.script.read_text(), source)

if __name__ == "__main__":
    unittest.main()
