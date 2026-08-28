{
  inputs,
  userName,
  pkgs,
  ...
}:
{
  home-manager.users.${userName} = { config, lib, ... }: {
    imports = [ inputs.sops-nix.homeManagerModules.sops ];

    sops = {
      # This stable user-local path is a symlink managed by `sops-age-key`.
      # The activation below seeds it from the shared recovery identity only
      # when no local host override exists.
      age.keyFile = "${config.xdg.configHome}/sops/age/keys.txt";
      defaultSopsFile = ../secrets/shared/api-keys.yaml;

      secrets = {
        OPENCODE_API_KEY = { };
        MINIMAX_API_KEY = { };
        ANTHROPIC_API_KEY = { };
        STITCH_API_KEY = { };
        INSFORGE_API_KEY = { };
        INSFORGE_API_BASE_URL = { };
        AVANTE_ANTHROPIC_API_KEY = { };
        ORGM_TOKEN = { };

        WINDOWS_RDP_PASSWORD_OSMAR_WINDOWS = {
          sopsFile = ../secrets/shared/windows-rdp.yaml;
          mode = "0400";
        };
        WINDOWS_RDP_PASSWORD_LENOVO_WINDOWS = {
          sopsFile = ../secrets/shared/windows-rdp.yaml;
          mode = "0400";
        };
        WINDOWS_RDP_PASSWORD_TONY_WINDOWS = {
          sopsFile = ../secrets/shared/windows-rdp.yaml;
          mode = "0400";
        };
        WINDOWS_RDP_PASSWORD_HP_WINDOWS = {
          sopsFile = ../secrets/shared/windows-rdp.yaml;
          mode = "0400";
        };
        WINDOWS_RDP_PASSWORD_INTEGRA_WINDOWS = {
          sopsFile = ../secrets/shared/windows-rdp.yaml;
          mode = "0400";
        };
      };
    };

    home.sessionVariables = {
      WINDOWS_RDP_OSMAR_WINDOWS_USER = "osmarg";
      WINDOWS_RDP_OSMAR_WINDOWS_PASSWORD_FILE = config.sops.secrets.WINDOWS_RDP_PASSWORD_OSMAR_WINDOWS.path;
      WINDOWS_RDP_LENOVO_WINDOWS_USER = "osmarg";
      WINDOWS_RDP_LENOVO_WINDOWS_PASSWORD_FILE = config.sops.secrets.WINDOWS_RDP_PASSWORD_LENOVO_WINDOWS.path;
      WINDOWS_RDP_TONY_WINDOWS_USER = "osmarg";
      WINDOWS_RDP_TONY_WINDOWS_PASSWORD_FILE = config.sops.secrets.WINDOWS_RDP_PASSWORD_TONY_WINDOWS.path;
      WINDOWS_RDP_HP_WINDOWS_USER = "osmarg";
      WINDOWS_RDP_HP_WINDOWS_PASSWORD_FILE = config.sops.secrets.WINDOWS_RDP_PASSWORD_HP_WINDOWS.path;
      WINDOWS_RDP_INTEGRA_WINDOWS_USER = "osmarg";
      WINDOWS_RDP_INTEGRA_WINDOWS_PASSWORD_FILE = config.sops.secrets.WINDOWS_RDP_PASSWORD_INTEGRA_WINDOWS.path;
    };
    home.activation.initializeSopsAgeKey = lib.hm.dag.entryBefore [ "sops-nix" ] ''
      key_file="${config.xdg.configHome}/sops/age/keys.txt"
      default_key_file="${config.home.homeDirectory}/Nextcloud/Documentos/keys/age.txt"

      if [ -L "$key_file" ] && [ ! -e "$key_file" ]; then
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/rm -f "$key_file"
      fi

      if [ ! -e "$key_file" ] && [ -r "$default_key_file" ]; then
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$key_file")"
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/chmod 700 "$(${pkgs.coreutils}/bin/dirname "$key_file")"
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/ln -s "$default_key_file" "$key_file"
      fi
    '';
  };
}
