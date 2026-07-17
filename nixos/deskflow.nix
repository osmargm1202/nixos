{
  config,
  lib,
  pkgs,
  userName ? "osmarg",
  ...
}:

let
  deskflowAppId = "org.deskflow.deskflow";
  deskflowLauncher = pkgs.writeShellScript "deskflow-launcher" ''
        #!/bin/sh
        set -eu

        wait_for_graphics() {
          i=0
          until [ "$i" -ge 30 ]; do
            # Query the user manager while its inherited runtime directory is intact.
            manager_environment="$(systemctl --user show-environment 2>/dev/null || true)"

            WAYLAND_DISPLAY=""
            DISPLAY=""
            XDG_RUNTIME_DIR=""

            while IFS= read -r line; do
              case "$line" in
                WAYLAND_DISPLAY=*) WAYLAND_DISPLAY="$(printf '%s' "$line" | sed 's/^WAYLAND_DISPLAY=//')" ;;
                DISPLAY=*) DISPLAY="$(printf '%s' "$line" | sed 's/^DISPLAY=//')" ;;
                XDG_RUNTIME_DIR=*) XDG_RUNTIME_DIR="$(printf '%s' "$line" | sed 's/^XDG_RUNTIME_DIR=//')" ;;
              esac
            done <<EOF
    $manager_environment
    EOF

            if [ -n "$WAYLAND_DISPLAY" ] || [ -n "$DISPLAY" ]; then
              if [ -n "$XDG_RUNTIME_DIR" ] && [ -S "$XDG_RUNTIME_DIR/bus" ]; then
                export WAYLAND_DISPLAY DISPLAY XDG_RUNTIME_DIR
                return 0
              fi
            fi

            sleep 1
            i=$((i + 1))
          done
          return 1
        }

        wait_for_graphics
        exec flatpak run ${deskflowAppId}
  '';
in
{
  services.flatpak.packages = lib.mkAfter [ deskflowAppId ];

  # Deskflow installed but not started automatically (manual only).
  home-manager.users.${userName} = {
    systemd.user.services.deskflow = {
      Unit = {
        Description = "Start Deskflow in GUI session (manual)";
      };

      Service = {
        Type = "simple";
        ExecStart = "${deskflowLauncher}";
        ExecStop = "-${pkgs.flatpak}/bin/flatpak kill ${deskflowAppId}";
        Restart = "on-failure";
        RestartSec = 10;
      };

      # Keep unit defined for manual start: `systemctl --user start deskflow`
      # Autostart disabled by removing default.target binding.
      Install = {
        WantedBy = [ ];
      };
    };
  };
}
