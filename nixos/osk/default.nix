{ config, lib, pkgs, userName ? "osmarg", ... }:
let
  home = config.users.users.${userName}.home;
  sway = config.programs.sway.enable;
  hyprland = config.programs.hyprland.enable;
  i3 = config.services.xserver.enable && config.services.xserver.windowManager.i3.enable;
  selected = builtins.elem "shell" (config.orgm.user.programs or [ ]);
  engine = import ./package.nix { inherit pkgs; };
  targets = lib.optional sway "sway-session.target"
    ++ lib.optional hyprland "orgm-hyprland-session.target"
    ++ lib.optional i3 "graphical-session.target";
in {
  options.orgm.osk.enable = lib.mkEnableOption "standalone Quickshell on-screen keyboard";
  config = lib.mkMerge [
    { orgm.osk.enable = lib.mkDefault (selected && (sway || hyprland || i3)); }
    (lib.mkIf config.orgm.osk.enable {
      environment.systemPackages = [ engine (import ../profiles/sway/quickshell.nix { inherit pkgs; }) ];
      systemd.user.services.orgm-osk = {
        description = "Standalone touch keyboard and persistent input engine";
        wantedBy = targets;
        partOf = targets;
        environment = {
          PATH = lib.mkForce "${home}/.local/bin:/run/wrappers/bin:/etc/profiles/per-user/${userName}/bin:/run/current-system/sw/bin";
          ORGM_OSK_BACKEND = if i3 then "x11" else "wayland";
          QT_QPA_PLATFORM = if i3 then "xcb" else "wayland";
          ORGM_OSK_ENGINE = "${engine}/bin/orgm-osk-engine";
        };
        serviceConfig = {
          ExecStart = "${home}/.local/bin/orgm-osk daemon";
          Restart = "on-failure";
          RestartSec = 2;
        };
      };
      environment.etc = lib.mkIf sway {
        "sway/config.d/orgm-osk.conf".text = "bindsym Mod4+Ctrl+o exec ${home}/.local/bin/orgm-osk toggle\n";
      };
    })
  ];
}
