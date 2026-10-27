#!/usr/bin/env python3
"""Real detached tmux save/restart/restore with fake agents and no API calls.

Usage: python3 tests/tmux-session.test.py /path/to/orgm-tmux-session
"""
import base64
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = Path(sys.argv[1]).resolve()
PORTABLE = (PACKAGE / 'lib/orgm-tmux/session.sh').is_file()
TMUX = shutil.which('tmux')
BASH = shutil.which('bash')
TOOLS = ['codex', 'codex', 'claude', 'pi', 'omp', 'opencode']
IDS = ['12345678-1234-1234-1234-123456789ab' + str(i) for i in range(5)] + ['ses_testSession123']


def wait_for(check):
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        if check():
            return
        time.sleep(0.05)
    raise AssertionError('condition timed out')


with tempfile.TemporaryDirectory(prefix='tmux-agents-') as directory:
    home = Path(directory) / 'home'
    runtime = Path(directory) / 'runtime'
    project = home / 'project with spaces'
    bin_dir = home / '.bun/bin' if PORTABLE else home / 'bin'
    for path in (runtime, project, bin_dir, home / '.config/tmux', home / '.claude/debug'):
        path.mkdir(parents=True, exist_ok=True)
    if PORTABLE:
        # Exercise the portable installation with its real upstream plugins.
        for relative in ('lib/orgm-tmux', 'share/orgm-dotfiles/tmux'):
            shutil.copytree(PACKAGE / relative, home / '.local' / relative, symlinks=True)
        (home / '.local/bin').mkdir(parents=True)
        for name in ('tmux-session', 'tmux-agent-resume', 'tmux-spanish-date'):
            shutil.copy2(PACKAGE / 'bin' / name, home / '.local/bin' / name)
        shutil.copy2(PACKAGE.parent / '.config/tmux/plugins.conf', home / '.config/tmux/plugins.conf')
    shutil.copy2(ROOT / 'dotfiles/config/programs/tmux/.config/tmux/persistence.conf',
                 home / '.config/tmux/persistence.conf')
    env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(home / '.config'),
               XDG_DATA_HOME=str(home / '.local/share'), XDG_STATE_HOME=str(home / '.local/state'),
               XDG_RUNTIME_DIR=str(runtime), TMUX=f'{directory}/socket,1,0',
               PATH=f'{bin_dir}:{PACKAGE}/bin:' + os.environ['PATH'])
    for key in ('TMUX_PANE', 'CODEX_HOME', 'CLAUDE_CONFIG_DIR'):
        env.pop(key, None)
    env['CODEX_HOME'] = str(home / '.codex')
    config = [
        'set -g base-index 1', 'set -g pane-base-index 1',
        'set -g default-shell ' + shlex.quote(BASH),
        'set -g default-command ' + shlex.quote(f'{BASH} --noprofile --norc -i'),
        'set -g @resurrect-save S', 'set -g @resurrect-restore R',
        'source-file ' + str(ROOT / 'dotfiles/config/programs/tmux/.config/tmux/persistence.conf'),
        'run-shell ' + shlex.quote(f'{PACKAGE}/bin/tmux-session plugins'),
    ]
    if PORTABLE:
        (home / '.tmux.conf').write_text((PACKAGE.parent / '.tmux.conf').read_text() +
                                       '\nset -g default-shell ' + shlex.quote(BASH) + '\n')
    else:
        (home / '.tmux.conf').write_text('\n'.join(config) + '\n')
    # A shell executable records resume argv verbatim, then holds a foreground
    # agent process. No real clients or network calls are made.
    python = shutil.which('python3')
    for tool in set(TOOLS):
        script = bin_dir / tool
        script.write_text(f'#!{python}\n' + '''import json,os,sys,time
from pathlib import Path
with (Path.home()/'resumes.jsonl').open('a') as f:
    f.write(json.dumps(dict(tool=Path(sys.argv[0]).name,args=sys.argv[1:],cwd=os.getcwd(),
      request=json.loads(os.environ.get('ORGM_TMUX_RESUME_REQUEST','null'))))+'\\n')
time.sleep(300)
''')
        script.chmod(0o755)

    def run(*args):
        result = subprocess.run(args, env=env, text=True, capture_output=True, timeout=30)
        run.last_stderr = result.stderr
        assert result.returncode == 0, (args, result.stdout, result.stderr)
        return result.stdout.strip()

    def tmux(*args):
        return run(TMUX, *args)

    def session(action):
        return run(str(PACKAGE / 'bin/tmux-session'), action)

    try:
        session('start')
        assert tmux('list-sessions', '-F', '#S') == 'main'
        assert tmux('show-option', '-gqv', '@continuum-restore') == 'off'
        first = tmux('list-panes', '-F', '#{pane_id}')
        for i, sid in enumerate(IDS):
            tool = TOOLS[i]
            if tool == 'codex':
                rollout = home / f'rollout-{sid}.jsonl'
                rollout.write_text(json.dumps(dict(type='session_meta', payload=dict(
                    id=sid, cwd=str(project), source='cli'))) + '\n')
            elif tool == 'claude':
                rollout = home / f'.claude/debug/{sid}.txt'
                rollout.write_text('')
            else:
                rollout = project / f'{sid}.jsonl'
                rollout.write_text(json.dumps(dict(type='session', id=sid, cwd=str(project))) + '\n')
            command = f'exec 3<{shlex.quote(str(rollout))}; exec -a {tool} {BASH} --noprofile --norc -i'
            if i == 0:
                tmux('respawn-pane', '-k', '-t', first, '-c', str(project), command)
                pane = first
            else:
                pane = tmux('new-window', '-d', '-P', '-F', '#{pane_id}', '-n', f'agent{i}', '-c', str(project), command)
            if tool in ('pi', 'omp', 'opencode'):
                pid = tmux('display-message', '-p', '-t', pane, '#{pane_pid}')
                wait_for(lambda: Path(f'/proc/{pid}/cmdline').read_bytes().split(b'\0')[0] == tool.encode())
                stat = Path(f'/proc/{pid}/stat').read_text().rsplit(')', 1)[1].split()
                proc_env = dict(os.fsdecode(v).split('=', 1) for v in
                                Path(f'/proc/{pid}/environ').read_bytes().split(b'\0') if b'=' in v)
                record = dict(pid=int(pid), start=stat[19], tool=tool, id=sid, cwd=str(project),
                              pane=pane, tmux=proc_env['TMUX'])
                if tool != 'opencode':
                    record['sessionFile'] = str(rollout)
                state = runtime / 'orgm-tmux-agents'
                state.mkdir(exist_ok=True)
                (state / f'{pid}.json').write_text(json.dumps(record))
        tmux('new-window', '-d', '-n', 'unknown', '-c', str(project),
             f'exec -a codex {BASH} --noprofile --norc -i')
        time.sleep(0.15)
        # Existing-server starts are idempotent and never restore over agents.
        session('start')
        assert len(tmux('list-panes', '-a').splitlines()) == 7, tmux('list-panes', '-a')
        assert tmux('list-clients') == ''
        for record_file in (runtime / 'orgm-tmux-agents').glob('*.json'):
            record = json.loads(record_file.read_text())
            pid = record['pid']
            current_env = dict(os.fsdecode(v).split('=', 1) for v in
                               Path(f'/proc/{pid}/environ').read_bytes().split(b'\0') if b'=' in v)
            assert record['tmux'] == current_env.get('TMUX'), (record, current_env.get('TMUX'))
            assert record['pane'] == current_env.get('TMUX_PANE'), (record, current_env.get('TMUX_PANE'))
        session('save')
        snapshot = home / '.tmux/resurrect/last'
        if not snapshot.exists():
            snapshot = home / '.local/share/tmux/resurrect/last'
        records = [line.split('\t') for line in snapshot.read_text().splitlines()
                   if line.startswith('pane\t')]
        saved = [json.loads(base64.urlsafe_b64decode(row[10].split()[-1]))
                 for row in records if row[9] == 'tmux-agent-resume']
        assert {record['id'] for record in saved} == set(IDS), (records, run.last_stderr)
        assert {record['cwd'] for record in saved} == {str(project)}
        assert [row for row in records if row[9] == 'bash'][0][10] == ':'
        tmux('kill-server')
        # Allow the old socket to disappear before simulating boot.
        wait_for(lambda: not (Path(directory) / 'socket').exists() or
                 subprocess.run([TMUX, 'list-sessions'], env=env, capture_output=True).returncode != 0)
        session('start')
        log = home / 'resumes.jsonl'
        wait_for(lambda: log.exists() and len(log.read_text().splitlines()) == 6)
        resumed = [json.loads(line) for line in log.read_text().splitlines()]
        assert {r['args'][1] for r in resumed} == {
            data.get('sessionFile', data['id']) for data in saved}, resumed
        assert {r['tool'] for r in resumed} == set(TOOLS)
        assert all((r['request']['prompt'] if r['tool'] == 'opencode' else r['args'][-1])
                   .startswith('La PC se reinició') for r in resumed), resumed
        assert all(r['cwd'] == str(project) for r in resumed), resumed
        assert len(tmux('list-panes', '-a').splitlines()) == 7
        session('start')
        time.sleep(0.1)
        assert len(log.read_text().splitlines()) == 6, 'duplicate agents after repeated start'
        print('PASS: detached save, six exact conversations, all five clients, unknown ID fallback, boot restore and idempotence')
    finally:
        result = subprocess.run([TMUX, 'list-panes', '-a', '-F', '#{pane_pid}'],
                                env=env, text=True, capture_output=True)
        pids = result.stdout.splitlines()
        subprocess.run([TMUX, 'kill-server'], env=env, capture_output=True)
        # Bash writes .bash_history as its pane exits; finish before removing HOME.
        wait_for(lambda: all(not Path(f'/proc/{pid}').exists() for pid in pids))
