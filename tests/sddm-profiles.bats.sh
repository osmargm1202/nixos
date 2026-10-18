#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 - "$ROOT" <<'PY'
import json
import subprocess
import sys

requested = [
    "pixel-emerald", "enfield", "forest", "winter", "last-of-us",
    "girl-coffee", "wuthering-waves", "osu-mania", "ninja-gaiden",
]

def evaluate(attribute, expression):
    result = subprocess.run(
        ["nix", "eval", "--impure", "--json", "--file", f"{sys.argv[1]}/tests/fixtures/legacy-configurations.nix", attribute.removeprefix("nixosConfigurations."), "--apply", expression],
        text=True, capture_output=True, check=True,
    )
    return json.loads(result.stdout)

def profile(name, theme=None):
    settings = f'orgm.sddm.profile = lib.mkForce "{name}";' + (
        f' orgm.sddm.qylockTheme = lib.mkForce "{theme}";' if theme else ""
    )
    return evaluate("nixosConfigurations.orgm-hyprland.extendModules", f'''extend:
      let cfg = (extend {{ modules = [ ({{ lib, ... }}: {{ {settings} }}) ]; }}).config;
      in {{
        theme = cfg.services.displayManager.sddm.theme;
        packages = builtins.filter (package:
          builtins.elem package [ "qylock-sddm-themes" "sddm-astronaut" "sddm-greenshift" ])
          (map (package: package.pname or package.name) cfg.environment.systemPackages);
      }}''')

assert evaluate("nixosConfigurations.orgm-hyprland.config.orgm.sddm", "sddm: { profile = sddm.profile; qylockTheme = sddm.qylockTheme; }") == {
    "profile": "qylock", "qylockTheme": "star-rail"
}
assert evaluate("nixosConfigurations.lenovo-hyprland.config.orgm.sddm", "sddm: { profile = sddm.profile; qylockTheme = sddm.qylockTheme; }") == {
    "profile": "qylock", "qylockTheme": "winter"
}
assert profile("greenshift") == {"theme": "GreenShift", "packages": ["sddm-greenshift"]}
assert profile("astronaut") == {"theme": "sddm-astronaut-theme", "packages": ["sddm-astronaut"]}
for theme in ["star-rail", "sword", "clockwork", *requested]:
    assert profile("qylock", theme) == {"theme": theme, "packages": ["qylock-sddm-themes"]}
# The standalone presets must work with Ryoku and the shared SDDM base.
for theme in requested:
    actual = evaluate("nixosConfigurations.orgm-hyprland.extendModules", f'''extend:
      let
        root = (builtins.getFlake "path:{sys.argv[1]}").outPath;
        cfg = (extend {{ modules = [ (root + "/nixos/sddm/qylock/{theme}.nix") ]; }}).config;
      in {{ profile = cfg.orgm.sddm.profile; theme = cfg.services.displayManager.sddm.theme; }}''')
    assert actual == {"profile": "qylock", "theme": theme}, (theme, actual)

result = subprocess.run([
    "nix", "eval", "--impure", "--json", "--expr", f'''
      let
        f = builtins.getFlake "path:{sys.argv[1]}";
        describe = c: {{
          theme = c.services.displayManager.sddm.theme;
          enable = c.services.displayManager.sddm.enable;
          wayland = c.services.displayManager.sddm.wayland.enable;
          numlock = c.services.displayManager.sddm.settings.General.Numlock;
        }};
      in {{
        normal = describe f.nixosConfigurations.envy.config;
        modes = builtins.mapAttrs (_: s: describe s.configuration)
          f.nixosConfigurations.envy.config.specialisation;
      }}'''
], text=True, capture_output=True, check=True)
envy = json.loads(result.stdout)
assert envy["normal"] == {"theme": "forest", "enable": True, "wayland": True, "numlock": "on"}
for name, mode in envy["modes"].items():
    assert mode["theme"] == "forest" and mode["enable"] == (name == "windows-vfio"), (name, mode)
print("PASS: Qylock presets, host defaults, and Envy modes evaluate correctly")
PY
