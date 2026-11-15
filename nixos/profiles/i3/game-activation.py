#!/usr/bin/env python3
"""Honor game activation requests without changing i3's global focus policy.

With i3's default smart policy, requests from hidden workspaces become urgent.
Follow only those urgency events for the same game classes used by Hyprland.
One blocking IPC subscriber; no polling, startup scan or focus-on-title rules.
"""
import json
import os
import re
import socket
import struct
import subprocess
import time

HEADER = struct.Struct("=6sII")
WINDOW_EVENT = (1 << 31) | 3
GAMES = re.compile(r"(?:dota2|steam_app_[0-9]+|gamescope|EtG\.x86_64)")


def receive(connection):
    def exact(size):
        data = bytearray()
        while len(data) < size:
            block = connection.recv(size - len(data))
            if not block:
                raise ConnectionError("i3 IPC disconnected")
            data.extend(block)
        return data

    magic, size, kind = HEADER.unpack(exact(HEADER.size))
    if magic != b"i3-ipc" or size > 8 * 1024 * 1024:
        raise ValueError("Invalid i3 IPC frame")
    return kind, json.loads(exact(size))


def send(connection, kind, payload):
    body = payload.encode()
    connection.sendall(HEADER.pack(b"i3-ipc", len(body), kind) + body)


def requested_game(event):
    container = event.get("container") or {}
    properties = container.get("window_properties") or {}
    identifier = container.get("id")
    if (event.get("change") == "urgent" and container.get("urgent") is True
            and type(identifier) is int and identifier > 0
            and GAMES.fullmatch(properties.get("class") or "")):
        return identifier
    return None


def serve(path):
    with socket.socket(socket.AF_UNIX) as events:
        events.connect(path)
        send(events, 2, '["window"]')
        kind, reply = receive(events)
        if kind != 2 or not reply.get("success"):
            raise ConnectionError("Cannot subscribe to i3 window events")
        print("i3 game activation: listening", flush=True)
        while True:
            kind, event = receive(events)
            identifier = requested_game(event) if kind == WINDOW_EVENT else None
            if identifier is None:
                continue
            # A separate command socket keeps replies out of the event stream.
            # Numeric IDs cannot inject commands; a closed window simply fails.
            with socket.socket(socket.AF_UNIX) as command:
                command.settimeout(3)
                command.connect(path)
                send(command, 0, f"[con_id={identifier}] focus")
                receive(command)


def main():
    retry = 0.25
    while True:
        try:
            # Resolve from this display after every restart. A lingering user
            # manager can still carry I3SOCK from the previous i3 process.
            env = {key: value for key, value in os.environ.items() if key != "I3SOCK"}
            result = subprocess.run(["i3", "--get-socketpath"], check=True,
                                    capture_output=True, text=True, timeout=3, env=env)
            path = result.stdout.strip()
            if not path:
                raise ConnectionError("i3 socket not ready")
            serve(path)
        except (OSError, ValueError, ConnectionError, subprocess.SubprocessError):
            # Normally blocked in receive(). Backoff is only for startup or an
            # interrupted session; it never changes the currently focused app.
            time.sleep(retry)
            retry = min(retry * 2, 3)


if __name__ == "__main__":
    main()
