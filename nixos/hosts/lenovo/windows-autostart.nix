{
  pkgs,
  lib,
  userName,
  ...
}:
let
  baseCompose = pkgs.writeText "compose.windows.yml" (
    builtins.readFile ../../containers/windows/compose.yml
  );
  renderCompose = pkgs.writeText "compose.lenovo-render.yml" ''
    services:
      windows:
        container_name: windows
        image: localhost/local/dockurr-windows-spice:latest
        environment:
          GPU: "Y"
        devices:
          - /dev/dri
        group_add:
          - keep-groups
  '';
  startExistingWindows = pkgs.writeShellApplication {
    name = "lenovo-windows-autostart";
    runtimeInputs = [
      pkgs.podman
      pkgs.podman-compose
    ];
    text =
      lib.replaceStrings
        [ "@BASE_COMPOSE@" "@RENDER_COMPOSE@" ]
        [ (toString baseCompose) (toString renderCompose) ]
        (builtins.readFile ./windows-autostart.sh);
  };
in
{
  system.build.lenovoWindowsRenderCompose = renderCompose;
  virtualisation.podman.enable = true;
  environment.etc."orgm/windows-vm-profile".text = lib.mkDefault "lenovo-render-node\n";
  users.users.${userName} = {
    linger = true;
    extraGroups = [ "podman" ];
  };

  # This belongs to the rootless user's default target, not a desktop session.
  # Select VFIO only in server/windows; otherwise use a render-node runtime
  # with the same disk. Never stop or recreate an existing container.
  systemd.user.services.lenovo-windows-autostart = {
    description = "Start Lenovo Windows with the current host GPU profile";
    wantedBy = [ "default.target" ];
    wants = [ "podman-user-wait-network-online.service" ];
    after = [ "podman-user-wait-network-online.service" ];
    unitConfig = {
      ConditionUser = userName;
      StartLimitIntervalSec = 0;
    };
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${startExistingWindows}/bin/lenovo-windows-autostart";
      Restart = "on-failure";
      RestartSec = "15s";
      TimeoutStartSec = "120s";
    };
    restartIfChanged = false;
  };
}
