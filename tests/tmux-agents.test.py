#!/usr/bin/env python3
"""Conversation identity, stale process binds, and safe resume arguments."""
import base64
import importlib.util
import json
import os
import subprocess
import sys
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('agents', ROOT / 'nixos/tmux/agents.py')
agents = importlib.util.module_from_spec(spec)
spec.loader.exec_module(agents)
SID = '12345678-1234-1234-1234-123456789abc'


class AgentsTest(unittest.TestCase):
    def test_cli_help_is_valid_for_all_subcommands(self):
        for command in ('bind', 'launch', 'save', 'run', 'restore'):
            result = subprocess.run([sys.executable, str(ROOT / 'nixos/tmux/agents.py'), command, '--help'],
                                    text=True, capture_output=True, timeout=5)
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_parent_thread_metadata_excludes_subagents(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'rollout.jsonl'
            for source in ('cli', 'vscode', {'subagent': {'thread_spawn': {}}}):
                path.write_text(json.dumps(dict(type='session_meta', payload=dict(
                    id=SID, cwd=directory, source=source))) + '\n')
                result = agents.file_identity(path)
                self.assertEqual(result, (SID, directory) if isinstance(source, str) else (None, None))

    def test_shared_daemon_is_not_part_of_pane(self):
        table = {1: dict(pid=1, ppid=0, argv=['codex']),
                 2: dict(pid=2, ppid=1, argv=['codex', 'app-server', '--managed-daemon']),
                 3: dict(pid=3, ppid=2, argv=['bash'])}
        self.assertEqual([p['pid'] for p in agents.descendants(1, table)], [1])

    def test_stale_binding_is_rejected_after_process_restart(self):
        agent = dict(pid=42, start='new', tool='codex')
        old = dict(pid=42, start='old', tool='codex', id=SID, cwd='/tmp')
        with patch.object(agents, 'discover', return_value=(None, None)), \
                patch.object(agents, 'tmux', return_value=json.dumps(old)):
            self.assertIsNone(agents.binding('%0', agent, {}))

    def test_prompt_and_old_resume_options_are_not_replayed(self):
        args = ['--model', 'test-model', 'resume', SID, 'delete $(anything)',
                '--config', 'test="value with spaces"', '--last', '--yolo', '--no-daemon']
        self.assertEqual(agents.context_args('codex', args),
                         ['--model', 'test-model', '--config', 'test="value with spaces"', '--yolo'])

    def test_resume_executes_exact_id_and_continuation_as_one_argument(self):
        data = dict(tool='codex', id=SID, cwd='/tmp', args=['--model', 'test-model'])
        token = base64.urlsafe_b64encode(json.dumps(data).encode()).decode()
        with patch.object(agents, 'tmux', return_value='on'), \
                patch.object(os, 'chdir') as chdir, patch.object(os, 'execvp') as execute:
            agents.resume(token)
            chdir.assert_called_once_with('/tmp')
            execute.assert_called_once_with('codex', ['codex', '--model', 'test-model',
                                                     'resume', SID, agents.CONTINUE])

    def test_wrapper_flags_do_not_accumulate_across_restores(self):
        args = ['--dangerously-skip-permissions'] * 4 + ['--model', 'opus', '--resume', SID]
        self.assertEqual(agents.context_args('claude', args),
                         ['--dangerously-skip-permissions', '--model', 'opus'])

    def test_resume_refuses_a_conversation_that_is_already_running(self):
        data = dict(tool='claude', id=SID, cwd='/tmp', args=[])
        token = base64.urlsafe_b64encode(json.dumps(data).encode()).decode()
        running = {1: dict(pid=1, argv=['/home/u/.bun/bin/claude', '--resume', SID])}
        with patch.object(agents, 'processes', return_value=running), \
                patch.object(agents, 'tmux', return_value='on'), \
                patch.object(os, 'chdir'), patch.object(os, 'execvp') as execute:
            agents.resume(token)
            execute.assert_not_called()

    def test_attach_only_does_not_send_a_prompt(self):
        data = dict(tool='claude', id=SID, cwd='/tmp', args=[])
        token = base64.urlsafe_b64encode(json.dumps(data).encode()).decode()
        with patch.object(agents, 'tmux', return_value='off'), \
                patch.object(os, 'chdir'), patch.object(os, 'execvp') as execute:
            agents.resume(token)
            execute.assert_called_once_with('claude', ['claude', '--resume', SID])

    def test_additional_clients_use_their_own_resume_syntax(self):
        for tool, selector, target in (('pi', '--session', '/tmp/project with spaces/session.jsonl'),
                                       ('omp', '--resume', '/tmp/project with spaces/session.jsonl'),
                                       ('opencode', '--session', 'ses_testSession123')):
            with self.subTest(tool=tool):
                sid = target if tool == 'opencode' else SID
                data = dict(tool=tool, id=sid, cwd='/tmp', args=[])
                if tool in ('pi', 'omp'):
                    data['sessionFile'] = target
                token = base64.urlsafe_b64encode(json.dumps(data).encode()).decode()
                with patch.object(agents, 'tmux', return_value='on'), \
                        patch.object(os, 'chdir'), patch.dict(os.environ), patch.object(os, 'execvp') as execute:
                    agents.resume(token)
                    prompt = [] if tool == 'opencode' else [agents.CONTINUE]
                    execute.assert_called_once_with(tool, [tool, selector, target, *prompt])
                    if tool == 'opencode':
                        self.assertEqual(json.loads(os.environ['ORGM_TMUX_RESUME_REQUEST']),
                                         dict(id=target, prompt=agents.CONTINUE))

    def test_opencode_id_is_validated_separately(self):
        self.assertEqual(agents.valid_id('ses_testSession123', 'opencode'), 'ses_testSession123')
        self.assertIsNone(agents.valid_id('ses_bad;touch /tmp/no', 'opencode'))
        self.assertIsNone(agents.valid_id('ses_testSession123', 'pi'))

    def test_disabled_pi_resources_are_preserved_and_tracker_is_refreshed(self):
        args = ['-ne', '--no-mcp', '--no-skills', '--model', 'provider/model', '--session', SID,
                '--extension', '/nix/store/old-hooks/pi-session.mjs', '--extension', '/my/extension.mjs',
                'original prompt']
        self.assertEqual(agents.context_args('pi', args),
                         ['-ne', '--no-mcp', '--no-skills', '--model', 'provider/model',
                          '--extension', '/my/extension.mjs'])

    def test_empty_tracked_selection_invalidates_old_binding(self):
        agent = dict(pid=42, start='same', tool='opencode')
        with patch.object(agents, 'tracked_session', return_value=dict(id=None, cwd='/tmp')), \
                patch.object(agents, 'tmux') as query:
            self.assertIsNone(agents.binding('%0', agent, {}))
            query.assert_not_called()

    def test_pi_and_omp_launch_load_tracker_even_with_discovery_disabled(self):
        for tool in ('pi', 'omp'):
            with self.subTest(tool=tool), patch.dict(os.environ, TMUX='/tmp/socket,1,0'), \
                    patch.object(os, 'execve') as execute:
                agents.launch(tool, '/native/' + tool, ['--no-extensions'])
                executable, argv, env = execute.call_args.args
                self.assertEqual(argv, [executable, '--extension', str(agents.HOOKS / 'pi-session.mjs'),
                                        '--no-extensions'])
                self.assertEqual(env['ORGM_TMUX_AGENT_TOOL'], tool)

    def test_management_subcommands_are_not_instrumented(self):
        for tool, command in (('pi', 'install'), ('omp', 'models'), ('opencode', 'run')):
            with self.subTest(tool=tool), patch.dict(os.environ, TMUX='/tmp/socket,1,0'), \
                    patch.object(os, 'execve') as execute:
                agents.launch(tool, '/native/' + tool, [command])
                self.assertEqual(execute.call_args.args[1], ['/native/' + tool, command])

    def test_opencode_custom_config_keeps_existing_settings_and_relative_plugins(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            custom = root / 'user.jsonc'
            custom.write_text('''{ // user's config
                "theme": "custom-theme",
                "plugin": ["./my-plugin.mjs", ["../other.mjs", {"setting": true}], "npm-plugin"]
            }''')
            with patch.dict(os.environ, TMUX='/tmp/socket,1,0', XDG_RUNTIME_DIR=directory,
                            OPENCODE_TUI_CONFIG=str(custom)), patch.object(os, 'execve') as execute:
                agents.launch('opencode', '/native/opencode', ['--session', 'ses_example'])
                env = execute.call_args.args[2]
                config = json.loads(Path(env['OPENCODE_TUI_CONFIG']).read_text())
                self.assertEqual(config['theme'], 'custom-theme')
                self.assertEqual(config['plugin'][0], (root / 'my-plugin.mjs').as_uri())
                self.assertEqual(config['plugin'][1], [(root.parent / 'other.mjs').as_uri(), {'setting': True}])
                self.assertEqual(config['plugin'][2], 'npm-plugin')
                self.assertEqual(env['ORGM_TMUX_ORIGINAL_TUI_CONFIG'], str(custom))
            self.assertIn('//', custom.read_text(), 'original config must remain editable and untouched')

    def test_jsonc_preserves_comment_markers_inside_strings(self):
        text = r'''{
          // ignored comment
          "url": "https://example.com/a//b",
          "quoted": "escaped quote: \" /* still a string */",
          /* multiline
             comment */
          "list": ["comma,}", 1,],
        }'''
        self.assertEqual(agents.parse_jsonc(text), {
            'url': 'https://example.com/a//b',
            'quoted': 'escaped quote: " /* still a string */',
            'list': ['comma,}', 1],
        })

    def test_portable_codex_preserves_permissions_and_uses_dedicated_tmux_backend(self):
        for inside in (False, True):
            with self.subTest(tmux=inside), patch.dict(os.environ), patch.object(os, 'execve') as execute:
                os.environ.pop('TMUX', None)
                if inside:
                    os.environ['TMUX'] = '/tmp/socket,1,0'
                agents.launch('codex', '/native/codex', ['resume', SID])
                expected = ['/native/codex', *(['--no-daemon'] if inside else []), 'resume', SID]
                self.assertEqual(execute.call_args.args[1], expected)


if __name__ == '__main__':
    unittest.main()
