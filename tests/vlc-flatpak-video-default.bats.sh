#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLATPAK="$ROOT/nixos/flatpak.nix"
I3="$ROOT/nixos/profiles/i3.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

grep -Fq '"org.videolan.VLC"' "$FLATPAK" ||
  fail 'VLC Flatpak must be installed'
if grep -Fq 'org.videolan.VLC.desktop' "$FLATPAK"; then
  fail 'global VLC MIME defaults would conflict with profile-specific players'
fi

for mime in \
  video/mp4 \
  video/x-matroska \
  video/webm \
  video/quicktime \
  video/x-msvideo \
  video/mpeg \
  video/ogg; do
  grep -Fq "\"$mime\" = [ \"org.videolan.VLC.desktop\" ];" "$I3" ||
    fail "VLC must be the default handler for $mime"
done

printf 'PASS: VLC Flatpak is installed as the default video player\n'
