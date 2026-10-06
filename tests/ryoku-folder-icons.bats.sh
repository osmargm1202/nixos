#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 - "$ROOT" <<'PY'
import hashlib
import os
from pathlib import Path
import subprocess
import sys
import tempfile

expression = '''let f = builtins.getFlake "path:ROOT"; in
  builtins.filter (p: (p.name or "") == "ryoku-folder-icons")
    f.nixosConfigurations.lenovo-ryoku.config.environment.systemPackages'''.replace("ROOT", sys.argv[1])
package = subprocess.check_output([
    "nix", "build", "--impure", "--no-link", "--print-out-paths", "--expr", expression
], text=True).strip()
helper = package + "/bin/ryoku-cmd-folders"
with tempfile.TemporaryDirectory() as directory:
    home = Path(directory)
    env = os.environ | {
        "HOME": directory, "XDG_DATA_HOME": str(home / "data"),
        "XDG_CACHE_HOME": str(home / "cache"), "XDG_CONFIG_HOME": str(home / "config"),
        "XDG_RUNTIME_DIR": directory, "GSETTINGS_BACKEND": "keyfile",
    }
    subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", "icon-theme", "custom-theme"], env=env, check=True)
    link = home / "data/icons/ryoku-folders"
    hashes = set()
    previous = None
    for accent in ("#ff0000", "#0000ff", "#00ff00"):
        subprocess.run([helper, accent], env=env, check=True)
        assert link.is_symlink() and (link / "index.theme").is_file()
        assert "Inherits=Papirus-Dark" in (link / "index.theme").read_text()
        hashes.add(hashlib.sha256((link / "places/folder.svg").read_bytes()).hexdigest())
        if previous:
            assert previous.is_dir(), "An in-flight reader must retain its old generation"
        previous = link.resolve()
        assert len(list((link.parent / ".ryoku-folders").iterdir())) <= 2
        theme = subprocess.check_output(["gsettings", "get", "org.gnome.desktop.interface", "icon-theme"], env=env, text=True).strip()
        assert theme == "'custom-theme'", "Palette updates must preserve a user's selected icon theme"
    assert len(hashes) == 3, "Folder icons must change with the palette accent"
print("PASS: Nix helper generates tinted folders, preserves user selection and retains the previous generation")
PY
