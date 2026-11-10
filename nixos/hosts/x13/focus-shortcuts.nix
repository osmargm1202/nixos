{ pkgs, userName, ... }:
let
  uuid = "x13-focus-shortcuts@orgm.local";
  extension = pkgs.runCommand "x13-focus-shortcuts" { nativeBuildInputs = [ pkgs.glib ]; } ''
    mkdir -p $out
    cp -r ${./focus-shortcuts}/* $out/
    chmod -R u+w $out
    glib-compile-schemas --strict $out/schemas
  '';
  python = pkgs.python3.withPackages (ps: [ ps.pygobject3 ]);
in {
  home-manager.users.${userName} = {
    dconf.settings."org/gnome/desktop/wm/keybindings".close = [ "<Super>q" ];
    xdg.dataFile."gnome-shell/extensions/${uuid}".source = extension;
    # Shell discovers the installed extension at the next login. Do not restart
    # it, use Eval, or replace the user's manually selected extension list.
    systemd.user.services.x13-focus-shortcuts = {
      Unit = {
        Description = "Merge X13 GNOME shortcut extension selection";
        After = [ "graphical-session-pre.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "oneshot";
        Environment = "GI_TYPELIB_PATH=${pkgs.glib.out}/lib/girepository-1.0";
        ExecStart = "${python}/bin/python3 ${./focus-shortcuts/enable.py}";
      };
      Install.WantedBy = [ "gnome-session.target" ];
    };
  };
}
