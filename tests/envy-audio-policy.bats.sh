#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
python3 - "$ROOT" <<'PY'
import json, os, re, subprocess, sys, tempfile
from pathlib import Path
root = Path(sys.argv[1])
expression = '''c: {
  policies = c.services.pipewire.wireplumber.extraConfig;
  package = toString c.services.pipewire.wireplumber.package;
}'''
result = subprocess.run(['nix', 'eval', '--json',
    '.#nixosConfigurations.envy.config', '--apply', expression],
    text=True, capture_output=True, check=True)
config = json.loads(result.stdout)
config['audioDefaults'] = json.loads((root/'dotfiles/config/profiles/ryoku/.config/orgm-ryoku/audio-defaults.json').read_text())
assert config['audioDefaults'] == {'audioBoost': True}, 'Ryoku UI/media-key limit must allow150%, not just PipeWire'
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
lua = os.environ.get('LUA_BIN', 'lua')
subprocess.run([lua, str(root/'tests/envy-audio-policy.lua'),
    str(Path(config['package'])/'share/wireplumber/scripts/device/apply-routes.lua'),
    str(props['device.routes.default-sink-volume']),
    str(props['device.routes.default-source-volume'])], check=True)
# Execute the pinned media-key helper, replacing only the real hardware CLI.
# A missing/false native flag reproduces the user's hard100% control cap.
upstream = subprocess.check_output(['nix', 'eval', '--raw', '--impure', '--expr',
    f'(builtins.getFlake {json.dumps("path:" + str(root))}).inputs.ryoku.outPath'], text=True).strip()
with tempfile.TemporaryDirectory() as temporary:
    home = Path(temporary)
    (home/'bin').mkdir()
    (home/'.config/ryoku').mkdir(parents=True)
    cli = home/'bin/wpctl'
    cli.write_text('#!/usr/bin/env python3\nimport json,os,sys\n'
        'if sys.argv[1]=="get-volume": print("Volume: 1.45")\n'
        'else: open(os.environ["CAPTURE"],"w").write(json.dumps(sys.argv[1:]))\n')
    cli.chmod(0o755)
    env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(home/'.config'),
        PATH=str(home/'bin')+':'+os.environ['PATH'], CAPTURE=str(home/'capture.json'))
    for boost, limit, percentage in ((False, '1', '100%'),
            (config['audioDefaults']['audioBoost'], '1.5', '150%')):
        (home/'.config/ryoku/shell.json').write_text(json.dumps({'qsbar': {'audioBoost': boost}}))
        subprocess.run(['bash', upstream+'/system/hardware/audio/ryoku-volume', 'up'], env=env, check=True)
        assert json.loads((home/'capture.json').read_text()) == [
            'set-volume', '-l', limit, '@DEFAULT_AUDIO_SINK@', percentage]
print('PASS: actual Ryoku media-key helper reaches150% with the declared native boost flag')
# A host-local change must not redefine another host's audio policy.
for host in ('lenovo', 'orgm', 'ero', 'jarq'):
    policies = json.loads(subprocess.check_output(['nix', 'eval', '--json',
        f'.#nixosConfigurations.{host}.config.services.pipewire.wireplumber.extraConfig'], text=True))
    assert '90-envy-audio-policy' not in policies, host
print('PASS: Envy integrated card defaults150%, saved manual routes preserved, other devices/hosts isolated')
PY
