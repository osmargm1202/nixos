#!/usr/bin/env python3
"""Exercise the generated pre-start guard using dummy state, never real pairing."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent


class StateGuard(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        result = subprocess.run(['nix', 'eval', '--impure', '--json', '--file',
                                 'tests/envy-fingerprint.nix'], cwd=ROOT,
                                capture_output=True, text=True, check=True)
        cls.script = json.loads(result.stdout)['preStartScript']

    def exercise(self, mode, state_override=None):
        with tempfile.TemporaryDirectory() as directory:
            state = Path(directory)/'private-state'
            if mode != 'missing':
                pairing = state/'0-persistent/synatlsmoc'
                pairing.mkdir(parents=True)
                if mode in ('empty-file', 'valid'):
                    (pairing/'0').write_bytes(b'not-real-pairing' if mode == 'valid' else b'')
            # Replace only the fixed expected path with the test-owned directory.
            # The real /var/lib/fprint-synatudor-test is never inspected or touched.
            script = self.script.replace('/var/lib/fprint-synatudor-test', str(state))
            return subprocess.run(['bash', '-eu', '-c', script],
                                  env=os.environ | {'STATE_DIRECTORY': state_override or str(state)},
                                  capture_output=True, text=True)

    def test_missing_directory_blocks_daemon(self):
        result = self.exercise('missing')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('pairing missing', result.stderr)

    def test_empty_directory_blocks_daemon(self):
        self.assertNotEqual(self.exercise('empty-directory').returncode, 0)

    def test_empty_pairing_file_blocks_daemon(self):
        self.assertNotEqual(self.exercise('empty-file').returncode, 0)

    def test_saved_nonempty_pairing_allows_daemon_without_printing_data(self):
        result = self.exercise('valid')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('not-real-pairing', result.stdout + result.stderr)

    def test_unexpected_or_concatenated_state_directory_blocks_daemon(self):
        for value in ('/var/lib/fprint', '/var/lib/fprint:/var/lib/fprint-synatudor-test'):
            result = self.exercise('valid', value)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('unexpected state directory', result.stderr)


if __name__ == '__main__':
    unittest.main()
