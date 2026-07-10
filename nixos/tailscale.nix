# Mesh VPN for remote access to machines behind NAT we don't control
# (e.g. jarq's). Auth is manual per host, not declarative:
#   sudo tailscale up --auth-key=tskey-auth-... --accept-dns=false
# accept-dns stays OFF: with it on, tailscaled rewrites /etc/resolv.conf
# to 100.100.100.100 and every DNS query depends on the daemon (broken
# internet on restarts/sleep). sshgo connects by Tailscale IP, so
# MagicDNS names aren't needed.
{ ... }:
{
  services.tailscale.enable = true;
  services.tailscale.useRoutingFeatures = "client";
}
