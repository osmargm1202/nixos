"""Surgical versioned migration of the supported mutable Ryoku desktop store."""
import json
import fcntl
import math
import os
from pathlib import Path
import sys
import tempfile


def atomic_text(path, value):
    fd, name = tempfile.mkstemp(prefix=path.name + ".", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as out:
            out.write(value)
        os.chmod(name, 0o600)
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def atomic_json(path, value):
    atomic_text(path, json.dumps(value, indent=2) + "\n")


def chord(value):
    return frozenset(part.strip().upper() for part in value.split("+"))


def migrate_window_defaults(config, state):
    source = config / "orgm-ryoku/window-defaults.json"
    if not source.exists():
        return
    path = config / "ryoku/desktop.json"
    original = path.read_bytes().decode()
    store = json.loads(original)
    desktop = store.setdefault("desktop", {})
    marker = state / "window-defaults-v1.applied.json"
    if not marker.exists():
        defaults = json.loads(source.read_text())["windowRules"]
        if not isinstance(defaults, list) or not all(isinstance(row, dict) for row in defaults):
            raise ValueError("windowRules defaults must be a list of rule objects")
        rules = desktop.setdefault("windowRules", [])
        for row in defaults:
            if row not in rules:
                rules.append(row)
        backup = state / "desktop.before-window-defaults-v1.json"
        if not backup.exists():
            atomic_text(backup, original)
    # The pinned Niri provider honors columnwidth, but Hyprland drops that
    # neutral action. Bridge only this missing action into the existing personal
    # module; fullscreen and all other supported actions stay provider-owned.
    lines = ["-- Derived from desktop.windowRules; edit the Hub store, not this file."]
    for index, row in enumerate(desktop.get("windowRules", [])):
        if row.get("action") != "columnwidth":
            continue
        # Selecting the action in the Hub initially leaves an empty value.
        # Match Niri's 0.5 fallback instead of blocking the next activation.
        try:
            width = float(row.get("value", ""))
        except (TypeError, ValueError):
            width = 0.5
        if not math.isfinite(width) or not 0 < width <= 1:
            print("Ryoku: skipped unsupported Hyprland columnwidth at rule "
                  + str(index + 1), file=sys.stderr)
            continue
        match = ", ".join(key + " = " + json.dumps(row[key], ensure_ascii=False)
                          for key in ("class", "title") if row.get(key))
        if not match:
            continue
        lines.append('hl.window_rule({ name = "orgm-native-column-width-' + str(index + 1)
                     + '", match = { ' + match + ' }, scrolling_width = ' + str(width) + ' })')
    # Validate/render before marking or replacing the user's store.
    if json.loads(original) != store:
        atomic_json(path, store)
    target = config / "orgm-ryoku/native-window-widths.lua"
    text = "\n".join(lines) + "\n"
    if not target.exists() or target.read_text() != text:
        atomic_text(target, text)
    if not marker.exists():
        atomic_json(marker, {"windowRules": defaults})


def migrate_audio_boost(config, state):
    defaults = config / "orgm-ryoku/audio-defaults.json"
    marker = state / "audio-boost-v1.applied.json"
    if not defaults.exists():
        return
    # The settings daemon locks path + ".lock" (not the Hub's desktop lock).
    path = config / "ryoku/shell.json"
    with (config / "ryoku/shell.json.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if marker.exists():
            return  # Later user changes, including disabling boost, must win.
        enabled = json.loads(defaults.read_text())["audioBoost"]
        if type(enabled) is not bool:
            raise ValueError("audioBoost default must be a boolean")
        original = path.read_text() if path.exists() else None
        store = json.loads(original) if original is not None else {}
        qsbar = store.setdefault("qsbar", {})
        backup = state / "shell.before-audio-boost-v1.json"
        if original is not None and not backup.exists():
            atomic_text(backup, original)
        qsbar["audioBoost"] = enabled
        if original is None or json.loads(original) != store:
            atomic_json(path, store)
        atomic_json(marker, {"audioBoost": enabled})


def migrate(config, state):
    source = config / "orgm-ryoku/native-session.json"
    if not source.exists():
        return
    defaults = json.loads(source.read_text())
    path = config / "ryoku/desktop.json"
    original = path.read_bytes()
    store = json.loads(original)
    desktop = store.setdefault("desktop", {})
    marker = state / "native-session-v1.applied.json"
    previous = json.loads(marker.read_text()) if marker.exists() else None
    backup = state / "desktop.before-native-session-v1.json"
    if not backup.exists():
        # Copy bytes, not a symlink into the immutable generation.
        backup.write_bytes(original)
        backup.chmod(0o600)

    required, optional = defaults["required"], defaults["optional"]
    had_startup = "autostart" in desktop
    startup = desktop.setdefault("autostart", [])
    managed = previous.get("managed", []) if previous else []
    if previous:
        retired = set(previous["optional"] + previous["required"]) - set(optional + required)
        startup = [row for row in startup if not (
            row.get("command") in retired and row.get("command") in managed
            and row == {"command": row["command"]})]
        additions = [cmd for cmd in optional if cmd not in previous["optional"]]
    else:
        additions = optional if not had_startup else []
    # Preserve the first row (including unknown metadata), removing exact-command
    # duplicates only. KDEConnect's daemon and indicator are different commands.
    unique, seen = [], set()
    for row in startup:
        command = row.get("command")
        if command not in seen:
            unique.append(row)
            seen.add(command)
    for command in required + additions:
        if command not in seen:
            unique.append({"command": command})
            seen.add(command)
            if command not in managed:
                managed.append(command)
    desktop["autostart"] = unique

    if not previous:
        keys = defaults["desktop"]
        existing = desktop.get("keybinds", [])
        rebinds = desktop.get("keybindRebinds", {})
        # An explicit H action/rebind target or H/S rebind belongs to the user.
        # Skip this linked shortcut bundle rather than partly displacing it.
        h = chord("SUPER + H")
        hide = chord("SUPER + CTRL + ALT + SHIFT + H")
        protected = {h, hide}
        occupied = any(chord(row.get("keys", "")) in protected for row in existing)
        occupied |= any(chord(key) in {h, chord("SUPER + S")} or chord(value) in protected
                        for key, value in rebinds.items())
        occupied |= any(chord(key) in protected for key in desktop.get("unbinds", []))
        if not occupied:
            desktop.setdefault("keybinds", []).extend(keys["keybinds"])
            desktop.setdefault("keybindRebinds", {}).update(keys["keybindRebinds"])
            unbinds = desktop.setdefault("unbinds", [])
            unbinds.extend(key for key in keys["unbinds"] if key not in unbinds)
        else:
            print("Ryoku: preserved existing H/S shortcut preference; native Stash seed skipped", file=sys.stderr)

        # Removing the old empty H/K placeholders must not let the upstream
        # default collide with an already-working custom Hub binding. Preserve
        # the custom chord, moving only the native default through the supported
        # map (and never overriding an explicit rebind/unbind).
        custom = {chord(row.get("keys", "")) for row in desktop.get("keybinds", [])}
        rebinds = desktop.get("keybindRebinds", {})
        unbound = {chord(key) for key in desktop.get("unbinds", [])}
        used = custom | unbound | {chord(value) for value in rebinds.values()}
        for key in ("H", "K"):
            original_key = "SUPER + " + key
            if (chord(original_key) not in custom or chord(original_key) in unbound
                    or any(chord(source) == chord(original_key) for source in rebinds)):
                continue
            candidates = ["SUPER + CTRL + ALT + SHIFT + " + key,
                          "SUPER + CTRL + ALT + " + key]
            candidates += ["SUPER + CTRL + ALT + SHIFT + F" + str(i) for i in range(1, 13)]
            target = next((candidate for candidate in candidates if chord(candidate) not in used), None)
            if target is None:
                raise ValueError("No free native shortcut for " + original_key)
            rebinds = desktop.setdefault("keybindRebinds", {})
            rebinds[original_key] = target
            used.add(chord(target))
    if json.loads(original) != store:
        atomic_json(path, store)
    # The personal Hyprland collision allocator must not claim explicit native
    # custom chords as fallback space. This is derived ownership only; actions
    # and rebindings continue to be rendered from the supported shared store.
    ownership = config / "orgm-ryoku/native-shortcut-ownership.lua"
    lua_list = lambda items: "{ " + ", ".join(json.dumps(item, ensure_ascii=False) for item in items) + " }"
    hint = "-- Derived from desktop.keybinds/unbinds during preparation.\nreturn {\n"
    hint += "  custom = " + lua_list(row["keys"] for row in desktop.get("keybinds", [])) + ",\n"
    hint += "  unbound = " + lua_list(desktop.get("unbinds", [])) + ",\n}\n"
    if not ownership.exists() or ownership.read_text() != hint:
        atomic_text(ownership, hint)
    record = {"required": required, "optional": optional, "managed": managed}
    if record != previous:
        atomic_json(marker, record)


if __name__ == "__main__":
    config, state = Path(sys.argv[1]), Path(sys.argv[2])
    # The Hub uses this same advisory lock for read-modify-write saves.
    with (config / "ryoku/.desktop.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        migrate(config, state)
        migrate_window_defaults(config, state)
    migrate_audio_boost(config, state)
