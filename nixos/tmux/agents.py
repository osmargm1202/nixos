"""Replace agent commands in resurrect snapshots with exact conversation resumes.

Never infer an ID from the newest conversation in a directory: several panes
can be working in that directory. Process identity also invalidates stale binds.
"""
import argparse
import base64
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import uuid

CONTINUE = (
    "La PC se reinició y esta conversación se restauró automáticamente en tmux. "
    "Revisa el historial y el estado real de los archivos antes de actuar. "
    "Continúa la última tarea pendiente ya autorizada desde donde quedó. "
    "Respeta los límites y las aprobaciones de la conversación. Si la tarea ya "
    "terminó, fue cancelada o pausada, o necesitas información, espera al usuario."
)
PROC = Path('/proc')
TOOLS = ('codex', 'claude', 'pi', 'omp', 'opencode')
HOOKS = Path(globals().get('RESOURCE_DIR', str(Path(__file__).parent / 'hooks')))
CLIENT_ENV = ('CODEX_HOME', 'CLAUDE_CONFIG_DIR', 'PI_CODING_AGENT_DIR',
              'PI_CODING_AGENT_SESSION_DIR', 'OMP_PROFILE', 'OPENCODE_CONFIG',
              'OPENCODE_CONFIG_DIR', 'XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_STATE_HOME')


def tmux(*args):
    return subprocess.check_output(['tmux', *args], text=True).strip()


def valid_id(value, tool=None):
    if tool == 'opencode':
        return value if isinstance(value, str) and re.fullmatch(r'ses_[A-Za-z0-9]+', value) else None
    try:
        return str(uuid.UUID(value))
    except (ValueError, TypeError, AttributeError):
        return None


def process(pid):
    try:
        path = PROC / str(pid)
        stat = (path / 'stat').read_text().rsplit(')', 1)[1].split()
        argv = [os.fsdecode(v) for v in (path / 'cmdline').read_bytes().split(b'\0') if v]
        return dict(pid=int(pid), ppid=int(stat[1]), group=int(stat[2]),
                    foreground=int(stat[5]), start=stat[19], argv=argv)
    except (OSError, ValueError, IndexError):
        return None


def processes():
    return {p['pid']: p for entry in PROC.iterdir()
            if entry.name.isdigit() and (p := process(entry.name))}


def descendants(pid, table):
    result = []
    pending = [pid]
    while pending:
        current = pending.pop(0)
        if current not in table:
            continue
        p = table[current]
        # A managed daemon serves other terminals too; never claim its threads.
        if '--managed-daemon' in p['argv']:
            continue
        result.append(p)
        pending.extend(p['pid'] for p in table.values() if p['ppid'] == current)
    return result


def agent_process(pane_pid, table):
    pane = table.get(int(pane_pid))
    if not pane:
        return None
    candidates = []
    for p in descendants(int(pane_pid), table):
        argv = p['argv']
        if not argv or p['group'] != pane['foreground']:
            continue
        name = Path(argv[0]).name
        # npm launches a Node shim before the native executable.
        if name in ('node', 'bun') and len(argv) > 1:
            argv = argv[1:]
            name = Path(argv[0]).name
            if name in ('cli.js', 'cli.mjs'):
                entry = str(Path(argv[0]).resolve())
                if '@oh-my-pi/pi-coding-agent/' in entry:
                    name = 'omp'
                elif '/pi-coding-agent/' in entry:
                    name = 'pi'
        if name not in TOOLS:
            continue
        if any(arg in ('app-server', 'exec', 'mcp-server', 'remote-control',
                       'daemon', '--print', '-p') for arg in argv[1:]) and name == 'claude':
            continue
        if name == 'codex' and any(arg in ('app-server', 'exec', 'mcp-server') for arg in argv[1:]):
            continue
        if name in ('pi', 'omp') and any(arg in ('--print', '-p', '--no-session') for arg in argv[1:]):
            continue
        if name == 'opencode' and argv[1:2] and argv[1] in ('run', 'serve', 'web', 'acp', 'mcp', 'attach'):
            continue
        candidates.append(dict(p, tool=name, args=argv[1:]))
    # Native Codex is a child of its Node shim and owns the backend.
    return candidates[-1] if candidates else None


def environment(pid):
    try:
        return dict(os.fsdecode(v).split('=', 1) for v in
                    (PROC / str(pid) / 'environ').read_bytes().split(b'\0') if b'=' in v)
    except OSError:
        return {}


def file_identity(path):
    try:
        with path.open() as source:
            record = json.loads(source.readline())
        data = record.get('payload', {})
        # Subagent rollouts must not replace the parent conversation.
        if record.get('type') == 'session_meta' and isinstance(data.get('source'), str):
            return valid_id(data.get('id')), data.get('cwd')
    except (OSError, ValueError):
        pass
    return None, None


def discover(agent, table):
    env = environment(agent['pid'])
    if agent['tool'] == 'claude':
        home = Path(env.get('CLAUDE_CONFIG_DIR', str(Path.home() / '.claude')))
        try:
            data = json.loads((home / 'sessions' / f"{agent['pid']}.json").read_text())
            if data.get('pid') == agent['pid'] and valid_id(data.get('sessionId')):
                return valid_id(data['sessionId']), data.get('cwd')
        except (OSError, ValueError):
            pass
    identities = set()
    for p in descendants(agent['pid'], table):
        try:
            files = list((PROC / str(p['pid']) / 'fd').iterdir())
        except OSError:
            continue
        for fd in files:
            try:
                path = Path(os.readlink(fd))
            except OSError:
                continue
            if agent['tool'] == 'codex' and path.name.startswith('rollout-') and path.suffix == '.jsonl':
                sid, cwd = file_identity(path)
                if sid:
                    identities.add((sid, cwd))
            elif agent['tool'] == 'claude' and path.parent.name == 'debug' and path.suffix == '.txt':
                if sid := valid_id(path.stem):
                    identities.add((sid, None))
    if len(identities) == 1:
        return identities.pop()
    return None, None


def tracked_session(agent):
    env = environment(agent['pid'])
    runtime = Path(env.get('XDG_RUNTIME_DIR', f'/run/user/{os.getuid()}'))
    try:
        data = json.loads((runtime / 'orgm-tmux-agents' / f"{agent['pid']}.json").read_text())
        if (data.get('pid'), data.get('start'), data.get('tool'), data.get('tmux'), data.get('pane')) == (
                agent['pid'], agent['start'], agent['tool'], env.get('TMUX'), env.get('TMUX_PANE')):
            return data
    except (OSError, ValueError):
        pass
    return None


def context_args(tool, args):
    # Retain configuration, never replay the original prompt or old resume flags.
    values = {
        'codex': {'-c', '--config', '-m', '--model', '-p', '--profile', '-s', '--sandbox',
                  '-a', '--ask-for-approval', '--add-dir', '--enable', '--disable'},
        'claude': {'--model', '--agent', '--effort', '--permission-mode', '--settings',
                   '--append-system-prompt', '--append-system-prompt-file'},
        'pi': {'--provider', '--model', '--thinking', '--models', '--session-dir',
               '--system-prompt', '--append-system-prompt', '--tools', '-t', '--exclude-tools',
               '--extension', '-e', '--skill', '--prompt-template', '--use-theme', '--tui-mode'},
        'omp': {'--provider', '--model', '--thinking', '--models', '--profile', '--session-dir',
                '--system-prompt', '--append-system-prompt', '--tools', '--approval-mode',
                '--extension', '-e', '--hook', '--plugin-dir', '--smol', '--slow', '--plan', '--service-tier'},
        'opencode': {'--model', '-m', '--agent'},
    }[tool]
    flags = {
        'codex': {'--dangerously-bypass-approvals-and-sandbox', '--yolo', '--search',
                  '--no-alt-screen', '--approve-for-me'},
        'claude': {'--dangerously-skip-permissions', '--allow-dangerously-skip-permissions'},
        'pi': {'--no-extensions', '-ne', '--no-mcp', '--no-skills', '-ns', '--no-themes',
               '--no-tools', '-nt', '--no-builtin-tools', '-nbt', '--no-prompt-templates', '-np'},
        'omp': {'--no-extensions', '--no-tools', '--no-lsp', '--hide-thinking'},
        'opencode': {'--pure'},
    }[tool]
    result = []
    iterator = iter(args)
    for arg in iterator:
        if arg in values:
            value = next(iterator, None)
            if value is not None:
                if arg in ('--extension', '-e') and Path(value).name == 'pi-session.mjs':
                    continue
                result.extend((arg, value))
        elif arg.split('=', 1)[0] in values and '=' in arg:
            result.append(arg)
        elif arg in flags:
            result.append(arg)
    return result


def binding(pane, agent, table):
    tracked = tracked_session(agent)
    session_file = None
    if tracked is not None:
        sid, cwd = valid_id(tracked.get('id'), agent['tool']), tracked.get('cwd')
        session_file = tracked.get('sessionFile')
        # An explicit empty TUI/home selection must invalidate an earlier bind.
        if not sid:
            return None
    else:
        sid, cwd = discover(agent, table)
    if not sid:
        try:
            saved = json.loads(tmux('show-option', '-pqv', '-t', pane, '@orgm-agent-binding') or '{}')
            if (saved.get('pid'), saved.get('start'), saved.get('tool')) == (
                    agent['pid'], agent['start'], agent['tool']):
                sid, cwd = valid_id(saved.get('id'), agent['tool']), saved.get('cwd')
        except ValueError:
            pass
    if not sid:
        return None
    if not cwd:
        cwd = os.readlink(PROC / str(agent['pid']) / 'cwd')
    env = environment(agent['pid'])
    result = dict(tool=agent['tool'], id=sid, cwd=cwd, args=context_args(agent['tool'], agent['args']),
                  env={key: env[key] for key in CLIENT_ENV if key in env})
    if agent['tool'] in ('pi', 'omp') and session_file:
        if not Path(session_file).is_file():
            return None
        result['sessionFile'] = session_file
    if env.get('ORGM_TMUX_ORIGINAL_TUI_CONFIG'):
        result['env']['OPENCODE_TUI_CONFIG'] = env['ORGM_TMUX_ORIGINAL_TUI_CONFIG']
    return result


def save(snapshot):
    table = processes()
    panes = {}
    fmt = '#{session_name}\t#{window_index}\t#{pane_index}\t#{pane_id}\t#{pane_pid}'
    for line in tmux('list-panes', '-a', '-F', fmt).splitlines():
        session, window, index, pane, pid = line.split('\t')
        if agent := agent_process(pid, table):
            panes[(session, window, index)] = (pane, agent)
    lines = []
    for line in snapshot.read_text().splitlines():
        fields = line.split('\t')
        if len(fields) == 11 and fields[0] == 'pane':
            found = panes.get((fields[1], fields[2], fields[5]))
            if found:
                pane, agent = found
                data = binding(pane, agent, table)
                if data:
                    token = base64.urlsafe_b64encode(json.dumps(data).encode()).decode()
                    fields[9:] = ['tmux-agent-resume', ':tmux-agent-resume run ' + token]
                else:
                    print(f"tmux-agent-resume: {fields[1]}:{fields[2]}.{fields[5]}: "
                          f"no exact {agent['tool']} ID; leaving a shell (use bind)", file=sys.stderr)
                    fields[9:] = ['bash', ':']
        lines.append('\t'.join(fields))
    snapshot.write_text('\n'.join(lines) + '\n')


def bind(tool, sid, pane):
    if not valid_id(sid, tool):
        raise ValueError('invalid conversation ID')
    pid = tmux('display-message', '-p', '-t', pane, '#{pane_pid}')
    agent = agent_process(pid, processes())
    if not agent or agent['tool'] != tool:
        raise ValueError(f'no foreground {tool} in pane {pane}')
    value = dict(pid=agent['pid'], start=agent['start'], tool=tool, id=sid,
                 cwd=os.readlink(PROC / str(agent['pid']) / 'cwd'))
    tmux('set-option', '-p', '-t', pane, '@orgm-agent-binding', json.dumps(value))


def resume(token):
    data = json.loads(base64.urlsafe_b64decode(token))
    tool = data['tool']
    if tool not in TOOLS or not valid_id(data['id'], tool):
        raise ValueError('invalid saved conversation')
    os.chdir(data['cwd'])
    os.environ.update({k: v for k, v in data.get('env', {}).items()
                       if k in (*CLIENT_ENV, 'OPENCODE_TUI_CONFIG')})
    args = [tool, *data.get('args', [])]
    target = data.get('sessionFile', data['id'])
    selectors = {'codex': ['resume', data['id']], 'claude': ['--resume', data['id']],
                 'pi': ['--session', target], 'omp': ['--resume', target],
                 'opencode': ['--session', data['id']]}
    args.extend(selectors[tool])
    if tmux('show-option', '-gqv', '@orgm-agent-auto-continue') == 'on':
        if tool == 'opencode':
            request = dict(id=data['id'], prompt=CONTINUE)
            iterator = iter(data.get('args', []))
            for arg in iterator:
                if arg in ('--model', '-m', '--agent'):
                    request['agent' if arg == '--agent' else 'model'] = next(iterator, '')
                elif arg.startswith(('--model=', '--agent=')):
                    key, value = arg[2:].split('=', 1)
                    request[key] = value
            os.environ['ORGM_TMUX_RESUME_REQUEST'] = json.dumps(request)
        else:
            args.append(CONTINUE)
    print(f"Restaurando {tool}: {data['id']}", flush=True)
    os.execvp(tool, args)


def parse_jsonc(text):
    # OpenCode config supports JSON comments and trailing commas. Protect JSON
    # strings before stripping either, including URLs and escaped quotes.
    string = r'"(?:\\.|[^"\\])*"'
    text = re.sub(string + r'|//[^\r\n]*|/\*[\s\S]*?\*/',
                  lambda m: m[0] if m[0].startswith('"') else re.sub(r'[^\r\n]', ' ', m[0]), text)
    text = re.sub(string + r'|,(?=\s*[}\]])',
                  lambda m: m[0] if m[0].startswith('"') else '', text)
    return json.loads(text)


def launch(tool, executable, args):
    env = os.environ.copy()
    management = {
        'codex': {'exec', 'e', 'review', 'login', 'logout', 'update', 'completion', 'mcp',
                  'mcp-server', 'plugin', 'features', 'doctor', 'help', 'app-server', 'remote-control',
                  'exec-server', 'agents', 'queue', 'archive', 'delete', 'unarchive', 'migrate-rollouts',
                  'cloud', 'debug', 'sandbox', 'apply'},
        'pi': {'install', 'remove', 'uninstall', 'update', 'list', 'config', 'auth', 'mcp'},
        'omp': {'agents', 'anonymize', 'auth', 'bench', 'browser', 'changelog', 'clip', 'commit',
                'commands', 'config', 'context', 'dry-balance', 'eval', 'find', 'gallery', 'gc',
                'git', 'grep', 'grievances', 'if-bench', 'images', 'install', 'join', 'login',
                'models', 'play', 'plugin', 'predict', 'ps', 'read', 'render', 'say', 'search',
                'session', 'setup', 'share', 'shell', 'skill', 'ssh', 'stats', 'stream',
                'tiny-models', 'token', 'toks', 'ttsr', 'update', 'usage', 'worktree'},
        'opencode': {'completion', 'run', 'serve', 'web', 'acp', 'mcp', 'attach', 'debug', 'providers',
                     'auth', 'agent', 'models', 'stats', 'export', 'import', 'session', 'plugin', 'db', 'upgrade', 'uninstall'},
    }[tool]
    interactive = (env.get('TMUX') and (not args or args[0] not in management)
                   and not any(arg in ('--help', '-h', '--version', '-v', '--print', '-p', '--no-session') for arg in args))
    if tool == 'omp':
        root = Path(executable).resolve().parent.parent
        if (root / 'package.json').is_file():
            env.setdefault('PI_PACKAGE_DIR', str(root))
    if interactive:
        env['ORGM_TMUX_AGENT_TOOL'] = tool
        if tool == 'codex':
            if '--no-daemon' not in args:
                args = ['--no-daemon', *args]
        elif tool in ('pi', 'omp'):
            args = ['--extension', str(HOOKS / 'pi-session.mjs'), *args]
        elif '--pure' not in args:
            # Custom config is merged alongside global/project settings by OpenCode.
            # Preserve an existing custom JSONC config and resolve its local plugins.
            custom = env.get('OPENCODE_TUI_CONFIG')
            if custom:
                env['ORGM_TMUX_ORIGINAL_TUI_CONFIG'] = custom
            directory = Path(env.get('XDG_RUNTIME_DIR', f'/run/user/{os.getuid()}')) / 'orgm-tmux-agents'
            directory.mkdir(mode=0o700, parents=True, exist_ok=True)
            target = directory / f'opencode-config-{os.getpid()}.json'
            config = parse_jsonc(Path(custom).read_text()) if custom else {}
            def resolve(spec):
                if isinstance(spec, str) and spec.startswith(('./', '../')):
                    return (Path(custom).parent / spec).resolve().as_uri()
                return spec
            config['plugin'] = [[resolve(p[0]), p[1]] if isinstance(p, list) else resolve(p)
                                for p in config.get('plugin', [])]
            config['plugin'].append((HOOKS / 'opencode-session.mjs').resolve().as_uri())
            descriptor = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
            with os.fdopen(descriptor, 'w') as output:
                json.dump(config, output)
            env['OPENCODE_TUI_CONFIG'] = str(target)
    os.execve(executable, [executable, *args], env)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    sub.add_parser('save').add_argument('snapshot', type=Path)
    sub.add_parser('run').add_argument('token')
    register = sub.add_parser('bind', help='bind an already running shared-daemon conversation')
    register.add_argument('tool', choices=TOOLS)
    register.add_argument('id')
    register.add_argument('pane', help='tmux pane ID from list-panes')
    launcher = sub.add_parser('launch', help='attach the session recorder to an interactive client')
    launcher.add_argument('tool', choices=('codex', 'pi', 'omp', 'opencode'))
    launcher.add_argument('executable')
    launcher.add_argument('args', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if args.command == 'save':
        save(args.snapshot)
    elif args.command == 'bind':
        bind(args.tool, args.id, args.pane)
    elif args.command == 'launch':
        launch(args.tool, args.executable, args.args)
    else:
        resume(args.token)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as exc:
        print(f'tmux-agent-resume: {exc}', file=sys.stderr)
        sys.exit(1)
