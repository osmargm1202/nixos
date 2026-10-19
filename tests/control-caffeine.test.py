#!/usr/bin/env python3
"""Persistent real Waybar caffeine controls in private HOME/command boundaries."""
import json
import os
from pathlib import Path
import runpy
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
MODULE = runpy.run_path(str(ROOT/'dotfiles/config/profiles/sway/.local/bin/orgm-sway-desktop'))
ENV = MODULE['main'].__globals__


class ControlCaffeine(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.bin = self.home/'bin'
        self.bin.mkdir()
        self.log = self.home/'systemctl.jsonl'
        self.write_binary('systemctl', '''import json,os,sys
from pathlib import Path
p=Path(os.environ['CONTROL_CALLS'])
with p.open('a') as f:f.write(json.dumps(sys.argv[1:])+'\\n')
if 'is-active' in sys.argv:sys.exit(0 if os.environ.get('BAR_ACTIVE', '1')=='1' else 3)
if 'restart' in sys.argv:sys.exit(1 if os.environ.get('FAIL_RESTART')=='1' else 0)
''')
        self.write_binary('brightnessctl', 'print("fixture,backlight,50,50%,100")\n')
        self.write_binary('swaync-client', 'print("false")\n')
        self.write_binary('notify-send', '')
        source = ROOT/'dotfiles/config/profiles/wayland/.local/bin/waybar-caffeine-state'
        shutil.copy2(source, self.bin/'waybar-caffeine-state')
        self.environ = patch.dict(os.environ, HOME=str(self.home), XDG_STATE_HOME=str(self.home/'state'),
                                  PATH=str(self.bin)+os.pathsep+os.environ['PATH'], CONTROL_CALLS=str(self.log))
        self.environ.start()
        self.addCleanup(self.environ.stop)

    def write_binary(self, name, body):
        path = self.bin/name
        path.write_text('#!'+sys.executable+'\n'+body)
        path.chmod(0o755)

    def test_caffeine_toggle_persists_and_restarts_only_the_current_compositors_bar(self):
        for compositor in ('sway', 'hyprland'):
            with self.subTest(compositor=compositor), patch.dict(ENV, SWAY=dict(ENV['SWAY'], compositor=compositor, game_mode_active=lambda: False)):
                before = MODULE['control_state']()
                self.assertIs(before.get('caffeine'), False)
                self.assertIs(before.get('caffeineAvailable'), True)
                after = MODULE['control_action']('caffeine')
                self.assertIs(after['caffeine'], True)
                self.assertEqual((self.home/'state/waybar/caffeine').read_text(), 'activated\n')
                self.assertIs(MODULE['control_action']('caffeine')['caffeine'], False)
        calls = [json.loads(line) for line in self.log.read_text().splitlines()]
        self.assertEqual([row for row in calls if 'restart' in row], [
            ['--user', 'restart', 'orgm-sway-waybar.service'],
            ['--user', 'restart', 'orgm-sway-waybar.service'],
            ['--user', 'restart', 'orgm-hyprland-waybar.service'],
            ['--user', 'restart', 'orgm-hyprland-waybar.service']])

    def test_inactive_bar_is_not_reported_as_inhibiting_and_cannot_be_toggled(self):
        subprocess.run([str(self.bin/'waybar-caffeine-state'), 'toggle'], check=True)
        with patch.dict(os.environ, BAR_ACTIVE='0'), patch.dict(ENV, SWAY=dict(ENV['SWAY'], game_mode_active=lambda: False)):
            state = MODULE['control_state']()
            self.assertIs(state.get('caffeine'), False)
            self.assertIs(state.get('caffeineAvailable'), False)
            with self.assertRaises(RuntimeError):
                MODULE['control_action']('caffeine')
        self.assertEqual((self.home/'state/waybar/caffeine').read_text(), 'activated\n')

    def test_failed_restart_restores_persistence_and_reports_failure(self):
        with patch.dict(os.environ, FAIL_RESTART='1'), patch.dict(ENV, SWAY=dict(ENV['SWAY'], game_mode_active=lambda: False)):
            with self.assertRaises(subprocess.CalledProcessError):
                MODULE['control_action']('caffeine')
        self.assertEqual((self.home/'state/waybar/caffeine').read_text(), 'deactivated\n')

    def test_widget_selection_launches_editor_after_panel_selection_returns(self):
        marker = self.home/'widget-args.json'
        self.write_binary('orgm-desktop-widgets', 'import json,sys\nfrom pathlib import Path\nPath('+repr(str(marker))+').write_text(json.dumps(sys.argv[1:]))\n')
        with patch.dict(ENV, control_state=lambda: {}, SWAY=dict(ENV['SWAY'], menu_context=lambda: {}, graphical_selection=lambda _: (True, 'widgets'))):
            MODULE['control']()
        self.assertTrue(marker.exists(), 'Edit widgets must invoke the desktop widget helper')
        self.assertEqual(json.loads(marker.read_text()), ['edit'])


class WaybarStartup(unittest.TestCase):
    def test_both_bars_restore_caffeine_and_clicks_persist_without_restarting_idle(self):
        for compositor in ('sway', 'hyprland'):
            with self.subTest(compositor=compositor), tempfile.TemporaryDirectory() as temporary:
                home = Path(temporary)
                binary = home/'bin'
                binary.mkdir()
                source = ROOT/'dotfiles/config/profiles/wayland/.local/bin/waybar-caffeine-state'
                shutil.copy2(source, binary/'waybar-caffeine-state')
                (binary/'notify-send').write_text('#!/bin/sh\nexit 0\n')
                (binary/'notify-send').chmod(0o755)
                config = home/'config'/('waybar' if compositor == 'sway' else 'waybar-hypr')
                config.mkdir(parents=True)
                # Real effective user overlay for Hyprland, base profile for Sway.
                origin = ROOT/('dotfiles/config/profiles/sway/.config/waybar/config' if compositor == 'sway' else
                               'dotfiles/config/users/osmarg/profiles/hyprland/.config/waybar-hypr/config')
                original = origin.read_text()
                if compositor == 'sway':
                    # Waybar accepts JSONC; the new launcher must not narrow
                    # editable configs to strict JSON or strip URL-like strings.
                    original = '// editable native Waybar config\n'+original.rstrip()[:-1]+',\n"fixture-url":"https://example.test/a/*path*/", /* keep strings */\n}'
                (config/'config').write_text(original)
                (config/'style.css').write_text('/* fixture */')
                env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(home/'config'), XDG_STATE_HOME=str(home/'state'),
                           XDG_CACHE_HOME=str(home/'cache'), PATH=str(binary)+os.pathsep+os.environ['PATH'], DISPLAY='', WAYLAND_DISPLAY='')
                if compositor == 'sway':
                    generated = home/'waybar-config.json'
                    fake_waybar = binary/'waybar'
                    fake_waybar.write_text('#!'+sys.executable+'\nimport sys\nfrom pathlib import Path\n'
                                          'Path('+repr(str(generated))+').write_text(Path(sys.argv[sys.argv.index("-c")+1]).read_text())\n')
                    fake_waybar.chmod(0o755)
                    command = [str(ROOT/'dotfiles/config/profiles/sway/.local/bin/orgm-sway-waybar')]
                else:
                    monitors = home/'monitors.json'
                    monitors.write_text('[{"name":"eDP-1","description":"Panel","focused":true}]')
                    env['HYPR_DISPLAY_TARGETS_MONITORS_JSON'] = str(monitors)
                    command = [str(ROOT/'dotfiles/config/profiles/hyprland/.local/bin/hypr-display-targets'), 'waybar-config', str(config)]
                def generate():
                    result = subprocess.run(command, env=env, check=True, capture_output=True, text=True)
                    data = json.loads((generated if compositor == 'sway' else Path(result.stdout.strip())).read_text())
                    if compositor == 'sway':
                        self.assertEqual(data['fixture-url'], 'https://example.test/a/*path*/')
                    return data[0] if isinstance(data, list) else data
                first = generate()['idle_inhibitor']
                self.assertIs(first.get('start-activated'), False)
                self.assertIn('on-click', first, 'Native bar clicks must persist the same state used by control center')
                subprocess.run(first['on-click'], env=env, shell=True, check=True)
                second = generate()['idle_inhibitor']
                self.assertIs(second['start-activated'], True)
                subprocess.run(second['on-click'], env=env, shell=True, check=True)
                self.assertIs(generate()['idle_inhibitor']['start-activated'], False)
                self.assertEqual((config/'config').read_text(), original, 'Generate runtime config, never rewrite editable source')


if __name__ == '__main__':
    unittest.main()
