{ config, lib, pkgs, profileName, userName, ... }:
let
  tailnetAddress = "100.94.177.77";
  sunshineHost = "sun.or-gm.com";
  syncthingHost = "sync-osmar.or-gm.com";
  listen = [
    { addr = tailnetAddress; port = 80; }
    { addr = tailnetAddress; port = 443; ssl = true; }
  ];
  panel = upstream: hostHeader: {
    inherit listen;
    forceSSL = true;
    useACMEHost = sunshineHost;
    locations."/" = {
      proxyPass = upstream;
      proxyWebsockets = true;
      recommendedProxySettings = false;
      extraConfig = ''
        proxy_set_header Host ${hostHeader};
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-For $remote_addr;
      '';
    };
  };
in
lib.mkIf (profileName == "hyprland" && config.services.tailscale.enable && config.services.sunshine.enable) {
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 80 443 ];
  services.sunshine.settings.csrf_allowed_origins = "https://${sunshineHost}";

  sops = {
    age.keyFile = lib.mkDefault "${config.users.users.${userName}.home}/.config/sops/age/keys.txt";
    secrets.CLOUDFLARE_DNS_API_TOKEN.sopsFile = ../../../secrets/shared/cloudflare.yaml;
  };
  security.acme = {
    acceptTerms = true;
    certs.${sunshineHost} = {
      email = "osmargm1202@gmail.com";
      extraDomainNames = [ syncthingHost ];
      dnsProvider = "cloudflare";
      credentialFiles.CF_DNS_API_TOKEN_FILE = config.sops.secrets.CLOUDFLARE_DNS_API_TOKEN.path;
      group = "nginx";
      reloadServices = [ "nginx.service" ];
    };
  };

  services.nginx = {
    enable = true;
    recommendedTlsSettings = true;
    virtualHosts = {
      ${sunshineHost} = panel "https://127.0.0.1:47990" "$host";
      # Syncthing checks Host when its GUI listens on loopback.
      ${syncthingHost} = panel "http://127.0.0.1:8384" "localhost";
      orgm-reject-unknown-host = {
        inherit listen;
        default = true;
        rejectSSL = true;
        locations."/".return = "421";
      };
    };
  };
  systemd.services.nginx = {
    after = [ "tailscaled.service" ];
    wants = [ "tailscaled.service" ];
    preStart = lib.mkBefore ''
      ready=false
      for attempt in $(seq 1 30); do
        if ${pkgs.iproute2}/bin/ip -4 -o addr show dev tailscale0 | ${pkgs.gnugrep}/bin/grep -Fq ' ${tailnetAddress}/'; then
          ready=true
          break
        fi
        sleep 1
      done
      "$ready"
    '';
    # The address check needs netlink in the service sandbox.
    serviceConfig.RestrictAddressFamilies = [ "AF_NETLINK" ];
  };
}
