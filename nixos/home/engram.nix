{ lib, pkgs, ... }:

{
  home.packages = [ pkgs.go ];

  home.activation.installEngram = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "$HOME/.local/bin"
    if [ -z "''${DRY_RUN:-}" ]; then
      GOBIN="$HOME/.local/bin" GOPATH="$HOME/go" ${pkgs.go}/bin/go install github.com/Gentleman-Programming/engram/cmd/engram@latest
    fi
  '';
}
