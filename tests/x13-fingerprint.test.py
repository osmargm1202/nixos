#!/usr/bin/env python3
"""Stock Goodix, scoped GDM/sudo/polkit fingerprint PAM and headless rescue policy."""
import json
from pathlib import Path
import subprocess
import sys

root=Path(__file__).resolve().parents[1]
flake=sys.argv[1] if len(sys.argv)>1 else str(root)
projection=r'''s: let
 c=s.config; r=c.specialisation.server.configuration; lib=s.pkgs.lib;
 view=x: {
   enabled=x.services.fprintd.enable;
   tod=x.services.fprintd.tod.enable;
   package=toString x.services.fprintd.package;
   generic=builtins.mapAttrs (_: p: p.fprintAuth) x.security.pam.services;
   pam=builtins.mapAttrs (_: p: p.text) x.security.pam.services;
   gdm=x.services.displayManager.gdm.enable;
   wheelNeedsPassword=x.security.sudo.wheelNeedsPassword;
 };
in {normal=view c; server=view r; stock=toString s.pkgs.fprintd;
  libfprint=s.pkgs.libfprint.version;
  assertions=map (a: a.message) (builtins.filter (a: !a.assertion) c.assertions);
}'''
r=subprocess.run(['nix','eval','--impure','--json',f'path:{flake}#nixosConfigurations.x13','--apply',projection],text=True,capture_output=True)
assert r.returncode==0,r.stderr
c=json.loads(r.stdout)
assert not c['assertions']
normal,server=c['normal'],c['server']
assert normal['enabled'] and normal['gdm'] and not normal['tod']
assert normal['package']==c['stock']
assert {name for name,enabled in normal['generic'].items() if enabled}=={'sudo','polkit-1'},normal['generic']
assert normal['wheelNeedsPassword']
readers=[name for name,text in normal['pam'].items() if 'pam_fprintd.so' in text]
assert readers==['gdm-fingerprint','polkit-1','sudo'],readers
for name in ['sudo','polkit-1']:
 assert 'pam_unix.so' in normal['pam'][name], 'password fallback required'
assert 'required' in normal['pam']['gdm-fingerprint']
for name in ['su','sshd','login','gdm-password']:
 assert name in normal['pam'] and 'pam_fprintd.so' not in normal['pam'][name]
assert not server['enabled'] and not server['gdm'] and not server['tod']
assert not any(server['generic'].values())
assert not any('pam_fprintd.so' in text for text in server['pam'].values())
print('PASS: stock fprintd/libfprint, GDM/sudo/polkit fingerprint with password fallback; password-only SSH/console and headless Server')
print('Selected libfprint:',c['libfprint'])
