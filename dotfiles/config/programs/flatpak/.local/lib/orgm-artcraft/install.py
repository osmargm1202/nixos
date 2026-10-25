"""Conditional, backed-up per-user integration; never modifies vendor files."""
import configparser
import io
import os
from pathlib import Path
import subprocess
import tempfile
import uuid

from cadcraft import APP, PORT, Error, private_directory


def run(args):
    return subprocess.run(args, check=True, capture_output=True, text=True, timeout=30)


def exec_quote(value):
    # Desktop Exec escaping is not shell quoting. Percent introduces field codes.
    value = value.replace("%", "%%")
    for char in ("\\", '"', "`", "$"):
        value = value.replace(char, "\\" + char)
    # Desktop values unescape once BEFORE Exec tokenization unescapes again.
    return '"' + value.replace("\\", "\\\\") + '"'


def atomic(path, content, mode=0o600):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix=".cadcraft-", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as file:
            os.fchmod(file.fileno(), mode)
            file.write(content)
            file.flush()
            os.fsync(file.fileno())
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def snapshot(path):
    if path.is_symlink() or (path.exists() and not path.is_file()):
        raise Error("No se reemplazará una ruta especial: " + str(path))
    return path.read_bytes() if path.exists() else None


def restore(path, content):
    if content is None:
        path.unlink(missing_ok=True)
    else:
        atomic(path, content)


def install():
    location = None
    for scope in ("--user", "--system"):
        try:
            location = Path(run(["flatpak", "info", scope, "--show-location", APP]).stdout.strip())
            break
        except subprocess.CalledProcessError:
            continue
    if location is None:
        return  # No ghost handler: native MIME alternatives must remain usable.
    vendor = location / "files/share/applications" / (APP + ".desktop")
    binary = location.parent / "active/files/bin/cadcraft"
    if not vendor.is_file() or not binary.is_file():
        raise Error("Instalación de CADCraft incompleta; no se cambiarán asociaciones")
    home = Path.home()
    data = Path(os.environ.get("XDG_DATA_HOME", home / ".local/share"))
    state = Path(os.environ.get("XDG_STATE_HOME", home / ".local/state")) / "orgm-cadcraft"
    desktop = data / "applications" / (APP + ".desktop")
    override = data / "flatpak/overrides" / APP
    old_desktop, old_override = snapshot(desktop), snapshot(override)
    config = configparser.ConfigParser(interpolation=None, delimiters=("=",), strict=False)
    config.optionxform = str
    config.read_string(vendor.read_text())
    entry = config["Desktop Entry"]
    # A percent-containing executable path is invalid to GIO even with %%; a
    # fixed env executable and an escaped literal argument avoid that parser bug.
    entry["Exec"] = "env " + exec_quote(str(home / ".local/bin/orgm-cadcraft")) + " -- %U"
    entry["TryExec"] = str(binary)
    entry["DBusActivatable"] = "false"
    entry["X-OrgM-CADCraft-Opening"] = "true"
    output = io.StringIO()
    config.write(output, space_around_delimiters=False)
    content = output.getvalue().encode()
    private_directory(state)
    backup = state / "backups" / uuid.uuid4().hex
    private_directory(backup)
    if old_desktop is not None:
        atomic(backup / "desktop", old_desktop)
    if old_override is not None:
        atomic(backup / "override", old_override)
    atomic(backup / "presence.json", ('{"desktop":' + str(old_desktop is not None).lower() + ',"override":' + str(old_override is not None).lower() + '}\n').encode())
    try:
        # Preserve font/filesystem overrides. Pin network isolation even if vendor
        # metadata changes later: its unauthenticated control protocol is broad.
        run(["flatpak", "override", "--user", "--unshare=network", "--env=CADCRAFT_CONTROL_PORT=" + str(PORT), APP])
        atomic(desktop, content, 0o644)
        run(["update-desktop-database", str(desktop.parent)])
    except Exception as original:
        failures = []
        for path, previous in ((desktop, old_desktop), (override, old_override)):
            try:
                restore(path, previous)
            except Exception as rollback:
                failures.append(str(path) + ": " + str(rollback))
        if failures:
            raise Error(str(original) + "; restauración incompleta: " + "; ".join(failures) + "; copia: " + str(backup)) from original
        raise
    print("CADCraft: integración instalada; copia anterior en " + str(backup))
