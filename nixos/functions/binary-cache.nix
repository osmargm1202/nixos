{ pkgs, ... }:

let
  orgmCacheRun = pkgs.writeShellApplication {
    name = "orgm-cache-run";
    runtimeInputs = [ pkgs.cachix ];
    text = ''
      if [ "$#" -eq 0 ]; then
        echo "Usage: orgm-cache-run <nix-build-command> [args...]" >&2
        echo "Example: orgm-cache-run nix build .#nixosConfigurations.orgm.config.system.build.toplevel" >&2
        exit 2
      fi

      exec cachix watch-exec --watch-mode post-build-hook orgm "$@"
    '';
  };
in
{
  # Public access needs no secret. The write token remains in the invoking
  # user's Cachix config and is only used by orgm-cache-run.
  nix.settings = {
    trusted-users = [ "root" "@wheel" ];
    substituters = [ "https://orgm.cachix.org" ];
    trusted-public-keys = [
      "orgm.cachix.org-1:8Be6uDm2ivJw4MPJBuCaoJfZtfp6RBbjh2IzI4JmqVA="
    ];
  };

  environment.systemPackages = [
    pkgs.cachix
    orgmCacheRun
  ];
}
