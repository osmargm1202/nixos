# One public CLI and one lifecycle implementation; host adapters supply policy.
{ pkgs, lib, host, manifest, adapter, podman, serviceName, image, buildContext, aliases ? [] }:
let
  runtime = pkgs.runCommand "windows-vm-runtime-${host}" {} ''
    mkdir -p "$out"
    cp ${./windows_runtime.py} "$out/windows_runtime.py"
    cp ${adapter} "$out/runtime.py"
  '';
in pkgs.runCommand "windows-vm-controller-${host}" {} ''
  mkdir -p "$out/bin" "$out/libexec"
  cat > "$out/libexec/windows-vm-supervise" <<'EOF'
  #!${pkgs.runtimeShell}
  export PATH=/run/wrappers/bin:${lib.makeBinPath [ podman pkgs.slirp4netns pkgs.fuse-overlayfs pkgs.coreutils ]}:$PATH
  exec ${pkgs.python3}/bin/python3 ${runtime}/runtime.py --manifest ${manifest} supervise
  EOF
  cat > "$out/bin/windows-vm" <<'EOF'
  #!${pkgs.runtimeShell}
  set -euo pipefail
  export PATH=/run/wrappers/bin:${lib.makeBinPath [ podman pkgs.slirp4netns pkgs.fuse-overlayfs pkgs.coreutils ]}:$PATH
  case "''${1:-status}" in
    start)
      ${pkgs.systemd}/bin/systemctl --user start --no-block ${serviceName}.service
      for ((i=0; i<120; i++)); do
        state="$(${pkgs.systemd}/bin/systemctl --user show -p ActiveState --value ${serviceName}.service)"
        case "$state" in
          active) exec ${pkgs.python3}/bin/python3 ${runtime}/runtime.py --manifest ${manifest} started ;;
          failed|inactive) echo 'Windows VM blocked: journalctl --user -u ${serviceName}' >&2; exit 1 ;;
        esac
        sleep 0.25
      done
      echo 'Windows not ready; its supervisor retains ownership if a guest exists. Check journalctl --user -u ${serviceName}' >&2
      exit 1
      ;;
    stop)
      ${pkgs.systemd}/bin/systemctl --user stop ${serviceName}.service
      exec ${pkgs.python3}/bin/python3 ${runtime}/runtime.py --manifest ${manifest} stop
      ;;
    status|preflight)
      exec ${pkgs.python3}/bin/python3 ${runtime}/runtime.py --manifest ${manifest} "''${1:-status}"
      ;;
    prepare-image)
      # Explicit provisioning only; ordinary start never builds/pulls an image.
      exec ${podman}/bin/podman build --pull=never --tag ${image} ${buildContext}
      ;;
    -h|--help) echo 'Usage: windows-vm {start|stop|status|preflight|prepare-image}' ;;
    *) echo 'Usage: windows-vm {start|stop|status|preflight|prepare-image}' >&2; exit 2 ;;
  esac
  EOF
  chmod +x "$out/bin/windows-vm" "$out/libexec/windows-vm-supervise"
  ${lib.concatMapStringsSep "\n" (alias: "ln -s windows-vm \"$out/bin/${alias}\"") aliases}
''
