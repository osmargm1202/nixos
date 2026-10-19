{ config, lib, pkgs, userName, ... }:
let
  home = config.users.users.${userName}.home;
  enabled = config.programs.hyprland.enable;
  target = "orgm-hyprland-session.target";
in
{
  imports = [ ../sway/qylock.nix ];
  systemd.user.targets.orgm-hyprland-session = lib.mkIf enabled {
    description = "Hyprland desktop services (owned by compositor event socket)";
  };
  systemd.user.services = lib.mkIf enabled (lib.mapAttrs (_: spec: {
    description = spec.description;
    partOf = [ target ];
    wantedBy = [ target ];
    aliases = lib.optional (spec ? busName) "swaync.service";
    unitConfig.ConditionEnvironment = "HYPRLAND_INSTANCE_SIGNATURE";
    environment.PATH = lib.mkForce "${home}/.local/bin:/run/wrappers/bin:/etc/profiles/per-user/${userName}/bin:/run/current-system/sw/bin";
    serviceConfig = {
      ExecStart = spec.command;
      Restart = "on-failure";
      RestartSec = 2;
    } // lib.optionalAttrs (spec ? busName) {
      Type = "dbus";
      BusName = spec.busName;
    };
  }) {
    orgm-hyprland-menus = { description = "Preloaded Quickshell desktop menus"; command = "${home}/.local/bin/orgm-hyprland-desktop menus-daemon"; };
    orgm-desktop-widgets = { description = "Ryoku-derived desktop clock and calendar"; command = "${home}/.local/bin/orgm-desktop-widgets daemon"; };
    orgm-hyprland-notifications = { description = "Desktop notification center"; command = "${pkgs.swaynotificationcenter}/bin/swaync"; busName = "org.freedesktop.Notifications"; };
    orgm-hyprland-waybar = { description = "Sway-style Hyprland status bar"; command = "${home}/.local/bin/waybar-watch ${home}/.config/waybar-hypr"; };
    orgm-hyprland-dock = { description = "Right application dock"; command = "${home}/.local/bin/hypr-nwg-dock"; };
    orgm-hyprland-idle = { description = "Idle screen lock"; command = "${pkgs.hypridle}/bin/hypridle"; };
    orgm-hyprland-clipboard = { description = "Clipboard history"; command = "${pkgs.wl-clipboard}/bin/wl-paste --watch ${pkgs.cliphist}/bin/cliphist store"; };
  });
  environment.systemPackages = [ (import ../sway/quickshell.nix { inherit pkgs; }) pkgs.swaynotificationcenter pkgs.hyprshot ];
}
