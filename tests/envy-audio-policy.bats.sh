#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
ORGM_TEST_LUA="$(bash "$ROOT/tests/helpers/declared-lua.sh" "$ROOT")"
export ORGM_TEST_LUA
python3 - "$ROOT" <<'PY'
import json, os, re, subprocess, sys, tempfile
from pathlib import Path
root = Path(sys.argv[1])
expression = '''c: {
  policies = c.services.pipewire.wireplumber.extraConfig;
  package = toString c.services.pipewire.wireplumber.package;
  sway = c.programs.sway.enable;
  ryoku = c.programs.ryoku.enable or false;
}'''
result = subprocess.run(['nix', 'eval', '--json',
    '.#nixosConfigurations.envy.config', '--apply', expression],
    text=True, capture_output=True, check=True)
config = json.loads(result.stdout)
assert config['sway'] and not config['ryoku'], 'exercise the active Envy desktop audio controls'
policy = config['policies'].get('90-envy-audio-policy')
assert policy is not None, 'Envy must declare persistent 150% integrated-audio defaults'
assert policy['wireplumber.settings']['device.restore-routes'] is True
rules = policy['monitor.alsa.rules']
assert len(rules) == 1
match = rules[0]['matches'][0]['device.name']
assert match.startswith('~')
assert re.fullmatch(match[1:], 'alsa_card.pci-0000_00_1f.3-platform-skl_hda_dsp_generic')
assert re.fullmatch(match[1:], 'alsa_card.pci-0000_00_1f.3')
assert not re.fullmatch(match[1:], 'alsa_card.usb-Headset-00')
assert not re.fullmatch(match[1:], 'bluez_card.AA_BB_CC_DD_EE_FF')
props = rules[0]['actions']['update-props']
assert props['device.routes.default-sink-volume'] == 3.375, '150% needs cubic-scale conversion, not linear1.5'
assert props['device.routes.default-source-volume'] == 3.375
# Global setting schema is capped at1.0; use supported per-device overrides.
assert 'device.routes.default-sink-volume' not in policy['wireplumber.settings']
assert 'device.routes.default-source-volume' not in policy['wireplumber.settings']
lua = os.environ['ORGM_TEST_LUA']
subprocess.run([lua, str(root/'tests/envy-audio-policy.lua'),
    str(Path(config['package'])/'share/wireplumber/scripts/device/apply-routes.lua'),
    str(props['device.routes.default-sink-volume']),
    str(props['device.routes.default-source-volume'])], check=True)
# The current Sway controls must not bring a boosted route back to 100%.
# Execute the installed helpers, replacing only the hardware/daemon CLIs.
profile = root/'dotfiles/config/profiles/sway'
bar = json.loads((profile/'.config/waybar/config').read_text())
for module, helper in (('pulseaudio', 'sway-volume-osd'),
        ('pulseaudio#microphone', 'sway-mic-volume-osd')):
    assert bar[module]['max-volume'] == 150
    assert bar[module]['on-scroll-up'] == helper + ' up'
    assert bar[module]['on-scroll-down'] == helper + ' down'
with tempfile.TemporaryDirectory() as temporary:
    home = Path(temporary)
    (home/'bin').mkdir()
    # An unavailable OSD forces the actual hardware fallback. Never contact
    # the user's daemon/PipeWire instance, even when qs is installed in PATH.
    (home/'bin/qs').write_text('#!/bin/sh\nexit 1\n')
    (home/'bin/qs').chmod(0o755)
    cli = home/'bin/pamixer'
    cli.write_text('#!' + sys.executable + '\nimport json,os,sys\n'
        'args=sys.argv[1:]\n'
        'with open(os.environ["CAPTURE"],"a") as f: f.write(json.dumps(args)+"\\n")\n'
        'if "--get-volume" in args: print("150")\n'
        'if "--get-mute" in args: print("false")\n')
    cli.chmod(0o755)
    env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(home/'.config'),
        PATH=str(home/'bin')+':'+os.environ['PATH'], CAPTURE=str(home/'capture.json'))
    for helper, prefix in (('sway-volume-osd', []),
            ('sway-mic-volume-osd', ['--default-source'])):
        for action, arguments in (('up', ['--allow-boost', '--set-limit', '150', '-i', '3']),
                ('down', ['--allow-boost', '--set-limit', '150', '-d', '3']),
                ('mute', ['-t'])):
            (home/'capture.json').unlink(missing_ok=True)
            subprocess.run([str(profile/'.local/bin'/helper), action], env=env, check=True)
            calls = [json.loads(line) for line in (home/'capture.json').read_text().splitlines()]
            assert calls == [prefix + arguments, prefix + ['--get-volume'],
                prefix + ['--get-mute']], (helper, action, calls)
print('PASS: actual Sway output/microphone helpers preserve150% boost, volume steps and mute')
# Also exercise the active daemon branch: one adjustment, no second pamixer write.
subprocess.run([sys.executable, str(root/'tests/sway-desktop.test.py'),
    'Desktop.test_audio_keys_use_one_native_adjustment_or_pamixer_without_notifications'], check=True)
# A host-local change must not redefine another host's audio policy.
for host in ('lenovo', 'orgm', 'orgm-ryoku', 'ero', 'jarq'):
    policies = json.loads(subprocess.check_output(['nix', 'eval', '--json',
        f'.#nixosConfigurations.{host}.config.services.pipewire.wireplumber.extraConfig'], text=True))
    assert '90-envy-audio-policy' not in policies, host
print('PASS: Envy integrated card defaults150%, saved manual routes preserved, other devices/hosts isolated')
PY
