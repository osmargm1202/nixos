#!/usr/bin/env python3
"""Fixed pump commands. Home Assistant credentials stay on the controller host."""

from __future__ import annotations

import argparse
import contextlib
import fcntl
import json
import os
from pathlib import Path
import signal
import socket
import socketserver
import subprocess
import sys
import time
import urllib.error
import urllib.request


class PumpError(Exception):
    pass


def validate(payload):
    if not isinstance(payload, dict) or set(payload) - {"action", "minutes"}:
        raise PumpError("Petición de bomba no válida")
    action = payload.get("action")
    if action not in {"status", "up", "down", "time"}:
        raise PumpError("Usa bomba up, bomba down, bomba time MINUTOS o bomba status")
    minutes = payload.get("minutes")
    if action == "time":
        if type(minutes) is not int or not 1 <= minutes <= 1440:
            raise PumpError("Indica un número entero de minutos entre 1 y 1440")
    elif "minutes" in payload:
        raise PumpError("Solo bomba time admite minutos")
    return action, minutes


def load_config(path=None):
    location = Path(path or os.environ.get("BOMBA_CONFIG", "")) if path or os.environ.get("BOMBA_CONFIG") else None
    if location is None:
        private = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "bomba/config.json"
        try:
            private_exists = private.is_file()
        except OSError:
            # Sandboxed services can use /etc without access to a home directory.
            private_exists = False
        location = private if private_exists else Path("/etc/bomba/config.json")
    try:
        return json.loads(location.read_text())
    except (OSError, ValueError) as exc:
        raise PumpError("Falta la configuración de bomba en ~/.config/bomba/config.json o /etc/bomba/config.json") from exc


class HomeAssistant:
    def __init__(self, config):
        self.base = config.get("url", "http://127.0.0.1:8123").rstrip("/")
        self.switch = config.get("switch", "switch.bomba")
        self.countdown = config.get("countdown", "number.bomba_countdown")
        self.timeout = config.get("request_timeout", 8)
        token_path = Path(config.get("token_file", str(Path.home() / ".config/bomba/ha-token"))).expanduser()
        try:
            if token_path.stat().st_mode & 0o077:
                raise PumpError("El token debe ser privado: chmod 600 ~/.config/bomba/ha-token")
            self.token = token_path.read_text().strip()
        except OSError as exc:
            raise PumpError("Falta el token de Home Assistant en ~/.config/bomba/ha-token") from exc
        if not self.token:
            raise PumpError("El token de Home Assistant está vacío")

    def request(self, path, body=None):
        request = urllib.request.Request(
            self.base + "/api/" + path,
            data=None if body is None else json.dumps(body).encode(),
            headers={"Authorization": "Bearer " + self.token, "Content-Type": "application/json"},
        )
        try:
            with urllib.request.urlopen(request, timeout=self.timeout) as response:
                return json.load(response)
        except urllib.error.HTTPError as exc:
            if exc.code == 401:
                raise PumpError("Home Assistant rechazó el token; crea uno nuevo") from exc
            if exc.code == 404:
                raise PumpError("Home Assistant todavía no tiene las entidades de la bomba") from exc
            raise PumpError(f"Home Assistant no pudo completar la acción (HTTP {exc.code})") from exc
        except (OSError, ValueError) as exc:
            raise PumpError("No hay conexión con Home Assistant") from exc

    def service(self, domain, action, entity, **data):
        return self.request(f"services/{domain}/{action}", {"entity_id": entity, **data})

    def status(self):
        switch = self.request("states/" + self.switch)
        timer = self.request("states/" + self.countdown)
        if switch.get("state") not in {"on", "off"} or timer.get("state") in {"unknown", "unavailable"}:
            raise PumpError("La bomba no está disponible en Smart Life")
        try:
            seconds = max(0, int(float(timer["state"])))
        except (KeyError, TypeError, ValueError) as exc:
            raise PumpError("No se pudo consultar el temporizador de la bomba") from exc
        return {"state": switch["state"], "remaining_seconds": seconds if switch["state"] == "on" else 0, "native_timer": True}

    def wait_for(self, entity, expected):
        deadline = time.monotonic() + 5
        while True:
            value = self.request("states/" + entity).get("state")
            if expected(value):
                return
            if time.monotonic() >= deadline:
                raise PumpError("El interruptor no confirmó el cambio; comprueba su conexión")
            time.sleep(0.25)

    def set_timer(self, seconds):
        self.service("number", "set_value", self.countdown, value=seconds)
        def matches(value):
            try:
                return max(0, seconds - 5) <= float(value) <= seconds
            except (ValueError, TypeError):
                return False
        self.wait_for(self.countdown, matches)

    def execute(self, payload):
        action, minutes = validate(payload)
        if action == "status":
            return self.status()
        current = self.status()
        if action == "down":
            # Always request off, even if clearing a previous timer fails.
            self.service("switch", "turn_off", self.switch)
            self.set_timer(0)
            self.wait_for(self.switch, lambda value: value == "off")
        elif action == "up":
            self.set_timer(0)
            self.service("switch", "turn_on", self.switch)
            self.wait_for(self.switch, lambda value: value == "on")
        else:
            try:
                if current["state"] == "off":
                    self.set_timer(0)
                    self.service("switch", "turn_on", self.switch)
                    self.wait_for(self.switch, lambda value: value == "on")
                self.set_timer(minutes * 60)
            except BaseException as exc:
                with contextlib.suppress(PumpError):
                    self.service("switch", "turn_off", self.switch)
                    self.set_timer(0)
                if isinstance(exc, (KeyboardInterrupt, SystemExit)):
                    raise
                raise PumpError("No se confirmó el temporizador; se solicitó apagar la bomba. Comprueba su estado") from exc
        return self.status()


def read_response(raw):
    try:
        response = json.loads(raw)
        if response.get("ok") is not True:
            raise PumpError(response.get("error", "El controlador no pudo completar la acción"))
        return response["result"]
    except (ValueError, KeyError, AttributeError) as exc:
        raise PumpError("Respuesta no válida del controlador de la bomba") from exc


def execute(config, payload):
    validate(payload)
    mode = config.get("mode", "local")
    if mode == "failover":
        # Check readiness before any write. A lost response after a write must
        # not replay a physical command through a second controller.
        try:
            primary_status = execute({**config["primary"], "request_timeout": 2}, {"action": "status"})
        except PumpError:
            result = execute(config["fallback"], payload)
            return {**result, "controller": "orgm", "fallback": True}
        result = primary_status if payload["action"] == "status" else execute(config["primary"], payload)
        return {**result, "controller": "jarq", "fallback": False}
    if mode == "local":
        state_dir = Path(config["state_dir"]) if "state_dir" in config else Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "bomba"
        state_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
        with (state_dir / "control.lock").open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            return HomeAssistant(config).execute(payload)
    if mode == "ssh":
        command = [
            "ssh", "-T", "-o", "BatchMode=yes", "-o", "ConnectTimeout=6",
            "-o", "IdentitiesOnly=yes", "-o", "StrictHostKeyChecking=yes",
            "-o", "UserKnownHostsFile=" + config["known_hosts"],
            "-i", config["identity"], config.get("user", "osmarg") + "@" + config["host"],
        ]
        try:
            result = subprocess.run(command, input=json.dumps(payload), capture_output=True, text=True, timeout=50)
        except (OSError, subprocess.TimeoutExpired) as exc:
            raise PumpError("No hay conexión con el controlador de la bomba en OrgM") from exc
        if not result.stdout.strip():
            raise PumpError("No se pudo conectar con OrgM; comprueba Tailscale y la clave de bomba")
        return read_response(result.stdout)
    if mode == "unix":
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
                connection.settimeout(55)
                connection.connect(config.get("socket", "/run/bomba/control.sock"))
                connection.sendall(json.dumps(payload).encode() + b"\n")
                with connection.makefile("rb") as stream:
                    return read_response(stream.readline(8193))
        except OSError as exc:
            raise PumpError("El servicio de bomba no está disponible en este equipo") from exc
    raise PumpError("Transporte de bomba no válido")


def envelope(config, payload):
    try:
        return {"ok": True, "result": execute(config, payload)}
    except PumpError as exc:
        return {"ok": False, "error": str(exc)}


def serve(config):
    path = Path(config.get("socket", "/run/bomba/control.sock"))
    path.unlink(missing_ok=True)
    class Handler(socketserver.StreamRequestHandler):
        def handle(self):
            self.connection.settimeout(60)
            try:
                raw = self.rfile.readline(4097)
                if len(raw) > 4096:
                    raise ValueError
                response = envelope(config, json.loads(raw))
            except (ValueError, OSError):
                response = {"ok": False, "error": "Petición de bomba no válida"}
            self.wfile.write(json.dumps(response).encode() + b"\n")
    class Server(socketserver.ThreadingUnixStreamServer):
        daemon_threads = True
    with Server(str(path), Handler) as server:
        path.chmod(0o660)
        server.serve_forever()


def main():
    parser = argparse.ArgumentParser(description="Control de la bomba de agua")
    parser.add_argument("--config")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("action", choices=["up", "down", "time", "status", "gateway", "serve"])
    parser.add_argument("minutes", nargs="?", type=int)
    args = parser.parse_args()
    if args.action in {"time", "gateway"}:
        # Finish programming the device even if the terminal/SSH client closes.
        signal.signal(signal.SIGHUP, signal.SIG_IGN)
    try:
        config = load_config(args.config)
        if args.action == "serve":
            serve(config)
            return
        if args.action == "gateway":
            try:
                raw = sys.stdin.readline(4097)
                if len(raw) > 4096:
                    raise ValueError
                payload = json.loads(raw)
            except ValueError as exc:
                raise PumpError("Petición de bomba no válida") from exc
        else:
            payload = {"action": args.action}
            if args.minutes is not None:
                payload["minutes"] = args.minutes
        response = envelope(config, payload)
    except PumpError as exc:
        response = {"ok": False, "error": str(exc)}
    if args.json or args.action == "gateway":
        print(json.dumps(response, ensure_ascii=False))
    elif not response["ok"]:
        print("bomba: " + response["error"], file=sys.stderr)
    else:
        result = response["result"]
        if result["state"] == "off":
            print("Bomba apagada.")
        elif result["remaining_seconds"]:
            seconds = result["remaining_seconds"]
            print(f"Bomba encendida. Apagado automático en {(seconds + 59) // 60} min.")
        else:
            print("Bomba encendida sin temporizador.")
        if result.get("fallback"):
            print("Control de respaldo: OrgM.")
    raise SystemExit(0 if response["ok"] else 1)


if __name__ == "__main__":
    main()
