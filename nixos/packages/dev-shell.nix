# FHS dev environment. Takes pkgs directly (not via callPackage) so the
# caller controls allowUnfree. Call as:
#   import ./packages/dev-shell.nix { inherit pkgs herdr; }
#
# After nixos-rebuild switch, the `dev` binary is in PATH system-wide —
# no flake checkout path required on the target machine.
{ pkgs, herdr }:
pkgs.buildFHSEnv {
  name = "dev";
  targetPkgs =
    pkgs: with pkgs; [
      # Shell
      fish
      # Node.js ecosystem
      nodejs_22
      nodePackages.pnpm
      bun
      # Python
      python3
      uv
      # Go
      go
      # Rust
      rustup
      # Core utils
      wget
      curl
      rsync
      git
      git-lfs
      gh
      vim
      neovim
      nano
      herdr
      stow
      less
      bc
      diffutils
      tree
      zip
      unzip
      pigz
      time
      # Search / navigation
      fd
      fzf
      ripgrep
      zoxide
      eza
      # Terminal tools
      starship
      glow
      gum
      yazi
      bat
      duf
      fastfetch
      figlet
      # System monitoring
      htop
      btop
      ncdu
      lsof
      mtr
      traceroute
      tcpdump
      inetutils
      # Dev tools
      age
      sops
      jq
      just
      watchexec
      inotify-tools
      trash-cli
      # Clipboard / X11
      wl-clipboard
      xclip
      xauth
      # Network
      openssh
      # Notifications
      libnotify
      # Build deps for native npm modules (node-gyp)
      gcc
      gnumake
      openssl
      openssl.dev
      pkg-config
      # AI/dev CLIs from nixpkgs
      claude-code
      gemini-cli
      pyright
      nodePackages.typescript-language-server
      nodePackages.svelte-language-server
    ];
  runScript = "fish";
  profile = ''
    export IN_DEV_SHELL=1
    export NPM_CONFIG_PREFIX="$HOME/.npm-global"
    export PATH="$HOME/.npm-global/bin:$PATH"
    export GOPATH="$HOME/go"
    export PATH="$GOPATH/bin:$PATH"
    export CARGO_HOME="$HOME/.cargo"
    export PATH="$CARGO_HOME/bin:$PATH"
  '';
}
