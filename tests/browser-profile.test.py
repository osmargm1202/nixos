#!/usr/bin/env python3
"""Origin preference migration must preserve existing data and never write a live profile."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

script = Path(__file__).resolve().parents[1]/'nixos/apps/browser-profile.py'
with tempfile.TemporaryDirectory(prefix='origin-profile-') as temporary:
    config = Path(temporary)
    root = config/'BraveSoftware/Brave-Origin'
    (root/'Default').mkdir(parents=True)
    preferences = root/'Default/Preferences'
    before = {'custom': {'retained': 123}, 'brave': {'tabs': {'vertical_tabs_enabled': False, 'other': 'retained'}}}
    preferences.write_text(json.dumps(before))
    env = dict(os.environ, XDG_CONFIG_HOME=str(config))
    (root/'SingletonLock').symlink_to('fixture-host-123')
    subprocess.run(['python3', str(script)], env=env, check=True, capture_output=True)
    assert json.loads(preferences.read_text()) == before
    (root/'SingletonLock').unlink()
    subprocess.run(['python3', str(script)], env=env, check=True)
    after = json.loads(preferences.read_text())
    assert after['brave']['tabs']['vertical_tabs_enabled'] is True
    assert after['custom'] == before['custom'] and after['brave']['tabs']['other'] == 'retained'
    backup = root/'.orgm-before-origin/Default/Preferences'
    assert json.loads(backup.read_text()) == before and backup.stat().st_mode & 0o777 == 0o600
    assert json.loads((root/'Local State').read_text())['brave']['origin']['free_tier_accepted'] is True
    subprocess.run(['python3', str(script)], env=env, check=True)
    assert json.loads(backup.read_text()) == before
print('PASS: live-profile guard, preserved preferences, private backup, Linux free tier and vertical tabs')
