"""Migrate only known browser/webapp pins; retain user ordering and backups."""
import ast
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

mapping = json.loads(Path(sys.argv[1]).read_text())
def migrate(items, suffix=""):
    result = []
    targets = {value + suffix for value in mapping.values()}
    for item in items:
        base = item.removesuffix(suffix) if suffix else item
        updated = mapping.get(base, base) + suffix
        if updated not in targets or updated not in result:
            result.append(updated)
    return result
home = Path.home()
state = Path(os.environ.get("XDG_STATE_HOME", str(home / ".local/state"))) / "orgm-origin"
state.mkdir(parents=True, exist_ok=True)
config = Path(os.environ.get("XDG_CONFIG_HOME", str(home / ".config")))
cache = Path(os.environ.get("XDG_CACHE_HOME", str(home / ".cache")))
for index, path in enumerate([
    cache / "nwg-dock-pinned",
    config / "nwg-dock-hyprland/pinned",
    config / "nwg-dock/pinned",
]):
    if not path.exists() or path.is_symlink():
        continue
    before = path.read_text()
    after = "\n".join(migrate(before.splitlines())) + "\n"
    if before != after:
        backup = state / f"pins-{index}.before-origin"
        if not backup.exists():
            shutil.copy2(path, backup)
        path.write_text(after)

bus = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")) / "bus"
if bus.exists():
    env = dict(os.environ, DBUS_SESSION_BUS_ADDRESS=f"unix:path={bus}")
    command = ["gsettings", "get", "org.gnome.shell", "favorite-apps"]
    result = subprocess.run(command, env=env, text=True, capture_output=True)
    if result.returncode == 0:
        favorites = ast.literal_eval(result.stdout.removeprefix("@as ").strip())
        updated = migrate(favorites, ".desktop")
        if updated != favorites:
            backup = state / "gnome-favorites.before-origin.json"
            if not backup.exists():
                backup.write_text(json.dumps(favorites))
            subprocess.run(["gsettings", "set", "org.gnome.shell", "favorite-apps", repr(updated)], env=env, check=True)
