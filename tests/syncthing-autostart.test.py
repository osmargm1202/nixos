#!/usr/bin/env python3
"""Syncthing starts at boot on the four hosts even without tmux or a login."""
import json
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[1]
projection = '''systems: let
  names = [ "envy" "lenovo" "lenovo-server" "orgm" ];
  lib = systems.orgm.pkgs.lib;
  inspect = system: let
    original = system.config.orgm.user.programs;
    withoutTmux = system.extendModules { modules = [ {
      orgm.user.programs = lib.mkOverride 40 (builtins.filter (p: p != "tmux") original);
    } ]; };
    c = withoutTmux.config;
    service = c.home-manager.users.osmarg.systemd.user.services.syncthing;
  in {
    selected = builtins.elem "syncthing" c.orgm.user.programs;
    tmux = builtins.elem "tmux" c.orgm.user.programs;
    linger = c.users.users.osmarg.linger;
    wanted = service.Install.WantedBy;
    exec = service.Service.ExecStart;
    restart = service.Service.Restart;
  };
in builtins.listToAttrs (map (name: { inherit name; value = inspect systems.${name}; }) names)'''
systems = json.loads(subprocess.check_output([
    'nix', 'eval', '--json', f'path:{root}#nixosConfigurations', '--apply', projection,
], text=True))
for name, c in systems.items():
    assert c['selected'] and not c['tmux'] and c['linger'], (name, c)
    assert 'default.target' in c['wanted'] and c['restart'] == 'on-failure', (name, c)
    assert any('syncthing serve --no-browser --no-restart' in str(x) for x in c['exec']), (name, c)
print('PASS: Syncthing starts on login-independent user managers on all four systems, without tmux')
