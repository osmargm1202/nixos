# Appliance role: deliberately independent of the personal desktop/Home Manager.
{
  config,
  lib,
  pkgs,
  inputs,
  userName,
  ...
}:
let
  cfg = config.orgm.multimedia;
  app = pkgs.callPackage "${inputs.orgm-multimedia}/package.nix" { };
  receiver = pkgs.uxplay.overrideAttrs (_: {
    version = "1.73.7";
    src = pkgs.fetchFromGitHub {
      owner = "FDH2";
      repo = "UxPlay";
      tag = "v1.73.7";
      hash = "sha256-S4E2PB8Wgtv5BZ/WVHE0wm1kuhqpyXsV48MI20prZ+I=";
    };
  });
  bomba = import ../apps/bomba/package.nix { inherit pkgs; };
  catalog = pkgs.formats.json { };
  remoteLocations."/" = {
    proxyPass = "http://127.0.0.1:8765";
    extraConfig = ''
      proxy_http_version 1.1;
      proxy_set_header Connection "";
      proxy_set_header Host $host;
      proxy_set_header Cf-Access-Jwt-Assertion $http_cf_access_jwt_assertion;
      proxy_read_timeout 75s;
      client_max_body_size 8k;
    '';
  };
  oskEngine = import ../osk/package.nix { inherit pkgs; };
  quickshell = import ./sway/quickshell.nix { inherit pkgs; };
  mirror = pkgs.wl-mirror.override { installExampleScripts = false; };
  wtypeForChrome = pkgs.wtype.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./multimedia/wtype-chromium.patch ];
  });
  apps = import ./multimedia/apps.nix ++ lib.optional config.services.home-assistant.enable {
    id = "home-assistant";
    type = "chrome";
    name = "Home Assistant";
    workspace = "13";
    url = "http://127.0.0.1:8123";
    control = "keyboard";
    match = "orgm-home-home-assistant";
  };
  # The internal backlight follows physical input even while HDMI video holds
  # an idle inhibitor. Use ext-idle-notify v2 input notifications in this role.
  touchIdle = pkgs.swayidle.overrideAttrs (old: {
    mesonFlags = builtins.filter (flag: !(lib.hasPrefix "-Dlogind=" flag)) (old.mesonFlags or [ ]) ++ [ "-Dlogind=disabled" ];
    postPatch = (old.postPatch or "") + ''
      substituteInPlace main.c \
        --replace-fail '&ext_idle_notifier_v1_interface, 1)' '&ext_idle_notifier_v1_interface, version >= 2 ? 2 : 1)' \
        --replace-fail 'register_timeout(cmd, cmd->timeout, true);' 'register_timeout(cmd, cmd->timeout, false);'
    '';
  });
  dimScreen = pkgs.writeShellScript "orgm-home-dim-screen" ''
    set -eu
    target="$1"
    current=$(${pkgs.brightnessctl}/bin/brightnessctl --device=intel_backlight get)
    maximum=$(${pkgs.brightnessctl}/bin/brightnessctl --device=intel_backlight max)
    if [ "$((current * 100))" -gt "$((maximum * target))" ]; then
      ${pkgs.brightnessctl}/bin/brightnessctl --device=intel_backlight --min-value=0 set "$target%"
    fi
    if [ "$target" = 0 ]; then
      printf '4\n' > /sys/class/backlight/intel_backlight/bl_power
    fi
  '';
  wakeScreen = pkgs.writeShellScript "orgm-home-wake-screen" ''
    printf '0\n' > /sys/class/backlight/intel_backlight/bl_power
    ${pkgs.brightnessctl}/bin/brightnessctl --device=intel_backlight set 100%
    ${quickshell}/bin/qs --path ${app}/${pkgs.python3.sitePackages}/orgm_home/touch/shell.qml ipc call -- touch controls || true
  '';
  idleScreen = pkgs.writeShellScript "orgm-home-idle-screen" ''
    exec ${touchIdle}/bin/swayidle -w \
      timeout 1 '${pkgs.coreutils}/bin/true' resume '${wakeScreen}' \
      timeout 20 '${dimScreen} 20' \
      timeout 60 '${dimScreen} 0'
  '';
  sessionReady = pkgs.writeShellScript "orgm-home-session-ready" ''
    ${pkgs.systemd}/bin/systemctl --user import-environment WAYLAND_DISPLAY SWAYSOCK DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE
    ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd WAYLAND_DISPLAY SWAYSOCK DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE
    ${pkgs.systemd}/bin/systemctl --user restart orgm-home-session.target
  '';
  session = pkgs.writeShellScript "orgm-home-session" ''
    export XDG_CURRENT_DESKTOP=sway
    export XDG_SESSION_DESKTOP=sway
    export XDG_SESSION_TYPE=wayland
    export NIXOS_OZONE_WL=1
    cleanup() {
      ${pkgs.systemd}/bin/systemctl --user stop orgm-home-session.target
      ${pkgs.systemd}/bin/systemctl --user unset-environment WAYLAND_DISPLAY SWAYSOCK DISPLAY
    }
    trap cleanup EXIT
    ${config.programs.sway.package}/bin/sway --config /etc/orgm-home/sway.conf
  '';
  sessionService = command: {
    wantedBy = [ "orgm-home-session.target" ];
    partOf = [ "orgm-home-session.target" ];
    after = [ "orgm-home-session.target" ];
    unitConfig = {
      ConditionUser = "media";
      StartLimitIntervalSec = 0;
    };
    environment = {
      ORGM_CATALOG = "/etc/orgm-home/apps.json";
      ORGM_AGENT_SOCKET = "/run/orgm-home/agent.sock";
      ORGM_DISPLAY_SOURCE = "eDP-1";
      ORGM_DISPLAY_TARGET = "HDMI-A-1";
      ORGM_DISPLAY_MODE = "1920x1080";
      ORGM_OSK_ENGINE = "${oskEngine}/bin/orgm-osk-engine";
      ORGM_PREVIEW_DIR = "/var/lib/orgm-home/previews";
      QT_QPA_PLATFORM = "wayland";
    };
    path = with pkgs; [
      app
      quickshell
      mirror
      sway
      google-chrome
      flatpak
      mpv
      wtypeForChrome
      wl-clipboard
      wireplumber
      brightnessctl
      pulseaudio
      playerctl
      pipewire
      systemd
      networkmanager
      grim
      kitty
    ];
    serviceConfig = {
      ExecStart = if command == "orgm-home-idle-screen" then idleScreen else "${app}/bin/${command}";
      Restart = "always";
      RestartSec = 3;
      TimeoutStopSec = 10;
      UMask = "0077";
      # Apps stay alive across agent restarts; compositor logout ends the session.
      KillMode = if command == "orgm-home-agent" then "process" else "control-group";
    };
  };
in
{
  imports = [ ../dns/hosts.nix ];

  options.orgm.multimedia = {
    exposure = lib.mkOption {
      type = lib.types.enum [
        "local"
        "tailscale"
        "cloudflare"
      ];
      default = "local";
      description = "Private Tailscale proxy or a JWT-protected Cloudflare origin.";
    };
    tailnetAddress = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Exact IPv4 Tailscale address for the private Nginx listener.";
    };
    lanAddress = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Optional private IPv4 origin for paired remotes on the trusted receiver LANs.";
    };
    tls = lib.mkEnableOption "private HTTPS for home.or-gm.com using Cloudflare DNS validation";
    tlsCredentialFile = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/orgm-home-acme/cloudflare-token";
      description = "Root-owned Cloudflare DNS token, loaded as a systemd credential outside the store.";
    };
    origins = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "http://127.0.0.1:8765"
        "http://localhost:8765"
        "https://home.or-gm.com"
      ]
      ++ lib.optional (cfg.exposure == "tailscale") "http://home.or-gm.com"
      ++ lib.optional (cfg.lanAddress != "") "http://${cfg.lanAddress}";
      description = "Exact allowed web origins. Add a private VPN origin explicitly if needed.";
    };
    accessEnvironmentFile = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/orgm-home/access.env";
      description = "Root-owned optional environment file with Cloudflare team, AUD and authorized emails. Public controls fail closed until set.";
    };
    nginx = lib.mkEnableOption "reuse Nginx on this host for home.or-gm.com";
    airplayName = lib.mkOption {
      type = lib.types.str;
      default = "ORGM ${config.networking.hostName}";
      description = "Name shown in the Apple AirPlay selector.";
    };
    airplayNetworks = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Trusted IPv4 LAN subnets allowed to reach the AirPlay receiver.";
    };
  };

  config = {
    orgm.multimedia.nginx = lib.mkDefault (cfg.exposure != "local");
    assertions = [
      {
        assertion =
          cfg.exposure != "tailscale"
          || builtins.match "100\\.[0-9]+\\.[0-9]+\\.[0-9]+" cfg.tailnetAddress != null;
        message = "Private multimedia exposure requires an explicit Tailscale IPv4 address.";
      }
      {
        assertion = cfg.lanAddress == "" || (cfg.exposure == "tailscale" && cfg.airplayNetworks != [ ]);
        message = "A LAN remote requires private exposure and explicit trusted receiver subnets.";
      }
    ];
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = lib.mkIf (cfg.exposure == "tailscale") ([
      80
    ] ++ lib.optional cfg.tls 443);
    # Do not bring personal desktop applications/services into the appliance.
    orgm.user.programs = lib.mkForce [ ];
    orgm.user.flatpakPackages = lib.mkForce [ ];
    orgm.user.webapps = lib.mkForce [ ];
    orgm.osk.enable = lib.mkForce false;
    orgm.tablet.enable = lib.mkForce false;

    system.nixos.label = "jarq-multimedia";
    system.stateVersion = "25.11";
    nixpkgs.config.allowUnfree = true;
    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    nix.settings.trusted-users = [
      "root"
      "@wheel"
    ];
    nix.registry.nixpkgs.flake = inputs.nixpkgs;
    documentation.enable = false;
    time.timeZone = "America/Santo_Domingo";
    i18n.defaultLocale = "es_DO.UTF-8";
    i18n.supportedLocales = [
      "es_DO.UTF-8/UTF-8"
      "en_US.UTF-8/UTF-8"
    ];

    # The current host's boot and Wi-Fi overrides still come from its base module.
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    boot.loader.timeout = 3;
    boot.initrd.systemd.enable = true;
    hardware.graphics.enable = true;
    networking.networkmanager.enable = true;
    services.resolved.enable = true;
    services.tailscale.enable = true;
    services.tailscale.package =
      inputs.nixpkgs-tailscale.legacyPackages.${pkgs.stdenv.hostPlatform.system}.tailscale;
    services.tailscale.extraSetFlags = [ "--accept-dns=true" ];
    networking.firewall.enable = true;
    networking.firewall.allowedTCPPorts = [ 22 ];
    networking.firewall.checkReversePath = "loose";
    networking.firewall.extraInputRules = lib.optionalString (cfg.airplayNetworks != [ ]) ''
      ip saddr { ${lib.concatStringsSep ", " cfg.airplayNetworks} } tcp dport 7000-7002 accept
      ip saddr { ${lib.concatStringsSep ", " cfg.airplayNetworks} } udp dport 7000-7002 accept
      ip saddr { ${lib.concatStringsSep ", " cfg.airplayNetworks} } tcp dport 8766 accept
      ip saddr { ${lib.concatStringsSep ", " cfg.airplayNetworks} } udp dport 1900 accept
    '' + lib.optionalString (cfg.lanAddress != "") ''
      ip saddr { ${lib.concatStringsSep ", " cfg.airplayNetworks} } tcp dport 80 accept
    '' + lib.optionalString (cfg.lanAddress != "" && cfg.tls) ''
      ip saddr { ${lib.concatStringsSep ", " cfg.airplayNetworks} } tcp dport 443 accept
    '';
    # Avahi owns mDNS; two responders caused repeated local hostname conflicts.
    services.resolved.settings.Resolve.MulticastDNS = false;
    services.avahi = {
      enable = true;
      openFirewall = true;
      publish.enable = true;
      publish.userServices = true;
    };
    services.openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no";
        AllowUsers = [ userName ];
      };
    };
    users.groups.${userName}.gid = 1000;
    users.users.${userName} = {
      isNormalUser = true;
      uid = 1000;
      group = userName;
      extraGroups = [
        "wheel"
        "networkmanager"
        "video"
        "render"
      ];
      shell = pkgs.bashInteractive;
    };
    users.groups.media = { };
    users.users.media = {
      isNormalUser = true;
      createHome = true;
      home = "/home/media";
      group = "media";
      uid = 1100;
      extraGroups = [
        "audio"
        "video"
        "render"
      ];
      hashedPassword = "!";
    };

    services.greetd = {
      enable = true;
      settings = {
        initial_session = {
          command = "${session}";
          user = "media";
        };
        default_session = {
          command = "${session}";
          user = "media";
        };
      };
    };
    # Package updates must not log out the living-room session during a switch.
    systemd.services.greetd.restartIfChanged = false;
    services.logind.settings.Login = {
      HandleLidSwitch = "ignore";
      HandleLidSwitchExternalPower = "ignore";
      HandleLidSwitchDocked = "ignore";
      IdleAction = "ignore";
    };
    systemd.targets.sleep.enable = false;
    systemd.targets.suspend.enable = false;
    systemd.targets.hibernate.enable = false;
    systemd.targets.hybrid-sleep.enable = false;
    programs.sway = {
      enable = true;
      wrapperFeatures.gtk = true;
      extraPackages = [ ];
      xwayland.enable = true;
    };
    services.dbus.enable = true;
    security.polkit.enable = true;
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
    };
    services.pipewire.wireplumber.extraConfig."51-orgm-home-hdmi" = {
      "monitor.alsa.rules" = [
        {
          matches = [ { "node.name" = "~alsa_output.*hdmi.*"; } ];
          actions.update-props = {
            "priority.session" = 2000;
            "priority.driver" = 2000;
          };
        }
      ];
    };
    xdg.portal = {
      enable = true;
      wlr.enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      config.sway.default = lib.mkForce [
        "wlr"
        "gtk"
      ];
    };
    services.flatpak.enable = true;
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (subject.user === "media" && [
          "org.freedesktop.NetworkManager.network-control",
          "org.freedesktop.NetworkManager.wifi.scan",
          "org.freedesktop.NetworkManager.enable-disable-wifi",
          "org.freedesktop.NetworkManager.settings.modify.own"
        ].indexOf(action.id) !== -1) return polkit.Result.YES;
      });
      polkit.addRule(function(action, subject) {
        if (subject.user === "media" && (
          action.id === "org.freedesktop.login1.reboot" ||
          action.id === "org.freedesktop.login1.reboot-multiple-sessions"
        )) return polkit.Result.YES;
      });
    '';
    services.udev.packages = [ pkgs.brightnessctl ];
    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="backlight", KERNEL=="intel_backlight", RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/backlight/%k/bl_power", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/backlight/%k/bl_power"
    '';

    environment.etc = {
      "orgm-home/apps.json".source = catalog.generate "orgm-home-apps.json" { inherit apps; };
      "orgm-home/sway.conf".text = ''
        set $mod Mod4
        output * bg #161b27 solid_color
        default_border none
        default_floating_border none
        focus_follows_mouse no
        seat * hide_cursor 3000
        input type:keyboard xkb_layout us
        input type:touch map_to_output eDP-1
        output eDP-1 enable mode 1920x1080 scale 1 position 0 0
        output HDMI-A-1 mode 1920x1080 scale 1 position 1920 0
        workspace 1 output eDP-1
        workspace 2 output eDP-1
        workspace 3 output eDP-1
        workspace 4 output eDP-1
        workspace 5 output eDP-1
        workspace 6 output eDP-1
        workspace 7 output eDP-1
        workspace 8 output eDP-1
        workspace 9 output eDP-1
        workspace 10 output eDP-1
        workspace 11 output eDP-1
        workspace 12 output eDP-1
        workspace 14 output eDP-1
        workspace 15 output eDP-1
        workspace 16 output eDP-1
        workspace 17 output eDP-1
        workspace 18 output eDP-1
        workspace 19 output eDP-1
        workspace 20 output eDP-1
        workspace 21 output eDP-1
        workspace 22 output eDP-1
        workspace 23 output eDP-1
        workspace 13 output eDP-1
        workspace 99 output HDMI-A-1
        no_focus [app_id="at.yrlf.wl_mirror"]
        for_window [app_id="at.yrlf.wl_mirror"] move container to workspace number 99, fullscreen enable
        for_window [app_id="^orgm-home-.*"] fullscreen enable
        for_window [app_id="^chrome-.*"] fullscreen enable
        for_window [app_id="rocks.shy.VacuumTube"] fullscreen enable
        for_window [app_id="(?i)^spotify$"] fullscreen enable
        for_window [app_id="(?i)retroarch"] fullscreen enable
        for_window [app_id="(?i)uxplay"] move container to workspace number 14, fullscreen enable
        for_window [app_id="^mpv$"] fullscreen enable
        workspace 1
        exec ${sessionReady}
        bindsym $mod+1 workspace number 1
        bindsym $mod+Ctrl+o exec ${quickshell}/bin/qs --path ${app}/${pkgs.python3.sitePackages}/orgm_home/touch/shell.qml ipc call -- touch toggle
        bindsym $mod+Shift+e exit
      '';
      "orgm/desktop-profile".text = "multimedia\n";
    };
    systemd.tmpfiles.rules = [
      "d /home/media/.config 0700 media media -"
      "d /home/media/.local 0700 media media -"
      "d /home/media/.local/share 0700 media media -"
      "d /home/media/.local/state 0700 media media -"
      "d /home/media/.local/share/orgm-home 0700 media media -"
      "d /home/media/.local/state/orgm-home 0700 media media -"
      "d /home/media/Videos 0750 media media -"
      "d /home/media/.config/sway 0700 media media -"
      "L+ /home/media/.config/sway/config - - - - /etc/orgm-home/sway.conf"
    ];
    systemd.services.orgm-home = {
      description = "ORGM Home authenticated web remote";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      path = [ pkgs.openssl ];
      preStart = ''
        if [ ! -s /var/lib/orgm-home/control-token ]; then
          umask 077
          ${pkgs.openssl}/bin/openssl rand -hex 32 > /var/lib/orgm-home/control-token
        fi
      '';
      environment = {
        ORGM_CATALOG = "/etc/orgm-home/apps.json";
        ORGM_BIND = "127.0.0.1";
        ORGM_AIRPLAY_NAME = cfg.airplayName;
        ORGM_PREVIEW_DIR = "/var/lib/orgm-home/previews";
        ORGM_REQUIRE_ACCESS = if cfg.exposure == "tailscale" then "false" else "true";
        ORGM_BOMBA_COMMAND = "${bomba}/bin/bomba";
        BOMBA_CONFIG = "/etc/bomba/config.json";
        ORGM_ORIGINS = lib.concatStringsSep "," cfg.origins;
      };
      unitConfig.StartLimitIntervalSec = 0;
      serviceConfig = {
        User = "media";
        Group = "media";
        WorkingDirectory = "/var/lib/orgm-home";
        ExecStart = "${app}/bin/orgm-home";
        EnvironmentFile = "-${cfg.accessEnvironmentFile}";
        StateDirectory = "orgm-home";
        StateDirectoryMode = "0700";
        RuntimeDirectory = "orgm-home";
        RuntimeDirectoryMode = "0700";
        RuntimeDirectoryPreserve = "yes";
        Restart = "on-failure";
        RestartSec = 2;
        UMask = "0077";
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
        ];
      };
    };
    systemd.user.targets.orgm-home-session = {
      description = "ORGM Home graphical session";
      bindsTo = [ "graphical-session.target" ];
      wants = [ "graphical-session-pre.target" ];
      after = [ "graphical-session-pre.target" ];
    };
    systemd.user.services = {
      orgm-home-agent = sessionService "orgm-home-agent";
      orgm-home-kiosk = sessionService "orgm-home-kiosk";
      orgm-home-display = sessionService "orgm-home-display";
      orgm-home-touch = sessionService "orgm-home-touch";
      orgm-home-idle = sessionService "orgm-home-idle-screen";
      orgm-home-airplay = {
        description = "ORGM AirPlay video and audio receiver";
        wantedBy = [ "orgm-home-session.target" ];
        partOf = [ "orgm-home-session.target" ];
        after = [ "orgm-home-session.target" ];
        unitConfig.ConditionUser = "media";
        environment = {
          PULSE_PROP = ''application.name="ORGM AirPlay" application.id=orgm-home-airplay'';
          GST_DEBUG = "2";
          GST_DEBUG_NO_COLOR = "1";
        };
        serviceConfig = {
          ExecStart = "${pkgs.coreutils}/bin/stdbuf -oL -eL ${receiver}/bin/uxplay " + lib.escapeShellArgs [
            "-n" cfg.airplayName "-nh" "-p" "7000" "-s" "1920x1080"
            "-hls" "2"
            # GStreamer 1.26 waylandsink sets fullscreen before creating its
            # window with -fs, causing "Window has no size set" on first frame.
            # The Sway uxplay rule applies fullscreen after the window maps.
            "-vs" "waylandsink" "-as" "pulsesink"
          ];
          Restart = "on-failure";
          RestartSec = 3;
          TimeoutStopSec = 10;
          UMask = "0077";
        };
      };
    };
    systemd.services.orgm-home-cast = lib.mkIf (cfg.airplayNetworks != [ ]) {
      description = "Private LAN YouTube discovery and launcher bridge";
      wantedBy = [ "multi-user.target" ];
      wants = [ "orgm-home.service" ];
      after = [ "orgm-home.service" "network.target" ];
      environment = {
        ORGM_DIAL_NETWORKS = lib.concatStringsSep "," cfg.airplayNetworks;
        ORGM_DIAL_NAME = "${cfg.airplayName} · YouTube";
      };
      serviceConfig = {
        ExecStart = "${app}/bin/orgm-home-cast";
        DynamicUser = true;
        User = "orgm-home-cast";
        LoadCredential = "control-token:/var/lib/orgm-home/control-token";
        Restart = "on-failure";
        RestartSec = 3;
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" ];
        IPAddressDeny = "any";
        IPAddressAllow = [ "localhost" "239.255.255.250/32" ] ++ cfg.airplayNetworks;
        UMask = "0077";
      };
    };
    systemd.services.orgm-home-flatpaks = {
      description = "Install the fixed ORGM Home Flatpak catalog";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      path = [ pkgs.flatpak ];
      script = ''
        flatpak remote-add --system --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
        flatpak install --system --noninteractive --assumeyes flathub rocks.shy.VacuumTube com.spotify.Client org.libretro.RetroArch
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = 60;
        TimeoutStartSec = 1800;
      };
    };

    # DNS validation alone does not stop redirects or DNS rebinding in Chrome.
    # Block new connections from media to private ranges, including tailnet/LAN.
    # API replies on established incoming connections remain possible.
    networking.nftables = {
      enable = true;
      tables.orgm-media-egress = {
        family = "inet";
        content = ''
          chain output {
            type filter hook output priority 0; policy accept;
            meta skuid 1100 ct state established,related accept
            meta skuid 1100 ip daddr 127.0.0.1 tcp dport 8765 accept
            # UxPlay's YouTube HLS player reads playlists from its own server.
            meta skuid 1100 ip daddr 127.0.0.1 tcp dport 7001 accept
            meta skuid 1100 ip6 daddr ::1 tcp dport 7001 accept
            ${lib.optionalString config.services.home-assistant.enable "meta skuid 1100 ip daddr 127.0.0.1 tcp dport 8123 accept"}
            meta skuid 1100 meta l4proto { tcp, udp } th dport 53 accept
            ${lib.optionalString (cfg.airplayNetworks != [ ]) "meta skuid 1100 ip daddr { ${lib.concatStringsSep ", " cfg.airplayNetworks} } udp sport 7000-7002 accept"}
            meta skuid 1100 ip daddr { 0.0.0.0/8, 10.0.0.0/8, 100.64.0.0/10, 127.0.0.0/8, 169.254.0.0/16, 172.16.0.0/12, 192.0.0.0/24, 192.0.2.0/24, 192.168.0.0/16, 198.18.0.0/15, 198.51.100.0/24, 203.0.113.0/24, 224.0.0.0/4, 240.0.0.0/4 } reject
            meta skuid 1100 ip6 daddr != 2000::/3 reject
            meta skuid 1100 ip6 daddr 2001:db8::/32 reject
          }
        '';
      };
    };
    security.acme = lib.mkIf cfg.tls {
      acceptTerms = true;
      certs."home.or-gm.com" = {
        dnsProvider = "cloudflare";
        credentialFiles.CF_DNS_API_TOKEN_FILE = cfg.tlsCredentialFile;
        dnsResolver = "1.1.1.1:53";
        group = "nginx";
        reloadServices = [ "nginx.service" ];
      };
    };
    services.nginx = lib.mkIf cfg.nginx {
      enable = true;
      # Set Host once: the recommended block plus a custom Host emits two
      # Host headers, which Uvicorn correctly rejects as malformed HTTP.
      recommendedProxySettings = false;
      virtualHosts = {
      "home.or-gm.com" = {
        useACMEHost = lib.mkIf cfg.tls "home.or-gm.com";
        forceSSL = cfg.tls;
        serverAliases = lib.optional (cfg.lanAddress != "" && !cfg.tls) cfg.lanAddress;
        listen = [
          {
            addr = if cfg.lanAddress != "" then "0.0.0.0" else if cfg.exposure == "tailscale" then cfg.tailnetAddress else "127.0.0.1";
            port = if cfg.exposure == "tailscale" then 80 else 8085;
          }
        ] ++ lib.optional cfg.tls {
          addr = if cfg.lanAddress != "" then "0.0.0.0" else cfg.tailnetAddress;
          port = 443;
          ssl = true;
        };
        locations = remoteLocations;
      };
      } // lib.optionalAttrs (cfg.tls && cfg.lanAddress != "") {
        "${cfg.lanAddress}" = {
          listen = [{ addr = "0.0.0.0"; port = 80; }];
          locations = remoteLocations;
        };
      };
    };
    systemd.services.nginx = lib.mkIf (cfg.nginx && cfg.exposure == "tailscale") {
      after = [ "tailscaled.service" ];
      wants = [ "tailscaled.service" ];
      unitConfig.StartLimitIntervalSec = lib.mkForce 0;
      preStart = lib.mkBefore (lib.optionalString (cfg.lanAddress == "") ''
        ready=false
        for attempt in $(seq 1 60); do
          if ${pkgs.iproute2}/bin/ip -4 -o addr show dev tailscale0 | ${pkgs.gnugrep}/bin/grep -Fq ' ${cfg.tailnetAddress}/'; then
            ready=true
            break
          fi
          sleep 1
        done
        "$ready"
      '');
      serviceConfig.RestartSec = lib.mkForce 5;
      # The readiness check queries interface addresses via netlink. Nginx's
      # default sandbox only permits stream families, so allow this local
      # query family while retaining its capability restrictions.
      serviceConfig.RestrictAddressFamilies = lib.mkForce [
        "AF_UNIX"
        "AF_INET"
        "AF_INET6"
        "AF_NETLINK"
      ];
    };
    environment.systemPackages = with pkgs; [
      app
      quickshell
      mirror
      oskEngine
      google-chrome
      mpv
      wtypeForChrome
      wl-clipboard
      jq
      curl
      wireplumber
      playerctl
      pulseaudio
      receiver
      kitty
      git
      rsync
      vim
      (writeShellScriptBin "orgm-home-pair" ''
        exec sudo ${coreutils}/bin/cat /var/lib/orgm-home/control-token
      '')
    ];
  };
}
