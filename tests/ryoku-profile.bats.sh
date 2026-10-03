#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
inventory="$(mktemp)"
trap 'rm -f "$inventory"' EXIT
nix eval --json "path:$ROOT#nixosConfigurations" --apply '
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
      personalBindingsSource = toString (c.home-manager.users.osmarg.home.file.".config/orgm-ryoku/osmarg-keybindings.lua".source or "");
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
    lenovo = host "lenovo-ryoku";
    orgm = host "orgm-ryoku";
    legacyNotifications = builtins.mapAttrs (_: name:
      builtins.elem "dunst" (map packageName systems.${name}.config.environment.systemPackages)
    ) { i3 = "lenovo-i3"; hyprland = "lenovo-hyprland"; };
  }
' > "$inventory"
python3 "$ROOT/tests/ryoku-profile-check.py" "$inventory"
