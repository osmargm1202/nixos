#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RYOKU_TEST_REPO="$ROOT" python3 - <<'PY'
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

repo = Path(os.environ['RYOKU_TEST_REPO'])
with tempfile.TemporaryDirectory() as tmp:
    root = Path(tmp)
    config = root / 'config'
    cache = root / 'cache'
    (config / 'orgm-ryoku').mkdir(parents=True)
    (config / 'rofi').mkdir()
    (cache / 'ryoku').mkdir(parents=True)
    for target in ('orgm-ryoku/rofi.rasi', 'rofi/config.rasi'):
        shutil.copy2(repo / 'dotfiles/config/profiles/ryoku/.config' / target, config / target)
    env = dict(os.environ, XDG_CONFIG_HOME=str(config), XDG_CACHE_HOME=str(cache))
    script = repo / 'nixos/profiles/ryoku/rofi-theme.sh'
    def update():
        subprocess.run(['bash', str(script)], env=env, check=True)
        return (config / 'orgm-ryoku/rofi-colors.rasi').read_text()

    assert 'ryoku-bg: #1f1f25ee;' in update(), 'fresh session needs fallback colors'
    palette = cache / 'ryoku/colors.json'
    palette.write_text(json.dumps({'surfaceContainer': '#010203', 'primary': '#ffddee',
                                  'onSurface': 'invalid color; window { border: 5px; }'}))
    colors = update()
    assert 'ryoku-bg: #010203ee;' in colors
    assert 'ryoku-accent: #ffddee;' in colors
    assert 'ryoku-fg: #e4e1e9;' in colors
    assert 'invalid color' not in colors
    rendered = subprocess.check_output(['rofi', '-config', str(config / 'rofi/config.rasi'),
                                        '-dump-theme'], env=env, text=True)
    assert re.search(r'ryoku-bg:\s+rgba\s*\(\s*1,\s*2,\s*3,', rendered), rendered
    assert 'border-radius:' in rendered
    palette.write_text('incomplete JSON')
    assert 'ryoku-bg: #1f1f25ee;' in update()
print('PASS: Rofi parses the Ryoku theme, follows its palette and handles missing/invalid colors')
PY
