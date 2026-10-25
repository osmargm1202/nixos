#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 - "$ROOT/dotfiles/config/users/osmarg/programs/ai/.local/bin/codex" "$ROOT/dotfiles/config/programs/shell/.config/bash/config.bash" <<'PY'
import os
import pathlib
import pty
import shlex
import subprocess
import sys
import tempfile

wrapper = pathlib.Path(sys.argv[1])
bash_config = pathlib.Path(sys.argv[2])
with tempfile.TemporaryDirectory(prefix="codex-stdin-") as directory:
    root = pathlib.Path(directory)
    home = root / "home"
    launcher = home / ".local/bin"
    consumer = root / "consumer"
    launcher.mkdir(parents=True)
    consumer.mkdir()
    (launcher / "codex").symlink_to(wrapper)
    executable = consumer / "codex"
    executable.write_text('''#!/usr/bin/env bash
set -euo pipefail
[[ $1 == --dangerously-bypass-approvals-and-sandbox ]] || exit 40
shift
if [[ ${EXPECT_PROMPT:-0} == 1 ]]; then
  [[ $# == 1 && $1 == 'prompt with spaces' ]] || exit 44
fi
if [[ $EXPECT_TTY == 1 ]]; then
  [[ -t 0 && -t 1 && -t 2 ]] || exit 41
else
  [[ ! -t 0 ]] || exit 42
fi
IFS= read -r payload
[[ $payload == 'input from caller' ]] || exit 43
''')
    executable.chmod(0o755)
    fnm = consumer / "fnm"
    fnm.write_text("#!/usr/bin/env bash\nprintf '%s\\n' " +
                   shlex.quote(f'export PATH="{consumer}:$PATH"') + "\n")
    fnm.chmod(0o755)
    environment = dict(os.environ, PATH=f"{launcher}:{consumer}:{os.environ['PATH']}")
    environment["EXPECT_TTY"] = "0"
    result = subprocess.run([str(launcher / "codex")], input=b"input from caller\n",
                            env=environment, capture_output=True, timeout=5)
    assert result.returncode == 0, (result.returncode, result.stderr)

    # fnm prepends its Node bin directory, which may also contain npm's Codex.
    shell_environment = dict(environment, HOME=str(home), XDG_CONFIG_HOME=str(home / ".config"),
                             TERM="dumb", CODEX_BASH_CONFIG=str(bash_config), EXPECT_PROMPT="1")
    result = subprocess.run(['bash', '--noprofile', '--norc', '-ic',
                             'source "$CODEX_BASH_CONFIG"; codex "prompt with spaces"'],
                            input=b"input from caller\n", env=shell_environment,
                            capture_output=True, timeout=5)
    assert result.returncode == 0, (result.returncode, result.stderr)

    master, slave = pty.openpty()
    try:
        environment["EXPECT_TTY"] = "1"
        process = subprocess.Popen([str(launcher / "codex")], stdin=slave,
                                   stdout=slave, stderr=slave, env=environment)
        try:
            os.write(master, b"input from caller\n")
            assert process.wait(timeout=5) == 0, "consumer lost the terminal or its input"
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()
    finally:
        os.close(slave)
        os.close(master)
print("PASS: Codex receives bypass permissions after fnm initialization and preserves arguments, terminal and piped stdin")
PY
