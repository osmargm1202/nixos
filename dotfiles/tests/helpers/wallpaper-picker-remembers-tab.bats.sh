#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
QML="$ROOT/config/shared/.config/quickshell/wallpaper-picker/shell.qml"

for needle in \
  'property string lastModePath:' \
  'function rememberedMode()' \
  'function rememberActiveMode(mode)' \
  'root.activeMode = remembered || (parsed.initialMode === "video" ? "video" : "static")' \
  'root.rememberActiveMode(nextMode)'; do
  if ! grep -Fq "$needle" "$QML"; then
    echo "FAIL: wallpaper picker does not persist selected tab; missing: $needle" >&2
    exit 1
  fi
done

echo "wallpaper picker tab memory smoke test passed"
