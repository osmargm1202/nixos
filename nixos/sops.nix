{
  inputs,
  userName,
  ...
}:
{
  home-manager.users.${userName} = { config, ... }: {
    imports = [ inputs.sops-nix.homeManagerModules.sops ];

    sops = {
      # Existing shared recovery/edit identity. It is intentionally outside Git
      # and the Nix store; future host-only secrets use SSH host identities.
      age.keyFile = "${config.home.homeDirectory}/Nextcloud/Documentos/keys/age.txt";
      defaultSopsFile = ../secrets/shared/api-keys.yaml;

      secrets = {
        OPENCODE_API_KEY = { };
        MINIMAX_API_KEY = { };
        ANTHROPIC_API_KEY = { };
        STITCH_API_KEY = { };
        INSFORGE_API_KEY = { };
        INSFORGE_API_BASE_URL = { };
        AVANTE_ANTHROPIC_API_KEY = { };
      };

    };
  };
}
