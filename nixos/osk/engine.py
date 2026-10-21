#!/usr/bin/env python3
"""Persistent, unprivileged OSK input engine. JSON stdin, no shell evaluation."""
import array
import ctypes as C
import ctypes.util
import json
import os
from pathlib import Path
import socket
import struct
import subprocess
import sys
import time


def validate(value):
    if not isinstance(value, dict) or value.get("action") not in ("tap", "release", "quit"):
        raise ValueError("unsupported action")
    if value["action"] == "tap":
        for name in ("code", "modifiers"):
            number = value.get(name, 0)
            if type(number) is not int or not 0 <= number <= 255:
                raise ValueError("invalid " + name)
        text = value.get("text", "")
        if not isinstance(text, str) or len(text) > 8 or any(ord(c) < 32 or ord(c) == 127 for c in text):
            raise ValueError("invalid text")
    if value.get("dead", "") not in ("", "dead_acute", "dead_diaeresis"):
        raise ValueError("invalid dead key")
    return value


def keymap():
    library = os.environ.get("ORGM_OSK_XKBCOMMON") or ctypes.util.find_library("xkbcommon")
    if not library:
        raise RuntimeError("libxkbcommon unavailable; use packaged orgm-osk-engine")
    xkb = C.CDLL(library)
    class Names(C.Structure):
        _fields_ = [(name, C.c_char_p) for name in ("rules", "model", "layout", "variant", "options")]
    xkb.xkb_context_new.restype = C.c_void_p
    xkb.xkb_keymap_new_from_names.argtypes = [C.c_void_p, C.POINTER(Names), C.c_int]
    xkb.xkb_keymap_new_from_names.restype = C.c_void_p
    xkb.xkb_keymap_get_as_string.argtypes = [C.c_void_p, C.c_int]
    xkb.xkb_keymap_get_as_string.restype = C.c_void_p
    xkb.xkb_keymap_unref.argtypes = [C.c_void_p]
    xkb.xkb_context_unref.argtypes = [C.c_void_p]
    context = xkb.xkb_context_new(0)
    compiled = xkb.xkb_keymap_new_from_names(context, C.byref(Names(None, b"pc105", b"latam", None, None)), 0)
    if not compiled:
        xkb.xkb_context_unref(context)
        raise RuntimeError("cannot compile Spanish Latin American keymap")
    string = xkb.xkb_keymap_get_as_string(compiled, 1)
    data = C.string_at(string) + b"\0"
    libc = C.CDLL(None); libc.free.argtypes = [C.c_void_p]; libc.free(string)
    xkb.xkb_keymap_unref(compiled); xkb.xkb_context_unref(context)
    return data


class WaylandKeyboard:
    def __init__(self):
        endpoint = os.environ.get("WAYLAND_DISPLAY", "wayland-0")
        if not endpoint.startswith("/"):
            endpoint = str(Path(os.environ["XDG_RUNTIME_DIR"]) / endpoint)
        self.socket = socket.socket(socket.AF_UNIX)
        self.socket.settimeout(4)
        self.socket.connect(endpoint)
        self.buffer = b""; self.next_id = 4; self.globals = {}
        self.send(1, 1, struct.pack("=I", 2))
        self.sync(3)
        for interface in ("zwp_virtual_keyboard_manager_v1", "wl_seat"):
            if interface not in self.globals:
                self.socket.close()
                raise RuntimeError("compositor lacks " + interface)
        manager = self.bind("zwp_virtual_keyboard_manager_v1")
        seat = self.bind("wl_seat")
        self.object_id = self.allocate()
        self.send(manager, 0, struct.pack("=II", seat, self.object_id))
        data = keymap(); fd = os.memfd_create("orgm-osk-keymap")
        try:
            os.write(fd, data)
            body = struct.pack("=II", 1, len(data))
            header = struct.pack("=II", self.object_id, (len(body) + 8) << 16)
            self.socket.sendmsg([header + body], [(socket.SOL_SOCKET, socket.SCM_RIGHTS, array.array("i", [fd]))])
            self.sync()
        finally:
            os.close(fd)

    def allocate(self):
        result = self.next_id; self.next_id += 1; return result

    def bind(self, interface):
        ident = self.allocate(); data = interface.encode() + b"\0"
        encoded = struct.pack("=I", len(data)) + data + b"\0" * (-len(data) % 4)
        self.send(2, 0, struct.pack("=I", self.globals[interface]) + encoded + struct.pack("=II", 1, ident))
        return ident

    def send(self, ident, opcode, body):
        self.socket.sendall(struct.pack("=II", ident, (len(body) + 8) << 16 | opcode) + body)

    def sync(self, ident=None):
        ident = ident or self.allocate()
        self.send(1, 0, struct.pack("=I", ident))
        while True:
            while len(self.buffer) < 8:
                self.receive()
            target, header = struct.unpack_from("=II", self.buffer)
            size, opcode = header >> 16, header & 65535
            if size < 8:
                raise RuntimeError("malformed Wayland event")
            while len(self.buffer) < size:
                self.receive()
            body, self.buffer = self.buffer[8:size], self.buffer[size:]
            if target == 1 and opcode == 0:
                raise RuntimeError("Wayland rejected OSK request")
            if target == 2 and opcode == 0:
                name, length = struct.unpack_from("=II", body)
                interface = body[8:8 + length - 1].decode()
                self.globals[interface] = name
            if target == ident and opcode == 0:
                return

    def receive(self):
        chunk = self.socket.recv(65536)
        if not chunk:
            raise RuntimeError("Wayland disconnected")
        self.buffer += chunk

    def modifiers(self, mask):
        self.send(self.object_id, 2, struct.pack("=IIII", mask, 0, 0, 0)); self.sync()

    def key(self, code, pressed):
        self.send(self.object_id, 1, struct.pack("=III", int(time.monotonic() * 1000) & 0xffffffff, code, int(pressed)))
        self.sync()

    def close(self):
        self.socket.close()


class WaylandBackend:
    def __init__(self):
        self.keyboard = WaylandKeyboard()

    def tap(self, command):
        code = command["code"]
        try:
            self.keyboard.modifiers(command.get("modifiers", 0))
            self.keyboard.key(code, True)
        finally:
            try:
                self.keyboard.key(code, False)
            finally:
                self.keyboard.modifiers(0)

    def release(self):
        self.keyboard.modifiers(0)

    def close(self):
        try:
            self.release()
        finally:
            self.keyboard.close()


class X11Backend:
    SPECIAL = {1: "Escape", 14: "BackSpace", 15: "Tab", 28: "Return", 57: "space", 102: "Home", 103: "Up", 104: "Prior", 105: "Left", 106: "Right", 107: "End", 108: "Down", 109: "Next", 111: "Delete"}
    LETTERS = dict(zip([16,17,18,19,20,21,22,23,24,25,30,31,32,33,34,35,36,37,38,44,45,46,47,48,49,50], "qwertyuiopasdfghjklzxcvbnm"))
    def tap(self, command):
        mask = command.get("modifiers", 0); text = command.get("text", "")
        binary = os.environ.get("ORGM_OSK_XDOTOOL", "xdotool")
        if command.get("dead"):
            args = [binary, "key", "--clearmodifiers", "--delay", "20", command["dead"]]
        elif text and not mask & (4 | 8 | 64):
            args = [binary, "type", "--clearmodifiers", "--delay", "20", "--", text]
        else:
            symbol = self.SPECIAL.get(command["code"], self.LETTERS.get(command["code"], text))
            if not symbol or "+" in symbol:
                raise ValueError("unsupported X11 key")
            prefix = [name for bit, name in ((1,"shift"),(4,"ctrl"),(8,"alt"),(64,"super")) if mask & bit]
            # Do not clear pointer-button modifiers: doing so releases the held
            # OSK button and cancels its navigation/delete repeat timer.
            args = [binary, "key", "--delay", "0", "+".join(prefix + [symbol])]
        subprocess.run(args, check=True, timeout=3, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    def release(self):
        pass  # Every XTest operation is an atomic press+release; no held keys.

    def close(self):
        pass


def emit(value):
    print(json.dumps(value), flush=True)


def main():
    backend = None
    try:
        kind = os.environ.get("ORGM_OSK_BACKEND") or ("wayland" if os.environ.get("WAYLAND_DISPLAY") else "x11")
        if kind not in ("wayland", "x11"):
            raise ValueError("invalid backend")
        backend = WaylandBackend() if kind == "wayland" else X11Backend()
        emit({"event": "ready", "backend": kind})
        while True:
            line = sys.stdin.readline(4097)
            if not line:
                break
            if len(line) > 4096:
                while line and not line.endswith("\n"):
                    line = sys.stdin.readline(4097)
                emit({"event": "error", "error": "request too long"}); continue
            try:
                command = validate(json.loads(line))
                if command["action"] == "quit":
                    break
                if command["action"] == "release":
                    backend.release()
                else:
                    backend.tap(command)
                emit({"event": "done"})
            except (ValueError, subprocess.SubprocessError) as error:
                emit({"event": "error", "error": type(error).__name__})
    except (OSError, RuntimeError, KeyError, ValueError) as error:
        emit({"event": "error", "error": str(error)})
        return 1
    finally:
        if backend:
            try:
                backend.close()
            except (OSError, RuntimeError):
                pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
