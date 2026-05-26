{ ... }:

{
  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true; # Required for reliable DRM/KMS capture on Wayland.
    openFirewall = true;
  };
}
