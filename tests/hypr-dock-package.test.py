#!/usr/bin/env python3
"""The compositor-owned dock must run the same compatibility package we install."""
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
expression = r'''
let
  flake = builtins.getFlake "path:__ROOT__";
  describe = system: let
    cfg = system.config;
    patched = import (__ROOT__ + "/nixos/profiles/hyprland/nwg-dock.nix") { pkgs = system.pkgs; };
  in {
    dock = cfg.systemd.user.services.orgm-hyprland-dock.environment.NWG_DOCK_BIN;
    expected = "${patched}/bin/nwg-dock-hyprland";
    installed = builtins.elem (toString patched) (map toString cfg.environment.systemPackages);
  };
in {
  orgm = describe flake.nixosConfigurations.orgm;
  swayUnchanged = !(flake.nixosConfigurations.envy.config.systemd.user.services ? orgm-hyprland-dock);
}
'''.replace('__ROOT__', str(ROOT))
result = subprocess.run(['nix', 'eval', '--impure', '--json', '--expr', expression],
                        check=True, capture_output=True, text=True, timeout=120)
config = json.loads(result.stdout)
assert config['orgm']['installed'], 'patched dock missing from system packages'
assert config['orgm']['dock'] == config['orgm']['expected'], 'dock bypasses patched dock'
assert config['swayUnchanged'], 'Hyprland service leaked into Sway'
print('PASS: Hyprland installs and runs the same Lua-compatible dock; Sway unchanged')
