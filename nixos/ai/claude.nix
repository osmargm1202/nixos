# Claude Code — instalador nativo (~/.local/bin/claude), preferido via `bun add`.
# Este módulo NO instala claude; solo provee sus necesidades de runtime.
{ pkgs, ... }:
let
  claudeInstall = pkgs.writeShellScriptBin "claude-install" ''
    #! /bin/sh
    if command -v bun >/dev/null 2>&1; then
      if [ -z "$BUN_INSTALL" ]; then
        export BUN_INSTALL="$HOME/.bun"
      fi
      export PATH="$BUN_INSTALL/bin:$PATH"
      exec bun add -g @anthropic-ai/claude-code "$@"
    fi

    if ! command -v npm >/dev/null 2>&1; then
      echo "claude-install: neither bun nor npm found. Instale bun (preferido) o npm." >&2
      exit 1
    fi

    if [ -z "$NPM_CONFIG_PREFIX" ]; then
      export NPM_CONFIG_PREFIX="$HOME/.npm-global"
    fi
    export PATH="$NPM_CONFIG_PREFIX/bin:$PATH"

    exec npm install -g @anthropic-ai/claude-code "$@"
  '';
in
{
  # Loader shim para el binario dinamico del instalador oficial.
  programs.nix-ld.enable = true;

  environment.systemPackages = with pkgs; [
    # Hooks de plugins (claude-mem, etc.) corren bajo /bin/sh sin fnm,
    # asi que node tiene que existir en el PATH base del sistema.
    nodejs_22
    # claude-mem ejecuta sus hooks con bun.
    bun
    # Por si algun plugin/instalador lo usa en vez de npm.
    pnpm
    claudeInstall
  ];
}
