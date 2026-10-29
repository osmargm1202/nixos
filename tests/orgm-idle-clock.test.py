#!/usr/bin/env python3
"""Exercise idle coordination without touching the real compositor or services."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'dotfiles/config/hosts/orgm/shared/.local/bin/orgm-idle-clock'


class IdleTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / 'bin'; self.bin.mkdir()
        self.log = self.root / 'log'
        self.status = self.root / 'media'; self.status.write_text('Paused\n')
        self.env = dict(os.environ, HOME=str(self.root), XDG_RUNTIME_DIR=str(self.root),
                        PATH=f'{self.bin}:{Path(sys.executable).parent}:/run/current-system/sw/bin', TEST_MEDIA=str(self.status), TEST_LOG=str(self.log))
        for name, code in {
            'playerctl': 'cat "$TEST_MEDIA"',
            'systemd-inhibit': 'echo inhibit >> "$TEST_LOG"; exec sleep 300',
            'systemctl': 'printf "systemctl %s\\n" "$*" >> "$TEST_LOG"',
            'orgm-qylock': 'printf "lock %s\\n" "$ORGM_QY_IDLE_CLOCK" >> "$TEST_LOG"',
            'qs': 'echo clock >> "$TEST_LOG"; exec sleep 300',
        }.items():
            path = self.bin / name
            path.write_text('#!/usr/bin/env bash\n' + code + '\n'); path.chmod(0o755)
        self.daemon = subprocess.Popen([str(SCRIPT), 'daemon'], env=self.env)
        self.addCleanup(self.stop)
        self.wait(lambda: (self.root / 'orgm-idle-clock.sock').exists())

    def stop(self):
        self.daemon.terminate()
        self.daemon.wait(timeout=5)

    def wait(self, check):
        until = time.monotonic() + 6
        while time.monotonic() < until:
            if check(): return
            self.assertIsNone(self.daemon.poll())
            time.sleep(.05)
        self.fail('timed out')

    def call(self, command):
        subprocess.run([str(SCRIPT), command], env=self.env, check=True, timeout=5)

    def entries(self):
        return self.log.read_text().splitlines() if self.log.exists() else []

    def test_show_lock_and_media_inhibition(self):
        self.call('show')
        self.wait(lambda: 'clock' in self.entries())
        self.call('lock')
        self.assertIn('lock 1', self.entries())
        self.status.write_text('Paused\nPlaying\n')
        self.wait(lambda: 'inhibit' in self.entries())
        count = len(self.entries())
        self.call('show'); self.call('lock'); self.call('suspend')
        self.assertEqual(len(self.entries()), count)
        self.status.write_text('Paused\n')
        self.wait(lambda: 'systemctl --user restart orgm-hyprland-idle.service' in self.entries())
        self.call('show')
        self.wait(lambda: self.entries().count('clock') == 2)


if __name__ == '__main__':
    unittest.main()
