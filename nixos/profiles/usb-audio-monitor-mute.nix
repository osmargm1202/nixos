{ pkgs, ... }:
let
  muteUsbMonitors = pkgs.writeShellApplication {
    name = "mute-usb-audio-monitors";
    runtimeInputs = [ pkgs.pulseaudio ];
    text = builtins.readFile ./usb-audio-monitor-mute.sh;
  };
in
{
  systemd.user.services.mute-usb-audio-monitors = {
    description = "Silence playback monitor sources for USB audio";
    wantedBy = [ "pipewire-pulse.service" ];
    after = [ "pipewire-pulse.service" ];
    partOf = [ "pipewire-pulse.service" ];
    serviceConfig = {
      ExecStart = "${muteUsbMonitors}/bin/mute-usb-audio-monitors";
      Restart = "always";
      RestartSec = "1s";
    };
  };
}
