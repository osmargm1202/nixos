{ ... }:
{
  services.pipewire.wireplumber.extraConfig."90-envy-audio-policy" = {
    # Defaults only: manual volume, channel balance and mute remain persistent.
    "wireplumber.settings"."device.restore-routes" = true;
    "monitor.alsa.rules" = [
      {
        matches = [ { "device.name" = "~alsa_card.pci-0000_00_1f.3.*"; } ];
        actions.update-props = {
          # PipeWire stores linear gain; 150% in wpctl/PulseAudio is 1.5^3.
          # Per-device overrides support amplification; global settings cap1.0.
          # Scope this to Envy's integrated card, not future USB/BT headsets.
          "device.routes.default-sink-volume" = 3.375;
          "device.routes.default-source-volume" = 3.375;
        };
      }
    ];
  };
}
