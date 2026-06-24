{ ... }:

{
  # Corsair HS55 SURROUND (1b1c:0a86) disconnects when Discord cycles audio
  # due to USB autosuspend (default: 2s). Setting to -1 disables it.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="1b1c", ATTR{idProduct}=="0a86", ATTR{power/autosuspend}="-1"
  '';

  services.pipewire.wireplumber.extraConfig."90-orgm-audio-policy" = {
    "monitor.alsa.rules" = [
      {
        matches = [
          {
            "node.name" = "alsa_output.usb-Corsair_Corsair_HS55_SURROUND-00.analog-stereo";
          }
        ];
        actions = {
          update-props = {
            "priority.driver" = 1100;
            "priority.session" = 1100;
            "session.suspend-timeout-seconds" = 0;
            "node.pause-on-idle" = false;
            "api.alsa.period-size" = 2048;
            "api.alsa.period-num" = 2;
            "api.alsa.headroom" = 1024;
            "clock.allowed-rates" = "[ 48000 ]";
          };
        };
      }
    ];
  };
}
