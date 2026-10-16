# Keep temporary provider fixes at the locked package boundary, not in Hub data.
{ inputs, pkgs, lib }:
let
  upstream = inputs.ryoku;
  system = pkgs.stdenv.hostPlatform.system;
  original = upstream.packages.${system};
  niri = original.ryoku-wm-niri.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace ryoku/wm/niri/config_rules.go \
        --replace-fail 'kdlNum(parseFloat(r.Value, 0.5))' 'kdlFloat(parseFloat(r.Value, 0.5))'
    '';
  });
  materializer = original.ryoku-materialize.overrideAttrs (old:
    assert lib.hasInfix (builtins.unsafeDiscardStringContext
      (toString original.ryoku-wm-niri)) old.text;
    {
      text = builtins.replaceStrings
        [ (toString original.ryoku-wm-niri) ] [ (toString niri) ] old.text;
    });
  bundle = original.ryoku-bundle.overrideAttrs (old:
    assert builtins.any (p: toString p == toString original.ryoku-wm-niri) old.paths;
    { paths = map (p: if toString p == toString original.ryoku-wm-niri then niri else p) old.paths; });
  packages = original // {
    ryoku-wm-niri = niri;
    ryoku-materialize = materializer;
    ryoku-bundle = bundle;
  };
  # Reuse the upstream module factory and its exact pinned package set/overlays.
  # Only self.packages changes, including the materializer's absolute provider
  # reference. The module's session PATH and live wrapper therefore agree with HM.
  fixedSelf = upstream // {
    packages = upstream.packages // { ${system} = packages; };
  };
  outputs = (import (upstream.outPath + "/flake.nix")).outputs
    (upstream.inputs // { self = fixedSelf; });
in {
  inherit packages;
  module = outputs.nixosModules.default;
}
