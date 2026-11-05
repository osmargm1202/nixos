{ pkgs, userName, ... }:
let
  base = import ../../profiles/gnome.nix { inherit pkgs; };
  isExtension = package: package ? extensionUuid;
in
base // {
  imports = base.imports ++ [ ./focus-shortcuts.nix ];
  # Preserve shared settings; only relocate compatible extension packages.
  environment = base.environment // {
    systemPackages = builtins.filter (p: !(isExtension p)) base.environment.systemPackages;
  };
  # Locked release 25 supports Shell 45–49, but this host selects Shell 50.
  # Other hosts keep their shared package selection unchanged.
  home-manager.users.${userName}.home.packages = builtins.filter
    (p: isExtension p && p.extensionUuid != "gnome-ui-tune@itstime.tech")
    base.environment.systemPackages;
}
