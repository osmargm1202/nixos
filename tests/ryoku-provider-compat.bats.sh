#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
inventory="$(RYOKU_TEST_REPO="$ROOT" nix build --impure --no-link --print-out-paths --expr '
let
  f = builtins.getFlake ("path:" + builtins.getEnv "RYOKU_TEST_REPO");
  c = f.nixosConfigurations.lenovo.config;
  lib = f.inputs.nixpkgs.lib;
  compat = import (builtins.getEnv "RYOKU_TEST_REPO" + "/nixos/profiles/ryoku/provider-compat.nix") {
    inputs = f.inputs; pkgs = f.nixosConfigurations.lenovo.pkgs; inherit lib;
  };
  original = f.inputs.ryoku.packages.x86_64-linux;
  fixed = compat.packages;
  has = p: paths: builtins.elem (toString p) (map toString paths);
  hasDefaults = host: user: let c=f.nixosConfigurations.${host}.config;
    ctx=builtins.fromJSON c.environment.etc."orgm-dot/context.json".text;
    in ctx.profile == "ryoku" && ctx.user == user
      && !(c.home-manager.users.${user}.home.file ? ".config/orgm-ryoku/window-defaults.json");
  contains = p: text: lib.hasInfix (builtins.unsafeDiscardStringContext (toString p)) text;
in
assert builtins.all (host: hasDefaults host "osmarg") [ "envy" "lenovo" "orgm" ];
assert !(hasDefaults "ero" "osmarg");
assert !(hasDefaults "jarq" "jarq");
assert c.services.fprintd.enable;
assert has fixed.ryoku-hub fixed.ryoku-bundle.paths;
assert !(has original.ryoku-hub fixed.ryoku-bundle.paths);
assert has fixed.ryoku-wm-niri c.environment.systemPackages;
assert !(has original.ryoku-wm-niri c.environment.systemPackages);
assert has fixed.ryoku-bundle c.environment.systemPackages;
assert !(has original.ryoku-bundle c.environment.systemPackages);
assert has fixed.ryoku-wm-niri c.systemd.user.services.ryoku-shell.path;
assert has fixed.ryoku-materialize c.systemd.user.services.ryoku-materialize.restartTriggers;
assert contains fixed.ryoku-materialize c.home-manager.users.osmarg.home.activation.ryokuDesktop.data;
assert has fixed.ryoku-wm-hyprland c.environment.systemPackages;
assert !(has original.ryoku-wm-hyprland c.environment.systemPackages);
assert has fixed.ryoku-wm-hyprland c.systemd.user.services.ryoku-shell.path;
assert toString c.programs.hyprland.package == toString original.ryoku-hyprland;
f.nixosConfigurations.lenovo.pkgs.writeText "ryoku-compat-test-inventory.json" (builtins.toJSON {
  hyprProvider = toString fixed.ryoku-wm-hyprland;
  oldHyprProvider = toString original.ryoku-wm-hyprland;
  hub = toString fixed.ryoku-hub;
  plugins = toString fixed.ryoku-hypr-plugins;
  readelf = "${f.nixosConfigurations.lenovo.pkgs.binutils}/bin/readelf";
  lockPam = map toString c.systemd.user.services.ryoku-materialize.serviceConfig.ExecStartPost;
  cli = toString fixed.ryoku-cli;
  data = toString fixed.ryoku-desktop-data;
  oldCli = toString original.ryoku-cli;
  oldData = toString original.ryoku-desktop-data;
  provider = toString fixed.ryoku-wm-niri;
  oldProvider = toString original.ryoku-wm-niri;
  materializer = toString fixed.ryoku-materialize;
  bundle = toString fixed.ryoku-bundle;
  wrapper = toString c.systemd.user.services.ryoku-materialize.serviceConfig.ExecStart;
})')"
cp "$inventory" "$tmp"
python3 - "$tmp" <<'CHECK'
import json
from pathlib import Path
import sys
import os
import subprocess
import tempfile
v = json.loads(Path(sys.argv[1]).read_text())
for plugin in (Path(v["plugins"]) / "lib/hyprland/plugins").glob("*.so"):
    symbols = subprocess.check_output([v["readelf"], "--dyn-syms", "--wide", str(plugin)], text=True)
    assert "pluginInit" in symbols and "pluginAPIVersion" in symbols, plugin
    assert " PHANDLE" not in symbols and " g_pGlobalState" not in symbols, (plugin, symbols)
materializer = (Path(v["materializer"]) / "bin/ryoku-materialize").read_text()
assert v["cli"] + "/bin/ryoku materialize" in materializer
assert v["data"] + "/share/ryoku/config" in materializer
assert v["oldCli"] not in materializer and v["oldData"] not in materializer
assert (Path(v["bundle"]) / "bin/ryoku").resolve() == Path(v["cli"]) / "bin/ryoku"
assert v["data"] in (Path(v["cli"]) / "bin/ryoku").read_text()
assert v["provider"] + "/bin/ryoku-wm-niri apply" in materializer
assert v["oldProvider"] not in materializer
assert v["hyprProvider"] + "/bin/ryoku-wm-hyprland apply" in materializer
assert v["oldHyprProvider"] not in materializer
assert (Path(v["bundle"]) / "bin/ryoku-wm-hyprland").resolve() == Path(v["hyprProvider"]) / "bin/ryoku-wm-hyprland"
assert (Path(v["bundle"]) / "bin/ryoku-wm-niri").resolve() == Path(v["provider"]) / "bin/ryoku-wm-niri"
wrapper = Path(v["wrapper"]).read_text()
assert v["materializer"] + "/bin/ryoku-materialize" in wrapper
for transaction in ("config.autoreload off", "config.reload config-only", "config.autoreload on", "trap cleanup EXIT"):
    assert transaction in wrapper, transaction
# Exercise installed binaries with isolated config and no compositor socket.
with tempfile.TemporaryDirectory() as home:
    cfg = Path(home) / ".config"
    (cfg / "ryoku").mkdir(parents=True)
    (cfg / "hypr").mkdir()
    store = cfg / "ryoku/desktop.json"
    original_store = {
        "desktop": {"appearance": {"rounding": 17, "wobblyWindows": True, "windowStyle": "gnomed"}},
        "wm": {"hyprland": {"anim": {"items": [{"leaf": "windowsIn", "enabled": True, "speed": 4}], "curves": []}}},
    }
    store.write_text(json.dumps(original_store))
    env = dict(os.environ, HOME=home, XDG_CONFIG_HOME=str(cfg), XDG_RUNTIME_DIR=home, RYOKU_WM="hyprland",
               PATH=v["hyprProvider"] + "/bin:" + os.environ["PATH"])
    env.pop("HYPRLAND_INSTANCE_SIGNATURE", None)
    env.pop("XDG_CURRENT_DESKTOP", None)
    subprocess.run([v["hub"] + "/bin/ryoku-hub", "desktop", "anim-preset", "fade"], env=env, check=True)
    saved = json.loads(store.read_text())
    assert saved["desktop"]["appearance"]["rounding"] == 17
    assert saved["desktop"]["appearance"]["windowStyle"] == "preset"
    assert "anim" not in saved["wm"]["hyprland"]
    assert json.loads(Path(str(store) + ".before-animation-presets").read_text()) == original_store
    settings = (cfg / "hypr/settings.lua").read_text()
    assert "gnomed" not in settings and 'leaf = "windowsIn"' not in settings
    roster = json.loads(subprocess.check_output([v["hyprProvider"] + "/bin/ryoku-wm-hyprland", "plugins", "list"], env=env))
    assert roster["toolchain"]["ok"], roster["toolchain"]
    assert all(p["installed"] for p in roster["plugins"] if p["bundled"]), roster
    assert all(p["path"].startswith(v["plugins"]) for p in roster["plugins"] if p["bundled"])
    pam = Path(v["lockPam"][-1]).read_text()
    assert "pam_fprintd.so timeout=-1" in pam and "ryoku-lock-pw" in pam
    fprint_path = pam.split("auth required ", 1)[1].split(" timeout", 1)[0]
    assert Path(fprint_path).is_file(), fprint_path
    quicksettings = (Path(v["data"]) / "share/ryoku/config/quickshell/shell/modules/bar/framebars/menus/quicksettings/QuickSettingsHome.qml").read_text()
    assert '["systemctl", "suspend"]' in quicksettings
print("PASS: fixed providers reach Hub/PATH, bundle, materializer, live transaction and HM; compositor ABI unchanged")
CHECK
