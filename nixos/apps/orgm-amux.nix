{
  config,
  inputs,
  lib,
  userName,
  ...
}:
# ORGM agent hub (amux) — shared parameters. A host only opts in with
#   services.orgm-amux.enable = true;
#   services.orgm-amux.dns.manage = true;   # only on the ACTIVE hub
# Moving the hub to another host = flip these two lines, restore the latest
# backup there (`orgm-amux restore`), and rebuild. See ~/Code/amux/PLAN.md.
let
  cfg = config.services.orgm-amux;
in
{
  imports = [
    inputs.sops-nix.nixosModules.sops
    inputs.orgm-amux.nixosModules.default
  ];

  services.orgm-amux = {
    user = lib.mkDefault userName;
    domain = lib.mkDefault "code.or-gm.com";
    acme = {
      email = lib.mkDefault "osmargm1202@gmail.com";
      environmentFile = config.sops.templates."orgm-amux-acme.env".path;
    };
    # Same age identity as .sops.yaml (&shared_age): every host holding the
    # shared key can restore every backup.
    backup.ageRecipient = lib.mkDefault "age1hmnr736sfpqqs02j8zgaydm9r8c8cw9f5eek644rwvlygkgknaxqe64kx7";
  };

  sops = lib.mkIf cfg.enable {
    # System-level sops uses the same shared identity the user profile seeds.
    age.keyFile = lib.mkDefault "/home/${userName}/.config/sops/age/keys.txt";
    secrets.CLOUDFLARE_DNS_API_TOKEN.sopsFile = ../../secrets/shared/cloudflare.yaml;
    templates."orgm-amux-acme.env".content = ''
      CLOUDFLARE_DNS_API_TOKEN=${config.sops.placeholder.CLOUDFLARE_DNS_API_TOKEN}
    '';
  };
}
