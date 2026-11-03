#!/usr/bin/env python3
"""Verify the applied Discord quirk without recording or playing audio.

Run with PACTL=/path/to/pactl python3 tests/orgm-audio-live.test.py.
A failed policy may briefly lower the source volume; always restore it.
"""
import json
import os
import shutil
import subprocess

pactl = os.environ.get('PACTL') or shutil.which('pactl')
assert pactl, 'Provide PACTL or run inside nix shell nixpkgs#pulseaudio'
source = 'alsa_input.usb-C-Media_Electronics_Inc._Mpow_HC_20170817-00.mono-fallback'


def volume():
    sources = json.loads(subprocess.check_output([pactl, '-f', 'json', 'list', 'sources']))
    return next(s['volume'] for s in sources if s['name'] == source)


before = volume()
original = [str(v['value']) for v in before.values()]
test_env = {
    **os.environ,
    'LC_ALL': 'C',
    'PULSE_PROP': 'application.process.binary=Discord application.name=orgm-audio-policy-test',
}
try:
    result = subprocess.run(
        [pactl, 'set-source-volume', source, '70%'],
        env=test_env, text=True, capture_output=True,
    )
    assert result.returncode != 0 and 'Access denied' in result.stderr, result.stderr
    assert volume() == before, 'Discord client changed physical microphone volume'
finally:
    subprocess.run([pactl, 'set-source-volume', source, *original], check=True)
print('PASS: Discord cannot change physical microphone volume')
