#!/usr/bin/env python3
"""The compositor-owned bar must run the same compatibility package we install."""
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
expression = r'''
let
  flake = builtins.getFlake "path:__ROOT__";
  describe = system: let
    cfg = system.config;
    patched = import (__ROOT__ + "/nixos/profiles/hyprland/waybar.nix") { pkgs = system.pkgs; };
  in {
    bar = cfg.systemd.user.services.orgm-hyprland-waybar.environment.WAYBAR_BIN;
    expected = "${patched}/bin/waybar";
    installed = builtins.elem (toString patched) (map toString cfg.environment.systemPackages);
  };
in {
  orgm = describe flake.nixosConfigurations.orgm;
  swayUnchanged = !(flake.nixosConfigurations.envy.config.systemd.user.services ? orgm-hyprland-waybar);
}
'''.replace('__ROOT__', str(ROOT))
result = subprocess.run(['nix', 'eval', '--impure', '--json', '--expr', expression],
                        check=True, capture_output=True, text=True, timeout=120)
config = json.loads(result.stdout)
assert config['orgm']['installed'], 'patched Waybar missing from system packages'
assert config['orgm']['bar'] == config['orgm']['expected'], 'bar bypasses patched Waybar'
assert config['swayUnchanged'], 'Hyprland service leaked into Sway'
print('PASS: Hyprland installs and runs the same Lua-compatible Waybar; Sway unchanged')
