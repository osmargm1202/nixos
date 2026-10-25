#!/usr/bin/env python3
"""Conditional integration on every public Flatpak host, without activation."""
import json
from pathlib import Path
import subprocess

ROOT=Path(__file__).resolve().parents[1]
projection=r'''builtins.mapAttrs (_: system: let
 c=system.config;
 ctx=builtins.fromJSON c.environment.etc."orgm-dot/context.json".text;
 action=c.home-manager.users.${ctx.user}.home.activation.cadcraftOpening or null;
 in { flatpak=builtins.elem "flatpak" c.orgm.user.programs;
      after=if action == null then [] else action.after;
      body=if action == null then "" else action.data;
 })'''
hosts=json.loads(subprocess.check_output(['nix','eval','--impure','--json',f'path:{ROOT}#nixosConfigurations','--apply',projection],text=True))
for host,config in hosts.items():
    if config['flatpak']:
        assert 'orgmDotBootstrap' in config['after'],(host,config)
        assert 'writeBoundary' in config['after'],(host,config)
        assert 'orgm-cadcraft" install' in config['body'],(host,config)
        assert '[ -x "$HOME/.local/bin/orgm-cadcraft" ]' in config['body'],(host,config)
    else:
        assert not config['body'],host
    print('PASS:',host,'conditional CADCraft activation after dotfile bootstrap')
for profile in ('sway','hyprland','i3'):
    output=subprocess.check_output(['orgm-dot','--repo',str(ROOT),'--user','jarq','--host','jarq','--profile',profile,'list'],text=True)
    assert 'cadcraft-opening' in output,profile
print('PASS: no orgm-dot ownership conflict across desktop profiles')
