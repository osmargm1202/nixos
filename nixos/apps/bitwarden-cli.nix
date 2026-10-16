{
  config,
  lib,
  pkgs,
  userName ? "osmarg",
  ...
}:
let
  enabled = builtins.elem "bitwarden-cli" config.orgm.user.programs;
  helper = pkgs.writeShellApplication {
    name = "bw-orgm";
    runtimeInputs = [ pkgs.bitwarden-cli pkgs.jq ];
    text = builtins.readFile ./bitwarden-cli.sh;
  };
in
{
  # No activation hook or credentials: server bootstrap is explicit and guarded.
  home-manager.users.${userName}.home.packages = lib.optionals enabled [
    pkgs.bitwarden-cli
    helper
  ];
}
