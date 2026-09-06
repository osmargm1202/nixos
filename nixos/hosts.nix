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
    ];
    ero = [ ./hardware/gpu/intel.nix ];
  };
in
{
  imports = hostModules.${hostName} or [ ];
  networking.extraHosts = ''
    172.18.0.251 vilserver1
    100.100.134.21 paperless-villarpando
    100.100.134.21 jellyfin
    100.100.134.21 dagendang
    100.100.134.21 adm-dagendang
    100.100.134.21 analisis-edes
    100.100.134.21 or
    100.100.134.21 dronemap
    100.100.134.21 vaultwarden
    100.100.134.21 qbittorrent
    100.100.134.21 orgm
    100.100.134.21 nginx
    100.100.134.21 immich
    100.100.134.21 portainer-orgm
    100.67.39.12 portainer-fifrex
    100.100.134.21 pihole-orgm
    100.100.134.21 romm

  '';
}
