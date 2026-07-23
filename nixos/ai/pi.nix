# pi coding agent — instalacion nativa via `bun add -g --ignore-scripts @earendil-works/pi-coding-agent`.
# Este módulo NO instala pi; solo provee sus necesidades de runtime.
{ pkgs, ... }:
let
  piInstall = pkgs.writeShellScriptBin "pi-install" ''
    #! /bin/sh
    if ! command -v bun >/dev/null 2>&1; then
      echo "pi-install: bun no está disponible. Asegúrate de tener bun instalado." >&2
      exit 1
    fi

    if [ -z "$BUN_INSTALL" ]; then
      export BUN_INSTALL="$HOME/.bun"
    fi
    export PATH="$BUN_INSTALL/bin:$PATH"

    exec bun add -g --ignore-scripts @earendil-works/pi-coding-agent "$@"
  '';
in
{
  environment.systemPackages = with pkgs; [
    # Runtime del CLI y de `bun add -g --ignore-scripts`.
    nodejs_22
    bun
    piInstall
  ];
}
