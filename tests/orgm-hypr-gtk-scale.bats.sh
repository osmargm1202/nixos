#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

orgm_hypr_settings="$(nix eval --json '.#nixosConfigurations.orgm-hyprland.config.home-manager.users.osmarg.dconf.settings')"
orgm_i3_settings="$(nix eval --json '.#nixosConfigurations.orgm-i3.config.home-manager.users.osmarg.dconf.settings')"
lenovo_hypr_settings="$(nix eval --json '.#nixosConfigurations.lenovo-hyprland.config.home-manager.users.osmarg.dconf.settings')"

jq -e '
  .["org/gnome/desktop/interface"] == {
    "font-name": "Sans 11",
    "text-scaling-factor": 1
  }
' <<<"$orgm_hypr_settings" >/dev/null

jq -e '
  has("org/gnome/desktop/interface") | not
' <<<"$orgm_i3_settings" >/dev/null

jq -e '
  has("org/gnome/desktop/interface") | not
' <<<"$lenovo_hypr_settings" >/dev/null

printf '%s\n' 'orgm-hypr-gtk-scale: ok'
