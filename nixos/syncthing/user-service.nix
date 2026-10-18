{ pkgs }:
{
  Unit = {
    Description = "Syncthing background synchronization";
    StartLimitIntervalSec = 60;
    StartLimitBurst = 4;
  };
  Service = {
    ExecStart = "${pkgs.syncthing}/bin/syncthing serve --no-browser --no-restart";
    Restart = "on-failure";
    RestartSec = 1;
    SuccessExitStatus = [ 3 4 ];
    RestartForceExitStatus = [ 3 4 ];
    MemoryDenyWriteExecute = true;
    NoNewPrivileges = true;
    SystemCallArchitectures = "native";
  };
  Install.WantedBy = [ "default.target" ];
}
