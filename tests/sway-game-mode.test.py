#!/usr/bin/env python3
"""Gaming transitions, configuration restoration, and wallpaper suppression."""
import json
import os
from pathlib import Path
import runpy
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
MODULE = runpy.run_path(str(ROOT/'dotfiles/config/profiles/sway/.local/bin/sway-game-mode'))
ENV = MODULE['main'].__globals__


class Gaming(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.home = Path(temporary.name)
        self.config = self.home/'.config/sway'
        self.config.mkdir(parents=True)
        self.state = self.home/'.local/state/orgm-sway'
        self.environment = patch.dict(os.environ, HOME=str(self.home),
            XDG_CONFIG_HOME=str(self.home/'.config'), XDG_STATE_HOME=str(self.home/'.local/state'))
        self.environment.start()
        self.addCleanup(self.environment.stop)
        (self.config/'config').write_text('set $dock_gap 37\ngaps inner 7\ngaps outer 9\n'
            'gaps right $dock_gap\ndefault_dim_inactive 0.07\n'
            'for_window [app_id="kitty"] opacity 0.83\n'
            'include extras.conf\ninclude game-mode.conf\n')
        (self.config/'extras.conf').write_text('for_window [class="example"] opacity 0.75\n')
        self.calls = []
        self.active = True

    def query(self, kind):
        if kind == 'get_version':
            return {'loaded_config_file_name': str(self.config/'config')}
        return [{'layer_shell_surfaces': [{'namespace': 'private-panel'}]}]

    def unit(self, action):
        self.calls.append(('dock', action))
        if action == 'is-active':
            return subprocess.CompletedProcess([], 0 if self.active else 3)
        self.active = action == 'start'
        return subprocess.CompletedProcess([], 0)

    def test_round_trip_preserves_configured_values_and_original_wallpaper(self):
        helpers = dict(ENV['SWAY'], hide_wallpaper=lambda: self.calls.append(('hide',)),
                       wallpaper=lambda: self.calls.append(('restore-wallpaper',)))
        with patch.dict(ENV, query=self.query, unit=self.unit, SWAY=helpers,
                        ipc=lambda c: self.calls.append(('ipc', c))):
            MODULE['main']('on')
            self.assertTrue(MODULE['read_state']()['enabled'])
            self.assertFalse(self.active)
            self.assertIn(('ipc', '[all] opacity 1'), self.calls)
            self.assertIn(('ipc', 'gaps outer all set 0'), self.calls)
            self.assertIn(('ipc', 'gaps right all set 0'), self.calls)
            self.assertIn('gaps right 0', (self.config/'game-mode.conf').read_text())
            self.assertIn(('hide',), self.calls)
            self.assertIn('for_window [all] opacity 1', (self.config/'game-mode.conf').read_text())
            MODULE['main']('off')
        self.assertFalse(MODULE['read_state']()['enabled'])
        self.assertTrue(self.active)
        self.assertIn(('ipc', 'gaps right all set 37'), self.calls)
        self.assertIn(('ipc', '[app_id="kitty"] opacity 0.83'), self.calls)
        self.assertIn(('ipc', '[class="example"] opacity 0.75'), self.calls)
        self.assertEqual(self.calls[-1], ('restore-wallpaper',))

    def test_inactive_dock_is_never_enabled_when_restoring(self):
        self.active = False
        helpers = dict(ENV['SWAY'], hide_wallpaper=lambda: None, wallpaper=lambda: None)
        with patch.dict(ENV, query=self.query, unit=self.unit, SWAY=helpers, ipc=lambda _: None):
            MODULE['main']('on')
            MODULE['main']('off')
        self.assertNotIn(('dock', 'start'), self.calls)

    def test_reload_sync_owns_gaps_in_both_modes(self):
        config = (ROOT/'dotfiles/config/profiles/sway/.config/sway/config').read_text()
        self.assertNotIn('exec_always swaymsg gaps', config)
        helpers = dict(ENV['SWAY'], hide_wallpaper=lambda: None)
        with patch.dict(ENV, query=self.query, unit=self.unit, SWAY=helpers,
                        ipc=lambda c: self.calls.append(('ipc', c))):
            MODULE['main']('sync')
            self.assertIn(('ipc', 'gaps right all set 37'), self.calls)
            self.assertTrue(all(c[0] == 'ipc' and c[1].startswith('gaps ') for c in self.calls))
            self.state.mkdir(exist_ok=True)
            (self.state/'game-mode.json').write_text('{"enabled":true,"dock":true}')
            self.calls.clear()
            MODULE['main']('sync')
            self.assertIn(('ipc', 'gaps right all set 0'), self.calls)
            self.assertNotIn(('ipc', 'gaps right all set 37'), self.calls)
            self.assertFalse(self.active)
            self.assertIn('gaps right 0', (self.config/'game-mode.conf').read_text())

    def test_failed_transition_rolls_back_state_and_restores_desktop(self):
        def ipc(command):
            if command == 'shadows disable':
                raise RuntimeError('injected effect failure')
        helpers = dict(ENV['SWAY'], hide_wallpaper=lambda: None,
                       wallpaper=lambda: self.calls.append(('restore-wallpaper',)))
        with patch.dict(ENV, query=self.query, unit=self.unit, SWAY=helpers, ipc=ipc):
            with self.assertRaisesRegex(RuntimeError, 'injected'):
                MODULE['main']('on')
        self.assertFalse(MODULE['read_state']()['enabled'])
        self.assertNotIn('blur disable', (self.config/'game-mode.conf').read_text())
        self.assertIn(('restore-wallpaper',), self.calls)

    def test_restore_skips_absent_windows_but_rejects_actual_errors(self):
        command = '[window_type="dialog"] opacity 1'
        for message in ('No matching node.', 'Invalid opacity value'):
            with self.subTest(message=message):
                error = subprocess.CalledProcessError(2, ['swaymsg', command],
                    output=json.dumps([dict(success=False, parse_error=False, error=message)]))
                helpers = dict(ENV['SWAY'], wallpaper=lambda: self.calls.append(('restore-wallpaper',)))
                with patch.dict(ENV, ipc=lambda _: (_ for _ in ()).throw(error), SWAY=helpers):
                    if message == 'No matching node.':
                        MODULE['restore']([command], dict(dock=False))
                        self.assertEqual(self.calls[-1], ('restore-wallpaper',))
                    else:
                        with self.assertRaises(subprocess.CalledProcessError):
                            MODULE['restore']([command], dict(dock=False))

    def test_saved_wallpaper_changes_keep_video_backend_stopped_while_gaming(self):
        self.state.mkdir(parents=True)
        (self.state/'game-mode.json').write_text('{"enabled":true}')
        media = self.home/'movie.mp4'
        preview = self.home/'preview.png'
        media.touch()
        preview.touch()
        helpers = ENV['SWAY']['main'].__globals__
        calls = []
        with patch.dict(helpers, wallpaper_preview=lambda _: preview,
                        stop_session_wallpaper_players=lambda: None,
                        ipc=lambda c: calls.append(c),
                        wallpaper_tool=lambda _: self.fail('Gaming must not need a video player'),
                        start_wallpaper_video=lambda _: self.fail('Video must remain stopped')):
            ENV['SWAY']['set_wallpaper'](media, record=False)
        self.assertEqual(calls, ['output * bg #000000 solid_color'])
        self.assertEqual((self.config/'wallpaper').read_text().strip(), str(media))

    def test_waybar_exposes_the_toggle_next_to_caffeine(self):
        bar = json.loads((ROOT/'dotfiles/config/profiles/sway/.config/waybar/config').read_text())
        self.assertEqual(bar['modules-left'][bar['modules-left'].index('idle_inhibitor')+1], 'custom/game_mode')
        self.assertEqual(bar['custom/game_mode']['on-click'], 'sway-game-mode toggle')


if __name__ == '__main__':
    unittest.main()
