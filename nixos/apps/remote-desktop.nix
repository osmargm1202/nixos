{ config, lib, pkgs, userName, profileName, ... }:
let
  cfg = config.orgm.remoteDesktop;
  home = config.users.users.${userName}.home;
  wayland = builtins.elem profileName [ "sway" "hyprland" "ryoku" ];
  target = if profileName == "sway" then "sway-session.target"
    else if profileName == "hyprland" then "orgm-hyprland-session.target"
    else "graphical-session.target";
  backend = if wayland then import ./wayvnc-private.nix { inherit pkgs; } else pkgs.tigervnc;
in {
  options.orgm.remoteDesktop.enable = lib.mkEnableOption "private existing-session VNC over SSH";
  config = lib.mkMerge [ {
    orgm.remoteDesktop.enable = lib.mkDefault (
      builtins.elem "flatpak" config.orgm.user.programs
      && builtins.elem profileName [ "sway" "hyprland" "i3" "ryoku" ]
    );
  } (lib.mkIf cfg.enable {
    environment.systemPackages = [ backend pkgs.openssh ];
    # No TCP VNC port is opened. SSH authentication protects Unix forwarding;
    # only the graphical-session owner can reach the native server socket.
    systemd.user.services.orgm-remote-desktop = {
      description = "Private session sharing over SSH (VNC Unix socket)";
      wantedBy = [ target ];
      partOf = [ target ];
      after = [ target ];
      unitConfig.ConditionEnvironment = [ "|WAYLAND_DISPLAY" "|DISPLAY" ];
      environment.PATH = lib.mkForce "${lib.makeBinPath [ backend pkgs.python3 pkgs.coreutils ]}:${home}/.local/bin:/run/current-system/sw/bin";
      serviceConfig = {
        ExecStart = "${pkgs.python3}/bin/python3 -B ${home}/.local/lib/orgm-remote-desktop/remote.py server";
        Restart = "always";
        RestartSec = 3;
        UMask = "0077";
        LimitCORE = 0; # Limit crash dumps of a process holding captured desktop data.
        NoNewPrivileges = true;
        RestrictAddressFamilies = [ "AF_UNIX" ];
      };
    };
    # Foreground SSH gives systemd real liveness/reconnection state. Remmina
    # 1.4.43 Flatpak silently ignores precommands; profiles need no shell hook.
    systemd.user.services."orgm-remote-tunnel@" = {
      description = "Private VNC tunnel to %i over SSH/Tailscale";
      partOf = [ target ];
      after = [ target ];
      environment.PATH = lib.mkForce "${lib.makeBinPath [ pkgs.openssh pkgs.python3 pkgs.coreutils ]}:/run/current-system/sw/bin";
      serviceConfig = {
        ExecStart = "${pkgs.python3}/bin/python3 -B ${home}/.local/lib/orgm-remote-desktop/remote.py tunnel-service %i";
        Restart = "on-failure";
        RestartSec = 5;
        UMask = "0077";
        NoNewPrivileges = true;
        RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
      };
    };
    home-manager.users.${userName} = { lib, ... }: {
      home.activation.remoteDesktopProfiles = lib.hm.dag.entryAfter [ "orgmDotBootstrap" "writeBoundary" ] ''
      if [ -x "$HOME/.local/bin/orgm-remote-desktop" ] \
        && ${pkgs.flatpak}/bin/flatpak info org.remmina.Remmina >/dev/null 2>&1; then
        # Retire only our marked no-switch rollout units, otherwise they would
        # shadow future declarative /etc/systemd/user definitions permanently.
        units="$HOME/.config/systemd/user"
        for name in orgm-remote-desktop.service orgm-remote-tunnel@.service; do
          if [ -f "$units/$name" ] \
            && ${pkgs.gnugrep}/bin/grep -qx '# orgm-remote-desktop temporary activation' "$units/$name"; then
            for link in "$units"/*.target.wants/orgm-remote-*.service; do
              if [ -L "$link" ] && [ "$(${pkgs.coreutils}/bin/readlink "$link")" = "$units/$name" ]; then
                $DRY_RUN_CMD ${pkgs.coreutils}/bin/rm -- "$link"
              fi
            done
            $DRY_RUN_CMD ${pkgs.coreutils}/bin/rm -- "$units/$name"
          fi
        done
        $DRY_RUN_CMD ${pkgs.systemd}/bin/systemctl --user daemon-reload
        $DRY_RUN_CMD ${pkgs.flatpak}/bin/flatpak override --user \
          --filesystem=xdg-run/orgm-remote-desktop:ro org.remmina.Remmina
        $DRY_RUN_CMD ${pkgs.python3}/bin/python3 -B "$HOME/.local/lib/orgm-remote-desktop/remote.py" profiles
        for peer in $(${pkgs.python3}/bin/python3 -B "$HOME/.local/lib/orgm-remote-desktop/remote.py" peers); do
          $DRY_RUN_CMD ${pkgs.systemd}/bin/systemctl --user add-wants ${target} "orgm-remote-tunnel@$peer.service"
        done
      fi
      '';
    };
  }) ];
}
