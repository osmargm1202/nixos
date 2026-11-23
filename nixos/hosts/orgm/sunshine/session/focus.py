"""Restore the i3 window for the application Sunshine is streaming."""

import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
from urllib.request import urlopen
from xml.etree import ElementTree
import zlib


EVENT = re.compile(r"(?:^|: )(CLIENT CONNECTED|CLIENT DISCONNECTED|Executing(?::)? \[.*\])$")
STEAM_ID = re.compile(r"steam://(?:rungameid|run)/(\d+)\b", re.IGNORECASE)
NUP_ID = re.compile(r"\[([0-9a-f]{16})\]", re.IGNORECASE)
PNG = b"\x89PNG\r\n\x1a\n"
STEAM_NATIVE_CLASSES = {
    "570": {"dota2"},
    "311690": {"etgx8664"},
    "2909400": {"ff7rebirthexe"},
}
LICHII_ALIASES = {"0400c3f00006e000": {"mkwrom"}}
WRAPPERS = {"setsid", "env", "exec"}


def normalized(value):
    return "".join(character for character in value.casefold() if character.isalnum())


def sunshine_id(key):
    number = zlib.crc32(key.encode())
    return str(abs(number if number < 2**31 else number - 2**32))


def applications(catalog, assets):
    # Match Sunshine's name/cover hash, including its index fallback for collisions.
    result = {}
    for index, app in enumerate(json.loads(catalog.read_text())["apps"]):
        key = app["name"]
        image = Path(app.get("image-path") or "")
        if image.suffix.lower() == ".png":
            cover = assets / image
            if not cover.is_file():
                cover = assets / "steam.png" if str(image) == "assets/steam.png" else image
            if cover != assets / "box.png" and cover.is_file():
                image_data = cover.read_bytes()
                if image_data.startswith(PNG):
                    key += hashlib.sha256(image_data).hexdigest()
        identifier = sunshine_id(key)
        if identifier in result:
            identifier = sunshine_id(key + str(index))
        result[identifier] = app
    return result


def window_rule(app):
    name = normalized(app["name"])
    commands = [command for command in [app.get("cmd"), *app.get("detached", [])] if command]
    if not commands:
        return None

    for command in commands:
        if steam := STEAM_ID.search(command):
            game = steam[1]
            classes = {f"steamapp{game}", name, f"{name}exe"} | STEAM_NATIVE_CLASSES.get(game, set())
            return lambda window, keys, title: bool(classes & keys)
        if "steam://open/bigpicture" in command.casefold():
            return lambda window, keys, title: (
                title in {"steambigpicture", "steambigpicturemode"}
                and bool({"steam", "steamwebhelper", "gamescope"} & keys)
                or title == "steam" and bool({"steam", "gamescope"} & keys)
                and bool(window.get("fullscreen_mode"))
            )
        if "launch-lichii.sh" in command or "lichii" in Path(command).name.casefold():
            ids = {match.lower() for match in NUP_ID.findall(command)}
            titles = ids | {alias for game in ids for alias in LICHII_ALIASES.get(game, ())}
            return lambda window, keys, title: (
                "lichii" in keys and (not ids or name in title or any(game in title for game in titles))
            )

    # For a regular app, its executable or catalog name normally matches WM_CLASS.
    classes = {name}
    for command in commands:
        words = shlex.split(command)
        executable = next((Path(word).name for word in words
                           if not word.startswith("-") and "=" not in word
                           and Path(word).name not in WRAPPERS), "")
        if executable:
            classes.add(normalized(Path(executable).stem))
    return lambda window, keys, title: bool(classes & keys)


def windows(tree):
    pending = [tree]
    while pending:
        node = pending.pop()
        if node.get("window"):
            yield node
        pending.extend(node.get("nodes", []))
        pending.extend(node.get("floating_nodes", []))


def application_window(desktop_windows, rule):
    matches = []
    for window in desktop_windows:
        properties = window.get("window_properties") or {}
        if properties.get("transient_for"):
            continue
        keys = {normalized(properties.get(key) or "") for key in ("class", "instance")} - {""}
        if rule(window, keys, normalized(window.get("name") or "")):
            matches.append(window)
    return max(matches, key=lambda window: (bool(window.get("focused")),
                                            bool(window.get("fullscreen_mode"))), default=None)


def i3(*args):
    # A user manager can retain I3SOCK after an i3 restart.
    env = {name: value for name, value in os.environ.items() if name != "I3SOCK"}
    result = subprocess.run(["i3-msg", *args], env=env, check=True, timeout=3,
                            capture_output=True, text=True)
    return json.loads(result.stdout)


def current_app(port):
    with urlopen(f"http://127.0.0.1:{port}/serverinfo", timeout=2) as response:
        return ElementTree.parse(response).findtext("currentgame")


def handle_event(event, catalog, assets, port, desktops):
    if event.startswith(("Executing [", "Executing: [")):
        desktops.clear()
        return
    identifier = current_app(port)
    if identifier in (None, "0"):
        return
    app = applications(catalog, assets).get(identifier)
    if app is None:
        return
    rule = window_rule(app)
    if rule is not None and event == "CLIENT DISCONNECTED":
        return
    desktop_windows = list(windows(i3("-t", "get_tree")))
    if rule is None:
        if event == "CLIENT DISCONNECTED":
            focused = next((window for window in desktop_windows if window.get("focused")), None)
            if focused is not None:
                desktops[identifier] = focused["id"], focused["window"]
            return
        target = desktops.get(identifier)
        window = next((w for w in desktop_windows if (w["id"], w["window"]) == target), None)
    else:
        window = application_window(desktop_windows, rule)
    if window is not None and not window.get("focused"):
        reply = i3(f'[con_id={int(window["id"])}] focus')
        if reply and reply[0].get("success"):
            print(f'Focused {app["name"]} on Moonlight connection', flush=True)


def main():
    assets = Path(sys.argv[1])
    port = int(sys.argv[2])
    config = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    catalog = config / "sunshine/apps.json"
    desktops = {}
    with subprocess.Popen(
        ["journalctl", "--user", "-u", "sunshine.service", "--follow", "--lines=0",
         "--output=cat", "--no-pager"],
        stdout=subprocess.PIPE, text=True,
    ) as journal:
        for line in journal.stdout:
            if match := EVENT.search(line.rstrip()):
                try:
                    handle_event(match[1], catalog, assets, port, desktops)
                except (OSError, ValueError, ElementTree.ParseError, subprocess.SubprocessError) as exc:
                    print(f"Unable to restore Moonlight window focus: {exc}", flush=True)
    raise SystemExit("Sunshine journal subscription ended")


if __name__ == "__main__":
    main()
