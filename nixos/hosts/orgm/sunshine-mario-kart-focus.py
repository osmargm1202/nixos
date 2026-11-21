"""Return focus to Lichii when a client connects to the Mario Kart stream."""

import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
from urllib.request import urlopen
from xml.etree import ElementTree
import zlib


APP = "Mario Kart World"
TITLE = re.compile(r"Mario Kart World|0400C3F00006E000", re.IGNORECASE)
CONNECTED = re.compile(r"(?:^|: )CLIENT CONNECTED$")
PNG = b"\x89PNG\r\n\x1a\n"


def app_id(catalog):
    # Sunshine hashes the application name and the SHA-256 hex of its cover.
    for entry in json.loads(catalog.read_text())["apps"]:
        if entry["name"] != APP:
            continue
        key = APP.encode()
        cover = Path(entry.get("image-path") or "")
        if cover.is_absolute() and cover.suffix.lower() == ".png" and cover.is_file():
            image = cover.read_bytes()
            if image.startswith(PNG):
                key += hashlib.sha256(image).hexdigest().encode()
        number = zlib.crc32(key)
        return str(abs(number if number < 2**31 else number - 2**32))
    return None


def mario_window(tree):
    pending = [tree]
    while pending:
        node = pending.pop()
        properties = node.get("window_properties") or {}
        if (node.get("window") and (properties.get("class") or "").casefold() == "lichii"
                and TITLE.search(node.get("name") or "")):
            return node
        pending.extend(node.get("nodes", []))
        pending.extend(node.get("floating_nodes", []))
    return None


def i3(*args):
    # A user manager can retain I3SOCK after an i3 restart.
    env = {name: value for name, value in os.environ.items() if name != "I3SOCK"}
    result = subprocess.run(["i3-msg", *args], env=env, check=True, timeout=3,
                            capture_output=True, text=True)
    return json.loads(result.stdout)


def focus_on_connect(catalog):
    expected = app_id(catalog)
    if expected is None:
        return
    with urlopen("http://127.0.0.1:47989/serverinfo", timeout=2) as response:
        if ElementTree.parse(response).findtext("currentgame") != expected:
            return
    window = mario_window(i3("-t", "get_tree"))
    if window is not None and not window.get("focused"):
        reply = i3(f'[con_id={int(window["id"])}] focus')
        if reply and reply[0].get("success"):
            print("Focused Mario Kart World in Lichii", flush=True)


def main():
    config = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    catalog = config / "sunshine/apps.json"
    with subprocess.Popen(
        ["journalctl", "--user", "-u", "sunshine.service", "--follow", "--lines=0",
         "--output=cat", "--no-pager"],
        stdout=subprocess.PIPE, text=True,
    ) as journal:
        for line in journal.stdout:
            if CONNECTED.search(line.rstrip()):
                try:
                    focus_on_connect(catalog)
                except (OSError, ValueError, ElementTree.ParseError, subprocess.SubprocessError) as exc:
                    print(f"Unable to focus Mario Kart World: {exc}", flush=True)
    raise SystemExit("Sunshine journal subscription ended")


if __name__ == "__main__":
    main()
