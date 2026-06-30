#!/usr/bin/env bash
set -euo pipefail

RECORD="$HOME/.dotfiles-config-backup"

if [ ! -f "$RECORD" ]; then
    echo "No backup record found."
    echo "Check for ~/.config.bak-* dirs manually."
    exit 1
fi

BACKUP=$(cat "$RECORD")

if [ ! -d "$BACKUP" ]; then
    echo "ERROR: Backup dir not found: $BACKUP"
    exit 1
fi

if [ -d "$HOME/.config" ]; then
    echo "Removing current ~/.config ..."
    rm -rf "$HOME/.config"
fi

mv "$BACKUP" "$HOME/.config"
rm "$RECORD"

echo "Restored: $BACKUP → ~/.config"
