{ pkgs, ... }:

# Full desktop-distro-style print/scan stack (mirrors what Mint/Ubuntu ship
# by default): CUPS with the broad driver set, network-printer autodiscovery
# via avahi/mDNS, driverless USB support via ipp-usb, SANE scanning with the
# common vendor backends, and a GUI to manage queues on non-GNOME DEs.
{
  services.printing = {
    enable = true;
    drivers = with pkgs; [
      gutenprint
      gutenprint-bin
      hplip
      splix
      epson-escpr
      epson-escpr2
    ];
  };

  # mDNS/Bonjour discovery so network/Wi-Fi printers show up automatically,
  # same as cups-browsed + avahi-daemon on Mint.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # Driverless IPP-over-USB — lets modern Epson/Canon/HP USB printers and
  # scanners be seen as driverless network devices, no vendor driver needed.
  services.ipp-usb.enable = true;

  hardware.sane = {
    enable = true;
    extraBackends = with pkgs; [
      sane-airscan # Driverless eSCL/WSD scanning (modern Epson/Canon/HP, e.g. WF-3251)
      hplipWithPlugin # HP scanners
      brscan4
      brscan5
    ];
  };

  environment.systemPackages = with pkgs; [
    system-config-printer
    simple-scan
  ];
}
