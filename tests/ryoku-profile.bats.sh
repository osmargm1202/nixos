#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
inventory="$(mktemp)"
trap 'rm -f "$inventory"' EXIT
RYOKU_TEST_REPO="$ROOT" nix eval --impure --json --expr '
  let
    root = builtins.getEnv "RYOKU_TEST_REPO";
    f = builtins.getFlake ("path:" + root);
    legacy = import (root + "/tests/fixtures/legacy-configurations.nix");
    check =
  systems:
  let
    packageName = package: package.pname or (builtins.parseDrvName package.name).name;
    describe = c: {
      ryoku = c.programs.ryoku.enable;
      hyprland = c.programs.hyprland.enable;
      niri = c.programs.niri.enable;
      sddm = c.services.displayManager.sddm.enable;
      lightdm = c.services.xserver.displayManager.lightdm.enable;
      theme = c.services.displayManager.sddm.theme;
      userFiles = builtins.attrNames c.home-manager.users.osmarg.home.file;
      personalBindingsSource = let
        rows = builtins.fromJSON (builtins.unsafeDiscardStringContext
          (c.home-manager.users.osmarg.xdg.configFile."orgm-ryoku/seed-manifest.json".text or "[]"));
        selected = builtins.filter (row: row.target == ".config/orgm-ryoku/osmarg-keybindings.lua") rows;
      in if selected == [ ] then "" else (builtins.head selected).source;
      nautilusTerminal = c.programs.nautilus-open-any-terminal.terminal;
      nautilusExtension = c.programs.nautilus-open-any-terminal.enable;
      homeServices = builtins.attrNames c.home-manager.users.osmarg.systemd.user.services;
      services = builtins.attrNames c.systemd.user.services;
      notificationDaemons = builtins.filter (name: builtins.elem name [ "mako" "dunst" ])
        (map packageName c.environment.systemPackages);
      homeDunst = c.home-manager.users.osmarg.services.dunst.enable;
      homeMako = c.home-manager.users.osmarg.services.mako.enable;
      autoLogin = c.services.displayManager.autoLogin.enable;
      sddmPam = c.security.pam.services.sddm.text or "";
      loginPam = c.security.pam.services.login.text;
      lidPolicy = c.services.logind.settings.Login;
      ryokuLidOverride = c.environment.etc."systemd/logind.conf.d/10-ryoku-lid.conf".enable or false;
      vfio = c.orgm.lenovo.windowsVfio.enable or false;
      target = c.systemd.defaultUnit;
      failedAssertions = map (a: a.message) (builtins.filter (a: !a.assertion) c.assertions);
    };
    host = name: let c = systems.${name}.config; in {
      normal = describe c;
      specialisations = builtins.mapAttrs (_: s: describe s.configuration) c.specialisation;
    };
  in {
    lenovo = host "lenovo";
    orgm = host "orgm";
    legacyNotifications = builtins.mapAttrs (_: name:
      builtins.elem "dunst" (map packageName legacy.${name}.config.environment.systemPackages)
    ) { i3 = "lenovo-i3"; hyprland = "lenovo-hyprland"; };
  }
  ; in check f.nixosConfigurations
' > "$inventory"
python3 "$ROOT/tests/ryoku-profile-check.py" "$inventory"
