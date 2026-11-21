#!/usr/bin/env python3
"""Exercise the installed SSH launcher in a C locale and a real isolated tmux."""
import json
import os
from pathlib import Path
import pty
import shutil
import subprocess
import tempfile
import time
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[1]


class LauncherTest(unittest.TestCase):
    def test_installer_and_noninteractive_arguments(self):
        with tempfile.TemporaryDirectory(prefix='tmux-utf8-') as directory:
            home = Path(directory) / 'home'
            subprocess.run(['bash', str(ROOT / 'server/install.sh'), '--source', str(ROOT),
                            '--home', str(home), '--tmux-only', '--no-plugins'],
                           check=True, capture_output=True)
            launcher = home / '.local/bin/tmux'
            self.assertTrue(os.access(launcher, os.X_OK))
            mock = Path(directory) / 'mock'
            mock.mkdir()
            binary = mock / 'tmux'
            binary.write_text('#!/usr/bin/python3\nimport json,sys\n'
                              'print(json.dumps([sys.argv[1:],sys.stdin.read()]))\n')
            binary.chmod(0o755)
            env = dict(os.environ, HOME=str(home), LC_ALL='C',
                       PATH=f'{launcher.parent}:{launcher.parent}:{mock}:/usr/bin:/bin')
            for arguments in [['attach', '-t', 'sesión con espacios'],
                              ['-u', 'attach', '-t', 'sesión con espacios']]:
                result = subprocess.run([str(launcher), *arguments], env=env,
                                        input='entrada intacta', capture_output=True,
                                        text=True, encoding='utf-8', check=True)
                self.assertEqual(json.loads(result.stdout),
                                 [['-u', 'attach', '-t', 'sesión con espacios'], 'entrada intacta'])

    @unittest.skipUnless(shutil.which('tmux'), 'tmux not installed')
    def test_real_client_without_utf8_locale(self):
        binary = shutil.which('tmux')
        with tempfile.TemporaryDirectory(prefix='tmux-pty-') as directory:
            home = Path(directory)
            launcher = home / 'bin/tmux'
            launcher.parent.mkdir()
            shutil.copy2(ROOT / 'server/dotfiles/.local/bin/tmux', launcher)
            launcher.chmod(0o755)
            env = dict(os.environ, HOME=str(home), LC_ALL='C', TERM='xterm-256color',
                       PATH=f'{launcher.parent}:/usr/bin:/bin')
            env.pop('TMUX', None)
            label = 'utf8-test-' + uuid.uuid4().hex
            text = 'áéíóú ñ ¿ ¡'
            pid, master = pty.fork()
            if pid == 0:
                os.execve(str(launcher), [str(launcher), '-L', label, '-f', '/dev/null',
                                         'new-session', '-s', 'accents',
                                         f"printf '%s' '{text}'; sleep 30"], env)
            try:
                deadline = time.monotonic() + 5
                while time.monotonic() < deadline:
                    clients = subprocess.run([binary, '-L', label, 'list-clients', '-F',
                                              '#{client_utf8}'], env=env,
                                             capture_output=True, text=True)
                    if clients.stdout.strip() == '1':
                        break
                    time.sleep(0.1)
                self.assertEqual(clients.stdout.strip(), '1', clients.stderr)
                pane = subprocess.check_output([binary, '-L', label, 'capture-pane',
                                                '-p', '-t', 'accents'], env=env).decode('utf-8')
                self.assertIn(text, pane)
            finally:
                subprocess.run([binary, '-L', label, 'kill-server'], env=env,
                               capture_output=True)
                os.close(master)
                os.waitpid(pid, 0)


if __name__ == '__main__':
    unittest.main()
