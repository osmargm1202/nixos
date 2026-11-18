{ lib, pkgs, userName, ... }:
let
  base = import ../../profiles/gnome.nix { inherit pkgs; };
  isExtension = package: package ? extensionUuid;
in
base // {
  # Native GNOME locking requires GDM. Keep printing, but omit the shared
  # SDDM module (including its greeter-specific environment and PAM settings).
  imports = builtins.filter (p: p != ../../sddm/sddm.nix) base.imports
    ++ [ ./focus-shortcuts.nix ./native-desktop.nix ./login-background.nix ./fingerprint.nix ./ai-shortcut.nix ./bitwarden.nix ];
  services = base.services // {
    displayManager = base.services.displayManager // {
      sddm.enable = lib.mkForce false;
      gdm.enable = true;
    };
  };
  # Preserve shared settings; only relocate compatible extension packages.
  environment = base.environment // {
    systemPackages = builtins.filter (p: !(isExtension p)) base.environment.systemPackages;
  };
  # Locked release 25 supports Shell 45–49, but this host selects Shell 50.
  # Other hosts keep their shared package selection unchanged.
  home-manager.users.${userName} = {
    home.packages = builtins.filter
      (p: isExtension p && p.extensionUuid != "gnome-ui-tune@itstime.tech")
      base.environment.systemPackages;
    dconf.settings = {
      "org/gnome/desktop/lockdown".disable-lock-screen = false;
      "org/gnome/desktop/screensaver".lock-enabled = true;
      "org/gnome/settings-daemon/plugins/media-keys".screensaver = [ "<Super>l" ];
      # Win+V opens Clipboard Indicator's history (Windows-style); the
      # notification list stays on Win+M.
      "org/gnome/shell/keybindings".toggle-message-tray = [ "<Super>m" ];
      "org/gnome/shell/extensions/clipboard-indicator" = {
        enable-keybindings = true;
        toggle-menu = [ "<Super>v" ];
      };
      # Let GNOME's sliders go past 100% (up to 150%).
      "org/gnome/desktop/sound".allow-volume-above-100-percent = true;
    };
    # Start every session with output and microphone at 150%.
    systemd.user.services.x13-volume-boost = {
      Unit = {
        Description = "Set default speaker and microphone volume to 150%";
        After = [ "wireplumber.service" ];
        Wants = [ "wireplumber.service" ];
      };
      Install.WantedBy = [ "graphical-session.target" ];
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.writeShellScript "x13-volume-boost" ''
          for _ in $(${pkgs.coreutils}/bin/seq 1 30); do
            ${pkgs.wireplumber}/bin/wpctl inspect @DEFAULT_AUDIO_SINK@ >/dev/null 2>&1 && break
            ${pkgs.coreutils}/bin/sleep 1
          done
          ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 1.5
          ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 1.5
        ''}";
      };
    };
  };
}
