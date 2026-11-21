#!/usr/bin/env python3
"""Check which window is restored for each kind of Moonlight entry."""

import json
from pathlib import Path
import runpy
import tempfile
from unittest.mock import Mock, patch


HOST = Path(__file__).resolve().parents[1] / "nixos/hosts/orgm"
focus = runpy.run_path(str(HOST / "sunshine-focus.py"))
catalog = HOST / "sunshine/apps.json"
entries = json.loads(catalog.read_text())["apps"]
by_name = {app["name"]: app for app in entries}


def window(identifier, cls, title, *, focused=False, fullscreen=False):
    return {
        "id": identifier,
        "window": identifier + 10,
        "name": title,
        "focused": focused,
        "fullscreen_mode": int(fullscreen),
        "window_properties": {"class": cls},
    }


def matches(app, node):
    rule = focus["window_rule"](app)
    return focus["application_window"]([node], rule) is node


steam_windows = [
    ("Darkwood", "steam_app_274520"),
    ("Dota 2", "dota2"),
    ("Enter the Gungeon", "EtG.x86_64"),
    ("Hollow Knight: Silksong", "Hollow Knight Silksong"),
    ("Puzzle Quest 3", "PuzzleQuest3.exe"),
    ("Steam Big Picture", "steam"),
]
for name, cls in steam_windows:
    assert matches(by_name[name], window(1, cls, name)), name
    assert not matches(by_name[name], window(2, "Brave-origin", name)), name
assert not matches(by_name["Steam Big Picture"], window(2, "steam", "Steam"))

nup_games = [app for app in entries if focus["NUP_ID"].search(" ".join(app.get("detached", [])))]
for app in nup_games:
    title_id = focus["NUP_ID"].search(app["detached"][0])[1]
    assert matches(app, window(1, "Lichii", f"Lichii | {title_id} (64-bit)")), app
    assert not matches(app, window(2, "Lichii", "Lichii | 0123456789ABCDEF")), app
assert matches(by_name["Lichii"], window(1, "Lichii", "Lichii"))
assert matches({"name": "Video Player", "cmd": "setsid /usr/bin/mpv --fullscreen"},
               window(1, "mpv", "Example video"))

with tempfile.TemporaryDirectory() as directory:
    assets = Path(directory)
    desktop_cover = (HOST / "sunshine/covers"
                     / "ChatGPT Image Sep 22, 2026, 01_53_11 AM (2).png")
    (assets / "desktop.png").write_bytes(desktop_cover.read_bytes())
    custom = assets / "apps.json"
    custom.write_text(json.dumps({"apps": [
        {**by_name["Desktop"], "image-path": str(desktop_cover)},
        by_name["Low Res Desktop"],
        by_name["Dota 2"],
    ]}))
    ids = {entry["name"]: identifier
           for identifier, entry in focus["applications"](custom, assets).items()}
    # The active Desktop entry on orgm uses these same cover bytes.
    assert ids["Desktop"] == "6651975"
    assert ids["Low Res Desktop"] != focus["sunshine_id"]("Low Res Desktop")

    handler = focus["handle_event"]
    desktops = {}
    terminal = window(5, "kitty", "Terminal", focused=True)
    dota = window(6, "dota2", "Dota 2")
    i3 = Mock(return_value={"nodes": [terminal, dota]})
    with patch.dict(handler.__globals__, {"current_app": lambda port: ids["Desktop"], "i3": i3}):
        handler("CLIENT DISCONNECTED", custom, assets, 47989, desktops)
        terminal["focused"] = False
        dota["focused"] = True
        i3.side_effect = [{"nodes": [terminal, dota]}, [{"success": True}]]
        handler("CLIENT CONNECTED", custom, assets, 47989, desktops)
        i3.assert_called_with("[con_id=5] focus")
        handler("Executing [Desktop]", custom, assets, 47989, desktops)
        assert not desktops

    dota["focused"] = False
    terminal["focused"] = True
    i3.side_effect = [{"nodes": [terminal, dota]}, [{"success": True}]]
    with patch.dict(handler.__globals__, {"current_app": lambda port: ids["Dota 2"], "i3": i3}):
        handler("CLIENT CONNECTED", custom, assets, 47989, desktops)
        i3.assert_called_with("[con_id=6] focus")

print("PASS: Steam, Big Picture, Lichii, desktop resume and ordinary apps")
