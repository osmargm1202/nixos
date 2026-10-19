{ pkgs }:
# Waybar 0.15 still sends legacy dispatch commands, rejected by Hyprland's
# Lua configuration. Backport the upstream click compatibility fix.
pkgs.waybar.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [
    (pkgs.fetchpatch {
      url = "https://github.com/Alexays/Waybar/commit/e17c0d9f0a73acc370df60ec8c532b1ed2385c73.patch";
      # The release has no built-in scroll handler; that upstream hunk targets
      # newer Waybar sources. Keep the IPC adapter and workspace click hunks.
      excludes = [ "src/modules/hyprland/workspaces.cpp" ];
      hash = "sha256-QsPcxs6B8YPIPE3IzBuxER+12Ur+3JoshouDm/3T3xE=";
    })
  ];
})
