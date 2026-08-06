#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

policy="$(nix eval --json '.#nixosConfigurations.lenovo-hyprland.config.services.pipewire.wireplumber.extraConfig."90-lenovo-audio-policy"')"

jq -e '
  .["wireplumber.settings"]["linking.follow-default-target"] == true
  and .["wireplumber.settings"]["node.restore-default-targets"] == true
  and .["monitor.alsa.rules"][0].matches[0]["node.name"] == "~.*HiFi__Headphones__sink$"
  and .["monitor.alsa.rules"][0].actions["update-props"]["priority.session"] == 1200
  and .["monitor.alsa.rules"][1].matches[0]["node.name"] == "~.*[hH][dD][mM][i].*"
  and .["monitor.alsa.rules"][1].actions["update-props"]["priority.session"] == 100
' <<<"$policy" >/dev/null

sync_service="$(nix eval --raw '.#nixosConfigurations.lenovo-hyprland.config.systemd.user.services.wireplumber-default-sink-sync.serviceConfig.ExecStart')"
[[ "$sync_service" == *"/bin/pipewire-default-sink-sync" ]]

printf '%s\n' 'lenovo-audio-policy: ok'
