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
  # i3bar only hosts XEmbed icons; StatusNotifier apps (Nextcloud, Sunshine)
  # must start after snixembed owns the watcher or they never show in the tray.
  waitForTray = pkgs.writeShellScript "orgm-wait-for-tray" ''
    for _ in $(${pkgs.coreutils}/bin/seq 1 300); do
      ${pkgs.systemd}/bin/busctl --user --quiet status org.kde.StatusNotifierWatcher >/dev/null 2>&1 && exit 0
      ${pkgs.coreutils}/bin/sleep 0.1
    done
  '';
  nextcloudConfig = pkgs.writeText "orgm-i3-nextcloud.conf" ''
    exec --no-startup-id sh -c '${waitForTray}; exec nextcloud --background'
  '';
  browserConfig = pkgs.writeText "orgm-i3-browser.conf" ''
    set $browser $run orgm-browser --restore-or-focus
    bindsym $mod+w exec --no-startup-id $browser
    bindsym $mod+m exec --no-startup-id $run orgm-browser --new-tab --prompt
  '';
  # Adapt the shared personal bindings for the ORGM i3 session.
  personalLines = lib.splitString "\n" (
    builtins.readFile ../../../dotfiles/config/users/osmarg/profiles/i3/.config/i3/config.d/90-osmarg.conf
  );
  personalConfig = pkgs.writeText "orgm-i3-personal.conf" (
    lib.concatStringsSep "\n" (
      builtins.filter (
        line:
        !(lib.hasInfix "orgm-visual-profile" line
          || lib.hasPrefix "set $status_command " line
          || lib.hasPrefix "exec --no-startup-id syncthingtray " line)
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
          else if program.name == "nextcloud" then
            "include ${nextcloudConfig}\n"
          else
            "include ${home}/.config/i3/config.d/${program.file}\n"
        )
      )
      [
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
    line:
    !(lib.hasPrefix "exec --no-startup-id $run i3-monitor-profile" line)
    # An active display may lack a RandR primary output. Let i3bar choose
    # an active output for the tray.
    && !(lib.hasPrefix "tray_output " (lib.trim line))
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
  # Headless desktop size for streaming. The virtual DFP-5 monitor only offers
  # 1920x1080, so NVIDIA renders the desktop at the requested size
  # (ViewPortIn) and scales it to that output; Sunshine captures the full
  # desktop. Without an argument it uses the size Moonlight asked for.
  resolution = pkgs.writeShellApplication {
    name = "orgm-resolution";
    runtimeInputs = [ config.hardware.nvidia.package.settings pkgs.xorg.xrandr ];
    text = ''
      size="''${1:-''${SUNSHINE_CLIENT_WIDTH:-}x''${SUNSHINE_CLIENT_HEIGHT:-}}"
      case "$size" in
        reset|x|1920x1080) mode="DFP-5: 1920x1080 +0+0" ;;
        *)
          if ! [[ "$size" =~ ^([0-9]{3,4})x([0-9]{3,4})$ ]] ||
            ((BASH_REMATCH[1] < 640 || BASH_REMATCH[1] > 3840 ||
              BASH_REMATCH[2] < 480 || BASH_REMATCH[2] > 2400)); then
            echo "usage: orgm-resolution [WIDTHxHEIGHT|reset] (640x480 to 3840x2400)" >&2
            exit 2
          fi
          mode="DFP-5: 1920x1080 +0+0 {ViewPortIn=$size}" ;;
      esac
      nvidia-settings --assign CurrentMetaMode="$mode" >/dev/null
      xrandr --query | head -n 1
    '';
  };
  resolutionMenu = pkgs.writeShellScript "orgm-resolution-menu" ''
    choice="$(printf '%s\n' 2560x1440 1920x1080 3840x2160 2560x1600 1920x1200 |
      ${pkgs.rofi}/bin/rofi -dmenu -i -p 'Resolución')" || exit 0
    [ -n "$choice" ] && exec ${resolution}/bin/orgm-resolution "$choice"
  '';
  # Sunshine runs these around every stream: size the desktop to the client
  # on start, return to 1920x1080 when the stream app quits.
  sunshinePrep = builtins.toJSON [
    {
      do = "${resolution}/bin/orgm-resolution";
      undo = "${resolution}/bin/orgm-resolution reset";
    }
  ];
  # Under X11, Sunshine captures with X11 + NVENC, which needs libcuda from the
  # driver path. The CAP_SYS_ADMIN wrapper (for Wayland KMS capture) runs in
  # secure-exec mode and cannot load it, so bypass the wrapper only under X11.
  sunshineLauncher = pkgs.writeShellScript "orgm-sunshine" ''
    if [ "''${XDG_SESSION_TYPE:-}" = x11 ]; then
      # i3-session.sh clears Wayland variables to empty strings; Sunshine
      # treats a defined WAYLAND_DISPLAY as Wayland and never tries X11.
      unset WAYLAND_DISPLAY WAYLAND_SOCKET
      ${waitForTray}
      export LD_LIBRARY_PATH=/run/opengl-driver/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
      exec ${config.services.sunshine.package}/bin/sunshine capture=x11 \
        global_prep_cmd=${lib.escapeShellArg sunshinePrep} "$@"
    fi
    exec /run/wrappers/bin/sunshine "$@"
  '';
  # Sorts after a hand-made override.conf so its ExecStart wins.
  sunshineFiles = lib.optionalAttrs config.services.sunshine.enable {
    "systemd/user/sunshine.service.d/zz-orgm-session.conf".text = ''
      [Service]
      ExecStart=
      ExecStart=${sunshineLauncher}
    '';
  };
  i3Config = pkgs.writeText "orgm-i3-minimal.conf" (
    lib.replaceStrings
      [
        "include ~/.config/i3/config.d/*.conf"
        "set_from_resource $status_command orgm.i3.statusCommand exec ~/.local/bin/i3status-localized"
        "i3-rofi --drun"
        "i3-rofi --window"
        "bindsym $mod+l focus right"
        "i3-lock"
        "exec --no-startup-id dex --autostart --environment i3"
      ]
      [
        "exec --no-startup-id ${pkgs.snixembed}/bin/snixembed\n${integrations}include ${personalConfig}"
        "set $status_command ${statusBar}/bin/orgm-i3-status"
        "${pkgs.rofi}/bin/rofi -show drun"
        "${pkgs.rofi}/bin/rofi -show window"
        "bindsym $mod+l exec --no-startup-id ${lock}"
        lock
        "exec --no-startup-id sh -c '${waitForTray}; exec dex --autostart --environment i3'"
      ]
      (lib.concatStringsSep "\n" minimalLines)
    + ''

      # Desktop size for streaming (Sunshine also sets it per client).
      bindsym $mod+F11 exec --no-startup-id ${resolutionMenu}

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
        resolution
      ];
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
        xdg.configFile = guardFiles // sunshineFiles // {
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
