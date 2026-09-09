#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 - "$ROOT" <<'PY'
import json
import subprocess
import sys

expression = '''cs: builtins.mapAttrs (_: system: {
  gvfs = system.config.services.gvfs.enable;
  goa = system.config.services.gnome.gnome-online-accounts.enable;
  packages = map (p: p.pname or p.name) system.config.environment.systemPackages;
}) (builtins.intersectAttrs { hyprland = null; i3 = null; gnome = null; labwc = null; } cs)'''
result = subprocess.run(["nix", "eval", "--json", f"path:{sys.argv[1]}#nixosConfigurations", "--apply", expression], text=True, capture_output=True, check=True)
for profile, config in json.loads(result.stdout).items():
    assert config["gvfs"] and config["goa"], f"{profile}: network file-manager backends disabled"
    manager = "thunar" if profile == "i3" else "nautilus"
    assert manager in config["packages"], f"{profile}: missing {manager}"
    assert "gnome-online-accounts-gtk" in config["packages"], f"{profile}: missing online-account settings"
print("PASS: evaluated desktops provide file managers, GVfs and online-account settings")
PY
