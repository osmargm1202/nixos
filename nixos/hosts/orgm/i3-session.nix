{
  config,
  lib,
  pkgs,
  userName,
  profileName ? null,
  ...
}:
let
  enabled = profileName == "hyprland" && config.programs.hyprland.enable;
  # Reuse the existing profile's packages, services and personal integrations.
  # Its system-wide desktop/default/greeter settings belong to standalone i3.
  existing = import ../../profiles/i3/i3.nix {
    inherit
      config
      lib
      pkgs
      userName
      ;
  };
  target = "orgm-i3-session.target";
  home = config.users.users.${userName}.home;
  dot = pkgs.callPackage ../../orgm/orgm-dot.nix { };
  lock = "${pkgs.i3lock}/bin/i3lock -c 000000";
  browserConfig = pkgs.writeText "orgm-i3-browser.conf" ''
    set $browser $run orgm-browser --restore-or-focus
    bindsym $mod+w exec --no-startup-id $browser
    bindsym $mod+m exec --no-startup-id $run orgm-browser --new-tab --prompt
  '';
  # Reuse the existing startup and bindings; omit only visual/OSK integration.
  personalLines = lib.splitString "\n" (
    builtins.readFile ../../../dotfiles/config/users/osmarg/profiles/i3/.config/i3/config.d/90-osmarg.conf
  );
  personalConfig = pkgs.writeText "orgm-i3-personal.conf" (
    lib.concatStringsSep "\n" (
      builtins.filter (
        line: !(lib.hasInfix "orgm-visual-profile" line || lib.hasPrefix "set $status_command " line)
      ) personalLines
    )
  );
  integrations =
    lib.concatMapStrings
      (
        program:
        lib.optionalString (builtins.elem program.name config.orgm.user.programs) (
          if program.name == "webapps" && config.orgm.browser.enable then
            "include ${browserConfig}\n"
          else
            "include ${home}/.config/i3/config.d/${program.file}\n"
        )
      )
      [
        {
          name = "tailscale";
          file = "10-tailscale.conf";
        }
        {
          name = "nextcloud";
          file = "20-nextcloud.conf";
        }
        {
          name = "kdeconnect";
          file = "30-kdeconnect.conf";
        }
        {
          name = "webapps";
          file = "40-webapps.conf";
        }
      ];
  baseLines = lib.splitString "\n" (
    builtins.readFile ../../../dotfiles/config/profiles/i3/.config/i3/config
  );
  minimalLines = builtins.filter (
    line: !(lib.hasPrefix "exec --no-startup-id $run i3-monitor-profile" line)
  ) baseLines;
  statusBar = pkgs.writeShellApplication {
    name = "orgm-i3-status";
    runtimeInputs = [
      pkgs.python3
      pkgs.i3status
      pkgs.xkb-switch
    ];
    text = ''
      export I3_STATUS_PICOM=0 I3_STATUS_VISUAL_PROFILE=0 I3_STATUS_SERVERS=0
      exec python3 ${../../../dotfiles/config/users/osmarg/profiles/i3/.local/bin/i3status-personal}
    '';
  };
  # Also protect older active generations until the system switch is applied.
  sessionGuards = {
    "picom.service" = "!XDG_CURRENT_DESKTOP=i3";
    "orgm-osk.service" = "XDG_SESSION_TYPE=wayland";
    "orgm-hyprland-notifications.service" = "XDG_SESSION_TYPE=wayland";
    "xdg-desktop-portal-hyprland.service" = "XDG_SESSION_TYPE=wayland";
  };
  guardFiles = lib.mapAttrs' (
    unit: condition:
    lib.nameValuePair "systemd/user/${unit}.d/90-orgm-session.conf" {
      text = "[Unit]\nConditionEnvironment=${condition}\n";
    }
  ) sessionGuards;
  i3Config = pkgs.writeText "orgm-i3-minimal.conf" (
    lib.replaceStrings
      [
        "include ~/.config/i3/config.d/*.conf"
        "set_from_resource $status_command orgm.i3.statusCommand exec ~/.local/bin/i3status-localized"
        "i3-rofi --drun"
        "i3-rofi --window"
        "bindsym $mod+l focus right"
        "i3-lock"
      ]
      [
        "${integrations}include ${personalConfig}"
        "set $status_command ${statusBar}/bin/orgm-i3-status"
        "${pkgs.rofi}/bin/rofi -show drun"
        "${pkgs.rofi}/bin/rofi -show window"
        "bindsym $mod+l exec --no-startup-id ${lock}"
        lock
      ]
      (lib.concatStringsSep "\n" minimalLines)
    + ''

      # Rofi menus use normal X11 windows; keep them centered and floating.
      for_window [class="(?i)^rofi$"] floating enable, border pixel 0, move position center
    ''
  );
  session = pkgs.writeShellApplication {
    name = "orgm-i3-session";
    runtimeInputs = [
      pkgs.i3
      pkgs.systemd
      pkgs.dbus
      pkgs.coreutils
    ];
    text = ''
      export ORGM_I3_CONFIG=${i3Config}
    ''
    + builtins.readFile ./i3-session.sh;
  };
  desktop =
    pkgs.runCommand "orgm-i3-x11-session"
      {
        passthru.providedSessions = [ "orgm-i3" ];
      }
      ''
        mkdir -p "$out/share/xsessions"
        cat > "$out/share/xsessions/orgm-i3.desktop" <<EOF
        [Desktop Entry]
        Name=i3 (X11)
        Comment=Sesión ligera sin fondo, efectos ni teclado virtual
        Exec=${session}/bin/orgm-i3-session
        Type=Application
        DesktopNames=i3;X-NIXOS-SYSTEMD-AWARE;
        EOF
      '';
in
{
  imports = [ ../../profiles/i3/game-activation.nix ];
  options = lib.optionalAttrs (profileName == "hyprland") existing.options;
  config = lib.mkIf enabled {
    orgm.i3GameActivation.targets = [ target ];
    # SDDM must decide the type before starting Xorg. Fixing it in the i3
    # launcher is too late: PAM's global Wayland value selects the wrong path.
    environment.sessionVariables.XDG_SESSION_TYPE = lib.mkForce null;
    services.xserver.enable = lib.mkOverride 90 true;
    services.xserver.desktopManager.xterm.enable = false;
    services.displayManager.sessionPackages = [ desktop ];
    systemd.services.display-manager.restartIfChanged = false;
    environment.systemPackages =
      existing.config.environment.systemPackages
      ++ [
        desktop
        session
      ]
      ++ lib.optional (builtins.elem "syncthing" config.orgm.user.programs) pkgs.syncthingtray;
    programs.xfconf.enable = true;
    programs.i3lock.enable = true;
    xdg.portal.config.i3.default = [ "gtk" ];
    xdg.terminal-exec.settings.i3 = [ "kitty.desktop" ];
    systemd.user.targets.orgm-i3-session = {
      description = "i3 desktop session";
      bindsTo = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
    };
    systemd.user.services = lib.mkMerge [
      (builtins.removeAttrs existing.config.systemd.user.services [ "picom" ])
      {
        i3-clipcat = {
          wantedBy = lib.mkForce [ target ];
          partOf = lib.mkForce [ target ];
        };
        orgm-osk = lib.mkIf config.orgm.osk.enable {
          unitConfig.ConditionEnvironment = "XDG_SESSION_TYPE=wayland";
        };
      }
    ];
    home-manager.users.${userName} = lib.mkMerge [
      existing.config.home-manager.users.${userName}
      ({ lib, ... }: {
        xdg.configFile = guardFiles // {
          "i3/orgm-minimal.conf".source = i3Config;
        };
        systemd.user.services.orgm-i3-dunst = {
          Unit = {
            Description = "i3 notifications";
            PartOf = [ target ];
          };
          Install.WantedBy = [ target ];
          Service = {
            Type = "dbus";
            BusName = "org.freedesktop.Notifications";
            ExecStart = "${pkgs.dunst}/bin/dunst";
          };
        };
        home.activation.orgmI3Dotfiles = lib.hm.dag.entryAfter [ "orgmDotBootstrap" ] ''
          $DRY_RUN_CMD ${dot}/bin/orgm-dot --profile i3 bootstrap
        '';
      })
    ];
  };
}
