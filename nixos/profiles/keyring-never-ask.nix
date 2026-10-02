{ config, lib, pkgs, userName, ... }:
let
  enabled = config.orgm.user.keyringMode == "never-ask";
  python = pkgs.python3.withPackages (ps: [ ps.dbus-python ]);
  keyring = pkgs.writeShellScript "orgm-keyring-never-ask" ''
    exec ${python}/bin/python3 ${./ryoku/keyring.py}
  '';
in {
  config = lib.mkIf enabled {
    services.gnome.gnome-keyring.enable = true;
    # A dedicated passwordless collection keeps existing encrypted collections
    # intact. Configure PAM declaratively so Ryoku never tries rewriting /etc.
    security.pam.services.sddm.enableGnomeKeyring = lib.mkForce false;
    security.pam.services.sddm-autologin.enableGnomeKeyring = lib.mkForce false;
    security.pam.services.login.enableGnomeKeyring = lib.mkForce false;
    systemd.user.services.orgm-keyring-never-ask = {
      description = "Passwordless default keyring for ${userName}";
      wantedBy = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      unitConfig.ConditionUser = userName;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = keyring;
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = 3;
      };
    };
  };
}
