"""Fixed least-action client, executed INSIDE a CADCraft Flatpak namespace.

Never publish the vendor control server on the host network. This check remains
necessary even if a user changes Flatpak overrides after installation.
"""
import json
import os
from pathlib import Path
import socket
import stat
import sys
import uuid


def control_token(port):
    runtime = os.environ.get("XDG_RUNTIME_DIR")
    directory = Path(runtime) if runtime else Path.home() / ".cache"
    path = directory / ("cadcraft-control-" + str(port) + ".token")
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC)
    except FileNotFoundError:
        return None  # Older vendor releases do not require a session token.
    with os.fdopen(fd, encoding="utf-8") as token_file:
        info = os.fstat(token_file.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o077:
            raise ValueError("Token de CADCraft sin permisos privados")
        token = token_file.read(4097).strip()
        if not token or len(token) > 4096:
            raise ValueError("Token de CADCraft inválido")
        return token


def call(request):
    host = request["host_netns"]
    if not isinstance(host, str) or not host.startswith("net:[") or os.readlink("/proc/self/ns/net") == host:
        raise ValueError("CADCraft comparte la red del host; se rechaza el control sin aislamiento")
    methods = {"ping": "ping", "open": "app.open", "focus": "ui.focus"}
    operation = request["operation"]
    if operation not in methods:
        raise ValueError("Operación no permitida")
    params = {}
    if operation == "open":
        path = request["path"]
        if not isinstance(path, str) or not os.path.isabs(path):
            raise ValueError("Ruta de plano inválida")
        if not os.path.isfile(path) or not os.access(path, os.R_OK):
            return {"needs_export": True}
        params["path"] = path
    ident = uuid.uuid4().hex
    payload = {"id": ident, "method": methods[operation], "params": params}
    port = request["port"]
    if type(port) is not int or not 1024 <= port <= 65535:
        raise ValueError("Puerto inválido")
    token = control_token(port)
    if token is not None:
        payload["token"] = token
    with socket.create_connection(("127.0.0.1", port), timeout=2) as conn:
        conn.settimeout(65 if operation == "open" else 3)
        conn.sendall((json.dumps(payload) + "\n").encode())
        with conn.makefile("rb") as stream:
            reply = stream.readline(1024 * 1024 + 1)
    if len(reply) > 1024 * 1024 or not reply.endswith(b"\n"):
        raise ValueError("Respuesta truncada o excesiva; no se reintentará la apertura")
    response = json.loads(reply)
    if not isinstance(response, dict) or response.get("id") != ident or type(response.get("ok")) is not bool:
        raise ValueError("Respuesta no corresponde a la petición; no se reintentará")
    return response


if __name__ == "__main__":
    try:
        print(json.dumps(call(json.load(sys.stdin))))
    except Exception as exc:
        print(json.dumps({"ok": False, "error": str(exc)}))
        sys.exit(1)
