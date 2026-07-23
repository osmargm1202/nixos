{ pkgs, ... }:
let
  ompPackage = "@oh-my-pi/pi-coding-agent";
  ompInstall = pkgs.writeShellScriptBin "omp-install" ''
    #! /bin/sh
    set -e

    if command -v bun >/dev/null 2>&1; then
      if [ -z "$BUN_INSTALL" ]; then
        export BUN_INSTALL="$HOME/.bun"
      fi
      export PATH="$BUN_INSTALL/bin:$PATH"
      exec bun add -g ${ompPackage} "$@"
    fi

    if command -v npm >/dev/null 2>&1; then
      if [ -z "$NPM_CONFIG_PREFIX" ]; then
        export NPM_CONFIG_PREFIX="$HOME/.npm-global"
      fi
      export PATH="$NPM_CONFIG_PREFIX/bin:$PATH"
      exec npm install -g ${ompPackage} "$@"
    fi

    if command -v pnpm >/dev/null 2>&1; then
      if [ -z "$PNPM_HOME" ]; then
        export PNPM_HOME="$HOME/.local/share/pnpm"
      fi
      export PATH="$PNPM_HOME:$PATH"
      exec pnpm add -g ${ompPackage} "$@"
    fi

    echo "omp-install: bun, npm, or pnpm is required. Install one first." >&2
    exit 1
  '';
  ompUpdate = pkgs.writeShellScriptBin "omp-update" ''
    #! /bin/sh
    exec omp-install "$@"
  '';
in
{
  # Node and JS installers used by the scripts above.
  programs.nix-ld.enable = true;
  environment.systemPackages = with pkgs; [
    bun
    nodejs_22
    pnpm
    ompInstall
    ompUpdate
  ];
}
