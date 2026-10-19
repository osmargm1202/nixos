#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
nix eval --impure --option allow-import-from-derivation false --raw --expr '
let
  f = builtins.getFlake (toString ./.);
  lib = f.inputs.nixpkgs.lib;
  c = f.nixosConfigurations.orgm.config;
  r = f.nixosConfigurations.orgm-ryoku.config;
  h = c.home-manager.users.osmarg;
  server = c.specialisation.server.configuration;
  masks = [ "autostart/tailscale-systray.desktop" "autostart/syncthingtray.desktop" ];
in
assert lib.assertMsg (f.nixosConfigurations ? orgm-ryoku) "missing retained orgm-ryoku output";
assert c.programs.hyprland.enable && !c.programs.sway.enable && !(c.programs.ryoku.enable or false);
assert r.programs.ryoku.enable;
assert c.services.tailscale.enable;
assert h.systemd.user.services ? syncthing;
assert lib.all (name: lib.hasInfix "Hidden=true" h.xdg.configFile.${name}.text) masks;
assert c.systemd.user.services.orgm-desktop-widgets.wantedBy == [ "orgm-hyprland-session.target" ];
assert !server.programs.hyprland.enable && !server.services.displayManager.sddm.enable;
assert !(server.systemd.user.services ? orgm-desktop-widgets);
assert !(server.systemd.user.services ? orgm-hyprland-menus);
assert lib.all (a: a.assertion) c.assertions;
assert lib.all (a: a.assertion) r.assertions;
"PASS: orgm Hyprland / orgm-ryoku, trayless services and server boundary\n"
'
