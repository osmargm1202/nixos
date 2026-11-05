{ lib, ... }:
{
  # Keep normal GNOME first; the server entry is an explicit rescue choice.
  boot.loader.systemd-boot.sortKey = "nixos-00-normal";

  specialisation.server.configuration = {
    # Inherit the host's storage, account and network policy, not another role.
    boot.loader.systemd-boot.sortKey = lib.mkForce "nixos-01-server";
    environment.etc."orgm/desktop-profile".text = lib.mkForce "server\n";
    systemd.defaultUnit = "multi-user.target";

    services.openssh = {
      enable = true;
      openFirewall = true;
    };
    networking.networkmanager.enable = true;

    services.desktopManager.gnome.enable = lib.mkForce false;
    services.gnome.gnome-online-accounts.enable = lib.mkForce false;
    services.displayManager.sddm.enable = lib.mkForce false;
    services.displayManager.autoLogin.enable = lib.mkForce false;
    services.xserver = {
      enable = lib.mkForce false;
      displayManager.lightdm.enable = lib.mkForce false;
      displayManager.startx.enable = lib.mkForce false;
    };
    systemd.services.display-manager.enable = lib.mkForce false;
    programs.xwayland.enable = lib.mkForce false;
    programs.steam = {
      enable = lib.mkForce false;
      gamescopeSession.enable = lib.mkForce false;
    };
    programs.gamemode.enable = lib.mkForce false;
    orgm.gaming.gamescopeTty1.enable = lib.mkForce false;

    # Keep the user's catalog declared, but never install it during rescue.
    services.flatpak = {
      enable = lib.mkForce false;
      packages = lib.mkForce [];
    };
    systemd.services.flatpak-managed-install.enable = lib.mkForce false;
    systemd.services.orgm-artcraft-integrations.enable = lib.mkForce false;

    # Only rescue tolerates a missing ESP. Inherit its device and FAT masks.
    fileSystems."/boot".options = [ "nofail" "x-systemd.device-timeout=10s" ];
  };
}
