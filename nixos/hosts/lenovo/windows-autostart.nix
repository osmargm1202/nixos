{ config, pkgs, lib, userName, ... }:
let
  vfio = config.orgm.lenovo.windowsVfio.enable;
  home = config.users.users.${userName}.home;
  baseImage = (builtins.fromJSON (builtins.readFile ../../containers/windows/hosts/envy/image.json)).image;
  installGuard = ../../containers/windows/refuse-install.py;
  spiceRecipe = lib.replaceStrings [ "FROM dockurr/windows:latest" ] [ "FROM ${baseImage}" ]
    (builtins.readFile ../../containers/windows/Containerfile.spice) + ''

    COPY refuse-install.py /tmp/windows-vm-install-guard.py
    RUN python3 /tmp/windows-vm-install-guard.py && rm /tmp/windows-vm-install-guard.py
  '';
  spiceContext = pkgs.runCommand "lenovo-windows-image-context" {} ''
    mkdir -p "$out"
    cp ${pkgs.writeText "Containerfile" spiceRecipe} "$out/Containerfile"
    cp ${installGuard} "$out/refuse-install.py"
  '';
  image = "localhost/lenovo-windows-spice:${builtins.hashString "sha256" (spiceRecipe + builtins.readFile installGuard)}";
  inputIso = pkgs.runCommand "lenovo-virtio-input.iso" { nativeBuildInputs = [ pkgs.xorriso ]; } ''
    mkdir -p "$out"
    xorriso -as mkisofs -V virtio-win -o "$out/virtio-input.iso" -graft-points \
      vioinput/w11/amd64=${pkgs.virtio-win}/vioinput/w11/amd64
  '';
  baseCompose = pkgs.writeText "compose.windows.yml" (builtins.readFile ../../containers/windows/compose.yml);
  renderCompose = pkgs.writeText "compose.lenovo-render.yml" ''
    services:
      windows:
        environment:
          GPU: "Y"
        group_add:
          - keep-groups
  '';
  vfioCompose = pkgs.writeText "compose.lenovo-vfio.yml"
    (builtins.readFile ../../containers/windows/hosts/lenovo-windows/compose.yml);
  public = {
    host = "lenovo";
    inherit image;
    mode = if vfio then "vfio" else "render";
    container = if vfio then "lenovo-windows" else "windows";
    bdf = "0000:01:00.0"; vendor = "0x10de"; device = "0x1fbb";
    renderBdf = "0000:00:02.0";
    runtimeDir = "/run/user/${toString config.users.users.${userName}.uid}/windows-vm-lenovo";
    envFile = "${home}/Apps/windows/.env";
    inputIso = "${inputIso}/virtio-input.iso";
    compose = [ "${baseCompose}" "${if vfio then vfioCompose else renderCompose}" ];
    commands = {
      podman = "${config.virtualisation.podman.package}/bin/podman";
      compose = "${pkgs.podman-compose}/bin/podman-compose";
    };
  };
  manifest = pkgs.writeText "windows-vm-lenovo.json" (builtins.toJSON (public // {
    generation = builtins.hashString "sha256" (builtins.toJSON public
      + builtins.readFile ./windows-runtime.py + builtins.readFile ../../containers/windows/windows_runtime.py);
  }));
  controller = import ../../containers/windows/controller.nix {
    inherit pkgs lib manifest image;
    host = "lenovo";
    adapter = ./windows-runtime.py;
    podman = config.virtualisation.podman.package;
    serviceName = "lenovo-windows-autostart";
    buildContext = spiceContext;
  };
in {
  system.build = {
    lenovoWindowsRenderCompose = renderCompose;
    windowsVmController = controller;
    windowsVmManifest = manifest;
  };
  virtualisation.podman.enable = true;
  environment.systemPackages = [ controller ];
  environment.etc."orgm/windows-vm-profile".text = lib.mkDefault "lenovo-render-node\n";
  users.users.${userName} = {
    linger = true;
    extraGroups = [ "podman" "kvm" "render" "video" ];
  };

  # Protect the supervisor from the outer system user-manager stop deadline,
  # including non-VFIO modes. A user-unit timeout alone does not cover shutdown.
  systemd.services."user@${toString config.users.users.${userName}.uid}" = {
    overrideStrategy = "asDropin";
    serviceConfig = { TimeoutStopSec = "infinity"; SendSIGKILL = false; };
  };

  # Preserve the deployed unit name and autostart policy, but use the same
  # lifetime supervisor and graceful stop as Envy. No rebuild restarts a guest.
  systemd.user.services.lenovo-windows-autostart = {
    description = "Guarded Lenovo Windows VM supervisor";
    wantedBy = [ "default.target" ];
    wants = [ "podman-user-wait-network-online.service" ];
    after = [ "podman-user-wait-network-online.service" ];
    unitConfig = { ConditionUser = userName; StartLimitIntervalSec = 0; };
    path = [ config.virtualisation.podman.package pkgs.slirp4netns pkgs.fuse-overlayfs ];
    serviceConfig = {
      Type = "notify"; NotifyAccess = "main";
      ExecStart = "${controller}/libexec/windows-vm-supervise";
      RuntimeDirectory = "windows-vm-lenovo"; RuntimeDirectoryMode = "0700"; RuntimeDirectoryPreserve = "yes";
      Restart = "on-failure"; RestartSec = "15s";
      TimeoutStartSec = "infinity"; TimeoutStopSec = "infinity";
      KillMode = "process"; SendSIGKILL = false;
    };
    restartIfChanged = false;
    stopIfChanged = false;
  };
}
