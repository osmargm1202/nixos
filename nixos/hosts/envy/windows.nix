{ config, lib, pkgs, userName, ... }:
let
  mode = config.orgm.envy.mode;
  runtimeMode = if mode == "gaming" then "disabled" else if config.orgm.envy.windowsVfio.enable then "vfio" else "render";
  home = config.users.users.${userName}.home;
  allocation = config.orgm.envy.windows;
  image = builtins.fromJSON (builtins.readFile ../../containers/windows/hosts/envy/image.json);
  compose = pkgs.runCommand "envy-windows-compose" {} ''
    mkdir -p "$out"
    cp ${../../containers/windows/hosts/envy/compose.yml} "$out/compose.yml"
    cp ${../../containers/windows/hosts/envy/compose.render.yml} "$out/compose.render.yml"
    cp ${../../containers/windows/hosts/envy/compose.vfio.yml} "$out/compose.vfio.yml"
  '';
  public = {
    inherit (image) image;
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
    generation = builtins.hashString "sha256" (builtins.toJSON public + builtins.readFile ./windows-runtime.py);
  }));
  controller = pkgs.runCommand "envy-windows-controller" {} ''
    mkdir -p "$out/bin" "$out/libexec"
    cp ${./windows-runtime.py} "$out/libexec/runtime.py"
    cat > "$out/libexec/envy-windows-supervise" <<'EOF'
    #!${pkgs.runtimeShell}
    export PATH=/run/wrappers/bin:${lib.makeBinPath [ config.virtualisation.podman.package pkgs.slirp4netns pkgs.fuse-overlayfs pkgs.coreutils ]}:$PATH
    exec ${pkgs.python3}/bin/python3 ${./windows-runtime.py} --manifest ${manifest} supervise
    EOF
    cat > "$out/bin/envy-windows" <<'EOF'
    #!${pkgs.runtimeShell}
    set -euo pipefail
    export PATH=/run/wrappers/bin:${lib.makeBinPath [ config.virtualisation.podman.package pkgs.slirp4netns pkgs.fuse-overlayfs pkgs.coreutils ]}:$PATH
    case "''${1:-status}" in
      start)
        ${lib.optionalString (runtimeMode == "disabled") "echo 'Windows is disabled in gaming mode' >&2; exit 1"}
        ${pkgs.systemd}/bin/systemctl --user start --no-block envy-windows.service
        for ((i=0; i<120; i++)); do
          state="$(${pkgs.systemd}/bin/systemctl --user show -p ActiveState --value envy-windows.service)"
          case "$state" in
            active) exec ${pkgs.python3}/bin/python3 ${./windows-runtime.py} --manifest ${manifest} status ;;
            failed|inactive) echo 'Envy Windows blocked: journalctl --user -u envy-windows' >&2; exit 1 ;;
          esac
          sleep 0.25
        done
        echo 'Windows not ready; supervisor retains ownership if a guest exists. Check journalctl --user -u envy-windows' >&2
        exit 1
        ;;
      stop) exec ${pkgs.systemd}/bin/systemctl --user stop envy-windows.service ;;
      status|preflight) exec ${pkgs.python3}/bin/python3 ${./windows-runtime.py} --manifest ${manifest} "''${1:-status}" ;;
      *) echo 'Usage: envy-windows {start|stop|status|preflight}' >&2; exit 2 ;;
    esac
    EOF
    chmod +x "$out/bin/envy-windows" "$out/libexec/envy-windows-supervise"
  '';
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
    vramMiB = lib.mkOption { type = lib.types.ints.between 256 4096; default = 1024; };
  };
  config = {
  system.build = { envyWindowsController = controller; envyWindowsManifest = manifest; envyWindowsCompose = compose; };
  virtualisation.podman.enable = true;
  users.users.${userName} = { linger = true; extraGroups = [ "podman" "kvm" "render" "video" ]; };
  environment.systemPackages = [ controller ];
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
      ExecStart = "${controller}/libexec/envy-windows-supervise";
      RuntimeDirectory = "envy-windows"; RuntimeDirectoryMode = "0700";
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
