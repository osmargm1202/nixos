#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

policy="$(nix eval --json '.#nixosConfigurations.orgm-cinnamon.config.services.pipewire.wireplumber.extraConfig."90-orgm-audio-policy"')"

jq -e '
  def has_realtek_rule($class; $node):
    any(
      .["monitor.alsa.rules"][];
      (.matches | any(.["media.class"] == $class and .["node.name"] == $node))
      and .actions["update-props"]["priority.session"] == 3000
    );

  has_realtek_rule("Audio/Sink"; "alsa_output.pci-0000_00_1f.3.analog-stereo")
  and has_realtek_rule("Audio/Source"; "alsa_input.pci-0000_00_1f.3.analog-stereo")
' <<<"$policy" >/dev/null

service="$(nix eval --json '.#nixosConfigurations.orgm-cinnamon.config.systemd.user.services.wireplumber-orgm-default-audio')"

jq -e '
  (.wantedBy | index("graphical-session.target") and index("wireplumber.service"))
  and .serviceConfig.Type == "oneshot"
  and .serviceConfig.RemainAfterExit == true
  and (.serviceConfig.ExecStart | endswith("/bin/pipewire-orgm-default-audio"))
' <<<"$service" >/dev/null

printf '%s\n' 'orgm-audio-policy: ok'
