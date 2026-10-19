#!/usr/bin/env python3
"""Validate Lua with the real Hyprland parser in a disposable HOME (no compositor)."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
binary = os.environ.get('ORGM_TEST_HYPRLAND') or shutil.which('Hyprland')
if not binary:
    raise SystemExit('SKIP: Hyprland parser unavailable')
with tempfile.TemporaryDirectory(prefix='hv-') as tmp:
    home = Path(tmp)
    config = home/'.config/hypr'
    shutil.copytree(ROOT/'dotfiles/config/profiles/hyprland/.config/hypr', config)
    shutil.copytree(ROOT/'dotfiles/config/users/osmarg/profiles/hyprland/.config/hypr', config, dirs_exist_ok=True)
    runtime = home/'r'
    runtime.mkdir(mode=0o700)
    env = dict(os.environ, HOME=tmp, XDG_CONFIG_HOME=str(home/'.config'), XDG_RUNTIME_DIR=str(runtime),
               HYPRLAND_NO_SD_NOTIFY='1', HYPRLAND_NO_SD_VARS='1')
    for name in ('HYPRLAND_INSTANCE_SIGNATURE', 'SWAYSOCK', 'I3SOCK', 'DBUS_SESSION_BUS_ADDRESS',
                 'DISPLAY', 'WAYLAND_DISPLAY', 'WAYLAND_SOCKET'):
        env.pop(name, None)
    result = subprocess.run([binary, '--verify-config', '--config', str(config/'hyprland.lua')],
                            env=env, capture_output=True, text=True, timeout=20)
    assert result.returncode == 0, result.stdout + result.stderr
print('PASS: real Hyprland Lua parser; rendered Hyprland/hardware session not exercised')
