#!/usr/bin/env python3
"""Validate a coherent installed control-center bundle; never contact a desktop.

ORGM_TEST_CONTROL_HOME optionally selects an already staged/copied deployment.
Otherwise seed the real manifest resolver into a disposable home.
"""
import os
from pathlib import Path
import runpy
import subprocess
import tempfile
ROOT=Path(__file__).resolve().parents[1]
def check(home):
    backend=runpy.run_path(str(home/'.local/bin/orgm-sway-desktop'))
    assert 'control_controls' in backend, 'installed backend is the old incomplete control center'
    controls=backend['control_controls'](); ids={c['id'] for c in controls}
    assert len(controls)>35 and {'tablet','keyboard','windows','advanced-audio','wifi','bluetooth','caffeine','workspace-10','power'}<=ids
    ui=(home/'.config/quickshell/orgm-wallpapers/modules/ControlMenu.qml').read_text()
    assert 'state.controls' in ui and 'root.sections' in ui, 'old UI paired with current backend'
    assert 'tablet-mode' not in ui and 'value: "auto"' not in ui
    assert 'property int fontSize:' in (home/'.config/quickshell/orgm-wallpapers/components/MenuButton.qml').read_text()
    tablet=runpy.run_path(str(home/'.local/lib/orgm-wayland/tablet.py'))
    assert 'set_policy' in tablet and 'bar_config' in tablet, 'old automatic tablet policy'
    for path in ('.local/bin/orgm-osk','.local/bin/orgm-session-dock','.config/quickshell/orgm-osk/shell.qml','.config/quickshell/orgm-tablet-dock/shell.qml'):
        assert (home/path).is_file(), 'missing dependency '+path
    assert "'bar-config'" in (home/'.local/bin/orgm-sway-waybar').read_text(), 'Waybar wrapper ignores tablet profile'
    print('PASS: coherent installed UI/backend, complete catalog, manual tablet, shared keyboard and bar/dock dependencies')
if os.environ.get('ORGM_TEST_CONTROL_HOME'):
    check(Path(os.environ['ORGM_TEST_CONTROL_HOME']))
else:
    with tempfile.TemporaryDirectory(prefix='control-deployment-') as temp:
        for app in ('sway','sway-tools','wayland-tools','sway-wallpapers','on-screen-keyboard'):
            subprocess.run(['orgm-dot','--repo',str(ROOT),'--home',temp,'--profile','sway','--user','jarq','--host','jarq','pull',app],check=True,capture_output=True)
        check(Path(temp))
