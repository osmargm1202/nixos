# Herramientas y necesidades de runtime compartidas por los AI CLIs.
# Los binarios con paquete local se gestionan mediante Nix; los demás CLIs
# conservan sus instaladores oficiales y reciben aquí su entorno de ejecución.
{ ... }:
{
  imports = [
    ./claude.nix
    ./codex.nix
    ./copilot.nix
    ./engram.nix
    ./rtk.nix
    ./pi.nix
    ./opencode.nix
  ];
}
