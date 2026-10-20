#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENVY_SWAY_REPO="$ROOT" nix eval --impure --json --expr '
let
  f = builtins.getFlake ("path:" + builtins.getEnv "ENVY_SWAY_REPO");
  describe = c: {
    host = c.networking.hostName;
    label = c.system.nixos.label;
    kernel = c.boot.kernelPackages.kernel.version;
    sway = c.programs.sway.enable;
    hyprland = c.programs.hyprland.enable;
    ryoku = c.programs.ryoku.enable or false;
    sddm = c.services.displayManager.sddm.enable;
    vfio = c.orgm.envy.windowsVfio.enable;
    offload = c.hardware.nvidia.prime.offload.enable;
    driver = c.hardware.nvidia.package.version;
    keyboardHwdb = c.services.udev.extraHwdb;
    sunshine = c.services.sunshine.enable;
    packages = map (p: p.pname or p.name or "") c.environment.systemPackages;
    units = builtins.filter (n: f.inputs.nixpkgs.lib.hasPrefix "orgm-sway-" n) (builtins.attrNames c.systemd.user.services);
    assertions = map (a: a.message) (builtins.filter (a: !a.assertion) c.assertions);
  };
  c = f.nixosConfigurations.envy.config;
in {
  normal = describe c;
  modes = builtins.mapAttrs (_: s: describe s.configuration) c.specialisation;
  session = c.programs.sway.extraSessionCommands;
  dock = c.systemd.user.services.orgm-sway-dock.serviceConfig.ExecStart;
  notifications = let u = c.systemd.user.services.orgm-sway-notifications; in {
    command = u.serviceConfig.ExecStart;
    type = u.serviceConfig.Type;
    busName = u.serviceConfig.BusName;
    inherit (u) aliases;
  };
  portal = c.xdg.portal.config.sway;
  dotfiles = builtins.fromJSON c.environment.etc."orgm-dot/context.json".text;
  unit = let u = c.systemd.user.services.orgm-sway-idle; in {
    inherit (u) environment wantedBy partOf;
  };
  outputs = builtins.attrNames f.nixosConfigurations;
}' | python3 -c '
import json,shlex,sys
v=json.load(sys.stdin)
# Keep exact canonical outputs; ORGM also retains its explicit Ryoku fallback.
assert v["outputs"] == ["envy", "ero", "jarq", "lenovo", "orgm", "orgm-ryoku"], v["outputs"]
assert sorted(v["modes"]) == ["gaming", "server", "windows-vfio"]
for name,c in {"normal":v["normal"],**v["modes"]}.items():
    assert not c["assertions"],(name,c["assertions"])
    graphics=name in ("normal","windows-vfio")
    vfio=name in ("server","windows-vfio")
    assert c["sway"] == graphics and c["sddm"] == graphics,name
    assert not c["hyprland"] and not c["ryoku"] and not c["sunshine"],name
    assert c["vfio"] == vfio and c["offload"] == (not vfio),name
    assert c["kernel"].startswith("6.12.") and c["driver"].startswith("580."),name
    assert bool(c["units"]) == graphics,name
    assert "evdev:atkbd:dmi:*:svnHP:pnHPENVYLaptop17m-ce1xxx:*" in c["keyboardHwdb"],name
    assert "KEYBOARD_KEY_c8=reserved" in c["keyboardHwdb"],name
assert v["normal"]["host"]=="envy" and v["normal"]["label"]=="sway"
for package in ["swayfx","waybar","nwg-dock","orgm-qylock","wl-screenrec","rofi","nautilus","colloid-icon-theme","SwayNotificationCenter","quickshell"]:
    assert package in v["normal"]["packages"],package
assert not {"hyprland","hypridle","nwg-dock-hyprland","dunst","swaylock","swaylock-effects"} & set(v["normal"]["packages"])
assert "readlink -f /dev/dri/by-path/pci-0000:00:02.0-card" in v["session"]
assert "WLR_RENDER_DRM_DEVICE" in v["session"]
assert "export PATH=\"$HOME/.local/bin:$PATH\"" in v["session"]
assert v["portal"]["org.freedesktop.impl.portal.ScreenCast"]=="wlr"
assert v["dotfiles"]["profile"]=="sway" and v["dotfiles"]["host"]=="envy"
assert "/home/osmarg/.local/bin" in v["unit"]["environment"]["PATH"]
assert v["unit"]["wantedBy"]==["sway-session.target"]
assert v["unit"]["partOf"]==["sway-session.target"]
dock_args = shlex.split(v["dock"])
assert dock_args[1:] == ["-p", "right", "-i", "32", "-w", "10", "-nows", "-mr", "6", "-l", "top", "-c", "sway-app-launcher"], dock_args
assert v["notifications"]["command"].endswith("/bin/swaync")
assert v["notifications"]["type"] == "dbus"
assert v["notifications"]["busName"] == "org.freedesktop.Notifications"
assert v["notifications"]["aliases"] == ["swaync.service"]
print("PASS: Sway desktop, Intel rendering, modes, Swaync activation and portable applications")
'
python3 "$ROOT/tests/sway-tools.test.py"
python3 "$ROOT/tests/sway-wallpapers.test.py"
python3 "$ROOT/tests/sway-menus.test.py"
python3 "$ROOT/tests/sway-desktop.test.py"
python3 "$ROOT/tests/envy-keyboard.test.py"
python3 "$ROOT/tests/sway-lock.test.py"
python3 "$ROOT/tests/sway-keyring.test.py"
python3 "$ROOT/tests/sway-game-mode.test.py"
bash "$ROOT/tests/sway-firefox-tabs.bats.sh"
