#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
inventory="$(mktemp)"
trap 'rm -f "$inventory"' EXIT
RYOKU_TEST_REPO="$ROOT" nix eval --impure --json --expr '
  let
    f = builtins.getFlake ("path:" + builtins.getEnv "RYOKU_TEST_REPO");
    describe = c: let h = c.home-manager.users.osmarg; in {
      session = builtins.fromJSON (h.xdg.configFile."orgm-ryoku/native-session.json".text or "{}");
      nextcloudMask = h.xdg.configFile."autostart/com.nextcloud.desktopclient.nextcloud.desktop".text or "";
      sunshineAuto = c.services.sunshine.autoStart;
      nextcloudBackup = h.home.activation.ryokuNextcloudAutostartBackup.data or "";
    };
    userEmpty = f.nixosConfigurations.envy.extendModules { modules = [
      ({ lib, ... }: { orgm.user.autostart = lib.mkForce []; })
    ]; };
    withoutTrays = f.nixosConfigurations.envy.extendModules { modules = [
      ({ lib, ... }: { orgm.user.programs = lib.mkForce (builtins.filter
        (name: !builtins.elem name [ "tailscale" "syncthing" ])
        f.nixosConfigurations.envy.config.orgm.user.programs); })
    ]; };
  in {
    hosts = builtins.mapAttrs (_: s: describe s.config)
      { inherit (f.nixosConfigurations) envy lenovo orgm; };
    empty = describe userEmpty.config;
    deselectedTrays = describe withoutTrays.config;
    serverHasSeed = f.nixosConfigurations.lenovo.config.specialisation.server.configuration
      .home-manager.users.osmarg.xdg.configFile ? "orgm-ryoku/native-session.json";
  }
' > "$inventory"
python3 - "$inventory" <<'CHECK'
import json
import sys
import os
from pathlib import Path
import subprocess
import tempfile
x = json.load(open(sys.argv[1]))
for host, c in x["hosts"].items():
    s = c["session"]
    assert s.get("required") == ["tailscale systray --theme light", "syncthingtray --single-instance --wait"], (host, s)
    assert "nextcloud --background" in s["optional"] and "kdeconnect-indicator" in s["optional"], host
    assert "firefox" in s["optional"], host
    assert not any("sunshine" in row for row in s["optional"]), host
    assert "Hidden=true" in c["nextcloudMask"], (host, c["nextcloudMask"])
assert x["empty"]["session"]["optional"] == [], x["empty"]
assert x["empty"]["session"]["required"] == ["tailscale systray --theme light", "syncthingtray --single-instance --wait"]
assert x["deselectedTrays"]["session"]["required"] == []
assert not x["serverHasSeed"]
with tempfile.TemporaryDirectory() as home:
    config = Path(home) / ".config"
    entry = config / "autostart/com.nextcloud.desktopclient.nextcloud.desktop"
    entry.parent.mkdir(parents=True)
    entry.write_text("personal Nextcloud autostart bytes\n")
    env = dict(os.environ, HOME=home, XDG_CONFIG_HOME=str(config),
               XDG_STATE_HOME=home + "/.local/state", DRY_RUN_CMD="")
    script = x["hosts"]["envy"]["nextcloudBackup"]
    subprocess.run(["bash", "-euc", script], env=env, check=True)
    backup = Path(home) / ".local/state/orgm-ryoku/nextcloud-autostart.before-native-session-v1.desktop"
    assert backup.exists(), "Ryoku must preserve the replaced XDG entry"
    assert backup.read_text() == "personal Nextcloud autostart bytes\n"
    entry.write_text("generation mask\n")
    subprocess.run(["bash", "-euc", script], env=env, check=True)
    assert backup.read_text() == "personal Nextcloud autostart bytes\n"

print("PASS: user-selected native startup, mandatory trays, Nextcloud mask and console isolation")
CHECK
python3 "$ROOT/tests/ryoku-native-session.py"
