{
  pkgs,
  lib,
  userName ? "osmarg",
  ...
}:
let
  psd = pkgs.profile-sync-daemon;
  psdPath = lib.makeBinPath [
    pkgs.rsync
    pkgs.gnugrep
    pkgs.gnused
    pkgs.gawk
    pkgs.coreutils
    pkgs.util-linux
    pkgs.procps
    pkgs.psmisc
    pkgs.kmod
  ];
in
{
  home-manager.users.${userName} = {
    xdg.configFile."psd/psd.conf".text = ''
      BROWSERS=(chromium)
    '';

    systemd.user.services.psd = {
      Unit = {
        Description = "Profile-sync-daemon";
        Wants = [ "psd-resync.service" ];
        RequiresMountsFor = [ "/home/" ];
      };
      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        Environment = "PATH=${psdPath}";
        ExecStart = "${psd}/bin/profile-sync-daemon startup";
        ExecStop = "${psd}/bin/profile-sync-daemon unsync";
        TimeoutStopSec = 60;
      };
      Install.WantedBy = [ "default.target" ];
    };

    systemd.user.services.psd-resync = {
      Unit = {
        Description = "Timed resync";
        After = [ "psd.service" ];
        BindsTo = [ "psd.service" ];
      };
      Service = {
        Type = "oneshot";
        Environment = "PATH=${psdPath}";
        ExecStart = "${psd}/bin/profile-sync-daemon resync";
      };
    };

    systemd.user.timers.psd-resync = {
      Unit.Description = "Timer for profile-sync-daemon - 1Hour";
      Unit.BindsTo = [ "psd.service" ];
      Timer.OnUnitActiveSec = "1h";
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
