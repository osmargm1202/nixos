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
    };
  };
}
