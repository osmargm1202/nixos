#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail() { echo "FAIL: $*" >&2; exit 1; }

if rg --hidden -n 'Exec=/nix/store/.*/distrobox|Exec=orgmos menu|Exec=orgm prop|Exec=/usr/bin/opencode-desktop|flatpak run com\.valvesoftware\.Steam' "$ROOT/config/hosts"; then
  fail "found stale desktop launcher Exec"
fi

for host in orgm lenovo; do
  appdir="$ROOT/config/hosts/$host/.local/share/applications"
  [ -d "$appdir" ] || continue
  [ ! -e "$appdir/orgmos.desktop" ] || fail "$host orgmos.desktop should be removed"
  [ ! -e "$appdir/propuestas.desktop" ] || fail "$host propuestas.desktop should be removed"
  [ ! -e "$appdir/opencode-desktop-handler.desktop" ] || fail "$host opencode handler should be removed until binary exists"
  if [ -e "$appdir/arch.desktop" ]; then
    grep -Fq 'Exec=distrobox enter arch' "$appdir/arch.desktop" || fail "$host arch desktop should use PATH distrobox enter"
    grep -Fq 'TryExec=distrobox' "$appdir/arch.desktop" || fail "$host arch desktop should use PATH TryExec"
    ! grep -Fq 'Exec=distrobox rm arch' "$appdir/arch.desktop" || fail "$host arch desktop remove action should be removed"
  fi
  if [ -e "$appdir/mimeinfo.cache" ]; then
    ! grep -Fq 'opencode-desktop-handler.desktop' "$appdir/mimeinfo.cache" || fail "$host mimeinfo.cache should not reference opencode handler"
  fi
done

echo "desktop launcher audit passed"
