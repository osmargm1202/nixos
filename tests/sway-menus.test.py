#!/usr/bin/env python3
"""Profile previews, menu fallback/dispatch and power confirmation boundaries."""
import json
import os
from pathlib import Path
import runpy
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
MODULE = runpy.run_path(str(ROOT/'dotfiles/config/profiles/sway/.local/bin/orgm-sway'))
ENV = MODULE['main'].__globals__


class Menus(unittest.TestCase):
    def test_profile_previews_use_each_saved_wallpaper_without_mutating_state(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            state = home/'state/orgm-visual-profile'
            state.mkdir(parents=True)
            (state/'current').write_text('slc\n')
            for name, suffix in (('slc', '.png'), ('orgm', '.mp4')):
                image = home/(name+suffix)
                image.touch()
                saved = state/'profiles'/name/'wallpaper'
                saved.parent.mkdir(parents=True)
                saved.write_text(str(image)+'\n')
            calls = []
            def preview(path):
                calls.append(path)
                return home/(path.stem+'.png')
            with patch.dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(home/'.config'),
                            XDG_STATE_HOME=str(home/'state')), patch.dict(
                    ENV, query=lambda _: [], wallpaper_preview=preview):
                data = MODULE['profile_catalog']()
            self.assertEqual(data['current'], 'slc')
            self.assertEqual([item['id'] for item in data['items']], ['slc', 'orgm', 'osmar'])
            self.assertEqual(data['items'][0]['preview'], (home/'slc.png').as_uri())
            self.assertEqual(data['items'][1]['preview'], (home/'orgm.png').as_uri())
            self.assertEqual(data['items'][2]['preview'], '')
            self.assertEqual(calls, [home/'slc.png', home/'orgm.mp4'])
            self.assertEqual((state/'current').read_text(), 'slc\n')

    def test_cancelled_graphical_menus_never_open_fallback_or_run_actions(self):
        with patch.dict(ENV, graphical_selection=lambda _: (True, ''),
                        menu_context=lambda: {}, profile_catalog=lambda: {},
                        pick=lambda *a: self.fail('Cancellation must not open Rofi'),
                        run=lambda *a, **kw: self.fail('Cancellation must not run actions')):
            MODULE['power']()
            MODULE['profiles']()

    def test_profile_dispatch_allows_only_known_ids_and_preserves_waybar(self):
        for selection in ('orgm', '../../bad'):
            calls = []
            with patch.dict(ENV, graphical_selection=lambda _: (True, selection),
                            profile_catalog=lambda: {}, run=lambda *a, **kw: calls.append((a, kw))):
                MODULE['profiles']()
            if selection == 'orgm':
                self.assertEqual(calls[0][0][1:], ('set', 'orgm'))
                self.assertEqual(calls[0][1]['env']['ORGM_VISUAL_PROFILE_KEEP_WAYBAR'], '1')
            else:
                self.assertFalse(calls)

    def test_power_graphical_result_dispatches_only_known_confirmed_actions(self):
        for selection, expected in (('Apagar', [('systemctl', 'poweroff')]),
                                    ('Suspender', [('orgm-qylock', 'lock'), ('systemctl', 'suspend')]),
                                    ('arbitrary command', [])):
            calls = []
            with patch.dict(ENV, graphical_selection=lambda _: (True, selection), menu_context=lambda: {},
                            pick=lambda *a: self.fail('QML has already confirmed this selection'),
                            run=lambda *a: calls.append(a)):
                MODULE['power']()
            self.assertEqual(calls, expected)

    def test_rofi_power_fallback_retains_confirmation(self):
        calls = []
        choices = iter(['Apagar', 'Cancelar'])
        with patch.dict(ENV, graphical_selection=lambda _: (False, ''), menu_context=lambda: {},
                        pick=lambda *a: next(choices), run=lambda *a: calls.append(a)):
            MODULE['power']()
        self.assertFalse(calls)

    def test_rofi_launcher_reads_validated_active_palette(self):
        with patch.dict(ENV, menu_colors=lambda: dict(bg='#123456', surface='#234567', fg='#ffffff',
                        muted='#888888', accent='#abcdef', error='#ff0000')):
            result = MODULE['launcher_theme']()
        self.assertIn('bg-panel: #123456eb;', result)
        self.assertIn('accent: #abcdef;', result)


if __name__ == '__main__':
    unittest.main()
