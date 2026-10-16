#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
nix eval --impure --raw --expr '
let
 f = builtins.getFlake ("path:" + toString ./.);
 c = f.nixosConfigurations.envy.config;
 names = [ "hypridle" "ryoku-shell" "ryoku-materialize" "ryogami" "ryoku-rashin" "ryoku-ai-usage" "ryotunesd" ];
 hasClient = name: builtins.elem (toString c.programs.hyprland.package)
   (map toString c.systemd.user.services.${name}.path);
in
assert f.inputs.nixpkgs.lib.assertMsg (builtins.all hasClient names)
 "Ryoku session services must find the selected compositor hyprctl, including resume";
assert f.inputs.nixpkgs.lib.assertMsg
 (let server = f.nixosConfigurations.lenovo.config.specialisation.server.configuration;
  in !server.programs.ryoku.enable && builtins.all
   (name: !(builtins.hasAttr name server.systemd.user.services)) names)
 "Runtime client fix must not create desktop services in the server mode";
"PASS: Ryoku services carry their pinned compositor client in PATH, not server mode\n"
'
