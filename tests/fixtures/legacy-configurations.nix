# Historical systems are test fixtures, never public flake outputs.
let
  root = ../..;
  flake = builtins.getFlake ("path:" + toString root);
  # Match production module/source identity; do not import local paths twice.
  inventory = import (flake.outPath + "/configurations-legacy.nix");
in
builtins.mapAttrs (_: flake.lib.mkSystem) inventory.configurations
