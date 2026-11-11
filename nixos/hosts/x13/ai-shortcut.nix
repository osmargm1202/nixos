{ pkgs, userName, ... }:
let
  orgmai = pkgs.callPackage ../../orgm/orgm-ai.nix {};
  launcher = pkgs.writeShellScript "x13-orgmai-chat" ''
    exec ${pkgs.kitty}/bin/kitty --class orgmai-chat \
      -o remember_window_size=no -o initial_window_width=160c \
      -o initial_window_height=42c -e ${orgmai}/bin/orgmai new
  '';
  python = pkgs.python3.withPackages (ps: [ ps.pygobject3 ]);
  merge = pkgs.writeShellScript "x13-ai-shortcut-merge" ''
    export GI_TYPELIB_PATH=${pkgs.glib.out}/lib/girepository-1.0
    export GSETTINGS_SCHEMA_DIR=${pkgs.gnome-settings-daemon}/share/gsettings-schemas/${pkgs.gnome-settings-daemon.name}/glib-2.0/schemas
    exec ${python}/bin/python3 ${./ai-shortcut-enable.py}
  '';
in {
  home-manager.users.${userName} = { lib, ... }: {
    dconf.settings = {
      # GNOME's default Super+A application grid would otherwise compete.
      "org/gnome/shell/keybindings".toggle-application-view = [];
      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/x13-orgmai" = {
        name = "ORGM AI";
        binding = "<Super>a";
        command = "${launcher}";
      };
    };
    # Merge the list instead of replacing unrelated user-defined shortcuts.
    home.activation.x13AiShortcut = lib.hm.dag.entryAfter [ "dconfSettings" ] ''
      if [ -S "/run/user/$(id -u)/bus" ]; then
        $DRY_RUN_CMD env XDG_RUNTIME_DIR="/run/user/$(id -u)" \
          DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus" ${merge}
      fi
    '';
    systemd.user.services.x13-ai-shortcut = {
      Unit = {
        Description = "Merge X13 native GNOME AI shortcut";
        After = [ "graphical-session-pre.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = { Type = "oneshot"; ExecStart = "${merge}"; };
      Install.WantedBy = [ "gnome-session.target" ];
    };
  };
}
