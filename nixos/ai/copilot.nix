# GitHub Copilot CLI — instalado como `gh extension install github/gh-copilot`.
# Es un binario Go compilado, corre via nix-ld.
# Este modulo NO instala copilot; solo provee su runtime.
{ ... }:
{
  # Binario compilado: necesita loader dinamico.
  programs.nix-ld.enable = true;
}
