{ config, lib, pkgs, userName, ... }:
let
  mode = config.orgm.envy.mode;
  runtimeMode = if mode == "gaming" then "disabled" else if config.orgm.envy.windowsVfio.enable then "vfio" else "render";
  home = config.users.users.${userName}.home;
  allocation = config.orgm.envy.windows;
  image = builtins.fromJSON (builtins.readFile ../../containers/windows/hosts/envy/image.json);
  vfio = runtimeMode == "vfio";
  lookingGlassClient = pkgs.callPackage ../../containers/windows/looking-glass-idd-client.nix {};
  # Provision explicitly, never build/pull while starting the guest. Unlike the
  # historical Lenovo recipe, this context cannot silently move to :latest.
  spiceRecipe = lib.replaceStrings [ "FROM dockurr/windows:latest" ] [ "FROM ${image.image}" ]
    (builtins.readFile ../../containers/windows/Containerfile.spice);
  spiceContext = pkgs.writeTextDir "Containerfile" spiceRecipe;
  vfioImage = "localhost/envy-windows-spice:${builtins.hashString "sha256" spiceRecipe}";
  inputIso = pkgs.runCommand "envy-virtio-input.iso" { nativeBuildInputs = [ pkgs.xorriso ]; } ''
    mkdir -p "$out"
    xorriso -as mkisofs -V virtio-win -o "$out/virtio-input.iso" -graft-points \
      vioinput/w11/amd64=${pkgs.virtio-win}/vioinput/w11/amd64
  '';
  compose = pkgs.runCommand "envy-windows-compose" {} ''
    mkdir -p "$out"
    cp ${../../containers/windows/hosts/envy/compose.yml} "$out/compose.yml"
    cp ${../../containers/windows/hosts/envy/compose.render.yml} "$out/compose.render.yml"
    cp ${../../containers/windows/hosts/envy/compose.vfio.yml} "$out/compose.vfio.yml"
  '';
  public = {
    inherit (image) image;
    inherit vfioImage;
    inputIso = "${inputIso}/virtio-input.iso";
    mode = runtimeMode;
    container = "envy-windows";
    bdf = "0000:02:00.0"; vendor = "0x10de"; device = "0x1d13";
    storageRoot = "/var/lib/windows";
    runtimeDir = "/run/user/${toString config.users.users.${userName}.uid}/envy-windows";
    passwordFile = "${home}/.config/envy-windows/password";
    cdiFile = "/run/cdi/nvidia-container-toolkit.json";
    ram = "${toString allocation.memoryMiB}M"; cpus = allocation.cpus;
    disk = "${toString allocation.diskGiB}G"; vram = "${toString allocation.vramMiB}M"; username = userName;
    compose = [ "${compose}/compose.yml" "${compose}/compose.${if runtimeMode == "vfio" then "vfio" else "render"}.yml" ];
    commands = {
      podman = "${config.virtualisation.podman.package}/bin/podman";
      compose = "${pkgs.podman-compose}/bin/podman-compose";
      findmnt = "${pkgs.util-linux}/bin/findmnt";
      lsattr = "${pkgs.e2fsprogs}/bin/lsattr";
    };
  };
  manifest = pkgs.writeText "envy-windows-manifest.json" (builtins.toJSON (public // {
    generation = builtins.hashString "sha256" (builtins.toJSON public + builtins.readFile ./windows-runtime.py
      + builtins.readFile ../../containers/windows/windows_runtime.py);
  }));
  controller = import ../../containers/windows/controller.nix {
    inherit pkgs lib manifest;
    host = "envy";
    adapter = ./windows-runtime.py;
    podman = config.virtualisation.podman.package;
    serviceName = "envy-windows";
    image = vfioImage;
    buildContext = spiceContext;
    aliases = [ "envy-windows" ];
  };
  prepare = pkgs.writeShellApplication {
    name = "envy-windows-storage";
    runtimeInputs = [ pkgs.util-linux pkgs.e2fsprogs pkgs.findutils pkgs.coreutils ];
    text = builtins.readFile ./windows-storage.sh;
  };
in {
  options.orgm.envy.windows = {
    memoryMiB = lib.mkOption { type = lib.types.ints.between 2048 8192; default = 4096; };
    cpus = lib.mkOption { type = lib.types.ints.between 1 8; default = 4; };
    diskGiB = lib.mkOption { type = lib.types.ints.between 32 256; default = 96; };
    vramMiB = lib.mkOption { type = lib.types.enum [ 256 512 1024 2048 4096 ]; default = 1024; };
  };
  config = {
  system.build = {
    envyWindowsController = controller; envyWindowsManifest = manifest; envyWindowsCompose = compose;
    windowsVmController = controller; windowsVmManifest = manifest;
  };
  virtualisation.podman.enable = true;
  users.users.${userName} = { linger = true; extraGroups = [ "podman" "kvm" "render" "video" ]; };
  environment.systemPackages = [ controller ] ++ lib.optionals vfio [ lookingGlassClient ];
  boot.extraModulePackages = lib.mkIf vfio [ config.boot.kernelPackages.kvmfr ];
  boot.kernelModules = lib.mkIf vfio [ "kvmfr" ];
  boot.extraModprobeConfig = lib.mkIf vfio "options kvmfr static_size_mb=128";
  services.udev.extraRules = lib.mkIf vfio ''
    KERNEL=="kvmfr0", GROUP="kvm", MODE="0660"
  '';
  environment.etc."orgm/windows-vm-profile".text = "envy-${if runtimeMode == "render" then "render-node" else runtimeMode}\n";
  systemd.services.envy-windows-storage = {
    description = "Prepare Envy mounted Windows storage without creating an image";
    wantedBy = [ "multi-user.target" ];
    before = [ "user@${toString config.users.users.${userName}.uid}.service" ];
    unitConfig.RequiresMountsFor = "/var/lib/windows";
    serviceConfig = {
      Type = "oneshot"; RemainAfterExit = true;
      ExecStart = "${prepare}/bin/envy-windows-storage /var/lib/windows ${userName} ${userName}";
    };
  };
  systemd.user.services.envy-windows = {
    description = "Guarded persistent Envy Windows supervisor";
    wantedBy = lib.optionals (builtins.elem mode [ "windows" "server" ]) [ "default.target" ];
    wants = [ "podman-user-wait-network-online.service" ];
    after = [ "podman-user-wait-network-online.service" ];
    unitConfig.ConditionUser = userName;
    restartIfChanged = false;
    stopIfChanged = false;
    path = [ config.virtualisation.podman.package pkgs.slirp4netns pkgs.fuse-overlayfs ];
    serviceConfig = {
      Type = "notify"; NotifyAccess = "main";
      ExecStart = "${controller}/libexec/windows-vm-supervise";
      RuntimeDirectory = "envy-windows"; RuntimeDirectoryMode = "0700"; RuntimeDirectoryPreserve = "yes";
      TimeoutStartSec = "infinity"; TimeoutStopSec = "infinity";
      KillMode = "process"; SendSIGKILL = false;
      Restart = "no";
    };
  };
  home-manager.users.${userName} = {
    home.file = lib.genAttrs [ "Apps/windows/envy/compose.yml" "Apps/windows/envy/compose.render.yml" "Apps/windows/envy/compose.vfio.yml" ]
      (name: { source = "${compose}/${baseNameOf name}"; });
    home.sessionVariables = {
      WINDOWS_RDP_ENVY_WINDOWS_USER = userName;
      WINDOWS_RDP_ENVY_WINDOWS_PASSWORD_FILE = public.passwordFile;
    };
  };
  };
}
