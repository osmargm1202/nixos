# opencode — instalador nativo (curl -fsSL https://opencode.ai/install | bash),
# binario standalone en ~/.opencode/bin (o ~/.local/bin). Corre via nix-ld.
# Este modulo NO instala opencode; solo provee sus necesidades de runtime.
{ ... }:
{
  # Binario compilado con bun: solo necesita el loader dinamico.
  programs.nix-ld.enable = true;
}
