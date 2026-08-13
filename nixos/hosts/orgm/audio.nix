{ pkgs, ... }:

let
  setOrgmDefaultAudio = pkgs.writeShellApplication {
    name = "pipewire-orgm-default-audio";
    runtimeInputs = [
      pkgs.pipewire
      pkgs.coreutils
    ];
    text = ''
      set -euo pipefail

      for _ in $(seq 1 50); do
        if
          pw-metadata --name default 0 default.configured.audio.sink \
            '{"name":"alsa_output.pci-0000_00_1f.3.analog-stereo"}' Spa:String:JSON &&
            pw-metadata --name default 0 default.audio.sink \
              '{"name":"alsa_output.pci-0000_00_1f.3.analog-stereo"}' Spa:String:JSON &&
            pw-metadata --name default 0 default.configured.audio.source \
              '{"name":"alsa_input.pci-0000_00_1f.3.analog-stereo"}' Spa:String:JSON &&
            pw-metadata --name default 0 default.audio.source \
              '{"name":"alsa_input.pci-0000_00_1f.3.analog-stereo"}' Spa:String:JSON
        then
          exit 0
        fi

        sleep 0.1
      done

      printf '%s\n' 'PipeWire default metadata did not become available after 50 attempts.' >&2
      exit 1
    '';
  };
in
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
      {
        matches = [
          {
            "media.class" = "Audio/Sink";
            "node.name" = "alsa_output.pci-0000_00_1f.3.analog-stereo";
          }
        ];
        actions.update-props."priority.session" = 3000;
      }
      {
        matches = [
          {
            "media.class" = "Audio/Source";
            "node.name" = "alsa_input.pci-0000_00_1f.3.analog-stereo";
          }
        ];
        actions.update-props."priority.session" = 3000;
      }
    ];
  };

  systemd.user.services.wireplumber-orgm-default-audio = {
    description = "Set ORGM PipeWire default audio devices";
    wantedBy = [
      "graphical-session.target"
      "wireplumber.service"
    ];
    after = [ "wireplumber.service" ];
    partOf = [ "wireplumber.service" ];
    startLimitBurst = 5;
    startLimitIntervalSec = 10;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${setOrgmDefaultAudio}/bin/pipewire-orgm-default-audio";
    };
  };
}
