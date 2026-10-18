{ config, lib, pkgs, userName, ... }:
let
  # Upstream 0.4.3 only supports bottom/top/left; add the mirrored right edge.
  swayDock = pkgs.callPackage ./nwg-dock-right.nix { };
  quickshellWithImages = import ./quickshell.nix { inherit pkgs; };
in
{
  imports = [ ../../sddm/sddm.nix ../../print/printer.nix ./qylock.nix ];
  services.xserver.enable = false;
  services.displayManager.defaultSession = "sway";
  programs.sway = {
    enable = true;
    package = pkgs.swayfx;
    wrapperFeatures.gtk = true;
    extraPackages = [ ];
    # SDDM does not run an interactive shell: copied desktop helpers need PATH.
    extraSessionCommands = ''
      export PATH="$HOME/.local/bin:$PATH"
      # PAM unlocks a partially initialized daemon. Complete its startup before
      # applications request secrets, otherwise that daemon times out and a
      # later D-Bus activation starts a new, locked keyring.
      if [ -z "$DBUS_SESSION_BUS_ADDRESS" ] && [ -S "$XDG_RUNTIME_DIR/bus" ]; then
        export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
      fi
      ${config.security.wrapperDir}/gnome-keyring-daemon --start --components=secrets >/dev/null \
        || echo "Sway: GNOME Keyring initialization failed" >&2
    '' + lib.optionalString (config.networking.hostName == "envy") ''
      # Only Intel owns outputs. PRIME offload and VFIO stay host/mode specific.
      export WLR_DRM_DEVICES="$(readlink -f /dev/dri/by-path/pci-0000:00:02.0-card)"
      export WLR_RENDER_DRM_DEVICE="$(readlink -f /dev/dri/by-path/pci-0000:00:02.0-render)"
      export LIBVA_DRIVER_NAME=iHD
    '';
  };
  security.polkit.enable = true;
  security.pam.services.login.enableGnomeKeyring = true;
  services.gnome.gnome-keyring.enable = true;
  services.gnome.gnome-online-accounts.enable = true;
  services.power-profiles-daemon.enable = true;
  services.dbus.enable = true;
  programs.dconf.enable = true;
  programs.nautilus-open-any-terminal = { enable = true; terminal = "kitty"; };
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    config.common.default = [ "gtk" ];
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };
  xdg.terminal-exec = {
    enable = true;
    settings.default = [ "kitty.desktop" ];
  };
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
    TERMINAL = "kitty";
  };
  # Session services stop with the compositor; console modes never start them.
  systemd.user.services = lib.mkIf config.programs.sway.enable (
    lib.mapAttrs (name: spec: {
      description = spec.description;
      partOf = [ "sway-session.target" ];
      after = [ "sway-session.target" ];
      wantedBy = [ "sway-session.target" ];
      # Package D-Bus activation must reach this session-owned unit, not a second daemon.
      aliases = lib.optional (name == "orgm-sway-notifications") "swaync.service";
      unitConfig.ConditionEnvironment = "SWAYSOCK";
      environment = {
        PATH = lib.mkForce "${config.users.users.${userName}.home}/.local/bin:/run/wrappers/bin:/etc/profiles/per-user/${userName}/bin:/run/current-system/sw/bin";
      } // lib.optionalAttrs (name == "orgm-sway-dock") {
        XDG_DATA_HOME = "${config.users.users.${userName}.home}/.local/share";
        GDK_PIXBUF_MODULE_FILE = "${pkgs.librsvg}/${pkgs.gdk-pixbuf.binaryDir}/loaders.cache";
      };
      serviceConfig = {
        ExecStart = spec.command;
        Restart = "on-failure";
        RestartSec = 2;
      } // lib.optionalAttrs (name == "orgm-sway-notifications") {
        Type = "dbus";
        BusName = "org.freedesktop.Notifications";
      };
    }) {
      orgm-sway-waybar = { description = "Sway status bar"; command = "${pkgs.waybar}/bin/waybar"; };
      # Keep above normal windows but below fullscreen; overlay bypasses fullscreen.
      orgm-sway-dock = { description = "Sway application dock"; command = "${swayDock}/bin/nwg-dock -p right -i 32 -w 10 -nows -mr 6 -l top -c sway-app-launcher"; };
      orgm-sway-notifications = { description = "Sway notification center and OSD"; command = "${pkgs.swaynotificationcenter}/bin/swaync"; };
      orgm-sway-policy = { description = "Graphical authentication"; command = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"; };
      orgm-sway-idle = { description = "Lock before suspend and switch idle displays off"; command = "${pkgs.swayidle}/bin/swayidle -w -C %h/.config/swayidle/config"; };
      orgm-sway-clipboard = { description = "Clipboard history"; command = "${pkgs.wl-clipboard}/bin/wl-paste --watch ${pkgs.cliphist}/bin/cliphist store"; };
    }
  );
  environment.systemPackages = with pkgs; [
    waybar swayDock swaybg swayidle quickshellWithImages mpvpaper ffmpeg
    rofi rofimoji libqalculate swaynotificationcenter libnotify
    grim slurp swappy wl-screenrec wl-clipboard cliphist wtype woomer
    brightnessctl pamixer playerctl pavucontrol pulsemixer
    blueman bluetui networkmanagerapplet nwg-displays nwg-look
    nautilus sushi loupe evince file-roller gnome-text-editor
    gnome-online-accounts-gtk gnome-system-monitor gnome-calculator
    adwaita-icon-theme hicolor-icon-theme colloid-icon-theme gnome-themes-extra
    catppuccin-gtk catppuccin-cursors.macchiatoTeal
    qt6.qtwayland python3
  ];
}
