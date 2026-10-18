#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"
EXPECTED="$REPO_DIR/tests/fixtures/nixos-configurations.txt"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

actual_names="$(
  nix eval --json "path:$REPO_DIR#nixosConfigurations" --apply builtins.attrNames \
    | jq -r '.[]'
)"

diff -u "$EXPECTED" <(printf '%s\n' "$actual_names") \
  || fail 'evaluated nixosConfigurations differ from the public baseline'

if grep -qx 'TEMPLATE' <<<"$actual_names"; then
  fail 'host templates must never be exported as nixosConfigurations'
fi

nix eval --impure --raw --expr '
  let
    f = builtins.getFlake ("path:" + toString ./.);
    expected = {
      envy = { host = "envy"; user = "osmarg"; desktop = "sway"; modes = ["gaming" "server" "windows-vfio"]; };
      lenovo = { host = "lenovo"; user = "osmarg"; desktop = "ryoku"; modes = ["battery" "gaming" "server" "windows-vfio"]; };
      orgm = { host = "orgm"; user = "osmarg"; desktop = "ryoku"; modes = ["server"]; };
      ero = { host = "ero"; user = "osmarg"; desktop = "i3"; modes = []; };
      jarq = { host = "jarq"; user = "jarq"; desktop = "i3"; modes = []; };
    };
    historical = import ./tests/fixtures/legacy-configurations.nix;
    selected = { envy = "envy"; lenovo = "lenovo-ryoku"; orgm = "orgm-ryoku"; ero = "ero-i3"; jarq = "jarq-i3"; };
    # Compare boot, graphics and VM boundaries against the preferred existing
    # descriptor, not an alternative desktop or the old host alias.
    mode = c: {
      inherit (c.boot) kernelParams kernelModules;
      initrdModules = c.boot.initrd.kernelModules;
      kernel = c.boot.kernelPackages.kernel.version;
      inherit (c.boot.loader) timeout;
      inherit (c.boot.loader.systemd-boot) sortKey extraInstallCommands;
      inherit (c.systemd) defaultUnit;
      inherit (c.hardware.graphics) enable;
      nvidia = if builtins.elem "nvidia" c.services.xserver.videoDrivers then {
        inherit (c.hardware.nvidia) open;
        inherit (c.hardware.nvidia.prime) intelBusId nvidiaBusId;
        offload = c.hardware.nvidia.prime.offload.enable;
        sync = c.hardware.nvidia.prime.sync.enable;
      } else null;
      inherit (c.services.displayManager) defaultSession;
      sddm = c.services.displayManager.sddm.enable;
      sway = c.programs.sway.enable;
      hyprland = c.programs.hyprland.enable;
      niri = c.programs.niri.enable;
      i3 = c.services.xserver.windowManager.i3.enable;
      compose = builtins.mapAttrs (_: file: {
        source = toString file.source;
        text = if file.text != null then file.text else builtins.readFile file.source;
      })
        (f.inputs.nixpkgs.lib.filterAttrs (name: _: builtins.match ".*compose.*" name != null)
          c.home-manager.users.${if c.networking.hostName == "jarq" then "jarq" else "osmarg"}.home.file);
      windowsVmProfile = c.environment.etc."orgm/windows-vm-profile".text or null;
      profileMarker = c.environment.etc."orgm/desktop-profile".text or null;
    };
    snapshot = c: {
      normal = mode c;
      specialisations = builtins.mapAttrs (_: spec: mode spec.configuration) c.specialisation;
    };
    matches = name: want:
      let c = f.nixosConfigurations.${name}.config; in
      c.networking.hostName == want.host
      && c.users.users.${want.user}.isNormalUser
      && builtins.attrNames c.home-manager.users == [want.user]
      && c.system.nixos.label == want.desktop
      && builtins.attrNames c.specialisation == want.modes
      && snapshot c == snapshot historical.${selected.${name}}.config;
  in assert f.inputs.nixpkgs.lib.all (name: matches name expected.${name}) (builtins.attrNames expected);
  "PASS: evaluated canonical host/user/desktop/modes\n"
'
printf 'PASS: evaluated flake output baseline\n'
