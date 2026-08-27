{ hostName, ... }:

let
  hostModules = {
    jarq = [
      ./hardware/gpu/intel.nix
      ./hosts/jarq/default.nix
    ];
    lenovo = [
      ./hosts/lenovo/p14s-gen2i-base.nix
      ./hosts/lenovo/audio.nix
    ];
    orgm = [
      ./hardware/gpu/nvidia.nix
      ./hosts/orgm/ms-7d43.nix
      ./hosts/orgm/zerotier.nix
    ];
    ero = [ ./hardware/gpu/intel.nix ];
  };
in
{
  imports = hostModules.${hostName} or [ ];
  networking.extraHosts = ''
    172.18.0.251 vilserver1
  '';
}
