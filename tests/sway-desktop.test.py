#!/usr/bin/env python3
"""Desktop backend validation, clipboard bytes and bounded private thumbnail capture."""
import json
import os
from pathlib import Path
import runpy
import subprocess
import tempfile
import unittest
import sys
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
MODULE = runpy.run_path(str(ROOT/'dotfiles/config/profiles/sway/.local/bin/orgm-sway-desktop'))
ENV = MODULE['main'].__globals__


class Desktop(unittest.TestCase):
    def test_audio_keys_use_one_native_adjustment_or_pamixer_without_notifications(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            log = root/'pamixer.jsonl'
            notification = root/'notification'
            for name, body in {
                'qs': 'import os,sys\nif os.environ.get("FIXTURE_QS_OK"):print("ok");sys.exit(0)\nsys.exit(1)\n',
                'pamixer': f'import sys,json\nfrom pathlib import Path\np=Path({str(log)!r})\nwith p.open("a") as f:f.write(json.dumps(sys.argv[1:])+"\\n")\nif "--get-volume" in sys.argv:print(73)\nif "--get-mute" in sys.argv:print("false")\n',
                'notify-send': f'from pathlib import Path\nPath({str(notification)!r}).touch()\n',
            }.items():
                binary = root/name
                binary.write_text('#!'+sys.executable+'\n'+body)
                binary.chmod(0o755)
            env = dict(os.environ, PATH=str(root)+os.pathsep+os.environ['PATH'], XDG_CONFIG_HOME=str(root/'config with spaces'))
            helpers = ROOT/'dotfiles/config/profiles/sway/.local/bin'
            for name, prefix in (('sway-volume-osd', []), ('sway-mic-volume-osd', ['--default-source'])):
                log.unlink(missing_ok=True)
                subprocess.run([str(helpers/name), 'up'], env=dict(env, FIXTURE_QS_OK='1'), check=True)
                self.assertFalse(log.exists(), 'The native path must not also change volume through pamixer')
                fallback = dict(env)
                fallback.pop('FIXTURE_QS_OK', None)
                subprocess.run([str(helpers/name), 'up'], env=fallback, check=True)
                calls = [json.loads(line) for line in log.read_text().splitlines()]
                self.assertEqual(calls, [prefix+['--allow-boost','--set-limit','150','-i','3'], prefix+['--get-volume'], prefix+['--get-mute']])
                self.assertFalse(notification.exists())

    def test_control_commands_are_an_allowlist_and_brightness_is_bounded(self):
        calls = []
        with patch.dict(ENV, run=lambda *a, **kw: calls.append(a), control_state=lambda: {}):
            MODULE['control_action']('brightness', '45')
            for action, value in (('brightness', '0'), ('brightness', '101'), ('brightness', '5; reboot'), ('command', 'reboot')):
                with self.assertRaises(ValueError):
                    MODULE['control_action'](action, value)
        self.assertEqual(calls, [('brightnessctl', '-q', 'set', '45%')])

    def test_clipboard_copy_preserves_image_bytes_and_rejects_non_ids(self):
        image = b'\x89PNG\r\n\x1a\nprivate fixture'
        calls = []
        def run(*args, **kwargs):
            calls.append((args, kwargs))
            return subprocess.CompletedProcess(args, 0, image, b'')
        with patch.dict(ENV, run=run):
            MODULE['copy_clipboard']('12')
            with self.assertRaises(ValueError):
                MODULE['copy_clipboard']('12; rm -rf')
        self.assertEqual(calls[0][0], ('cliphist', 'decode'))
        self.assertEqual(calls[0][1]['input'], b'12')
        self.assertEqual(calls[1][0], ('wl-copy', '--type', 'image/png'))
        self.assertEqual(calls[1][1]['input'], image)

    def test_window_catalog_follows_focus_order_and_keeps_hidden_windows(self):
        tree = dict(focus=[1], nodes=[dict(id=1, focus=[3, 2], nodes=[
            dict(id=2, type='workspace', name='1', focus=[4], nodes=[dict(id=4, app_id='app-a', name='A', visible=False)]),
            dict(id=3, type='workspace', name='2', focus=[5], nodes=[dict(id=5, app_id='app-b', name='B', visible=True, focused=True)])])])
        def query(kind):
            return tree if kind == 'get_tree' else [dict(name='1', visible=False), dict(name='2', visible=True)]
        with patch.dict(ENV, query=query):
            items = MODULE['window_items']()
        self.assertEqual([item['id'] for item in items], ['5', '4'])
        self.assertTrue(items[0]['visible'])
        self.assertFalse(items[1]['visible'])

    def test_workspace_groups_include_only_occupied_desktops_in_numeric_order(self):
        items = [dict(id='8', workspace='10'), dict(id='9', workspace='2'),
                 dict(id='10', workspace='1'), dict(id='11', workspace='2')]
        metadata = [dict(name=str(i), num=i, focused=i == 2) for i in (10, 2, 1, 3)]
        with patch.dict(ENV, query=lambda _: metadata):
            groups = MODULE['workspace_groups'](items)
        self.assertEqual([group['name'] for group in groups], ['1', '2', '10'])
        self.assertEqual([item['id'] for item in groups[1]['items']], ['9', '11'])
        self.assertTrue(groups[1]['focused'])

    def test_workspace_and_window_focus_are_distinct_and_validate_current_targets(self):
        calls = []
        items = [dict(id='7', workspace='1'), dict(id='8', workspace='2')]
        with patch.dict(ENV, window_items=lambda: items, ipc=calls.append):
            MODULE['focus_selection']('workspace:2')
            MODULE['focus_selection']('7')
            MODULE['focus_selection']('workspace:3')
            MODULE['focus_selection']('workspace:2; exit')
            MODULE['focus_selection']('99')
        self.assertEqual(calls, ['workspace "2"', '[con_id=7] focus'])

    def test_preview_capture_never_runs_for_hidden_windows_and_files_are_private(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            calls = []
            def run(*args, **kwargs):
                calls.append(args)
                Path(args[-1]).write_bytes(b'fixture PNG')
            items = [dict(id='2', visible=False, focused=False, rect=dict(x=0, y=0, width=200, height=100)),
                     dict(id='3', visible=True, focused=True, rect=dict(x=-200, y=30, width=200, height=100))]
            with patch.dict(ENV, capture_allowed=lambda: True, run=run):
                MODULE['capture_previews'](root, items, all_visible=True)
            self.assertEqual(len(calls), 1)
            self.assertEqual(calls[0][:-1], ('grim', '-s', '0.25', '-g', '-200,30 200x100'))
            self.assertEqual((root/'3.png').stat().st_mode & 0o777, 0o600)
            self.assertFalse((root/'2.png').exists())

    def test_previews_pause_while_gaming_or_a_menu_is_visible(self):
        helpers = dict(ENV['SWAY'], game_mode_active=lambda: True)
        with patch.dict(ENV, SWAY=helpers, query=lambda _: self.fail('Gaming must not query capture surfaces')):
            self.assertFalse(MODULE['capture_allowed']())
        with tempfile.TemporaryDirectory() as directory, patch.dict(os.environ, XDG_RUNTIME_DIR=directory):
            helpers['game_mode_active'] = lambda: False
            with patch.dict(ENV, SWAY=helpers, query=lambda _: [dict(layer_shell_surfaces=[dict(namespace='orgm-control')])]):
                self.assertFalse(MODULE['capture_allowed']())

    def test_existing_wifi_bluetooth_and_capture_bindings_are_preserved(self):
        config = json.loads((ROOT/'dotfiles/config/profiles/sway/.config/waybar/config').read_text())
        self.assertEqual(config['network']['on-click'], 'kitty --class nmtui -e nmtui')
        self.assertEqual(config['bluetooth']['on-click'], 'kitty --class bluetui -e bluetui')
        self.assertEqual(config['custom/control']['on-click'], 'orgm-sway control')
        self.assertEqual(config['pulseaudio']['on-click'], 'orgm-sway audio')
        sway = (ROOT/'dotfiles/config/profiles/sway/.config/sway/config').read_text()
        self.assertIn('bindsym Print $exec orgm-sway screenshot region', sway)
        self.assertIn('bindsym Mod1+Shift+Tab $exec orgm-sway windows prev', sway)


if __name__ == '__main__':
    unittest.main()
