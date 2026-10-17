#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
RYOKU_TEST_REPO="$ROOT" nix eval --impure --json --expr '
let
  f = builtins.getFlake ("path:" + builtins.getEnv "RYOKU_TEST_REPO");
  c = f.nixosConfigurations.envy.config;
  lib = f.inputs.nixpkgs.lib;
  compat = import (builtins.getEnv "RYOKU_TEST_REPO" + "/nixos/profiles/ryoku/provider-compat.nix") {
    inputs = f.inputs; pkgs = f.nixosConfigurations.envy.pkgs; inherit lib;
  };
  original = f.inputs.ryoku.packages.x86_64-linux;
  fixed = compat.packages;
  has = p: paths: builtins.elem (toString p) (map toString paths);
  hasDefaults = host: user: builtins.hasAttr ".config/orgm-ryoku/window-defaults.json"
    f.nixosConfigurations.${host}.config.home-manager.users.${user}.home.file;
  contains = p: text: lib.hasInfix (builtins.unsafeDiscardStringContext (toString p)) text;
in
assert builtins.all (host: hasDefaults host "osmarg") [ "envy" "lenovo" "orgm" ];
assert !(hasDefaults "ero" "osmarg");
assert !(hasDefaults "jarq" "jarq");
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
{
  hyprProvider = toString fixed.ryoku-wm-hyprland;
  oldHyprProvider = toString original.ryoku-wm-hyprland;
  cli = toString fixed.ryoku-cli;
  data = toString fixed.ryoku-desktop-data;
  oldCli = toString original.ryoku-cli;
  oldData = toString original.ryoku-desktop-data;
  provider = toString fixed.ryoku-wm-niri;
  oldProvider = toString original.ryoku-wm-niri;
  materializer = toString fixed.ryoku-materialize;
  bundle = toString fixed.ryoku-bundle;
  wrapper = toString c.systemd.user.services.ryoku-materialize.serviceConfig.ExecStart;
}' > "$tmp"
python3 - "$tmp" <<'CHECK'
import json
from pathlib import Path
import sys
v = json.loads(Path(sys.argv[1]).read_text())
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
print("PASS: fixed providers reach Hub/PATH, bundle, materializer, live transaction and HM; compositor ABI unchanged")
CHECK
