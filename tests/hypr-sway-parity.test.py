#!/usr/bin/env python3
"""Hyprland backend contracts: real JSON normalization and safe command boundaries."""
import json
from pathlib import Path
import runpy
import subprocess
import tempfile
import unittest
import os
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
ADAPTER = ROOT/'dotfiles/config/profiles/hyprland/.local/lib/orgm-wayland/hyprland.py'


class Backend(unittest.TestCase):
    def setUp(self):
        self.assertTrue(ADAPTER.is_file(), 'native Hyprland adapter missing')
        self.module = runpy.run_path(str(ADAPTER))
        self.commands = []
        self.clients = [
            dict(address='0xabc', mapped=True, hidden=False, title='A "quoted"; exit',
                 **{'class': 'kitty'}, workspace=dict(id=2, name='2'), monitor=0,
                 at=[-100, 40], size=[600, 400], focusHistoryID=0),
            dict(address='0xdef', mapped=True, hidden=False, title='Browser',
                 **{'class': 'firefox'}, workspace=dict(id=3, name='3'), monitor=0,
                 at=[0, 0], size=[800, 600], focusHistoryID=1)]
        self.outputs = [dict(id=0, name='DP-1', focused=True, activeWorkspace=dict(id=2, name='2'),
                             specialWorkspace=dict(id=0, name=''), width=1920, height=1080, scale=1)]
        def request(kind):
            return dict(clients=self.clients, monitors=self.outputs,
                        activewindow=dict(address='0xabc'))[kind]
        self.backend = self.module['Backend'](request=request, dispatch=lambda *args: self.commands.append(args))

    def test_dispatch_uses_native_lua_and_rejects_zero_exit_errors(self):
        calls = []
        response = subprocess.CompletedProcess([], 0, 'ok\n', '')
        def execute(args, **kwargs):
            calls.append(args)
            return response
        with patch.object(subprocess, 'run', execute):
            self.module['dispatch']('focuswindow', 'address:0xabc')
            self.assertEqual(calls[-1], ['hyprctl', 'dispatch',
                'hl.dsp.focus({window=[[\naddress:0xabc]]})'])
            self.module['dispatch']('workspace', 'name:quoted "x" ]] workspace')
            self.assertEqual(calls[-1][2], 'hl.dsp.focus({workspace=[=[\nname:quoted "x" ]] workspace]=]})')
            self.module['dispatch']('togglespecialworkspace', 'magic')
            self.assertEqual(calls[-1][2], 'hl.dsp.workspace.toggle_special([[\nmagic]])')
            response.stdout = 'error: invalid Lua dispatcher\n'
            with self.assertRaisesRegex(RuntimeError, 'invalid Lua dispatcher'):
                self.module['dispatch']('focuswindow', 'address:0xabc')

    def test_normalizes_focus_hidden_workspaces_and_quoted_titles(self):
        items = self.backend.windows()
        self.assertEqual([i['id'] for i in items], ['0xabc', '0xdef'])
        self.assertTrue(items[0]['focused'])
        self.assertTrue(items[0]['visible'])
        self.assertFalse(items[1]['visible'])
        self.assertEqual(items[0]['name'], 'A "quoted"; exit')
        self.assertEqual(items[0]['rect']['x'], -100)
        self.assertEqual(self.backend.active_output(), 'DP-1')

    def test_focus_only_live_addresses_or_known_workspaces(self):
        for selection in ('0xabc', 'workspace:3', '0xabc;exit', '0xdead', 'workspace:3;exit'):
            self.backend.focus_selection(selection)
        self.assertEqual(self.commands, [('focuswindow', 'address:0xabc'), ('workspace', 'name:3')])
        self.clients.clear()
        self.backend.focus_selection('0xabc')
        self.assertEqual(len(self.commands), 2, 'closed windows must not dispatch stale commands')

    def test_named_workspaces_never_become_relative_navigation(self):
        names = ['Web', 'previous', 'e+1', 'quoted "name"']
        self.clients.extend(dict(self.clients[0], address='0x'+str(100+i),
                                 workspace=dict(id=10+i, name=name)) for i, name in enumerate(names))
        for name in names:
            self.backend.focus_selection('workspace:'+name)
        self.assertEqual(self.commands, [('workspace', 'name:'+name) for name in names])

    def test_groups_include_only_occupied_workspaces(self):
        groups = self.backend.workspace_groups(self.backend.windows())
        self.assertEqual([g['name'] for g in groups], ['2', '3'])
        self.assertTrue(groups[0]['focused'])

    def test_window_previews_fall_back_without_wrong_screen_capture(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.assertFalse(self.backend.capture_window('0xabc', Path(tmp)/'window.png'))
            self.assertEqual(list(Path(tmp).iterdir()), [])

    def test_shared_cli_loads_with_native_backend_without_sway_environment(self):
        entry = ROOT/'dotfiles/config/profiles/hyprland/.local/bin/orgm-hyprland'
        self.assertTrue(entry.is_file())
        shell = runpy.run_path(str(entry))
        with patch.dict(os.environ, XDG_STATE_HOME='/tmp/private-state'):
            self.assertEqual(shell['wallpaper_state'](), Path('/tmp/private-state/hypr-wallpaper/current'))

    def test_waybar_matches_sway_without_sway_ipc(self):
        source = ROOT/'dotfiles/config/profiles/sway/.config/waybar/config'
        target = ROOT/'dotfiles/config/users/osmarg/profiles/hyprland/.config/waybar-hypr/config'
        sway, hypr = json.loads(source.read_text()), json.loads(target.read_text())
        self.assertIsInstance(hypr, dict, 'one compact Sway-based bar')
        self.assertEqual(hypr['height'], sway['height'])
        self.assertEqual(hypr['modules-center'], sway['modules-center'])
        self.assertIn('hyprland/workspaces', hypr['modules-left'])
        self.assertIn('custom/notifications', hypr['modules-right'])
        self.assertFalse('swaymsg' in json.dumps(hypr))


if __name__ == '__main__':
    unittest.main()
