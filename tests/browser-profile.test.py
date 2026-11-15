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
    state = root/'Local State'
    before_state = {'brave': {'origin': {'free_tier_accepted': True}, 'widevine_opted_in': False}, 'custom': {'retained': 456}}
    state.write_text(json.dumps(before_state))
    env = dict(os.environ, XDG_CONFIG_HOME=str(config))
    (root/'SingletonLock').symlink_to('fixture-host-123')
    subprocess.run(['python3', str(script)], env=env, check=True, capture_output=True)
    assert json.loads(preferences.read_text()) == before
    assert json.loads(state.read_text()) == before_state
    (root/'SingletonLock').unlink()
    subprocess.run(['python3', str(script)], env=env, check=True)
    after = json.loads(preferences.read_text())
    assert after['brave']['tabs']['vertical_tabs_enabled'] is True
    assert after['custom'] == before['custom'] and after['brave']['tabs']['other'] == 'retained'
    backup = root/'.orgm-before-origin/Default/Preferences'
    assert json.loads(backup.read_text()) == before and backup.stat().st_mode & 0o777 == 0o600
    after_state = json.loads(state.read_text())
    assert after_state['brave']['origin']['free_tier_accepted'] is True
    assert after_state['brave']['widevine_opted_in'] is True
    assert after_state['custom'] == before_state['custom']
    state_backup = root/'.orgm-before-origin/Local State'
    assert json.loads(state_backup.read_text()) == before_state
    assert state_backup.stat().st_mode & 0o777 == 0o600
    state_mtime = state.stat().st_mtime_ns
    subprocess.run(['python3', str(script)], env=env, check=True)
    assert json.loads(backup.read_text()) == before
    assert json.loads(state_backup.read_text()) == before_state
    assert state.stat().st_mtime_ns == state_mtime
print('PASS: live-profile guard, preserved preferences, private backup, Linux free tier, vertical tabs and Widevine opt-in')
