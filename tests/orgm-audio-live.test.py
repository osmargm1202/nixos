#!/usr/bin/env python3
"""Verify Discord clients can set the active microphone volume.

Run with PACTL=/path/to/pactl python3 tests/orgm-audio-live.test.py.
The test requests the current volume, without recording or playing audio.
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
subprocess.run([pactl, 'set-source-volume', source, *original], env=test_env, check=True)
assert volume() == before, 'Setting the current volume changed the microphone volume'
print('PASS: Discord clients can set microphone volume')
