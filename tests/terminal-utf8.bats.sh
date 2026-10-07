#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 - "$ROOT" <<'PYTEST'
import os
import pathlib
import pty
import select
import shutil
import subprocess
import sys
import tempfile
import time

root = pathlib.Path(sys.argv[1])
tmux = shutil.which('tmux')
assert tmux, 'tmux is required to verify real client UTF-8'
bash = shutil.which('bash')
with tempfile.TemporaryDirectory(prefix='orgm-tmux-utf8-') as directory:
    home = pathlib.Path(directory)
    socket = home/'test.socket'
    master, slave = pty.openpty()
    env = os.environ.copy()
    env.update(HOME=str(home), XDG_CONFIG_HOME=str(home/'.config'),
               XDG_CACHE_HOME=str(home/'.cache'), TERM='xterm-256color', LC_ALL='C')
    env.pop('TMUX', None)
    env.pop('BASH_ENV', None)
    # This socket is private to the test; existing servers/programs are untouched.
    command = 'source "$1"; tmux -S "$2" -f /dev/null new-session -s utf8 "$3"'
    pane_command = "printf 'Prueba: áéíóú ñ Ñ ü ¿¡ ✓\\n'; exec bash --noprofile --norc"
    client = subprocess.Popen([bash, '--noprofile', '--norc', '-c', command, '_',
                               str(root/'server/dotfiles/.config/bash/terminal.bash'),
                               str(socket), pane_command], env=env,
                              stdin=slave, stdout=slave, stderr=slave)
    os.close(slave)
    output = bytearray()
    try:
        deadline = time.monotonic()+10
        while time.monotonic() < deadline:
            if select.select([master], [], [], .1)[0]:
                output.extend(os.read(master, 65536))
            clients = subprocess.run([tmux, '-S', str(socket), 'list-clients',
                                      '-F', '#{client_utf8}'], env=env,
                                     capture_output=True, text=True)
            if clients.stdout.strip() == '1' and 'áéíóú ñ Ñ ü ¿¡ ✓'.encode() in output:
                break
        else:
            raise AssertionError((clients.stdout, bytes(output)))
        assert client.poll() is None, 'client must remain connected after rendering accents'
    finally:
        subprocess.run([tmux, '-S', str(socket), 'kill-server'], env=env,
                       capture_output=True)
        client.wait(timeout=5)
        os.close(master)
print('PASS: real tmux client forces UTF-8 and renders accents with LC_ALL=C')
PYTEST
