#!/usr/bin/env python3
"""The installed shared layer must provide the same public Sway menu contracts."""
from pathlib import Path
import runpy
import unittest

ROOT = Path(__file__).resolve().parents[1]
SHARED = ROOT/'dotfiles/config/profiles/wayland/.local/lib/orgm-wayland'


class Shared(unittest.TestCase):
    def test_shared_ui_and_sway_entrypoints(self):
        self.assertTrue((SHARED/'shell.py').is_file(), 'shared shell core missing')
        self.assertTrue((SHARED/'desktop.py').is_file(), 'shared desktop core missing')
        script = ROOT/'dotfiles/config/profiles/sway/.local/bin/orgm-sway'
        module = runpy.run_path(str(script))
        self.assertEqual(module['main'].__code__.co_filename, str(SHARED/'shell.py'))
        self.assertEqual(module['launcher_theme'].__globals__['ENTRYPOINT'], str(script))
        ui = ROOT/'dotfiles/config/profiles/wayland/.config/quickshell/orgm-wallpapers'
        self.assertTrue((ui/'daemon.qml').is_file())


if __name__ == '__main__':
    unittest.main()
