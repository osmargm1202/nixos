#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 - "$ROOT/dotfiles/config/shared/.local/bin/codex" <<'PY'
import os
import pathlib
import pty
import subprocess
import sys
import tempfile

wrapper = pathlib.Path(sys.argv[1])
with tempfile.TemporaryDirectory(prefix="codex-stdin-") as directory:
    root = pathlib.Path(directory)
    launcher = root / "launcher"
    consumer = root / "consumer"
    launcher.mkdir()
    consumer.mkdir()
    (launcher / "codex").symlink_to(wrapper)
    executable = consumer / "codex"
    executable.write_text('''#!/usr/bin/env bash
set -euo pipefail
if [[ $EXPECT_TTY == 1 ]]; then
  [[ -t 0 && -t 1 && -t 2 ]] || exit 41
else
  [[ ! -t 0 ]] || exit 42
fi
IFS= read -r payload
[[ $payload == 'input from caller' ]] || exit 43
''')
    executable.chmod(0o755)
    environment = dict(os.environ, PATH=f"{launcher}:{consumer}:{os.environ['PATH']}")
    environment["EXPECT_TTY"] = "0"
    result = subprocess.run([str(launcher / "codex")], input=b"input from caller\n",
                            env=environment, capture_output=True, timeout=5)
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
print("PASS: Codex wrapper preserves terminal and piped stdin for its consumer")
PY
