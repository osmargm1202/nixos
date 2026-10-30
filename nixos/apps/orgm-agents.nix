{
  config,
  inputs,
  lib,
  userName,
  ...
}:
# ORGM agent hub (Codeman) — shared parameters. A host only opts in with
#   services.orgm-agents.enable = true;
#   services.orgm-agents.dns.manage = true;   # only on the ACTIVE hub
# Moving the hub to another host = flip these two lines, restore the latest
# backup there (`orgm-agents restore`), and rebuild. See ~/Code/amux/PLAN.md.
# Other servers need nothing from this module: the hub reaches them over SSH
# (sshAuthorizedKeys) and runs the agents in their tmux.
let
  cfg = config.services.orgm-agents;
in
{
  imports = [
    inputs.sops-nix.nixosModules.sops
    inputs.orgm-amux.nixosModules.default
  ];

  services.orgm-agents = {
    user = lib.mkDefault userName;
    domain = lib.mkDefault "code.or-gm.com";
    settings.CODEMAN_USERNAME = lib.mkDefault userName;
    environmentFiles = [ config.sops.templates."orgm-agents-codeman.env".path ];
    acme = {
      email = lib.mkDefault "osmargm1202@gmail.com";
      environmentFile = config.sops.templates."orgm-agents-acme.env".path;
    };
    # Same age identity as .sops.yaml (&shared_age): every host holding the
    # shared key can restore every backup.
    backup.ageRecipient = lib.mkDefault "age1hmnr736sfpqqs02j8zgaydm9r8c8cw9f5eek644rwvlygkgknaxqe64kx7";
  };

  sops = lib.mkIf cfg.enable {
    # System-level sops uses the same shared identity the user profile seeds.
    age.keyFile = lib.mkDefault "/home/${userName}/.config/sops/age/keys.txt";
    secrets.CLOUDFLARE_DNS_API_TOKEN.sopsFile = ../../secrets/shared/cloudflare.yaml;
    secrets.CODEMAN_PASSWORD.sopsFile = ../../secrets/shared/codeman.yaml;
    templates."orgm-agents-acme.env".content = ''
      CLOUDFLARE_DNS_API_TOKEN=${config.sops.placeholder.CLOUDFLARE_DNS_API_TOKEN}
    '';
    # Read by the user service, so the user must own it.
    templates."orgm-agents-codeman.env" = {
      owner = userName;
      content = ''
        CODEMAN_PASSWORD=${config.sops.placeholder.CODEMAN_PASSWORD}
      '';
    };
  };
}
