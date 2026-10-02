{
  config,
  lib,
  pkgs,
  ...
}:
let
  enabled = builtins.elem "neovim" config.orgm.user.programs;
in
{
  config = lib.mkIf enabled {
    environment.systemPackages = with pkgs; [
      neovim
      git
      tree-sitter
      gcc
      gnumake
      curl
      unzip
      fzf
      ripgrep
      fd
      lazygit
    ];
  };
}
