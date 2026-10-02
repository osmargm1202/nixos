# GitHub Copilot CLI — instalado como `gh extension install github/gh-copilot`.
# Es un binario Go compilado, corre via nix-ld.
# Este modulo NO instala copilot; solo provee su runtime.
{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf (builtins.elem "ai" config.orgm.user.programs) {
    # Binary CLI needs the dynamic loader.
    programs.nix-ld.enable = true;
  };
}
