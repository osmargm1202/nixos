#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 - "$ROOT" <<'PY'
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

repo = sys.argv[1]
expr = r'''
let
  f = builtins.getFlake ("path:" + builtins.getEnv "ORGM_TEST_REPO");
  host = builtins.getEnv "ORGM_TEST_HOST";
  c = f.nixosConfigurations.${host}.config;
  user = if host == "jarq" then "jarq" else "osmarg";
  lib = f.inputs.nixpkgs.lib;
in {
  sunshine = { inherit (c.services.sunshine) enable autoStart capSysAdmin openFirewall; };
  sunshineSelected = builtins.elem "sunshine" c.orgm.user.programs;
  sunshineUnit = c.systemd.user.services ? sunshine;
  packages = map lib.getName c.environment.systemPackages;
  flatpaks = map (p: if builtins.isString p then p else p.appId) c.services.flatpak.packages;
  cleanupSystem = c.systemd.services.flatpak-managed-install.postStart;
  cleanupUser = c.home-manager.users.${user}.home.activation.removeFastpotify.data;
}
'''

for host in ["envy", "lenovo", "orgm", "ero", "jarq"]:
    row = json.loads(subprocess.check_output(
        ["nix", "eval", "--impure", "--json", "--expr", expr], text=True,
        env=dict(os.environ, ORGM_TEST_REPO=repo, ORGM_TEST_HOST=host)))
    expected = host == "orgm"
    assert row["sunshine"]["enable"] == expected, host
    assert row["sunshineSelected"] == expected, host
    assert row["sunshineUnit"] == expected, host
    assert ("sunshine" in row["packages"]) == expected, host
    if expected:
        assert all(row["sunshine"].values()), host
    else:
        assert not row["sunshine"]["openFirewall"], host
    assert "com.spotify.Client" in row["flatpaks"], host
    assert not any("fastpotify" in app.lower() for app in row["flatpaks"]), host
    assert "rocks.fastpotify.Fastpotify" in row["cleanupSystem"], host
    assert "--delete-data" not in row["cleanupSystem"] + row["cleanupUser"], host
    if host == "envy":
        scripts = row
    print(f"PASS: {host}: Sunshine={expected}, Spotify declared, Fastpotify retired", flush=True)

# Execute the evaluated migration with a fake Flatpak state. Only the replaced
# app may disappear; a failed/missing Spotify installation preserves the old one.
with tempfile.TemporaryDirectory(prefix="flatpak-retirement-") as directory:
    root = Path(directory)
    state = root / "state.json"
    fake = root / "flatpak"
    fake.write_text("#!" + sys.executable + "\n" + r'''
import json, os, sys
from pathlib import Path
p = Path(os.environ["FLATPAK_TEST_STATE"])
state = json.loads(p.read_text())
args = sys.argv[1:]
scope = "user" if "--user" in args else "system"
app = args[-1]
if args[0] == "info":
    raise SystemExit(0 if app in state[scope] else 1)
assert args[0] == "uninstall" and app == "rocks.fastpotify.Fastpotify", args
assert "--delete-data" not in args
state[scope].remove(app)
p.write_text(json.dumps(state))
''')
    fake.chmod(0o700)
    old, new, other = "rocks.fastpotify.Fastpotify", "com.spotify.Client", "org.example.Other"
    env = dict(os.environ, FLATPAK_TEST_STATE=str(state), DRY_RUN_CMD="")
    def run_script(name, system, user):
        state.write_text(json.dumps(dict(system=system, user=user)))
        script = re.sub(r"/nix/store/[^\s]+/bin/flatpak", str(fake), scripts[name])
        subprocess.run(["bash", "-e", "-c", script], env=env, check=True)
        return json.loads(state.read_text())
    assert run_script("cleanupSystem", [old, new, other], [old, other]) == {
        "system": [new, other], "user": [old, other]}
    assert run_script("cleanupSystem", [old, other], []) == {
        "system": [old, other], "user": []}
    assert run_script("cleanupUser", [new, other], [old, other]) == {
        "system": [new, other], "user": [other]}
    assert run_script("cleanupUser", [new, other], [other]) == {
        "system": [new, other], "user": [other]}
print("PASS: system/user migration preserves other apps and data; retry is idempotent")
PY
