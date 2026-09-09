#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 - "$ROOT" <<'PY'
import json
import subprocess
import sys

flake = f"path:{sys.argv[1]}"

def evaluate(attribute, expression):
    result = subprocess.run(
        ["nix", "eval", "--json", f"{flake}#{attribute}", "--apply", expression],
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
for theme in ["star-rail", "forest", "sword", "wuthering-waves", "clockwork", "last-of-us"]:
    assert profile("qylock", theme) == {"theme": theme, "packages": ["qylock-sddm-themes"]}
print("PASS: host defaults and every selected Qylock SDDM profile evaluate correctly")
PY
