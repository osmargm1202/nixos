#!/usr/bin/env bash
# Explicit heavyweight integration: builds native Hyprland and Ryoku providers.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
exec python3 "$ROOT/tests/dotfiles-copies.py" NativeIntegration "$@"
