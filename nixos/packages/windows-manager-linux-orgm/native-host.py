#!/usr/bin/env python3
import argparse
import json
import os
import selectors
import socket
import struct
import sys
import uuid
from pathlib import Path
from urllib.parse import urlsplit

SOCKET_NAME = "windows_manager_linux_orgm.sock"
MAX_MESSAGE_BYTES = 64 * 1024


def runtime_dir():
    return Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))


def socket_path():
    return runtime_dir() / SOCKET_NAME


def valid_url(url):
    parsed = urlsplit(url)
    return parsed.scheme in {"http", "https"} and bool(parsed.netloc)


def read_exact(stream, size):
    chunks = []
    remaining = size
    while remaining:
        chunk = stream.read(remaining)
        if not chunk:
            return None
        chunks.append(chunk)
        remaining -= len(chunk)
    return b"".join(chunks)


def read_native_message(stream):
    header = read_exact(stream, 4)
    if header is None:
        return None
    (size,) = struct.unpack("<I", header)
    if size > MAX_MESSAGE_BYTES:
        raise ValueError("native message exceeds maximum size")
    payload = read_exact(stream, size)
    if payload is None:
        return None
    return json.loads(payload.decode("utf-8"))


def write_native_message(message):
    payload = json.dumps(message, separators=(",", ":")).encode("utf-8")
    sys.stdout.buffer.write(struct.pack("<I", len(payload)))
    sys.stdout.buffer.write(payload)
    sys.stdout.buffer.flush()


def send_client_message(connection, message):
    connection.sendall(json.dumps(message, separators=(",", ":")).encode("utf-8") + b"\n")


def request_url(url):
    if not valid_url(url):
        raise ValueError("only http(s) URLs are supported")
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
        connection.settimeout(3)
        connection.connect(str(socket_path()))
        send_client_message(connection, {"url": url})
        response = bytearray()
        while not response.endswith(b"\n"):
            chunk = connection.recv(4096)
            if not chunk:
                raise RuntimeError("browser tab bridge closed without a response")
            response.extend(chunk)
            if len(response) > MAX_MESSAGE_BYTES:
                raise RuntimeError("browser tab bridge response exceeds maximum size")
    message = json.loads(response.decode("utf-8"))
    if not message.get("ok"):
        raise RuntimeError(message.get("error", "browser tab bridge rejected the request"))


def run_client(url):
    try:
        request_url(url)
    except (OSError, ValueError, RuntimeError, json.JSONDecodeError) as error:
        print(f"windows-manager-linux-orgm-tab: {error}", file=sys.stderr)
        return 1
    return 0


class NativeHost:
    def __init__(self):
        self.selector = selectors.DefaultSelector()
        self.pending = {}
        self.buffers = {}
        self.listener = None
        self.path = socket_path()

    def start_listener(self):
        self.path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        self.listener = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.listener.bind(str(self.path))
        self.path.chmod(0o600)
        self.listener.listen()
        self.listener.setblocking(False)
        self.selector.register(self.listener, selectors.EVENT_READ, self.accept_client)
        self.selector.register(sys.stdin.buffer, selectors.EVENT_READ, self.read_browser_message)

    def accept_client(self, listener):
        connection, _ = listener.accept()
        connection.setblocking(False)
        self.buffers[connection] = bytearray()
        self.selector.register(connection, selectors.EVENT_READ, self.read_client_message)

    def close_client(self, connection):
        self.pending = {key: value for key, value in self.pending.items() if value is not connection}
        self.buffers.pop(connection, None)
        try:
            self.selector.unregister(connection)
        except KeyError:
            pass
        connection.close()

    def read_client_message(self, connection):
        chunk = connection.recv(4096)
        if not chunk:
            self.close_client(connection)
            return
        buffer = self.buffers[connection]
        buffer.extend(chunk)
        if len(buffer) > MAX_MESSAGE_BYTES:
            send_client_message(connection, {"ok": False, "error": "request exceeds maximum size"})
            self.close_client(connection)
            return
        if b"\n" not in buffer:
            return
        raw_message, _, _ = buffer.partition(b"\n")
        try:
            request = json.loads(raw_message.decode("utf-8"))
            url = request["url"]
            if not isinstance(url, str) or not valid_url(url):
                raise ValueError("only http(s) URLs are supported")
        except (KeyError, ValueError, json.JSONDecodeError) as error:
            send_client_message(connection, {"ok": False, "error": str(error)})
            self.close_client(connection)
            return
        request_id = str(uuid.uuid4())
        self.pending[request_id] = connection
        write_native_message({"type": "focus-existing", "id": request_id, "url": url})

    def read_browser_message(self, _):
        message = read_native_message(sys.stdin.buffer)
        if message is None:
            raise EOFError
        request_id = message.get("id")
        connection = self.pending.pop(request_id, None)
        if connection is None:
            return
        send_client_message(connection, message)
        self.close_client(connection)

    def run(self):
        self.start_listener()
        try:
            while True:
                for key, _ in self.selector.select():
                    key.data(key.fileobj)
        except EOFError:
            return
        finally:
            self.selector.close()
            if self.listener is not None:
                self.listener.close()
            try:
                self.path.unlink()
            except FileNotFoundError:
                pass


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--client", metavar="URL")
    args = parser.parse_args()
    if args.client is not None:
        return run_client(args.client)
    NativeHost().run()
    return 0


if __name__ == "__main__":
    sys.exit(main())
