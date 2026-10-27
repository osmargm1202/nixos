{ config, lib, pkgs, userName, ... }:
let
  enabled = builtins.elem "tmux" config.orgm.user.programs;
  package = pkgs.callPackage ./package.nix { };
in {
  config = lib.mkIf enabled {
    environment.systemPackages = [ package ];
    # Start the user manager at boot and keep detached agents alive after logout.
    users.users.${userName}.linger = true;
    home-manager.users.${userName}.systemd.user = {
      services.tmux-session = {
        Unit.Description = "Restore tmux and agent conversations";
        Service = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStartPre = lib.optionals config.networking.networkmanager.enable [
            "-${pkgs.networkmanager}/bin/nm-online --quiet --timeout=30"
          ];
          ExecStart = "${package}/bin/tmux-session start";
          ExecStop = "${package}/bin/tmux-session save";
          # Stopping/reloading this unit saves without terminating its tmux server.
          KillMode = "process";
          TimeoutStartSec = 90;
          TimeoutStopSec = 30;
          Environment = [ "PATH=%h/.local/bin:%h/.bun/bin:%h/.npm-global/bin:/etc/profiles/per-user/${userName}/bin:/run/current-system/sw/bin" ];
        };
        Install.WantedBy = [ "default.target" ];
      };
      services.tmux-session-save = {
        Unit = {
          Description = "Save tmux even without attached clients";
          After = [ "tmux-session.service" ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${package}/bin/tmux-session save";
        };
      };
      timers.tmux-session-save = {
        Unit.Description = "Save tmux every minute";
        Timer = {
          OnBootSec = "2min";
          OnUnitActiveSec = "1min";
          AccuracySec = "5s";
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };
  };
}
