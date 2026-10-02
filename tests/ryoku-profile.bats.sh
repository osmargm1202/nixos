#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
inventory="$(mktemp)"
trap 'rm -f "$inventory"' EXIT
nix eval --json "path:$ROOT#nixosConfigurations" --apply '
  systems:
  let
    describe = c: {
      ryoku = c.programs.ryoku.enable;
      hyprland = c.programs.hyprland.enable;
      niri = c.programs.niri.enable;
      sddm = c.services.displayManager.sddm.enable;
      lightdm = c.services.xserver.displayManager.lightdm.enable;
      theme = c.services.displayManager.sddm.theme;
      userFiles = builtins.attrNames c.home-manager.users.osmarg.home.file;
      homeServices = builtins.attrNames c.home-manager.users.osmarg.systemd.user.services;
      services = builtins.attrNames c.systemd.user.services;
      keyringPolicy = c.orgm.user.keyringMode;
      keyringPam = c.security.pam.services.sddm.enableGnomeKeyring;
      vfio = c.orgm.lenovo.windowsVfio.enable or false;
      target = c.systemd.defaultUnit;
      failedAssertions = map (a: a.message) (builtins.filter (a: !a.assertion) c.assertions);
    };
    host = name: let c = systems.${name}.config; in {
      normal = describe c;
      specialisations = builtins.mapAttrs (_: s: describe s.configuration) c.specialisation;
    };
  in { lenovo = host "lenovo-ryoku"; orgm = host "orgm-ryoku"; }
' > "$inventory"
python3 "$ROOT/tests/ryoku-profile-check.py" "$inventory"
