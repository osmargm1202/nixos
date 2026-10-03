# Mesh VPN for remote access to machines behind NAT we don't control
# (e.g. jarq's). Authentication remains manual per host:
#   sudo tailscale up --auth-key=tskey-auth-...
# `--accept-dns=true` delegates tailnet names to Tailscale's native
# systemd-resolved integration. Tailscale reapplies split DNS after daemon,
# link, suspend and network changes; static /etc/hosts entries remain only for
# service aliases that MagicDNS does not provide.
{
  config,
  inputs,
  lib,
  pkgs,
  userName,
  ...
}:
let
  cfg = config.orgm.tailscale.peerNotifications;
  localReady = pkgs.writeShellApplication {
    name = "tailscale-local-ready";
    runtimeInputs = [ pkgs.networkmanager pkgs.tailscale pkgs.jq ];
    text = builtins.readFile ./tailscale-local-ready.sh;
  };
  peerMonitorServiceName = "tailscale-peer-monitor";
  peerNotifierServiceName = "tailscale-peer-notifier";

  tailscalePeerMonitor = pkgs.writeShellApplication {
    name = peerMonitorServiceName;
    runtimeInputs = with pkgs; [
      localReady
      bash
      coreutils
      jq
      systemd
      tailscale
    ];
    text = builtins.readFile ./tailscale-peer-monitor.sh;
  };

  tailscalePeerNotifier = pkgs.writeShellApplication {
    name = peerNotifierServiceName;
    runtimeInputs = with pkgs; [
      localReady
      bash
      coreutils
      libnotify
      systemd
    ];
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      LOG_TAG="tailscale-peer-notifier"
      SYSTEM_STATE="/var/lib/tailscale-peer-monitor"
      EVENT_FILE="$SYSTEM_STATE/events-v3.tsv"
      STATE_DIR="''${XDG_STATE_HOME:-$HOME/.local/state}/tailscale-peer-monitor"
      CURSOR_FILE="$STATE_DIR/last-event-id-v3"

      mkdir -p "$STATE_DIR"
      [ -r "$EVENT_FILE" ] || exit 0

      latest_event="$(tail -n 1 "$EVENT_FILE")"
      if [ -z "$latest_event" ]; then
        # Start before the first real event, without replaying an existing
        # stream on installation. Zero is the empty-stream cursor.
        [ -f "$CURSOR_FILE" ] || printf '%s\n' 0 > "$CURSOR_FILE"
        exit 0
      fi
      IFS=$'\t' read -r latest_event_id _ <<< "$latest_event"

      if [ ! -f "$CURSOR_FILE" ]; then
        printf '%s\n' "$latest_event_id" > "$CURSOR_FILE"
        exit 0
      fi

      read -r last_event_id < "$CURSOR_FILE" || last_event_id=""
      if ! [[ "$last_event_id" =~ ^[0-9]+$ ]]; then
        printf '%s\n' "$latest_event_id" > "$CURSOR_FILE"
        exit 0
      fi
      [ "$latest_event_id" != "$last_event_id" ] || exit 0

      # Suppress delivery too: an event may be queued just before our uplink
      # disappears. It must not become a flood after reconnecting.
      if ! tailscale-local-ready || [ -e "$SYSTEM_STATE/local-network-down" ]; then
        printf '%s\n' "$latest_event_id" > "$CURSOR_FILE"
        exit 0
      fi
      delivery_floor=0
      if [ -r "$SYSTEM_STATE/delivery-floor" ]; then
        read -r delivery_floor < "$SYSTEM_STATE/delivery-floor" || delivery_floor=0
      fi

      cursor_found=false
      [ "$last_event_id" != 0 ] || cursor_found=true
      while IFS=$'\t' read -r event_id _; do
        if [ "$event_id" = "$last_event_id" ]; then
          cursor_found=true
          break
        fi
      done < "$EVENT_FILE"

      if [ "$cursor_found" != true ]; then
        printf '%s\n' "Cursor de eventos expiró; se omiten eventos históricos." | systemd-cat -t "$LOG_TAG" -p info || true
        printf '%s\n' "$latest_event_id" > "$CURSOR_FILE"
        exit 0
      fi

      after_cursor=false
      [ "$last_event_id" != 0 ] || after_cursor=true
      while IFS=$'\t' read -r event_id host ip state; do
        if [ "$after_cursor" = false ]; then
          if [ "$event_id" = "$last_event_id" ]; then
            after_cursor=true
          fi
          continue
        fi

        if [ "$event_id" -lt "$delivery_floor" ]; then
          printf '%s\n' "$event_id" > "$CURSOR_FILE"
          continue
        fi
        if [ "$state" = "online" ]; then
          title="Tailscale: equipo en línea"
          message="''${host} (''${ip}) volvió en línea"
        else
          title="Tailscale: equipo desconectado"
          message="''${host} (''${ip}) se desconectó"
        fi

        if notify-send -a Tailscale -u normal "$title" "$message"; then
          printf '%s\n' "$event_id" > "$CURSOR_FILE"
        else
          printf '%s\n' "No se pudo mostrar: $message" | systemd-cat -t "$LOG_TAG" -p warning || true
          exit 1
        fi
      done < "$EVENT_FILE"
    '';
  };
in
{
  options.orgm.tailscale.peerNotifications = {
    enable = lib.mkEnableOption "desktop notifications for real Tailscale peer changes";
    disconnectGraceSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 90;
      description = "Continuous observed offline time before notifying about a peer IP.";
    };
  };
  config = lib.mkIf (builtins.elem "tailscale" config.orgm.user.programs) {
  orgm.tailscale.peerNotifications.enable = lib.mkDefault (builtins.elem "orgm" config.orgm.user.programs);
  # Keep tailscaled, the CLI/systray and peer-monitor tooling on one version.
  nixpkgs.overlays = [
    (_final: prev: {
      tailscale = inputs.nixpkgs-tailscale.legacyPackages.${prev.stdenv.hostPlatform.system}.tailscale;
    })
  ];

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
    # Set this explicitly because the preference persists in Tailscale state.
    extraSetFlags = [ "--accept-dns=true" ];
  };

  # Tailscale integrates with resolved dynamically while NetworkManager keeps
  # managing the normal per-link resolvers.
  services.resolved.enable = true;


  systemd = lib.mkIf cfg.enable {
    services.${peerMonitorServiceName} = {
      description = "Detect Tailscale peer connection changes";
      after = [ "tailscaled.service" ];
      wants = [ "tailscaled.service" ];
      serviceConfig = {
        Type = "oneshot";
        Environment = "DISCONNECT_GRACE_SECONDS=${toString cfg.disconnectGraceSeconds}";
        StateDirectory = "tailscale-peer-monitor";
        StateDirectoryMode = "0755";
        ExecStart = "${tailscalePeerMonitor}/bin/${peerMonitorServiceName}";
        StandardOutput = "journal";
        StandardError = "journal";
      };
    };

    timers.${peerMonitorServiceName} = {
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

    user.services.${peerNotifierServiceName} = {
      description = "Show desktop notifications for Tailscale peer changes";
      after = [ "graphical-session.target" ];
      unitConfig.ConditionUser = userName;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${tailscalePeerNotifier}/bin/${peerNotifierServiceName}";
      };
    };

    user.timers.${peerNotifierServiceName} = {
      wantedBy = [ "graphical-session.target" ];
      timerConfig = {
        Unit = "${peerNotifierServiceName}.service";
        OnBootSec = "5s";
        OnUnitActiveSec = "5s";
        AccuracySec = "1s";
      };
    };
  };
  };
}
