{ pkgs, ... }:
{
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
}
