{
  config,
  lib,
  pkgs,
  userName,
  ...
}:
let
  targets = config.orgm.i3GameActivation.targets;
  helper = pkgs.writeShellApplication {
    name = "i3-game-activation";
    runtimeInputs = [
      pkgs.python3
      pkgs.i3
    ];
    text = ''
      exec python3 ${./game-activation.py}
    '';
  };
in
{
  options.orgm.i3GameActivation.targets = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "i3 session targets that enable activation requests from recognized games";
  };
  config = lib.mkIf (targets != [ ]) {
    home-manager.users.${userName}.systemd.user.services.orgm-i3-game-activation = {
      Unit = {
        Description = "Focus i3 games when they request attention";
        PartOf = targets;
        ConditionEnvironment = "XDG_CURRENT_DESKTOP=i3";
      };
      Install.WantedBy = targets;
      Service = {
        ExecStart = "${helper}/bin/i3-game-activation";
        Restart = "on-failure";
        RestartSec = 2;
      };
    };
  };
}
