{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.orgm.i3LightSession;
  enabled =
    cfg.enable
    && (config.services.displayManager.gdm.enable || config.services.displayManager.sddm.enable);
  target = "orgm-i3-light-session.target";
  caffeine = pkgs.writeShellApplication {
    name = "i3-caffeine-toggle";
    runtimeInputs = [
      pkgs.xset
      pkgs.util-linux
      pkgs.libnotify
      pkgs.coreutils
      pkgs.gawk
    ];
    text = lib.removePrefix "#!/usr/bin/env bash\n" (
      builtins.readFile ../../../dotfiles/config/profiles/i3/.local/bin/i3-caffeine-toggle
    );
  };
  statusConfig = pkgs.writeText "i3-light-status.conf" (
    builtins.readFile ../../../dotfiles/config/profiles/i3/.config/i3/i3status.conf
  );
  status = pkgs.writeShellApplication {
    name = "i3-light-status";
    runtimeInputs = [
      pkgs.python3
      pkgs.i3status
      pkgs.xkb-switch
    ];
    text = ''
      export I3_STATUS_PICOM=0 I3_STATUS_VISUAL_PROFILE=0 I3_STATUS_SERVERS=0
      export I3STATUS_CONFIG=${statusConfig}
      export I3_CAFFEINE_COMMAND=${caffeine}/bin/i3-caffeine-toggle
      exec python3 ${../../../dotfiles/config/users/osmarg/profiles/i3/.local/bin/i3status-personal}
    '';
  };
  i3Config = pkgs.replaceVars ./light-config {
    DEFAULT_SINK = null;
    DEFAULT_SOURCE = null;
    terminal = "${pkgs.kitty}/bin/kitty";
    rofi = "${pkgs.rofi.override { plugins = [ pkgs.rofi-calc ]; }}/bin/rofi";
    status = "${status}/bin/i3-light-status";
    caffeine = "${caffeine}/bin/i3-caffeine-toggle";
    lock = "${pkgs.i3lock}/bin/i3lock -n -c 000000";
    xssLock = "${pkgs.xss-lock}/bin/xss-lock";
    setxkbmap = "${pkgs.setxkbmap}/bin/setxkbmap";
    pactl = "${pkgs.pulseaudio}/bin/pactl";
    playerctl = "${pkgs.playerctl}/bin/playerctl";
    brightnessctl = "${pkgs.brightnessctl}/bin/brightnessctl";
    open = "${pkgs.xdg-utils}/bin/xdg-open";
    nmtui = "${pkgs.networkmanager}/bin/nmtui";
    bluetooth = "${pkgs.bluetui}/bin/bluetui";
    audio = "${pkgs.pavucontrol}/bin/pavucontrol";
  };
  session = pkgs.writeShellApplication {
    name = "i3-light-session";
    runtimeInputs = [
      pkgs.i3
      pkgs.systemd
      pkgs.dbus
      pkgs.coreutils
    ];
    text = ''
      export I3_LIGHT_CONFIG=${i3Config}
    ''
    + builtins.readFile ./light-session.sh;
  };
  desktop =
    pkgs.runCommand "i3-light-desktop"
      {
        passthru.providedSessions = [ "orgm-i3-light" ];
      }
      ''
        mkdir -p "$out/share/xsessions"
        cat > "$out/share/xsessions/orgm-i3-light.desktop" <<EOF
        [Desktop Entry]
        Name=i3 ligero (X11)
        Comment=Sesión rápida sin fondo, efectos ni teclado virtual
        Exec=${session}/bin/i3-light-session
        Type=Application
        DesktopNames=i3;X-NIXOS-SYSTEMD-AWARE;
        EOF
      '';
in
{
  imports = [ ./game-activation.nix ];
  options.orgm.i3LightSession.enable = lib.mkEnableOption "an optional lightweight i3 X11 session";
  config = lib.mkIf enabled {
    orgm.i3GameActivation.targets = [ target ];
    # Do not enable the standalone i3 profile, change the login manager or
    # select i3 by default. Console/gaming specialisations omit this session.
    services.xserver.enable = lib.mkOverride 90 true;
    services.xserver.desktopManager.xterm.enable = false;
    services.displayManager.sessionPackages = [ desktop ];
    environment.sessionVariables.XDG_SESSION_TYPE = lib.mkForce null;
    environment.systemPackages = [
      desktop
      session
      pkgs.i3
      status
      caffeine
    ];
    programs.i3lock.enable = true;
    xdg.portal.config.i3.default = [ "gtk" ];
    systemd.user.targets.orgm-i3-light-session = {
      description = "Lightweight i3 session";
      bindsTo = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
    };
    systemd.user.services = {
      i3-light-notifications = {
        description = "Lightweight i3 notifications";
        wantedBy = [ target ];
        partOf = [ target ];
        serviceConfig = {
          Type = "dbus";
          BusName = "org.freedesktop.Notifications";
          ExecStart = "${pkgs.dunst}/bin/dunst";
        };
      };
      i3-light-polkit = {
        description = "i3 authentication agent";
        wantedBy = [ target ];
        partOf = [ target ];
        serviceConfig.ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      };
      orgm-osk = lib.mkIf config.orgm.osk.enable {
        unitConfig.ConditionEnvironment = "XDG_SESSION_TYPE=wayland";
      };
    };
  };
}
