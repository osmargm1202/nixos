#!/usr/bin/env python3
"""Browser pin migration preserves unrelated entries, backups and repeatability."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

script = Path(__file__).resolve().parents[1]/'nixos/apps/browser-pins.py'
with tempfile.TemporaryDirectory(prefix='origin-pins-') as temporary:
    home = Path(temporary)
    (home/'cache').mkdir()
    (home/'runtime').mkdir()
    (home/'config/nwg-dock-hyprland').mkdir(parents=True)
    pins = home/'cache/nwg-dock-pinned'
    before = 'kitty\nchromium-browser\nfirefox\nchrome-a__-Default\ncustom-app\n'
    pins.write_text(before)
    link = home/'config/nwg-dock-hyprland/pinned'
    link.symlink_to(pins)
    mapping = home/'map.json'
    mapping.write_text(json.dumps({'firefox':'brave-origin', 'chromium-browser':'brave-origin', 'chrome-a__-Default':'brave-a__-Default'}))
    env = dict(os.environ, HOME=str(home), XDG_CACHE_HOME=str(home/'cache'), XDG_CONFIG_HOME=str(home/'config'), XDG_STATE_HOME=str(home/'state'), XDG_RUNTIME_DIR=str(home/'runtime'))
    subprocess.run(['python3', str(script), str(mapping)], env=env, check=True)
    expected = 'kitty\nbrave-origin\nbrave-a__-Default\ncustom-app\n'
    assert pins.read_text() == expected
    backup = home/'state/orgm-origin/pins-0.before-origin'
    assert backup.read_text() == before
    assert link.is_symlink()
    subprocess.run(['python3', str(script), str(mapping)], env=env, check=True)
    assert pins.read_text() == expected and backup.read_text() == before
print('PASS: exact pin migration, duplicate collapse, unrelated entries, symlinks, backups and repeatability')
