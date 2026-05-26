{ ... }:

{
  services.pipewire.wireplumber.extraConfig."90-lenovo-audio-policy" = {
    "wireplumber.settings" = {
      "linking.follow-default-target" = false;
    };

    "monitor.alsa.rules" = [
      {
        matches = [
          {
            "media.class" = "Audio/Sink";
            "node.name" = "~.*[hH][dD][mM][i].*";
          }
        ];
        actions = {
          update-props = {
            "node.disabled" = true;
          };
        };
      }
    ];
  };
}
