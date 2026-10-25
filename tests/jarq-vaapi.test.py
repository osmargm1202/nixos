#!/usr/bin/env python3
"""Jarq's Broadwell VA-API must be installed as a driver, not just a PATH app."""
import json
from pathlib import Path
import subprocess
ROOT=Path(__file__).resolve().parents[1]
projection='''builtins.mapAttrs (_: system: let c=system.config; in {
  host=c.networking.hostName;
  drivers=map (p: p.pname or p.name) c.hardware.graphics.extraPackages;
  drivers32=map (p: p.pname or p.name) c.hardware.graphics.extraPackages32;
  vars=c.environment.sessionVariables;
})'''
hosts=json.loads(subprocess.check_output(['nix','eval','--impure','--json',f'path:{ROOT}#nixosConfigurations','--apply',projection],text=True))
jarq=hosts['jarq']
assert 'intel-media-driver' in jarq['drivers'], jarq
assert 'intel-media-driver' in jarq['drivers32'], jarq
assert jarq['vars'].get('LIBVA_DRIVER_NAME','')!='i965', 'do not force an obsolete legacy driver'
assert 'MOZ_DISABLE_RDD_SANDBOX' not in jarq['vars'], 'never disable decoder isolation'
print('PASS: Jarq iHD VA-API64/32 declared; no legacy-driver force or disabled RDD sandbox')
