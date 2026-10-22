#!/usr/bin/env python3
"""Wayland-only Sway fixtures must not allocate global /tmp X11 sockets."""
import ast
from pathlib import Path
root=Path(__file__).resolve().parents[1]
checked=[];unsafe=[]
for path in sorted((root/'tests').glob('*.test.py')):
 source=path.read_text()
 if 'WLR_BACKENDS' not in source or 'headless' not in source:continue
 tree=ast.parse(source,filename=str(path))
 for call in ast.walk(tree):
  if not isinstance(call,ast.Call) or not isinstance(call.func,ast.Attribute) or call.func.attr!='write_text' or not call.args:continue
  literal=''.join(n.value for n in ast.walk(call.args[0]) if isinstance(n,ast.Constant) and isinstance(n.value,str))
  if 'output HEADLESS-' not in literal:continue
  checked.append(path.name)
  if 'xwayland disable\n' not in literal:unsafe.append(path.name+':'+str(call.lineno))
assert len(checked)>=15,('Fixture discovery unexpectedly incomplete',checked)
assert not unsafe,'Private Wayland fixtures can unlink the live X11 socket: '+', '.join(unsafe)
print('PASS: '+str(len(checked))+' private Sway configs explicitly disable unused Xwayland')
