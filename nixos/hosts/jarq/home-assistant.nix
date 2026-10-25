{ config, ... }:
let
  address = config.orgm.multimedia.tailnetAddress;
in
{
  imports = [ ../../apps/home-assistant-tuya.nix ];
  services.home-assistant.config = {
    homeassistant.name = "Casa Jarq";
    http = {
      use_x_forwarded_for = true;
      trusted_proxies = [ "127.0.0.1" "::1" ];
    };
  };

  # Reuse the existing private proxy; the HA service stays on loopback.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 8123 ];
  services.nginx.virtualHosts."home-assistant-jarq" = {
    listen = [ { addr = address; port = 8123; } ];
    locations."/" = {
      proxyPass = "http://127.0.0.1:8123";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_set_header Host ${address}:8123;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 90s;
        proxy_buffering off;
      '';
    };
  };

  orgm.bomba.localFirst = true;
}
