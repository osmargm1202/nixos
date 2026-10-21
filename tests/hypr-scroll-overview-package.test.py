#!/usr/bin/env python3
"""ScrollOverview must be built against the exact compositor and isolated from Sway."""
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
expression = r'''
let
  f = builtins.getFlake "path:__ROOT__";
  system = f.nixosConfigurations.orgm;
  cfg = system.config;
  enabled = cfg.environment.etc ? "scrolloverview.so";
  plugin = system.pkgs.callPackage (__ROOT__ + "/nixos/profiles/hyprland/hyprland-scroll-overview.nix") {
    hyprland = cfg.programs.hyprland.package;
    inherit (system.pkgs.hyprlandPlugins) mkHyprlandPlugin;
  };
in {
  declared = cfg.environment.etc."scrolloverview.so".source or null;
  expected = if enabled then "${plugin}/lib/libscrolloverview.so" else null;
  compositor = toString cfg.programs.hyprland.package;
  builtFor = if enabled then toString (plugin.hyprlandForPlugin or "missing") else "missing";
  revision = if enabled then plugin.src.rev else "missing";
  swayUnchanged = !(f.nixosConfigurations.envy.config.environment.etc ? "scrolloverview.so");
}
'''.replace('__ROOT__', str(ROOT))
result = subprocess.run(['nix', 'eval', '--impure', '--json', '--expr', expression],
                        check=True, capture_output=True, text=True, timeout=120)
config = json.loads(result.stdout)
assert config['declared'] is not None, 'Hyprland does not install ScrollOverview'
assert config['declared'] == config['expected'], 'wrong plugin binary exposed'
assert config['compositor'] == config['builtFor'], 'plugin/compiler compositor mismatch'
assert config['revision'] == 'cfc23b194ba9378d1606c7aa73060f6ffbe38445'
assert config['swayUnchanged'], 'ScrollOverview leaked into Sway'
print('PASS: pinned ScrollOverview installed for exact Hyprland; Sway unchanged')
