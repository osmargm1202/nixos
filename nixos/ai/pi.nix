# pi coding agent — instalacion nativa via `npm install -g @mariozechner/pi`
# (prefix ~/.npm-global, ya en PATH via fish). No existe en nixpkgs.
# Este modulo NO instala pi; solo provee sus necesidades de runtime.
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # Runtime del CLI y de `npm install -g`.
    nodejs_22
  ];
}
