#!/usr/bin/env python3
"""Every desktop host seeds the launcher once and lets it update itself."""
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
  packages = map (p: if builtins.isString p then { appId = p; } else { inherit (p) appId; })
    (system.config.services.flatpak.packages or []);
  bootstrap = let s = system.config.systemd.user.services.orgm-artcraft-launcher-bootstrap or null; in
    if s == null || !(s.enable or true) then null else {
      wantedBy = s.wantedBy;
      script = builtins.readFile s.serviceConfig.ExecStart;
    };
}) (flake.nixosConfigurations // { empty-personal-list = emptyPersonalList; })
'''.replace("__ROOT__", str(ROOT))
result = subprocess.run(
    ["nix", "eval", "--impure", "--json", "--expr", expression],
    check=True, capture_output=True, text=True,
)
hosts = json.loads(result.stdout)
assert {"envy", "lenovo", "orgm", "orgm-ryoku", "ero", "jarq"} <= hosts.keys()
for host, config in hosts.items():
    pinned = [p for p in config["packages"] if p["appId"] == APP_ID]
    assert not pinned, f"{host}: nix-flatpak must not own the self-updating launcher"
    boot = config["bootstrap"]
    # Servers (some keep Home Manager, like lenovo-server) run without Flatpak.
    if not config["desktop"] or not config["enabled"]:
        assert boot is None, f"{host}: host without Flatpak must not install a desktop launcher"
        continue
    assert boot, f"{host}: missing launcher bootstrap"
    assert not config["prune"], f"{host}: must preserve manually installed apps"
    assert "default.target" in boot["wantedBy"], host
    script = boot["script"]
    assert f"info --user {APP_ID}" in script and f"info --system {APP_ID}" in script, host
    assert "install --user --noninteractive --assumeyes /nix/store/" in script, host
    assert "--reinstall" not in script, f"{host}: must never replace a self-updated launcher"
    if host not in ("empty-personal-list", "thinkpad11e"):
        assert any(p["appId"] == "com.spotify.Client" for p in config["packages"]), host
    print(f"PASS: {host} seeds the launcher once, outside nix-flatpak")
