#!/usr/bin/env python3
"""Evaluate every public host plus terminal exclusion; no system activation."""
import json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
projection=r'''builtins.mapAttrs (_: s: let
 c=s.config;
 ctx=builtins.fromJSON c.environment.etc."orgm-dot/context.json".text;
 in if c.environment.etc ? "orgm-dot/context.json" then {
 desktop=true; inherit (ctx) user profile; defaults=c.xdg.mime.defaultApplications;
 activation=c.home-manager.users.${ctx.user}.home.activation.artcraftFileDefaults.after or [];
 } else { desktop=false; defaults=c.xdg.mime.defaultApplications or {}; activation=[]; })'''
result=subprocess.check_output(['nix','eval','--impure','--json',f'path:{ROOT}#nixosConfigurations','--apply',projection],text=True)
for host,c in json.loads(result).items():
 if not c['desktop']:
  assert not c['activation'] and not any('storyteller' in str(v) for v in c['defaults'].values()),(host,c)
  print('PASS:',host,'appliance excludes desktop ArtCraft defaults',flush=True)
  continue
 def handlers(mime):
  value=c['defaults'].get(mime,[])
  return value.split(';') if isinstance(value,str) else value
 for mime,app in [('image/vnd.dwg','cadcraft'),('application/pdf','pdfcraft'),('image/svg+xml','vectorcraft'),('text/plain','wordcraft'),('text/csv','gridcraft')]:
  assert handlers(mime)[0]=='ai.storyteller.'+app+'.desktop',(host,mime,handlers(mime))
 assert 'org.gnome.Evince.desktop' in handlers('application/pdf'),host
 assert handlers('text/x-python')==['nvim.desktop'],host
 assert 'setPreferredFileHandlers' in c['activation'] and 'mimeAppsDefaults' in c['activation'],(host,c['user'],c['activation'])
 assert all('storyteller' not in app for mime in ('text/html','inode/directory','x-scheme-handler/https') for app in handlers(mime)),host
 print('PASS:',host,'ArtCraft preference, native fallback, code/browser preserved, correct user activation',flush=True)
terminal=json.loads(subprocess.check_output(['nix','eval','--impure','--json','--file',str(ROOT/'tests/fixtures/legacy-configurations.nix'),'orgm-terminal','--apply','s: s.config.xdg.mime.defaultApplications'],text=True))
assert 'image/vnd.dwg' not in terminal and 'application/pdf' not in terminal,terminal
print('PASS: terminal profile does not impose graphical ArtCraft defaults')
