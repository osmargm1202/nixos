{ pkgs, userName, ... }:
let
  base = import ../../profiles/gnome.nix { inherit pkgs; };
  isExtension = package: package ? extensionUuid;
in
base // {
  # Preserve shared imports/settings; only relocate extension packages.
  environment = base.environment // {
    systemPackages = builtins.filter (p: !(isExtension p)) base.environment.systemPackages;
  };
  home-manager.users.${userName}.home.packages = builtins.filter isExtension base.environment.systemPackages;
}
