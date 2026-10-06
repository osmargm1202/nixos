#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 - "$ROOT" "$@" <<'PY'
import configparser
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(sys.argv[1])
projection = '''system: let
  c = system.config;
  value = c.xdg.mime.defaultApplications."inode/directory" or [];
in {
  handlers = system.pkgs.lib.toList value;
  activation = c.home-manager.users.osmarg.home.activation.setPreferredFileHandlers.data;
  packages = map (p: p.pname or p.name)
    (c.environment.systemPackages ++ c.home-manager.users.osmarg.home.packages);
  xdgMime = "${system.pkgs.xdg-utils}/bin/xdg-mime";
  fileHandlers = builtins.mapAttrs (_: handlers: system.pkgs.lib.toList handlers)
    (builtins.intersectAttrs { "text/plain" = null; "text/markdown" = null;
      "text/x-markdown" = null; "text/x-python" = null; } c.xdg.mime.defaultApplications);
  neovim = if c.home-manager.users.osmarg.xdg.desktopEntries ? nvim then {
    inherit (c.home-manager.users.osmarg.xdg.desktopEntries.nvim) exec terminal;
  } else null;
}'''

for profile in sys.argv[2:] or ("hyprland", "ryoku", "i3", "gnome", "labwc", "cinnamon", "terminal"):
    result = subprocess.run([
        "nix", "eval", "--json", f"path:{root}#nixosConfigurations.orgm-{profile}",
        "--apply", projection,
    ], text=True, capture_output=True, check=True)
    config = json.loads(result.stdout)
    expected = "org.gnome.Nautilus.desktop" if profile in ("hyprland", "ryoku") else "thunar.desktop"
    if profile != "terminal":
        assert config["handlers"] == [expected], (profile, config["handlers"])
        package = "nautilus" if profile in ("hyprland", "ryoku") else "thunar"
        assert package in config["packages"], f"{profile}: default manager is not installed"
        editor = "xed.desktop" if profile == "cinnamon" else "org.gnome.TextEditor.desktop"
        for mime in ("text/plain", "text/markdown", "text/x-markdown"):
            assert config["fileHandlers"][mime] == [editor], (profile, mime, config["fileHandlers"])
        assert config["fileHandlers"]["text/x-python"] == ["nvim.desktop"]
        assert not config["neovim"]["terminal"]
        assert "/bin/kitty -e nvim %F" in config["neovim"]["exec"]
    else:
        assert config["handlers"] == [], "Terminal profile must not impose a graphical file manager"
        expected = "user-selected.desktop"

    # Run the evaluated MIME activation, never Home Manager itself, with an
    # isolated generic desktop environment so no real session is contacted.
    with tempfile.TemporaryDirectory() as temporary:
        home = Path(temporary)
        env = os.environ | {
            "HOME": temporary,
            "XDG_CONFIG_HOME": str(home / "config"),
            "XDG_DATA_HOME": str(home / "data"),
            "XDG_CONFIG_DIRS": str(home / "config-dirs"),
            "XDG_DATA_DIRS": str(home / "data-dirs"),
            "XDG_CURRENT_DESKTOP": "generic",
            "DE": "generic",
            "DISPLAY": "",
            "WAYLAND_DISPLAY": "",
            "DBUS_SESSION_BUS_ADDRESS": "unix:path=" + str(home / "no-session-bus"),
            "DRY_RUN_CMD": "",
        }
        (home / "config").mkdir()
        # Start from stale Neovim defaults, as on the affected real machine.
        for mime in ("text/plain", "text/markdown", "text/x-markdown", "text/x-python"):
            subprocess.run([config["xdgMime"], "default", "nvim.desktop", mime], env=env, check=True)
        subprocess.run([config["xdgMime"], "default", "user-selected.desktop", "inode/directory"], env=env, check=True)
        subprocess.run(["bash", "-euc", config["activation"]], env=env, check=True)
        preferences = configparser.ConfigParser(interpolation=None)
        preferences.read(home / "config" / "mimeapps.list")
        actual = preferences.get("Default Applications", "inode/directory").rstrip(";")
        assert actual == expected, (profile, actual, expected)
        for mime in ("text/plain", "text/markdown", "text/x-markdown", "text/x-python"):
            expected_editor = "nvim.desktop" if profile == "terminal" else config["fileHandlers"][mime][0]
            assert preferences.get("Default Applications", mime).rstrip(";") == expected_editor, (profile, mime)
    print(f"PASS: {profile}: evaluated policy and MIME activation agree ({expected})")
PY
