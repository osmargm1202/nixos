{ pkgs, zenBrowserFlakeSrc, channel ? "beta" }:
let
  system = pkgs.stdenv.hostPlatform.system;
  sources = builtins.fromJSON (builtins.readFile "${zenBrowserFlakeSrc}/sources.json");
  variant = sources.variants.${channel}.${system};
  unwrapped = pkgs.callPackage "${zenBrowserFlakeSrc}/package.nix" {
    name = "browser";
    inherit variant;
  };
in
pkgs.wrapFirefox unwrapped { icon = "zen-browser"; }
