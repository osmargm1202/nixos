#!/usr/bin/env bash
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 - "$REPO_DIR/server/dotfiles/.bashrc" "$(command -v bash)" <<'PY'
import os
import pathlib
import pty
import subprocess
import sys
import tempfile

rc, bash = sys.argv[1:]
with tempfile.TemporaryDirectory(prefix="orgm-bash-banner-") as root:
    home = pathlib.Path(root)
    bin_dir = home / ".local/bin"
    bin_dir.mkdir(parents=True)
    neofetch = bin_dir / "neofetch"
    neofetch.write_text(f'#!{bash}\nprintf "NEOFETCH_BANNER\\n"\n')
    neofetch.chmod(0o755)
    (home / ".bashrc").write_text(pathlib.Path(rc).read_text())

    def run(*, tmux=False, tty=True, term="xterm-256color", interactive=True, manual=False):
        env = {"HOME": str(home), "PATH": str(bin_dir), "TERM": term}
        if tmux:
            env["TMUX"] = "/tmp/tmux-test/default,1,0"
        command = f'source "{rc}"; '
        if manual:
            command += 'neofetch; '
        command += 'printf "SHELL_OK\\n"'
        args = [bash, "--noprofile", "-ic" if interactive else "-c", command]
        if tty:
            master, slave = pty.openpty()
            proc = subprocess.Popen(args, env=env, stdin=slave, stdout=slave, stderr=slave)
            os.close(slave)
            output = bytearray()
            while True:
                try:
                    chunk = os.read(master, 4096)
                except OSError:
                    break
                if not chunk:
                    break
                output.extend(chunk)
            os.close(master)
            assert proc.wait(timeout=10) == 0, output.decode(errors="replace")
            result = output.decode(errors="replace")
        else:
            proc = subprocess.run(args, env=env, capture_output=True, text=True, timeout=10)
            assert proc.returncode == 0, proc.stderr
            result = proc.stdout
        assert "SHELL_OK" in result, result
        return result.count("NEOFETCH_BANNER")

    # Automatic .bashrc loading plus explicit reload must show only one banner.
    assert run() == 1, "interactive terminal should show one banner, including reload"
    assert run(tmux=True) == 0, "tmux panes must not show an automatic banner"
    assert run(tmux=True, manual=True) == 1, "manual neofetch must remain available in tmux"
    assert run(tty=False) == 0, "redirected output must remain banner-free"
    assert run(term="dumb") == 0, "dumb terminals must remain banner-free"
    assert run(interactive=False) == 0, "scripts must remain banner-free"
print("PASS: Bash banner outside tmux, suppression inside tmux, manual command, reload and noninteractive output")
PY
