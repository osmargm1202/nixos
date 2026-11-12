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
        self.caffeine = self.root / '.local/state/waybar/caffeine'; self.caffeine.parent.mkdir(parents=True)
        self.caffeine.write_text('deactivated\n')
        self.gaming = self.root / '.local/state/hypr/game-mode'; self.gaming.parent.mkdir(parents=True)
        self.gaming.write_text('deactivated\n')
        self.clock_pid = self.root / 'clock-pid'
        self.clients = self.root / 'clients'; self.clients.write_text('[]')
        self.env = dict(os.environ, HOME=str(self.root), XDG_RUNTIME_DIR=str(self.root),
                        XDG_STATE_HOME=str(self.root / '.local/state'),
                        PATH=f'{self.bin}:{Path(sys.executable).parent}:/run/current-system/sw/bin', TEST_MEDIA=str(self.status), TEST_LOG=str(self.log), TEST_CLIENTS=str(self.clients), TEST_CLOCK_PID=str(self.clock_pid))
        for name, code in {
            'playerctl': 'cat "$TEST_MEDIA"',
            'hyprctl': 'cat "$TEST_CLIENTS"',
            'systemd-inhibit': 'echo inhibit >> "$TEST_LOG"; exec sleep 300',
            'systemctl': 'printf "systemctl %s\\n" "$*" >> "$TEST_LOG"',
            'orgm-qylock': 'printf "lock %s\\n" "$ORGM_QY_IDLE_CLOCK" >> "$TEST_LOG"',
            'qs': 'echo $$ > "$TEST_CLOCK_PID"; echo clock >> "$TEST_LOG"; exec sleep 300',
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

    def test_caffeine_clock_respects_media_and_video_inhibitors(self):
        self.call('show-caffeine')
        self.assertNotIn('clock', self.entries())
        self.caffeine.write_text('activated\n')
        self.clients.write_text('[{"mapped":true,"hidden":false,"inhibitingIdle":true}]')
        self.call('show-caffeine')
        self.assertNotIn('clock', self.entries())
        self.clients.write_text('[]')
        self.status.write_text('Playing\n')
        self.call('show-caffeine')
        self.assertNotIn('clock', self.entries())
        self.status.write_text('Paused\n')
        self.call('show-caffeine')
        self.wait(lambda: 'clock' in self.entries())

    def test_gaming_blocks_both_clock_listeners_and_restores_after_exit(self):
        self.gaming.write_text('activated\n')
        self.caffeine.write_text('activated\n')
        self.call('show')
        self.call('show-caffeine')
        self.assertNotIn('clock', self.entries())
        self.gaming.write_text('deactivated\n')
        self.call('show')
        self.wait(lambda: 'clock' in self.entries())
        self.call('hide')
        self.call('show-caffeine')
        self.wait(lambda: self.entries().count('clock') == 2)

    def test_entering_gaming_hides_an_existing_clock(self):
        self.call('show')
        self.wait(lambda: 'clock' in self.entries())
        pid = int(self.clock_pid.read_text())
        self.gaming.write_text('activated\n')
        self.wait(lambda: not Path(f'/proc/{pid}').exists())


if __name__ == '__main__':
    unittest.main()
