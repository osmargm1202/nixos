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
  imports = [ ./lazyvim-prebuilt.nix ];
  config = lib.mkIf enabled {
    environment.systemPackages = with pkgs; [
      git
      curl
      unzip
      fzf
      ripgrep
      fd
      lazygit
    ] ++ lib.optionals (!config.orgm.neovim.prebuilt) [ neovim tree-sitter gcc gnumake ];
  };
}
