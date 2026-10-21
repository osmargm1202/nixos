{ config, lib, ... }:
let desktop=config.programs.sway.enable || config.programs.hyprland.enable;
in {
  options.orgm.tablet = {
    enable=lib.mkEnableOption "manual-only tablet presentation";
    # Kept as a no-op so older host snapshots can migrate without new hardware policy.
    jarqDetector=lib.mkEnableOption "legacy diagnostic compatibility (automatic mode removed)";
  };
  config=lib.mkMerge [
    {orgm.tablet.enable=lib.mkDefault desktop;}
    {
      # Old automatic units and Squeekboard are intentionally not installed.
      systemd.user.services.orgm-sway-tablet.enable=lib.mkForce false;
      systemd.user.services.orgm-hyprland-tablet.enable=lib.mkForce false;
    }
  ];
}
