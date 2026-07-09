#!/usr/bin/env python3
"""Notification + focus RGB effects for the Logitech G213 keyboard.

Two layers of lighting on top of the base OpenRGB profile:

- Ambient: while a mapped app's window is focused in Hyprland, the whole
  keyboard holds that app's color; focusing anything else reloads the
  saved .orp profile.
- Notification: desktop notifications from mapped apps blink the 5 G213
  areas (distinct colors per area, on/off) for a few seconds, then fall
  back to whatever ambient state is current.

The G213 exposes a single zone with 5 LEDs (Left, Middle, Right,
Arrow/Home, Numpad); "zones" refers to those LEDs. Direct writes only
reach the hardware in Direct mode, so it is forced before every effect.
Restoring is done by reloading the .orp file through the openrgb CLI —
the SDK server's color buffer is not a reliable snapshot of the profile.

Requires the OpenRGB SDK server (services.hardware.openrgb) plus
dbus-monitor and openrgb in PATH. Exits cleanly when no G213 is
connected so the same unit can run on every host. Without a Hyprland
session the focus layer is skipped and only notifications work.
"""

import glob
import os
import re
import socket
import subprocess
import sys
import threading
import time

from openrgb import OpenRGBClient
from openrgb.utils import RGBColor

RED = RGBColor(255, 0, 0)
BLUE = RGBColor(0, 0, 255)
OFF = RGBColor(0, 0, 0)

# notification app_name substring (lowercase) -> blink base color
NOTIFY_COLORS = {
    "discord": RED,
    "vesktop": RED,
    "dota": RED,
    "steam": BLUE,
}

# focused window class substring (lowercase) -> steady ambient color
FOCUS_COLORS = {
    "discord": RED,
    "vesktop": RED,
    "dota": RED,
    "steam": BLUE,
}

EFFECT_SECONDS = 3.0
FRAME_SECONDS = 0.5  # on/off cadence; G213 writes are slow, keep this coarse
SERVER_RETRY_SECONDS = 5
DEVICE_NAME = "G213"


def palette_for(base: RGBColor) -> list[RGBColor]:
    """Distinct color per LED area, derived from the app base color."""
    dim = RGBColor(base.red // 4, base.green // 4, base.blue // 4)
    white = RGBColor(255, 255, 255)
    return [base, white, dim, base, white]


def match_color(table: dict, name: str) -> RGBColor | None:
    name = name.lower()
    for key, color in table.items():
        if key in name:
            return color
    return None


def profile_path() -> str | None:
    config_dir = os.path.join(
        os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")), "OpenRGB"
    )
    preferred = os.path.join(config_dir, f"{socket.gethostname()}.orp")
    if os.path.isfile(preferred):
        return preferred
    candidates = sorted(glob.glob(os.path.join(config_dir, "*.orp")))
    return candidates[0] if candidates else None


class G213Notifier:
    def __init__(self):
        self.client = None
        self.device = None
        self.ambient_color = None  # None -> base profile
        self.lock = threading.Lock()  # serializes all writes to the device

    def connect(self):
        while True:
            try:
                self.client = OpenRGBClient(name="lg213-notify")
                break
            except (ConnectionError, OSError):
                time.sleep(SERVER_RETRY_SECONDS)
        keyboards = [d for d in self.client.devices if DEVICE_NAME in d.name]
        if not keyboards:
            print(f"no {DEVICE_NAME} detected, exiting", flush=True)
            sys.exit(0)
        self.device = keyboards[0]
        print(f"connected: {self.device.name} ({len(self.device.leds)} leds)", flush=True)

    def ensure_direct(self):
        try:
            if self.device.active_mode is None or self.device.modes[self.device.active_mode].name.lower() != "direct":
                self.device.set_mode("direct")
        except Exception:
            # Fall back to setting it unconditionally; harmless if already direct.
            try:
                self.device.set_mode("direct")
            except Exception as e:
                print(f"could not force direct mode: {e}", flush=True)

    def _set(self, colors):
        try:
            self.device.set_colors(colors, fast=True)
        except (ConnectionError, OSError) as e:
            print(f"lost server: {e}, reconnecting", flush=True)
            self.connect()

    def restore_base(self):
        """Reload the saved profile — the only trustworthy 'undo'."""
        path = profile_path()
        if path:
            subprocess.run(
                ["openrgb", "-p", path],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=False,
            )
        else:
            self._set([OFF] * len(self.device.leds))

    def apply_ambient(self):
        with self.lock:
            if self.ambient_color is not None:
                self.ensure_direct()
                self._set([self.ambient_color] * len(self.device.leds))
            else:
                self.restore_base()

    # --- notification layer -------------------------------------------------

    def blink(self, base: RGBColor):
        # One effect at a time; a notification during an effect is dropped.
        if not self.lock.acquire(blocking=False):
            return
        try:
            self.ensure_direct()
            palette = palette_for(base)
            n = len(self.device.leds)
            on = [palette[i % len(palette)] for i in range(n)]
            off = [OFF] * n
            for frame in range(int(EFFECT_SECONDS / FRAME_SECONDS)):
                self._set(on if frame % 2 == 0 else off)
                time.sleep(FRAME_SECONDS)
        finally:
            self.lock.release()
        # Land on whatever ambient is current *now* (focus may have changed
        # mid-effect), not on a stale snapshot.
        self.apply_ambient()

    def on_notification(self, app_name: str):
        color = match_color(NOTIFY_COLORS, app_name)
        if color is not None:
            print(f"notification from {app_name!r}", flush=True)
            threading.Thread(target=self.blink, args=(color,), daemon=True).start()

    def listen_notifications(self):
        """Follow org.freedesktop.Notifications Notify calls on the session bus."""
        cmd = [
            "dbus-monitor",
            "type='method_call',interface='org.freedesktop.Notifications',member='Notify'",
        ]
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, text=True)
        expecting_app = False
        for line in proc.stdout:
            if "member=Notify" in line:
                expecting_app = True  # next string argument is app_name
                continue
            if expecting_app:
                m = re.search(r'string "(.*)"', line)
                if m:
                    expecting_app = False
                    self.on_notification(m.group(1))
        raise RuntimeError("dbus-monitor exited")

    # --- focus layer --------------------------------------------------------

    def on_focus(self, window_class: str):
        color = match_color(FOCUS_COLORS, window_class)
        if color != self.ambient_color:
            self.ambient_color = color
            label = window_class if color else "base profile"
            print(f"ambient -> {label}", flush=True)
            self.apply_ambient()

    def hypr_socket_path(self) -> str | None:
        runtime = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
        sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
        if sig:
            path = f"{runtime}/hypr/{sig}/.socket2.sock"
            return path if os.path.exists(path) else None
        # systemd user services don't inherit the signature; pick newest socket
        candidates = glob.glob(f"{runtime}/hypr/*/.socket2.sock")
        return max(candidates, key=os.path.getmtime) if candidates else None

    def listen_focus(self):
        """Follow activewindow events from Hyprland's event socket."""
        while True:
            path = self.hypr_socket_path()
            if not path:
                time.sleep(30)
                continue
            try:
                with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
                    s.connect(path)
                    buf = b""
                    while True:
                        chunk = s.recv(4096)
                        if not chunk:
                            break
                        buf += chunk
                        while b"\n" in buf:
                            line, buf = buf.split(b"\n", 1)
                            text = line.decode(errors="replace")
                            if text.startswith("activewindow>>"):
                                window_class = text.split(">>", 1)[1].split(",", 1)[0]
                                self.on_focus(window_class)
            except OSError:
                pass
            time.sleep(SERVER_RETRY_SECONDS)  # hyprland restarted; re-resolve socket


def main():
    notifier = G213Notifier()
    notifier.connect()
    threading.Thread(target=notifier.listen_focus, daemon=True).start()
    notifier.listen_notifications()


if __name__ == "__main__":
    main()
