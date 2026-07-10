# Claude Code — instalador nativo (~/.local/bin/claude), corre via nix-ld.
# Este modulo NO instala claude; solo provee sus necesidades de runtime.
{ pkgs, ... }:
{
  # Loader shim para el binario dinamico del instalador oficial.
  programs.nix-ld.enable = true;

  environment.systemPackages = with pkgs; [
    # Hooks de plugins (claude-mem, etc.) corren bajo /bin/sh sin fnm,
    # asi que node tiene que existir en el PATH base del sistema.
    nodejs_22
    # claude-mem ejecuta sus hooks con bun.
    bun
    # Por si algun plugin/instalador lo usa en vez de npm.
    pnpm
  ];
}
