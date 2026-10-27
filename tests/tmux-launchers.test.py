#!/usr/bin/env python3
"""Exercise the real launchers and helper without contacting a model provider."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = Path(sys.argv[1]).resolve()
with tempfile.TemporaryDirectory(prefix='tmux-launchers-') as directory:
    home = Path(directory)
    launchers = home / '.local/bin'
    native = home / 'native'
    runtime = home / 'runtime'
    for path in (launchers, native, runtime):
        path.mkdir(parents=True)
    env = dict(os.environ, HOME=str(home), XDG_RUNTIME_DIR=str(runtime),
               PATH=f'{launchers}:{native}:{PACKAGE}/bin:' + os.environ['PATH'])
    for key in ('TMUX', 'TMUX_PANE', 'OPENCODE_TUI_CONFIG', 'ORGM_TMUX_ORIGINAL_TUI_CONFIG'):
        env.pop(key, None)
    for tool in ('pi', 'omp', 'opencode'):
        (launchers / tool).symlink_to(ROOT / 'dotfiles/config/programs/ai/.local/bin' / tool)
        client = native / tool
        client.write_text(f'#!{sys.executable}\n' + '''import json,os,sys
print(json.dumps(dict(args=sys.argv[1:],stdin=sys.stdin.read(),
  tool=os.getenv('ORGM_TMUX_AGENT_TOOL'),config=os.getenv('OPENCODE_TUI_CONFIG'),
  assets=os.getenv('PI_PACKAGE_DIR'))))
''')
        client.chmod(0o755)
        for inside in (False, True):
            current = dict(env)
            if inside:
                current.update(TMUX='/tmp/test/socket,1,0', TMUX_PANE='%1')
            args = ['--model', 'provider/model', 'prompt with spaces']
            result = subprocess.run([str(launchers / tool), *args], input='caller stdin\nsecond line\n',
                                    env=current, text=True, capture_output=True, timeout=10)
            assert result.returncode == 0, (tool, inside, result.stderr)
            record = json.loads(result.stdout)
            assert record['stdin'] == 'caller stdin\nsecond line\n', record
            if inside and tool in ('pi', 'omp'):
                assert record['args'][0] == '--extension', record
                assert Path(record['args'][1]).name == 'pi-session.mjs', record
                assert record['args'][2:] == args, record
                assert record['tool'] == tool, record
            else:
                assert record['args'] == args, record
            if inside and tool == 'opencode':
                config = json.loads(Path(record['config']).read_text())
                assert config['plugin'][-1].endswith('/opencode-session.mjs'), config
    package_dir = home / 'OMP package'
    (package_dir / 'dist').mkdir(parents=True)
    native_omp = native / 'omp'
    entrypoint = package_dir / 'dist/cli.js'
    entrypoint.write_bytes(native_omp.read_bytes())
    entrypoint.chmod(0o755)
    (package_dir / 'package.json').write_text('{}')
    native_omp.unlink()
    native_omp.symlink_to(entrypoint)
    omp_env = dict(env)
    omp_env.pop('PI_PACKAGE_DIR', None)
    result = subprocess.run([str(launchers / 'omp'), 'asset test'], input='stdin\n',
                            env=omp_env, text=True, capture_output=True, timeout=10)
    assert result.returncode == 0, result.stderr
    assert json.loads(result.stdout)['assets'] == str(package_dir), result.stdout

    fnm = native / 'fnm'
    fnm.write_text('#!/usr/bin/env bash\nprintf \'export PATH="%s:$PATH"\\n\' "$FNM_NATIVE_PATH"\n')
    fnm.chmod(0o755)
    result = subprocess.run([shutil.which('bash'), '--noprofile', '--norc', '-ic',
                             'source "$TERMINAL_CONFIG"; type -P pi'],
                            env=dict(env, FNM_NATIVE_PATH=str(native),
                                     TERMINAL_CONFIG=str(ROOT / 'server/dotfiles/.config/bash/terminal.bash')),
                            text=True, capture_output=True, timeout=10)
    assert result.returncode == 0 and result.stdout.strip() == str(launchers / 'pi'), result.stderr + result.stdout
    print('PASS: launchers preserve stdin, arguments, OMP assets and priority after fnm; recording stays inside tmux')
