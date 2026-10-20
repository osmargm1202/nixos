{ pkgs }:
# 0.4.8 uses legacy dispatch syntax, rejected by Hyprland's native Lua config.
# Backport upstream PR #116 without changing the released dependency closure.
pkgs.nwg-dock-hyprland.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [
    (pkgs.fetchpatch {
      url = "https://github.com/nwg-piotr/nwg-dock-hyprland/commit/afcbb25b3702c4ccf1aa3b3583c0f61b71b3c587.patch";
      hash = "sha256-FWBGdzulTNFSmfc5zNQQ/p1HJZMvxtFpgL8vX3Ne98I=";
    })
  ];
})
