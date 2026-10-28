#!/usr/bin/env python3
"""Shared terminal apps must survive every role and keep audio output defaults."""
import configparser
import json
from pathlib import Path
import re
import subprocess

root = Path(__file__).resolve().parents[1]
projection = '''systems: builtins.mapAttrs (_: s: {
  enabled=s.config.orgm.terminalVisuals.enable;
  bundle=map (p: p.outPath) (builtins.filter
    (p: (p.name or "") == "orgm-terminal-visuals") s.config.environment.systemPackages);
  autostart=s.config.orgm.user.autostart;
}) systems'''
configs = json.loads(subprocess.check_output([
    "nix", "eval", "--json", f"path:{root}#nixosConfigurations", "--apply", projection,
], text=True))
for host, config in configs.items():
    assert config["enabled"] and len(config["bundle"]) == 1, (host, config)
    assert not any(re.search(r"\b(rmatrix|peaclock|cava)\b", item) for item in config["autostart"]), host
bundles = {config["bundle"][0] for config in configs.values()}
assert len(bundles) == 1, "All current hosts should share the same native binaries"
bundle = Path(next(iter(bundles)))
for application in ("rmatrix", "peaclock", "cava"):
    assert (bundle / "bin" / application).is_file(), application
    desktop = configparser.ConfigParser(interpolation=None)
    desktop.read(bundle / "share/applications" / f"orgm-{application}.desktop")
    assert desktop["Desktop Entry"]["Exec"] == application
    assert desktop["Desktop Entry"].getboolean("Terminal")
    subprocess.run(["desktop-file-validate", str(bundle / "share/applications" / f"orgm-{application}.desktop")], check=True)
launcher = (bundle / "bin/cava").read_text()
ini_path = re.search(r"-p (/nix/store/[^\s]+)", launcher).group(1)
ini = configparser.ConfigParser()
ini.read(ini_path)
assert ini["general"].getint("framerate") == 30
assert ini["general"].getint("sleep_timer") == 5
assert dict(ini["input"]) == {"method": "pulse", "source": "auto"}
assert ini["output"]["method"] == "noncurses"
print("PASS: rmatrix, Peaclock and CAVA are permanent in every host, with desktop launchers and low-cost music capture")
