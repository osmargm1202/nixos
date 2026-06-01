{ config, lib, ... }:

{
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
