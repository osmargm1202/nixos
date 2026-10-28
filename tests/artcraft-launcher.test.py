#!/usr/bin/env python3
"""All desktop hosts must install the launcher, not just Osmarg's host."""
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
APP_ID = "ai.storyteller.artcraft-launcher"
expression = r'''
let
  flake = builtins.getFlake "path:__ROOT__";
  emptyPersonalList = flake.nixosConfigurations.ero.extendModules {
    modules = [ ({ lib, ... }: {
      orgm.user.flatpakPackages = lib.mkForce [];
    }) ];
  };
in builtins.mapAttrs (_: system: {
  desktop = system.config ? home-manager;
  enabled = system.config.services.flatpak.enable;
  prune = (system.config.services.flatpak.uninstallUnmanaged or false);
  packages = map (package: {
    inherit (package) appId bundle sha256 origin;
  }) (system.config.services.flatpak.packages or []);
}) (flake.nixosConfigurations // { empty-personal-list = emptyPersonalList; })
'''.replace("__ROOT__", str(ROOT))
result = subprocess.run(
    ["nix", "eval", "--impure", "--json", "--expr", expression],
    check=True, capture_output=True, text=True,
)
hosts = json.loads(result.stdout)
assert {"envy", "lenovo", "orgm", "orgm-ryoku", "ero", "jarq"} <= hosts.keys()
for host, config in hosts.items():
    launchers = [p for p in config["packages"] if p["appId"] == APP_ID]
    if not config["desktop"]:
        assert not launchers, f"{host}: appliance must not install a desktop launcher"
        continue
    assert len(launchers) == 1, f"{host}: missing or duplicated shared launcher"
    launcher = launchers[0]
    assert config["enabled"], f"{host}: Flatpak installation is disabled"
    assert not config["prune"], f"{host}: must preserve manually installed apps"
    assert launcher["bundle"].startswith("/nix/store/"), f"{host}: bundle not fetched by Nix"
    assert launcher["sha256"], f"{host}: missing bundle integrity check"
    assert launcher["origin"] != "flathub", f"{host}: bundle is not a Flathub app"
    if host not in ("empty-personal-list", "thinkpad11e"):
        assert any(p["appId"] == "com.spotify.Client" for p in config["packages"]), host
    print(f"PASS: {host} installs one shared, checksum-verified ArtCraft bundle")
