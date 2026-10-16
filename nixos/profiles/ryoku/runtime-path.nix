{ config, lib, ... }:
{
  # Upstream runtimePackages includes the WM provider but omits Hyprland itself.
  # These systemd services do not inherit the interactive /run/current-system
  # PATH, so WM queries and resume output.power calls cannot exec hyprctl.
  # Use the selected ABI-matched package, not an unrelated nixpkgs compositor.
  config = lib.mkIf config.programs.ryoku.enable {
    systemd.user.services = lib.genAttrs [
      "hypridle"
      "ryoku-shell"
      "ryoku-materialize"
      "ryogami"
      "ryoku-rashin"
      "ryoku-ai-usage"
      "ryotunesd"
    ] (_: { path = lib.mkAfter [ config.programs.hyprland.package ]; });
  };
}
