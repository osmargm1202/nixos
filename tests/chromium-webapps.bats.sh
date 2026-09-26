#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 - "$ROOT" <<'PY'
import json
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile

root = Path(sys.argv[1])

def evaluate(*args):
    result = subprocess.run(["nix", "eval", "--json", *args], text=True, capture_output=True)
    assert result.returncode == 0, result.stderr
    return json.loads(result.stdout)

def wayland_app_id(url):
    from urllib.parse import urlsplit
    parsed = urlsplit(url)
    app_name = parsed.hostname + "_" + (parsed.path or "/")
    return "chrome-" + app_name.replace("/", "_") + "-Default"
assert wayland_app_id("https://chatgpt.com") == "chrome-chatgpt.com__-Default"
assert wayland_app_id("https://claude.ai") == "chrome-claude.ai__-Default"

catalog = evaluate("--file", str(root / "nixos/apps/webapps.catalog.nix"))
apps = [app for group in catalog.values() for app in group]
ids = {app["id"] for app in apps}
assert len(apps) == len(ids) == 27, "Catalog must retain 27 unique applications"
expression = '''hm: {
  entries = builtins.mapAttrs (_: d: {
    inherit (d) name exec icon categories terminal settings;
  }) (builtins.removeAttrs hm.xdg.desktopEntries [ "com.discordapp.Discord" ]);
  packages = map (p: { inherit (p) name text; })
    (builtins.filter (p:
      builtins.match "orgm-webapp-.*" (p.name or "") != null
      || builtins.match "chrome-.*-Default\\.desktop" (p.name or "") != null
    ) hm.home.packages);
}'''

for configuration, native_wayland in (("hyprland", True), ("i3", False)):
    hm = evaluate(
        f"path:{root}#nixosConfigurations.{configuration}.config.home-manager.users.osmarg",
        "--apply",
        expression,
    )
    identities = {"orgm-webapp-" + id for id in ids}
    desktop_ids = {
        wayland_app_id(app["url"]) if native_wayland else "orgm-webapp-" + app["id"]
        for app in apps
    }
    assert set(hm["entries"]) == desktop_ids
    launchers = [p for p in hm["packages"] if p["name"] in identities]
    desktops = [p for p in hm["packages"] if p["name"].endswith(".desktop")]
    assert len(launchers) == len(desktops) == len(identities)
    assert {p["name"] for p in launchers} == identities
    assert {p["name"] for p in desktops} == {id + ".desktop" for id in desktop_ids}
    scripts = {p["name"]: p["text"] for p in launchers}
    profiles = set()
    for app in apps:
        identity = "orgm-webapp-" + app["id"]
        desktop_id = wayland_app_id(app["url"]) if native_wayland else identity
        entry = hm["entries"][desktop_id]
        exec_args = shlex.split(entry["exec"])
        assert len(exec_args) == 1 and exec_args[0].startswith("/nix/store/")
        assert exec_args[0].endswith("/bin/" + identity)
        assert entry["name"] == app["name"] and entry["icon"] == app["icon"]
        assert entry["terminal"] is False
        assert entry["settings"]["StartupNotify"] == "true"
        if native_wayland:
            assert "StartupWMClass" not in entry["settings"]
        else:
            assert entry["settings"]["StartupWMClass"] == identity
        argv = shlex.split(scripts[identity], comments=True)
        assert argv[0] == "exec" and argv[1].startswith("/nix/store/")
        assert argv[1].endswith("/bin/chromium")
        flags = argv[2:]
        expected_profile = "/home/osmarg/.local/share/chromium-webapps/" + app["id"]
        profile_flags = [arg for arg in flags if arg.startswith("--user-data-dir=")]
        assert profile_flags == ["--user-data-dir=" + expected_profile]
        assert expected_profile not in profiles, "Webapps must never share credential roots"
        profiles.add(expected_profile)
        assert flags.count("--app=" + app["url"]) == 1
        if native_wayland:
            assert not any(flag.startswith("--class=") for flag in flags)
        else:
            assert flags.count("--class=" + identity) == 1
        for flag in (
            "--disable-sync",
            "--no-default-browser-check",
            "--ozone-platform=" + ("wayland" if native_wayland else "x11"),
        ):
            assert flags.count(flag) == 1
        assert "firefox-open-tab" not in scripts[identity]
        assert ".config/chromium" not in scripts[identity]
        assert not any(arg.startswith("--profile-directory") for arg in flags)
print("PASS: Hyprland Wayland and i3 X11 webapps retain isolated profiles and desktop identities")

# Mutate only disposable catalog copies: invalid data must fail even when a
# consumer asks only for entry names (before Nix's lazy listToAttrs can hide it).
with tempfile.TemporaryDirectory(prefix="chromium-webapps-regression-") as temporary:
    directory = Path(temporary)
    shutil.copy2(root / "nixos/apps/webapps.nix", directory / "webapps.nix")
    fixture = directory / "webapps.catalog.nix"
    expression = f'''let
      flake = builtins.getFlake {json.dumps(str(root))};
      module = import {directory}/webapps.nix {{
        inherit (flake.nixosConfigurations.hyprland) config pkgs;
        lib = flake.inputs.nixpkgs.lib;
      }};
    in builtins.attrNames module.home-manager.users.osmarg.xdg.desktopEntries'''
    cases = [
        ('{ id = "Bad_ID"; name = "Bad"; url = "https://example.com"; icon = "web"; }',
         "Invalid Chromium webapp id 'Bad_ID'"),
        ('{ id = "bad"; name = "Bad"; url = "file:///tmp/a"; icon = "web"; }',
         "Invalid Chromium webapp URL 'file:///tmp/a' for 'bad'"),
        ('{ id = "same"; name = "A"; url = "https://a.example"; icon = "web"; } '
         '{ id = "same"; name = "B"; url = "https://b.example"; icon = "web"; }',
         "Duplicate Chromium webapp ids: same"),
    ]
    for records, message in cases:
        fixture.write_text("{ office = [ " + records + " ]; }")
        result = subprocess.run(["nix", "eval", "--impure", "--json", "--expr", expression], text=True, capture_output=True)
        assert result.returncode != 0 and message in result.stderr, result.stderr
    print("PASS: malformed IDs, non-HTTP URLs and duplicate identities fail closed")
PY
