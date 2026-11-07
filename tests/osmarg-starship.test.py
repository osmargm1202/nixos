#!/usr/bin/env python3
"""Render the selected Bash prompt in a private PTY, not `starship prompt`."""
import json
import os
from pathlib import Path
import re
import select
import shutil
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
# Source already present from the locked Ryoku input. No downloads/builds here.
RYOKU = Path('/nix/store/rrdyj3sb0iyvw69dm9942d5cxnz4xh9w-source')


class Prompt(unittest.TestCase):
    def test_selected_mythos_prompt(self):
        for profile in ('gnome', 'hyprland', 'ryoku'):
            with self.subTest(profile=profile), tempfile.TemporaryDirectory(prefix='osmarg-prompt-', dir='/tmp') as tmp:
                base = Path(tmp)
                home, repo = base / 'home', base / 'repo'
                home.mkdir()
                # orgm-dot locks its checkout as well as HOME: never use ROOT live.
                shutil.copytree(ROOT / 'dotfiles/apps', repo / 'dotfiles/apps')
                shutil.copytree(ROOT / 'dotfiles/config', repo / 'dotfiles/config', symlinks=True)
                context = base / 'context.json'
                context.write_text(json.dumps(dict(repository=str(repo), user='osmarg',
                    host='orgm', profile=profile, programs=['shell'])))
                env = dict(os.environ, HOME=str(home), USER='osmarg',
                    XDG_CONFIG_HOME=str(home / '.config'), XDG_CACHE_HOME=str(home / '.cache'),
                    XDG_STATE_HOME=str(home / '.state'), XDG_DATA_HOME=str(home / '.data'),
                    XDG_RUNTIME_DIR=str(home / '.runtime'), HISTFILE=str(home / 'history'),
                    _ZO_DATA_DIR=str(home / 'zoxide'), ATUIN_CONFIG_DIR=str(home / '.config/atuin'),
                    TERM='xterm-256color')
                for key in list(env):
                    if key.startswith(('BLE_', '_ble_', '__ORGM', '__RYOKU', '__DOTFILES',
                                       '__ETC_BASHRC', 'STARSHIP_')):
                        env.pop(key, None)
                for name in ('.cache', '.runtime'):
                    (home / name).mkdir(mode=0o700)
                if profile == 'ryoku':
                    self.assertTrue((RYOKU / 'ryoku/apps/bash/ryoku.bash').is_file(),
                                    'locked Ryoku source required; never silently skip native startup')
                    native = base / 'native'
                    shutil.copytree(RYOKU / 'ryoku/apps/bash', native / 'ryoku/apps/bash')
                    for path in native.rglob('*'):
                        path.chmod(0o755 if path.is_dir() else 0o644)
                    patch = subprocess.run(['patch', '-p1', '-i', str(ROOT / 'nixos/profiles/ryoku/bash-zoxide-order.patch')],
                        cwd=native, capture_output=True, text=True)
                    self.assertEqual(patch.returncode, 0, patch.stdout + patch.stderr)
                    cfg = home / '.config'
                    (cfg / 'bash').mkdir(parents=True)
                    shutil.copy(native / 'ryoku/apps/bash/ryoku.bash', cfg / 'bash/ryoku.bash')
                    shutil.copy(RYOKU / 'ryoku/apps/bash/rashin.bash', cfg / 'bash/rashin.bash')
                    (cfg / 'ryoku-terminal').mkdir()
                    shutil.copy(RYOKU / 'ryoku/apps/terminal-shell/env.sh', cfg / 'ryoku-terminal/env.sh')
                for app in ('bash', 'starship'):
                    pulled = subprocess.run(['orgm-dot', '--context', str(context), '--home', str(home),
                        'pull', app], env=env, capture_output=True, text=True)
                    self.assertEqual(pulled.returncode, 0, pulled.stdout + pulled.stderr)
                self.assertEqual((home / '.config/starship.toml').read_bytes(),
                                 (ROOT / 'dotfiles/config/programs/shell/.config/starship.toml').read_bytes())
                (home / 'prompt-proof').mkdir()
                # Each newline returns to the REPL. Inspect the prompt AFTER cd,
                # bounded by non-echoed control-byte markers, not command output.
                with subprocess.Popen(['script', '-q', '-e', '-c', 'bash --noprofile -i', '/dev/null'],
                        cwd=home, env=env, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                        stderr=subprocess.STDOUT) as terminal:
                    output = bytearray()

                    def receive(token, start=0):
                        deadline = time.monotonic() + 45
                        while token not in output[start:]:
                            self.assertLess(time.monotonic(), deadline, repr(bytes(output[-4000:])))
                            if select.select([terminal.stdout], [], [], 0.2)[0]:
                                chunk = os.read(terminal.stdout.fileno(), 65536)
                                self.assertTrue(chunk, repr(bytes(output[-4000:])))
                                output.extend(chunk)

                    try:
                        receive('λ'.encode())
                        output.clear()
                        terminal.stdin.write(b'builtin cd "$HOME/prompt-proof"; printf "\\036BEGIN\\037"\n')
                        terminal.stdin.flush()
                        receive(b'\x1eBEGIN\x1f')
                        # Do not feed all lines then EOF: Blesh consumes that as
                        # terminal input rather than a sequence of REPL commands.
                        receive('λ'.encode(), output.index(b'\x1eBEGIN\x1f') + len(b'\x1eBEGIN\x1f'))
                        rendered = output.decode(errors='replace').split('\x1eBEGIN\x1f', 1)[1]
                        output.clear()
                        terminal.stdin.write(b'printf "%s" "${STARSHIP_CONFIG:-unset}" > "$HOME/effective-config"; printf "\\036END\\037"\n')
                        terminal.stdin.flush()
                        receive(b'\x1eEND\x1f')
                        terminal.stdin.write(b'exit 0\n')
                        terminal.stdin.flush()
                        terminal.communicate(timeout=45)
                        self.assertEqual(terminal.returncode, 0)
                    finally:
                        if terminal.poll() is None:
                            terminal.terminate()
                            terminal.wait(timeout=5)
                plain = re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]', '', rendered)
                for expected in ('λ', '', '', '󰉋', 'prompt-proof'):
                    self.assertIn(expected, plain, (profile, repr(rendered[-4000:])))
                for color in ('38;2;236;167;91', '48;2;35;37;46'):
                    self.assertIn(color, rendered, (profile, repr(rendered[-4000:])))
                self.assertEqual((home / 'effective-config').read_text(), 'unset')
                print(f'PASS: {profile}: real post-command Mythos lambda, directory pills, gold/slate; default config')


if __name__ == '__main__':
    unittest.main()
