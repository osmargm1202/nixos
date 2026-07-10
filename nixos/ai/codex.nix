# OpenAI Codex CLI — instalacion nativa via `npm install -g @openai/codex`
# (prefix ~/.npm-global, ya en PATH via fish). Corre via nix-ld.
# Este modulo NO instala codex; solo provee sus necesidades de runtime.
{ pkgs, ... }:
{
  programs.nix-ld.enable = true;

  environment.systemPackages = with pkgs; [
    # Runtime del CLI y de `npm install -g`.
    nodejs_22
  ];
}
