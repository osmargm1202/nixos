#!/usr/bin/env bash
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 - "$REPO_DIR" "$(command -v bash)" <<'PY'
import json
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile

repo, bash = pathlib.Path(sys.argv[1]), sys.argv[2]
with tempfile.TemporaryDirectory(prefix='orgm-server-terminal-') as root:
    home = pathlib.Path(root) / 'home'
    subprocess.run([bash, str(repo/'server/install.sh'), '--source', str(repo),
                    '--home', str(home), '--no-plugins'], check=True, capture_output=True)
    mock = pathlib.Path(root) / 'mock'
    mock.mkdir()
    record = pathlib.Path(root) / 'record.json'
    python = sys.executable
    def executable(name, body):
        path = mock / name
        path.write_text(f'#!{python}\n' + body)
        path.chmod(0o755)
        return path
    recorder = ('import json, os, pathlib, sys\n'
                'pathlib.Path(os.environ["RECORD"]).write_text(json.dumps({'
                '"args": sys.argv[1:], "stdin": sys.stdin.read(), '
                '"prefix": os.environ.get("NPM_CONFIG_PREFIX"), '
                '"bun": os.environ.get("BUN_INSTALL"), '
                '"assets": os.environ.get("PI_PACKAGE_DIR")}))\n')
    for name in ('codex', 'claude', 'omp', 'bun', 'npm'):
        executable(name, recorder)
    env = os.environ.copy()
    coreutils_bin = str(pathlib.Path(shutil.which('readlink')).resolve().parent)
    bash_bin = str(pathlib.Path(bash).resolve().parent)
    env.update(HOME=str(home), TERM='dumb', PATH=f'{mock}:{coreutils_bin}:{bash_bin}', RECORD=str(record))
    for variable in ('BUN_INSTALL', 'NPM_CONFIG_PREFIX', 'PNPM_HOME', 'PI_PACKAGE_DIR',
                     '__ORGM_SERVER_BASHRC_SOURCED', 'BASH_ENV'):
        env.pop(variable, None)
    def shell(command, input='stdin remains attached\n'):
        result = subprocess.run([bash, '--noprofile', '--norc', '-ic',
                                 'source "$HOME/.bashrc"; ' + command],
                                env=env, input=input, capture_output=True, text=True, timeout=15)
        assert result.returncode == 0, result.stdout + result.stderr
        return result
    for command, expected in (
        ('codex "prompt with spaces"', ['--dangerously-bypass-approvals-and-sandbox', 'prompt with spaces']),
        ('codex resume --last', ['--dangerously-bypass-approvals-and-sandbox', 'resume', '--last']),
        ('claude "prompt with spaces"', ['--dangerously-skip-permissions', 'prompt with spaces']),
        ('codex login --device-auth', ['login', '--device-auth']),
        ('codex remote-control pair', ['remote-control', 'pair']),
        ('claude remote-control', ['remote-control']),
        ('command codex "normal permissions"', ['normal permissions']),
        ('omp "prompt with spaces"', ['prompt with spaces']),
    ):
        shell(command)
        logged = json.loads(record.read_text())
        assert logged['args'] == expected, (command, logged)
        assert logged['stdin'] == 'stdin remains attached\n', (command, logged)

    for name, package in (('codex', '@openai/codex'), ('claude', '@anthropic-ai/claude-code'),
                          ('omp', '@oh-my-pi/pi-coding-agent')):
        for operation in ('install', 'update'):
            shell(f'{name}-{operation} --verbose')
            logged = json.loads(record.read_text())
            assert logged['args'] == ['add', '-g', package+'@latest', '--verbose'], logged
            assert logged['bun'] == str(home / '.bun'), logged
    (mock/'bun').unlink()
    shell('codex-install --verbose')
    logged = json.loads(record.read_text())
    assert logged['args'] == ['install', '-g', '@openai/codex@latest', '--verbose'], logged
    assert logged['prefix'] == str(home / '.npm-global'), logged
    result = subprocess.run([str(home/'.local/bin/omp-install')], env=env,
                            capture_output=True, text=True, timeout=10)
    assert result.returncode != 0 and 'bun-install' in result.stderr, result

    executable('curl', 'import pathlib, sys\n'
               'path = pathlib.Path(sys.argv[sys.argv.index("--output") + 1])\n'
               'path.write_text(\'printf "%s\\\\n" "$@" > "$RECORD"\\n\')\n')
    shell('claude-install stable')
    assert record.read_text() == 'stable\n', 'native Claude fallback must forward installer arguments'
    record.unlink()
    executable('curl', 'import sys\nsys.exit(17)\n')
    result = subprocess.run([str(home/'.local/bin/claude-install')], env=env,
                            capture_output=True, text=True, timeout=10)
    assert result.returncode != 0 and not record.exists(), 'failed download must not execute an installer'

    # Package symlinks must resolve assets while retaining the caller's stdin.
    package_dir = pathlib.Path(root) / 'omp package'
    (package_dir/'dist').mkdir(parents=True)
    launcher = package_dir/'dist/cli.js'
    launcher.write_text(f'#!{python}\n' + recorder)
    launcher.chmod(0o755)
    (mock/'omp').unlink()
    (mock/'omp').symlink_to(launcher)
    shell('omp "asset test"')
    logged = json.loads(record.read_text())
    assert logged['assets'] == str(package_dir) and logged['stdin'] == 'stdin remains attached\n', logged

    # Exercise real shell functions: inherited PATH must not gain duplicates.
    result = shell('first=$PATH; unset __ORGM_SERVER_BASHRC_SOURCED; source "$HOME/.bashrc"; '
                   '[[ $first == "$PATH" ]]')
    sample = home / 'sample with spaces.txt'
    sample.write_text('portable preview\n')
    result = subprocess.run([str(home/'.local/bin/switch-preview'), str(sample)],
                            env=env, capture_output=True, text=True, timeout=10)
    assert result.returncode == 0 and 'portable preview' in result.stdout, result
    result = shell('mkdir -p "$HOME/one/two"; cd "$HOME/one/two"; back-op; '
                   '[[ $PWD == "$HOME/one" ]]')
    result = subprocess.run([bash, '--noprofile', '--norc', '-c',
                             'source "$HOME/.bashrc"; declare -F codex'], env=env,
                            capture_output=True, text=True, timeout=10)
    assert result.returncode != 0 and not result.stdout, 'noninteractive shells must remain untouched'
print('PASS: portable AI launchers, stdin, permissions, installer dispatch, user prefixes, PATH and previews')
PY
