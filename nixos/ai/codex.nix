# OpenAI Codex CLI — instalacion nativa via bun (`bun add -g @openai/codex`, fallback a npm).
# (prefix ~/.bun/bin o ~/.npm-global, ya en PATH via fish). Corre via nix-ld.
# Este módulo NO instala codex; solo provee sus necesidades de runtime.
{ pkgs, ... }:
let
  codexInstall = pkgs.writeShellScriptBin "codex-install" ''
    #! /bin/sh
    if command -v bun >/dev/null 2>&1; then
      if [ -z "$BUN_INSTALL" ]; then
        export BUN_INSTALL="$HOME/.bun"
      fi
      export PATH="$BUN_INSTALL/bin:$PATH"
      exec bun add -g @openai/codex "$@"
    fi

    if ! command -v npm >/dev/null 2>&1; then
      echo "codex-install: neither bun nor npm found. Instale bun (preferido) o npm." >&2
      exit 1
    fi

    if [ -z "$NPM_CONFIG_PREFIX" ]; then
      export NPM_CONFIG_PREFIX="$HOME/.npm-global"
    fi
    export PATH="$NPM_CONFIG_PREFIX/bin:$PATH"

    exec npm install -g @openai/codex "$@"
  '';
in
{
  programs.nix-ld.enable = true;

  environment.systemPackages = with pkgs; [
    # Runtime del CLI y de `bun`/`npm install -g`.
    nodejs_22
    bun
    codexInstall
  ];
}
