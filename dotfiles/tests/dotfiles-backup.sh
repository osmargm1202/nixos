#!/usr/bin/env bash
set -euo pipefail

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP="$HOME/.config.bak-$TIMESTAMP"
RECORD="$HOME/.dotfiles-config-backup"

if [ ! -d "$HOME/.config" ]; then
    echo "ERROR: ~/.config not found"
    exit 1
fi

if [ -f "$RECORD" ]; then
    PREV=$(cat "$RECORD")
    echo "WARNING: previous backup record exists: $PREV"
    echo "Delete it manually or run dotfiles-restore.sh first."
    exit 1
fi

mv "$HOME/.config" "$BACKUP"
echo "$BACKUP" > "$RECORD"

echo "Backed up: ~/.config → $BACKUP"
echo ""
echo "Next steps:"
echo "  1. nh os switch"
echo "  2. tests/dotfiles-audit.sh"
echo "  (rollback: tests/dotfiles-restore.sh)"
