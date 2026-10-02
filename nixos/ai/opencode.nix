# opencode — instalador nativo (curl -fsSL https://opencode.ai/install | bash),
# binario standalone en ~/.opencode/bin (o ~/.local/bin). Corre via nix-ld.
# Este modulo NO instala opencode; solo provee sus necesidades de runtime.
{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf (builtins.elem "ai" config.orgm.user.programs) {
    # The standalone binary needs the dynamic loader.
    programs.nix-ld.enable = true;
  };
}
