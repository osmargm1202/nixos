{ config, lib, ... }:
{
  options.orgm.envy = {
    mode = lib.mkOption {
      type = lib.types.enum [ "normal" "gaming" "windows" "server" ];
      default = "normal";
      description = "Internal Envy boot mode, not a separate desktop flake.";
    };
    windowsVfio.enable = lib.mkOption {
      type = lib.types.bool;
      default = builtins.elem config.orgm.envy.mode [ "windows" "server" ];
      description = "Reserve only Envy's MX250 for the Windows guest at boot.";
    };
  };
}
