{
  config,
  lib,
  pkgs,
  userName,
  ...
}:
let
  sync = pkgs.writeShellApplication {
    name = "nextcloud-server-sync";
    runtimeInputs = [
      pkgs.nextcloud-client
      pkgs.procps
      pkgs.systemd
      pkgs.util-linux
    ];
    text = builtins.readFile ./nextcloud-server-sync.sh;
  };
in
{
  config = lib.mkIf (builtins.elem "nextcloud" config.orgm.user.programs) {
    users.users.${userName}.linger = true;

    # The live installation can use just these units without switching the
    # whole NixOS generation. Hand its exact bootstrap links over to /etc on
    # the next normal deployment so they cannot mask future unit updates.
    system.activationScripts.nextcloud-server-unit-handoff = {
      deps = [ "etc" ];
      text = ''
        nextcloud_home=${lib.escapeShellArg config.users.users.${userName}.home}
        for nextcloud_unit in nextcloud-server.service nextcloud-server.timer; do
          nextcloud_link="$nextcloud_home/.config/systemd/user/$nextcloud_unit"
          if [ -L "$nextcloud_link" ] &&
            [ "$(${pkgs.coreutils}/bin/readlink "$nextcloud_link")" = "$nextcloud_home/.local/state/nextcloud-server/units/$nextcloud_unit" ]; then
            ${pkgs.coreutils}/bin/rm "$nextcloud_link"
          fi
        done
        nextcloud_link="$nextcloud_home/.config/systemd/user/timers.target.wants/nextcloud-server.timer"
        if [ -L "$nextcloud_link" ] &&
          [ "$(${pkgs.coreutils}/bin/readlink "$nextcloud_link")" = "$nextcloud_home/.config/systemd/user/nextcloud-server.timer" ]; then
          ${pkgs.coreutils}/bin/rm "$nextcloud_link"
        fi
      '';
    };

    systemd.user.services.nextcloud-server = {
      description = "Synchronize Nextcloud files in server mode";
      unitConfig = {
        ConditionUser = userName;
        ConditionPathExists = "%h/.config/nextcloud-server.env";
      };
      serviceConfig = {
        Type = "oneshot";
        EnvironmentFile = "%h/.config/nextcloud-server.env";
        ExecCondition = "${sync}/bin/nextcloud-server-sync --check";
        ExecStart = "${sync}/bin/nextcloud-server-sync";
        TimeoutStartSec = "6h";
        TimeoutStopSec = "60s";
        UMask = "0077";
        Nice = 10;
        IOSchedulingClass = "idle";
        NoNewPrivileges = true;
        PrivateTmp = true;
      };
    };

    systemd.user.timers.nextcloud-server = {
      description = "Synchronize Nextcloud every five minutes in server mode";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "1min";
        OnUnitInactiveSec = "5min";
        AccuracySec = "15s";
        Unit = "nextcloud-server.service";
      };
    };
  };
}
