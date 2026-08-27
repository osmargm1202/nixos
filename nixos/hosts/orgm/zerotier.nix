{ lib, ... }:

{
  services.zerotierone = {
    enable = true;
    joinNetworks = [ "45b6e887e20a1ed3" ];
  };

  services.tailscale = {
    useRoutingFeatures = lib.mkForce "both";
    extraSetFlags = [ "--advertise-routes=172.18.0.0/24" ];
  };


  networking.nat = {
    enable = true;
    externalInterface = "ztyjkofgjr";
    internalIPs = [
      "10.0.0.0/8"
      "100.64.0.0/10"
      "172.16.0.0/12"
      "192.168.0.0/16"
    ];
  };
}
