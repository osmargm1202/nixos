{ ... }:
{
  imports = [ ../../apps/bomba.nix ../../apps/home-assistant-tuya.nix ];
  orgm.bomba = {
    enable = true;
    controller = true;
  };
}
