{
  config,
  inputs,
  pkgs,
  lib,
  userName,
  ...
}:

let
  extensionUuids = [
    "cinnamon-maximus@fmete"
    "BlurCinnamon@klangman"
    "centered-cinnamon-dock@mostlynick3"
  ];

  cinnamonRiceExtensions = pkgs.runCommand "cinnamon-rice-extensions" { } ''
    mkdir -p "$out/share/cinnamon/extensions"
    for uuid in ${lib.escapeShellArgs extensionUuids}; do
      cp -R \
        "${inputs.cinnamon-spices-extensions}/$uuid/files/$uuid" \
        "$out/share/cinnamon/extensions/$uuid"
    done
  '';

  graphiteNord = pkgs.graphite-gtk-theme.override {
    themeVariants = [ "blue" ];
    colorVariants = [ "dark" ];
    sizeVariants = [ "compact" ];
    tweaks = [
      "nord"
      "rimless"
    ];
  };

  nordzyDark = pkgs.nordzy-icon-theme.override {
    nordzy-themes = [ "default" ];
  };
  cinnamonXSession = pkgs.writeShellScript "cinnamon-xsession" ''
    export DESKTOP_SESSION=cinnamon
    export XDG_CURRENT_DESKTOP=X-Cinnamon
    export XDG_SESSION_DESKTOP=cinnamon
    export XDG_SESSION_TYPE=x11
    exec ${config.services.displayManager.sessionData.wrapper} \
      ${pkgs.cinnamon}/bin/cinnamon-session-cinnamon
  '';
in
{
  imports = [
    ./printer.nix
    ./vesktop.nix
  ];

  services.xserver.enable = true;

  # Force Cinnamon-only desktop stack.
  services.desktopManager.gnome.enable = lib.mkForce false;
  services.displayManager.defaultSession = lib.mkForce "cinnamon";
  services.xserver.displayManager.lightdm.enable = lib.mkForce false;

  services.xserver.displayManager.startx = {
    enable = true;
    generateScript = false;
  };

  programs.bash.loginShellInit = lib.mkAfter ''
    if [[ $- == *i* && "$USER" = "${userName}" && "$(tty)" = /dev/tty1 && -z "$DISPLAY" && -z "$WAYLAND_DISPLAY" ]]; then
      exec ${pkgs.xinit}/bin/startx ${cinnamonXSession}
    fi
  '';

  # Cinnamon as desktop environment.
  services.xserver.desktopManager.cinnamon.enable = true;
  services.cinnamon.apps.enable = true;

  services.libinput.enable = true;
  services.dbus.enable = true;
  services.gvfs.enable = true;
  services.udisks2.enable = true;
  services.power-profiles-daemon.enable = true;
  services.gnome = {
    gnome-keyring.enable = true;
    gnome-online-accounts.enable = true;
    gcr-ssh-agent.enable = true;
    glib-networking.enable = true;
  };

  nixpkgs.overlays = [
    (final: prev: {
      cinnamon = prev.cinnamon.overrideAttrs (old: {
        postInstall = (old.postInstall or "") + ''
          substituteInPlace "$out/share/cinnamon/cinnamon-settings/bin/Spices.py" \
            --replace-fail \
            "totalSize = int(response.headers.get('content-length'))" \
            "totalSize = int(response.headers.get('content-length') or 0)"
          substituteInPlace "$out/share/cinnamon/cinnamon-settings/bin/Spices.py" \
            --replace-fail \
            "fraction = count * blockSize / float((totalSize / blockSize + 1) * blockSize)" \
            "fraction = 0 if totalSize <= 0 else count * blockSize / float((totalSize / blockSize + 1) * blockSize)"
        '';
      });
    })
  ];

  services.upower.enable = true;

  services.pulseaudio.enable = false;

  programs.dconf.enable = true;
  security.pam.services.login.enableGnomeKeyring = true;

  systemd.services."getty@tty1" = {
    wantedBy = [ "getty.target" ];
    after = [ "home-manager-${userName}.service" ];
    wants = [ "home-manager-${userName}.service" ];
  };
  security.polkit.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-xapp
      xdg-desktop-portal-gtk
    ];
    config = {
      common.default = [
        "xapp"
        "gtk"
      ];
    };
    configPackages = [ pkgs.cinnamon ];
  };

  xdg.terminal-exec = {
    enable = true;
    settings = {
      cinnamon = [ "kitty.desktop" ];
      default = [ "kitty.desktop" ];
    };
  };

  xdg.mime = {
    enable = true;
    defaultApplications = {
      "inode/directory" = [ "nemo.desktop" ];
      "text/plain" = [ "xed.desktop" ];
      "text/markdown" = [ "xed.desktop" ];
      "text/x-markdown" = [ "xed.desktop" ];
      "application/pdf" = [ "xreader.desktop" ];
      "image/png" = [ "xviewer.desktop" ];
      "image/jpeg" = [ "xviewer.desktop" ];
      "image/webp" = [ "xviewer.desktop" ];
      "image/gif" = [ "xviewer.desktop" ];
      "video/mp4" = [ "io.github.celluloid_player.Celluloid.desktop" ];
      "video/x-matroska" = [ "io.github.celluloid_player.Celluloid.desktop" ];
      "video/webm" = [ "io.github.celluloid_player.Celluloid.desktop" ];
      "video/x-msvideo" = [ "io.github.celluloid_player.Celluloid.desktop" ];
      "application/zip" = [ "org.gnome.FileRoller.desktop" ];
      "application/x-tar" = [ "org.gnome.FileRoller.desktop" ];
      "application/x-7z-compressed" = [ "org.gnome.FileRoller.desktop" ];
      "application/x-rar" = [ "org.gnome.FileRoller.desktop" ];
    };
  };

  environment.sessionVariables = {
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
    TERMINAL = "kitty";
  };

  environment.systemPackages = with pkgs; [
    # Cinnamon core.
    cinnamon
    nemo
    xed
    xreader
    xviewer
    celluloid
    file-roller

    # Reproducible Cinnamon rice.
    graphiteNord
    nordzyDark
    ulauncher
    rofi
    cinnamonRiceExtensions

    # Gnome-keyring / desktop plumbing.
    gcr
    gnome-keyring
    gsettings-desktop-schemas

    # XDG portal + desktop integration.
    xdg-utils
    xdg-desktop-portal
    xdg-desktop-portal-xapp
    xdg-desktop-portal-gtk
  ];

  home-manager.users.${userName} = {
    dconf.settings."org/cinnamon".enabled-extensions = extensionUuids;
    dconf.settings."org/cinnamon/desktop/interface" = {
      gtk-theme = "Graphite-blue-Dark-compact-nord";
      icon-theme = "Nordzy-dark";
    };
    dconf.settings."org/cinnamon/theme".name = "Graphite-blue-Dark-compact-nord";

    xdg.configFile."autostart/ulauncher.desktop".source =
      "${pkgs.ulauncher}/share/applications/ulauncher.desktop";
    xdg.configFile."autostart/kdeconnect-indicator.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=KDE Connect Indicator
      Exec=kdeconnect-indicator
      Icon=kdeconnect
      Terminal=false
    '';
  };
}
