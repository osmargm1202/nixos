{ config, lib, ... }:

{
  services.sunshine = lib.mkIf
    (config.networking.hostName == "orgm" && builtins.elem "sunshine" config.orgm.user.programs) {
    enable = true;
    autoStart = true;
    capSysAdmin = true; # Required for reliable DRM/KMS capture on Wayland.
    openFirewall = true;
  };
}
