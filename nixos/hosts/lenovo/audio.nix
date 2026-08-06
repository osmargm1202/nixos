{ pkgs, ... }:

let
  syncDefaultSink = pkgs.writeShellApplication {
    name = "pipewire-default-sink-sync";
    runtimeInputs = [ pkgs.pipewire ];
    text = ''
      set -euo pipefail

      # WirePlumber persists the choice made in Pavucontrol.

      pw-metadata --monitor --name default |
        while IFS= read -r event; do
          if [[ $event =~ key:\'default\.configured\.audio\.sink\'\ value:\'(.*)\'\ type: ]]; then
            pw-metadata --name default 0 default.audio.sink "''${BASH_REMATCH[1]}" Spa:String:JSON
          fi
        done
    '';
  };
in

{
  services.pipewire.wireplumber.extraConfig."90-lenovo-audio-policy" = {
    "wireplumber.settings" = {
      "linking.follow-default-target" = true;
      "node.restore-default-targets" = true;
    };

    "monitor.alsa.rules" = [
      {
        # This UCM profile drives the P14s integrated speakers.
        matches = [
          {
            "media.class" = "Audio/Sink";
            "node.name" = "~.*HiFi__Headphones__sink$";
          }
        ];
        actions = {
          update-props = {
            "priority.session" = 1200;
          };
        };
      }
      {
        # Keep HDMI available for manual selection, but never auto-select it.
        matches = [
          {
            "media.class" = "Audio/Sink";
            "node.name" = "~.*[hH][dD][mM][i].*";
          }
        ];
        actions = {
          update-props = {
            "priority.session" = 100;
          };
        };
      }
    ];
  };

  systemd.user.services.wireplumber-default-sink-sync = {
    description = "Synchronize Pavucontrol fallback output with PipeWire";
    wantedBy = [ "graphical-session.target" ];
    after = [ "wireplumber.service" ];
    partOf = [ "wireplumber.service" ];
    serviceConfig = {
      # Let WirePlumber finish restoring default-node metadata before syncing it.
      ExecStartPre = "${pkgs.coreutils}/bin/sleep 5";
      ExecStart = "${syncDefaultSink}/bin/pipewire-default-sink-sync";
      Restart = "on-failure";
      RestartSec = 3;
    };
  };
}
