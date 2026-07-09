# Mesh VPN for remote access to machines behind NAT we don't control
# (e.g. jarq's). Auth is manual per host, not declarative:
#   sudo tailscale up --auth-key=tskey-auth-... --accept-dns
{ ... }:
{
  services.tailscale.enable = true;
  services.tailscale.useRoutingFeatures = "client";
}
