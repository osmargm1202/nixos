#!/usr/bin/env python3
"""Widget config/launcher boundaries, with a private HOME and real JS models."""
import json
import os
from pathlib import Path
import runpy
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT/'dotfiles/config/profiles/wayland'
LAUNCHER = BASE/'.local/bin/orgm-desktop-widgets'


class Widgets(unittest.TestCase):
    def setUp(self):
        self.assertTrue(LAUNCHER.exists(), 'standalone widget launcher missing')
        self.module = runpy.run_path(str(LAUNCHER))

    def test_default_clock_is_original_digital_24h(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp)/'orgm-desktop/widgets.json'
            settings = self.module['load_settings'](path)
            self.assertEqual((settings['clockDesign'], settings['clock24h'],
                              settings['clockSeconds'], settings['dateShow']),
                             ('digital', True, False, True))
            self.assertFalse(path.exists(), 'reading defaults must not write HOME')

    def test_invalid_settings_are_safe_without_overwriting(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp)/'widgets.json'
            for text in ('broken', '[]', '{"clockScale": -3, "clockX": "bad", "clock24h": "no"}'):
                path.write_text(text)
                settings = self.module['load_settings'](path)
                self.assertGreater(settings['clockScale'], 0)
                self.assertIsInstance(settings['clockX'], (int, float))
                self.assertIs(settings['clock24h'], True)
                self.assertEqual(path.read_text(), text)

    def test_launcher_uses_private_config_and_does_not_read_ryoku(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            config = home/'config'
            own = config/'orgm-desktop/widgets.json'
            own.parent.mkdir(parents=True)
            own.write_text('{"clock24h": false, "clockX": 140}')
            ryoku = config/'ryoku/widgets.json'
            ryoku.parent.mkdir()
            ryoku.write_text('{"clock24h": true, "clockX": 777}')
            env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(config))
            result = subprocess.run([str(LAUNCHER), 'settings'], env=env,
                                    capture_output=True, text=True, check=True)
            settings = json.loads(result.stdout)
            self.assertIs(settings['clock24h'], False)
            self.assertEqual(settings['clockX'], 140)
            self.assertEqual(ryoku.read_text(), '{"clock24h": true, "clockX": 777}')

    def update(self, config, patch, screen=''):
        env = dict(os.environ, XDG_CONFIG_HOME=str(config))
        return subprocess.run([str(LAUNCHER), 'update', json.dumps(patch), screen],
                              env=env, capture_output=True, text=True)

    def test_position_update_is_private_and_preserves_other_settings(self):
        with tempfile.TemporaryDirectory() as tmp:
            config = Path(tmp); path = config/'orgm-desktop/widgets.json'
            path.parent.mkdir()
            path.write_text('{"clock24h":false,"custom":"keep","screens":{"HDMI-A-1":{"clockX":60}}}')
            result = self.update(config, {'clockX': 300, 'clockY': 180}, 'DP-3')
            self.assertEqual(result.returncode, 0, result.stderr)
            saved = json.loads(path.read_text())
            self.assertEqual(saved['screens']['DP-3'], {'clockX': 300, 'clockY': 180})
            self.assertEqual(saved['screens']['HDMI-A-1']['clockX'], 60)
            self.assertEqual(saved['custom'], 'keep')
            self.assertIs(saved['clock24h'], False)
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
            self.assertEqual(json.loads(result.stdout)['screens']['DP-3']['clockY'], 180)

    def test_visibility_update_survives_a_new_launcher(self):
        with tempfile.TemporaryDirectory() as tmp:
            config = Path(tmp)
            result = self.update(config, {'clockEnabled': False, 'calendarEnabled': True})
            self.assertEqual(result.returncode, 0, result.stderr)
            result = subprocess.run([str(LAUNCHER), 'settings'], env=dict(os.environ, XDG_CONFIG_HOME=tmp),
                                    capture_output=True, text=True, check=True)
            self.assertIs(json.loads(result.stdout)['clockEnabled'], False)

    def test_invalid_writes_never_replace_existing_preferences(self):
        with tempfile.TemporaryDirectory() as tmp:
            config = Path(tmp); path = config/'orgm-desktop/widgets.json'; path.parent.mkdir()
            for original, patch, screen in [
                ('{"clockX":72}', {'clockX': '300'}, 'DP-3'),
                ('{"clockX":72}', {'clockX': -1}, 'DP-3'),
                ('{"clockX":72}', {'clockEnabled': 'false'}, ''),
                ('{"clockX":72}', {'command': 'exit'}, ''),
                ('broken JSON', {'clockEnabled': False}, ''),
            ]:
                path.write_text(original)
                result = self.update(config, patch, screen)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(path.read_text(), original)

    def test_symlinked_preferences_are_not_written_through(self):
        with tempfile.TemporaryDirectory() as tmp:
            config = Path(tmp); path = config/'orgm-desktop/widgets.json'; path.parent.mkdir()
            external = config/'external.json'; external.write_text('{"clockX":99}')
            path.symlink_to(external)
            result = self.update(config, {'clockEnabled': False})
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(external.read_text(), '{"clockX":99}')
            self.assertTrue(path.is_symlink())

    def test_concurrent_monitor_updates_do_not_lose_each_other(self):
        with tempfile.TemporaryDirectory() as tmp:
            config = Path(tmp)
            env = dict(os.environ, XDG_CONFIG_HOME=tmp)
            jobs = [subprocess.Popen([str(LAUNCHER), 'update', json.dumps(patch), screen], env=env,
                                     stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                    for patch, screen in [({'clockX': 220, 'clockY': 100}, 'DP-3'),
                                          ({'calendarX': 40, 'calendarY': 30}, 'DP-2')]]
            results = [job.communicate(timeout=5) for job in jobs]
            for job, (out, err) in zip(jobs, results):
                self.assertEqual(job.returncode, 0, err)
            saved = json.loads((config/'orgm-desktop/widgets.json').read_text())
            self.assertEqual(saved['screens']['DP-3']['clockX'], 220)
            self.assertEqual(saved['screens']['DP-2']['calendarY'], 30)

    def test_calendar_leap_year_and_year_boundary(self):
        model = BASE/'.config/quickshell/orgm-desktop/lib/calendar.js'
        script = '''const assert=require('assert'); const m=require(process.argv[1]);
          assert.equal(m.daysInMonth(2024,1),29);
          assert.deepEqual(m.shiftMonth(2026,11,1),{year:2027,month:0});
          const days=m.buildRange(new Date(2024,1,29,12),2024,1,6,1);
          assert.equal(days.length,42);
          assert.equal(days.filter(d=>d.today).length,1);
          assert.equal(days.filter(d=>d.today)[0].key,'2024-02-29');
          assert.equal(days[0].column,0);
          assert.equal(m.isoWeek(new Date(2021,0,1)).week,53);'''
        subprocess.run(['node', '-e', script, str(model)], check=True)


if __name__ == '__main__':
    unittest.main()
