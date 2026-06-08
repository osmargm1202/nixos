{ lib, ... }:

{
  # Jarq's Cinnamon build reaches userspace but LightDM fails to start.
  # Use GDM as the known-good display manager from the Jarq GNOME profile,
  # while keeping Cinnamon as the selected desktop session.
  services.displayManager.defaultSession = lib.mkOverride 40 "cinnamon";
  services.displayManager.gdm = {
    enable = lib.mkOverride 40 true;
    autoSuspend = false;
  };
  services.xserver.displayManager.lightdm.enable = lib.mkForce false;
}
