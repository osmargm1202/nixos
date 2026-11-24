#!/usr/bin/env python3
"""Evaluate X13's standalone webapps; no build, network or laptop access."""
import json
from pathlib import Path
import shlex
import subprocess
from urllib.parse import urlsplit

root = Path(__file__).resolve().parents[1]
expected = {
    "slc-daily": ("SLC Daily", "https://daily.slci.stream"),
    "slc-vill-docs": ("SLC Vill Docs", "https://vill-docs.slci.stream"),
    "orgm-adm": ("ORGM Administration", "https://adm.or-gm.com"),
    "orgm-automation": ("ORGM Automation", "https://automation.or-gm.com"),
    "orgm-code": ("ORGM Code", "https://code.or-gm.com"),
    "dgii-facturador": ("Facturador Gratuito DGII", "https://fg.dgii.gov.do/ecf/PortalFG/login"),
    "cloud-orgm": ("Cloud ORGM", "https://cloud.or-gm.com/"),
}
projection = r'''s: let
  c = s.config;
  hm = c.home-manager.users.osmarg;
  original = import ./nixos/users/osmarg.nix {
    inherit (s.pkgs) lib; role = "desktop"; userName = "osmarg"; hostName = "x13";
  };
in {
  selected = c.orgm.user.webapps;
  previous = original.orgm.user.webapps;
  programs = c.orgm.user.programs;
  defaults = c.xdg.mime.defaultApplications;
  chromium = c.orgm.chromium.enable;
  entries = builtins.mapAttrs (_: d: {
    inherit (d) name exec icon categories terminal settings;
  }) (s.pkgs.lib.filterAttrs (name: _: s.pkgs.lib.hasPrefix "chrome-" name) hm.xdg.desktopEntries);
  scripts = map (p: { inherit (p) name text; })
    (builtins.filter (p:
      s.pkgs.lib.hasPrefix "orgm-webapp-" (p.name or "")
      && !(s.pkgs.lib.hasSuffix ".desktop" (p.name or ""))
    ) hm.home.packages);
}'''
result = subprocess.run([
    "nix", "eval", "--impure", "--json", f"path:{root}#nixosConfigurations.x13",
    "--apply", projection,
], cwd=root, text=True, capture_output=True)
assert result.returncode == 0, result.stderr
config = json.loads(result.stdout)
new_ids = {"slc-daily", "slc-vill-docs", "orgm-adm"}
assert set(config["selected"]) == set(config["previous"]) | new_ids
assert len(config["selected"]) == len(set(config["selected"])), "No duplicate selection, including cloud-orgm"
assert "orgm" in config["programs"], "Existing ORGM CLI tools must remain selected"
scripts = {p["name"]: p["text"] for p in config["scripts"]}
assert set(scripts) == {"orgm-webapp-" + id for id in config["selected"]}
assert len(config["entries"]) == len(scripts)
assert config["chromium"]
for mime in ("text/html", "application/xhtml+xml", "x-scheme-handler/http", "x-scheme-handler/https"):
    assert config["defaults"][mime] == "firefox.desktop"
profiles = set()
# Include a previous catalog consumer: its identity, endpoint and profile stay intact.
for id, (name, url) in (expected | {"gmail": ("Gmail", "https://gmail.com")}).items():
    identity = "orgm-webapp-" + id
    parsed = urlsplit(url)
    app_name = f"{parsed.netloc}_{parsed.path or '/'}"
    desktop_id = f"chrome-{app_name.replace('/', '_')}-Default"
    entry = config["entries"][desktop_id]
    assert entry["name"] == name
    assert entry["terminal"] is False
    assert entry["icon"] and entry["categories"]
    assert entry["settings"] == {"StartupNotify": "true", "StartupWMClass": identity}
    command = shlex.split(entry["exec"])
    assert len(command) == 1 and command[0].startswith("/nix/store/")
    assert command[0].endswith("/bin/" + identity)
    script = scripts[identity]
    assert 'if [[ "${XDG_SESSION_TYPE:-}" != x11 && -n "${WAYLAND_DISPLAY:-}" ]]; then' in script
    assert "set -- --ozone-platform=wayland" in script
    assert f"set -- --ozone-platform=x11 --class={identity}" in script
    argv = shlex.split(script.split("exec ", 1)[1], comments=True)
    argv.insert(0, "exec")
    assert argv[0] == "exec" and argv[1].startswith("/nix/store/")
    assert argv[1].endswith("/bin/chromium")
    profile = "/home/osmarg/.local/share/chromium-webapps/" + id
    assert argv[2:] == [
        "--app=" + url,
        "--user-data-dir=" + profile,
        "--disable-sync",
        "--no-default-browser-check",
        "$@",
    ]
    assert profile not in profiles
    profiles.add(profile)
print("PASS: Firefox defaults, independent Chromium profiles and GNOME/i3 application identities")
