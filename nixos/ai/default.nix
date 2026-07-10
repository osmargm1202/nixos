# Necesidades de runtime de los AI CLIs (instaladores nativos + nix-ld).
# Los binarios se instalan/actualizan con sus instaladores oficiales;
# estos modulos solo garantizan el entorno en todos los hosts.
{ ... }:
{
  imports = [
    ./claude.nix
    ./codex.nix
    ./copilot.nix
    ./pi.nix
    ./opencode.nix
  ];
}
