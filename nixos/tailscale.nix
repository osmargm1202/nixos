# Mesh VPN for remote access to machines behind NAT we don't control
# (e.g. jarq's). Auth is manual per host, not declarative:
#   sudo tailscale up --auth-key=tskey-auth-... --accept-dns=false
# accept-dns stays OFF: with it on, tailscaled rewrites /etc/resolv.conf
# to 100.100.100.100 and every DNS query depends on the daemon (broken
# internet on restarts/sleep). sshgo connects by Tailscale IP, so
# MagicDNS names aren't needed.
{ pkgs, ... }:
let
  peerMonitorServiceName = "tailscale-peer-monitor";
  peerNotifierServiceName = "tailscale-peer-notifier";

  tailscalePeerMonitor = pkgs.writeShellApplication {
    name = peerMonitorServiceName;
    runtimeInputs = with pkgs; [
      bash
      coreutils
      jq
      systemd
      tailscale
    ];
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      LOG_TAG="tailscale-peer-monitor"
      STATE_DIR="''${STATE_DIRECTORY:-/var/lib/tailscale-peer-monitor}"
      EVENT_FILE="$STATE_DIR/events.tsv"
      STATE_FILE="$STATE_DIR/peer-status.tsv"

      collect_peers() {
        local status_json

        if ! status_json="$(tailscale status --json 2>&1)"; then
          printf '%s\n' "tailscale status failed: $status_json" | systemd-cat -t "$LOG_TAG" -p err || true
          return 1
        fi

        echo "$status_json" | jq -r '
          (.Peer // {})
          | if type == "object" then to_entries | map(.value)
            elif type == "array" then .
            else [] end
          | map(select((.Self // false) | not))
          | map({
              host: ((.HostName // .HostInfo.HostName // "") | ascii_downcase),
              ip: (.TailscaleIPs[0] // "sin-ip"),
              state: (if (.Online // false) then "online" else "offline" end)
            })
          | map(select(.host != ""))
          | sort_by(.host)
          | .[]
          | "\(.host)\t\(.ip)\t\(.state)"
        '
      }

      emit_event() {
        local host="$1"
        local ip="$2"
        local state="$3"
        local message

        if [ "$state" = "online" ]; then
          message="''${host} (''${ip}) volvió en línea"
        else
          message="''${host} (''${ip}) se desconectó"
        fi

        printf '%s\n' "$message" | systemd-cat -t "$LOG_TAG" -p info || true
        printf '%s\t%s\t%s\n' "$host" "$ip" "$state" >> "$EVENT_FILE"
      }

      main() {
        local current
        local -A previous_state
        local -A previous_ip
        local -A seen_host

        if ! current="$(collect_peers)"; then
          return
        fi

        mkdir -p "$STATE_DIR" "$(dirname "$EVENT_FILE")"
        touch "$EVENT_FILE"
        if [ ! -f "$STATE_FILE" ]; then
          printf '%s\n' "$current" > "$STATE_FILE"
          return
        fi

        while IFS=$'\t' read -r host ip state; do
          previous_state["$host"]="$state"
          previous_ip["$host"]="$ip"
        done < "$STATE_FILE"

        while IFS=$'\t' read -r host ip state; do
          [ -z "''${host:-}" ] && continue
          seen_host["$host"]=1

          if [ "''${previous_state[$host]+x}" = "x" ]; then
            if [ "''${previous_state[$host]}" != "$state" ]; then
              emit_event "$host" "$ip" "$state"
            fi
          elif [ "$state" = "online" ]; then
            emit_event "$host" "$ip" "$state"
          fi
        done <<< "$current"

        for host in "''${!previous_state[@]}"; do
          if [ "''${seen_host[$host]+x}" != "x" ] && [ "''${previous_state[$host]}" = "online" ]; then
            emit_event "$host" "''${previous_ip[$host]}" offline
          fi
        done

        printf '%s\n' "$current" > "$STATE_FILE"
      }

      main
    '';
  };

  tailscalePeerNotifier = pkgs.writeShellApplication {
    name = peerNotifierServiceName;
    runtimeInputs = with pkgs; [
      bash
      coreutils
      libnotify
      systemd
    ];
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      LOG_TAG="tailscale-peer-notifier"
      EVENT_FILE="/var/lib/tailscale-peer-monitor/events.tsv"
      STATE_DIR="''${XDG_STATE_HOME:-$HOME/.local/state}/tailscale-peer-monitor"
      OFFSET_FILE="$STATE_DIR/notification-offset"

      mkdir -p "$STATE_DIR"

      if [ -r "$EVENT_FILE" ]; then
        total_lines="$(wc -l < "$EVENT_FILE")"
        offset=0
        if [ -f "$OFFSET_FILE" ]; then
          read -r offset < "$OFFSET_FILE" || offset=0
        fi

        if ! [[ "$offset" =~ ^[0-9]+$ ]] || [ "$total_lines" -lt "$offset" ]; then
          offset=0
        fi

        if [ "$total_lines" -gt "$offset" ]; then
          start_line=$((offset + 1))
          events="$(tail -n "+$start_line" "$EVENT_FILE")"
          while IFS=$'\t' read -r host ip state; do
            [ -z "''${host:-}" ] && continue

            if [ "$state" = "online" ]; then
              title="Tailscale: equipo en línea"
              message="''${host} (''${ip}) volvió en línea"
            else
              title="Tailscale: equipo desconectado"
              message="''${host} (''${ip}) se desconectó"
            fi

            if notify-send -a Tailscale -u normal "$title" "$message"; then
              offset=$((offset + 1))
              printf '%s\n' "$offset" > "$OFFSET_FILE"
            else
              printf '%s\n' "No se pudo mostrar: $message" | systemd-cat -t "$LOG_TAG" -p warning || true
              break
            fi
          done <<< "$events"
        fi
      fi
    '';
  };
in
{
  services.tailscale.enable = true;
  services.tailscale.useRoutingFeatures = "client";

  systemd.services.${peerMonitorServiceName} = {
    description = "Detect Tailscale peer connection changes";
    after = [ "tailscaled.service" ];
    wants = [ "tailscaled.service" ];
    serviceConfig = {
      Type = "oneshot";
      StateDirectory = "tailscale-peer-monitor";
      StateDirectoryMode = "0755";
      ExecStart = "${tailscalePeerMonitor}/bin/${peerMonitorServiceName}";
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };

  systemd.timers.${peerMonitorServiceName} = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      Unit = "${peerMonitorServiceName}.service";
      OnBootSec = "30s";
      OnUnitActiveSec = "30s";
      AccuracySec = "5s";
      RandomizedDelaySec = "5s";
      Persistent = true;
    };
  };

  systemd.user.services.${peerNotifierServiceName} = {
    description = "Show desktop notifications for Tailscale peer changes";
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${tailscalePeerNotifier}/bin/${peerNotifierServiceName}";
    };
  };

  systemd.user.timers.${peerNotifierServiceName} = {
    wantedBy = [ "graphical-session.target" ];
    timerConfig = {
      Unit = "${peerNotifierServiceName}.service";
      OnBootSec = "5s";
      OnUnitActiveSec = "5s";
      AccuracySec = "1s";
    };
  };
}
