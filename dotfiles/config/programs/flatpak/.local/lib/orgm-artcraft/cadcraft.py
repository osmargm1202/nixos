"""Reuse the vendor CADCraft Flatpak through its network-isolated control socket."""
import fcntl
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import time
from urllib.parse import unquote, urlsplit

APP = "ai.storyteller.cadcraft"
PORT = 47835
HERE = Path(__file__).resolve().parent


class Error(Exception):
    pass


def paths_from_arguments(arguments):
    paths = []
    for value in arguments:
        if value.startswith("file:"):
            uri = urlsplit(value)
            if uri.netloc not in ("", "localhost") or uri.query or uri.fragment:
                raise Error("Solo se admiten archivos locales: " + value)
            value = unquote(uri.path, errors="strict")
        elif "://" in value:
            raise Error("Solo se admiten archivos locales: " + value)
        path = Path(value).absolute()
        if not path.is_file() or not os.access(path, os.R_OK):
            raise Error("No se puede leer el plano: " + str(path))
        paths.append(str(path))
    return paths


def private_directory(path):
    try:
        path.mkdir(mode=0o700, parents=True, exist_ok=True)
        info = path.lstat()
        if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid():
            raise Error("Directorio de ejecución inseguro: " + str(path))
        path.chmod(0o700)
    except OSError as exc:
        raise Error(str(exc)) from exc


def open_files(arguments, backend, runtime):
    paths = paths_from_arguments(arguments)  # Validate ALL paths before any side effect.
    private_directory(runtime)
    try:
        fd = os.open(runtime / "open.lock", os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW | os.O_CLOEXEC, 0o600)
    except OSError as exc:
        raise Error("No se puede bloquear CADCraft: " + str(exc)) from exc
    with os.fdopen(fd, "w") as lock:
        if os.fstat(lock.fileno()).st_uid != os.getuid():
            raise Error("Bloqueo de CADCraft de otro usuario")
        os.fchmod(lock.fileno(), 0o600)
        fcntl.flock(lock, fcntl.LOCK_EX)
        instances = backend.discover()
        if len(instances) > 1:
            raise Error("Hay varias instancias de CADCraft. Guarda y cierra las sobrantes antes de continuar.")
        if instances:
            instance = instances[0]
            # Native egui may stop processing control requests on a hidden
            # workspace. Targeted compositor activation must precede even ping.
            backend.focus(instance)
            try:
                reply = backend.rpc(instance, "ping")
                if reply.get("result") != "pong":
                    raise Error("Respuesta inesperada de CADCraft")
            except Error as exc:
                raise Error("CADCraft ya está abierto sin la integración. Guarda tus planos y cierra CADCraft una vez; después vuelve a abrir el archivo. " + str(exc)) from exc
        else:
            if backend.pending(runtime):
                raise Error("CADCraft sigue iniciándose. No se iniciará otra instancia; revisa cadcraft.log.")
            backend.start(runtime)
            deadline = time.monotonic() + 45
            while True:
                instances = backend.discover()
                if len(instances) > 1:
                    raise Error("Aparecieron varias instancias; no se abrirá otro CADCraft.")
                if instances:
                    instance = instances[0]
                    try:
                        backend.focus(instance)
                        if backend.rpc(instance, "ping").get("result") == "pong":
                            break
                    except Error:
                        pass
                if time.monotonic() >= deadline:
                    raise Error("CADCraft no responde todavía. No se iniciará una segunda instancia; revisa cadcraft.log.")
                time.sleep(.2)
        backend.ready(runtime)
        results = []
        for path in paths:
            response = backend.rpc(instance, "open", path)
            if response.get("needs_export"):
                # The sandbox checked before sending app.open, so ONLY this retry is safe.
                response = backend.rpc(instance, "open", backend.export(path))
            if not response.get("ok"):
                raise Error("No se pudo abrir el plano: " + str(response.get("error", response)))
            results.append(response.get("result"))
        try:
            backend.rpc(instance, "focus")
            backend.focus(instance)
        except Error as exc:
            print("CADCraft: plano abierto; no se pudo enfocar: " + str(exc), file=sys.stderr)
        return results


class Backend:
    def run(self, args, **kwargs):
        try:
            return subprocess.run(args, check=True, capture_output=True, text=True, timeout=75, **kwargs)
        except (OSError, subprocess.SubprocessError) as exc:
            detail = getattr(exc, "stderr", None) or str(exc)
            raise Error(str(detail).strip()) from exc

    def rows(self):
        output = self.run(["flatpak", "ps", "--columns=instance,application,pid,child-pid"]).stdout
        rows = []
        for row in output.splitlines():
            fields = row.split()
            if len(fields) == 4 and fields[1] == APP:
                if not all(fields[n].isdigit() for n in (0, 2, 3)):
                    raise Error("Identificador Flatpak inválido")
                rows.append(fields)
        return rows

    def discover(self):
        return [r[0] for r in self.rows()]

    def rpc(self, instance, operation, path=None):
        request = {"operation": operation, "host_netns": os.readlink("/proc/self/ns/net"), "port": PORT}
        if path is not None:
            request["path"] = path
        output = self.run(["flatpak", "enter", instance, "/usr/bin/python3", "-c", (HERE / "sandbox.py").read_text()], input=json.dumps(request)).stdout
        try:
            response = json.loads(output)
        except ValueError as exc:
            raise Error("Respuesta inválida de CADCraft") from exc
        if not isinstance(response, dict) or (not response.get("ok") and not response.get("needs_export")):
            raise Error(str(response))
        return response

    def start(self, runtime):
        logfile = runtime / "cadcraft.log"
        fd = os.open(logfile, os.O_CREAT | os.O_WRONLY | os.O_TRUNC | os.O_NOFOLLOW | os.O_CLOEXEC, 0o600)
        with os.fdopen(fd, "w") as log:
            os.fchmod(log.fileno(), 0o600)
            # A marker is durable before spawning: a launcher crash during the
            # spawn/identity handoff must fail closed, not start another GUI.
            self.mark_launch(runtime, {})
            try:
                process = subprocess.Popen(["flatpak", "run", "--unshare=network", "--env=CADCRAFT_CONTROL_PORT=" + str(PORT), APP], stdin=subprocess.DEVNULL, stdout=log, stderr=log, close_fds=True, start_new_session=True)
            except OSError:
                self.ready(runtime)
                raise
            stamp = self.process_stamp(process.pid)
            if stamp:
                self.mark_launch(runtime, {"pid": process.pid, "stamp": stamp})
            elif process.poll() is not None:
                self.ready(runtime)
                raise Error("CADCraft terminó al iniciar; revisa cadcraft.log")

    def mark_launch(self, runtime, record):
        fd, temporary = tempfile.mkstemp(prefix=".launch-", dir=runtime)
        try:
            with os.fdopen(fd, "w") as output:
                json.dump(record, output)
                output.flush()
                os.fsync(output.fileno())
            os.replace(temporary, runtime / "launch.json")
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)

    def process_stamp(self, pid):
        try:
            proc = Path("/proc") / str(pid)
            if proc.stat().st_uid != os.getuid():
                return None
            fields = (proc / "stat").read_text().rsplit(")", 1)[1].split()
            if fields[0] == "Z":
                return None
            boot = Path("/proc/sys/kernel/random/boot_id").read_text().strip()
            return boot + ":" + fields[19]
        except (FileNotFoundError, ProcessLookupError):
            return None
        except (OSError, IndexError) as exc:
            raise Error("No se puede verificar el proceso que inicia CADCraft: " + str(exc)) from exc

    def pending(self, runtime):
        path = runtime / "launch.json"
        if not path.exists() and not path.is_symlink():
            return False
        if path.is_symlink():
            raise Error("Registro de inicio inseguro")
        try:
            record = json.loads(path.read_text())
            if type(record.get("pid")) is not int or not isinstance(record.get("stamp"), str):
                return True  # Uncertain handoff: never guess that spawning is safe.
            if self.process_stamp(record["pid"]) == record["stamp"]:
                return True
        except (OSError, ValueError, AttributeError):
            return True
        self.ready(runtime)  # The identified process exited or its PID was reused.
        return False

    def ready(self, runtime):
        (runtime / "launch.json").unlink(missing_ok=True)

    def export(self, path):
        args = ["flatpak", "document-export", "--app=" + APP, "--allow-read"]
        if os.access(path, os.W_OK):
            args.append("--allow-write")
        output = self.run(args + [path]).stdout.rstrip("\n")
        if not output.startswith("/run/user/" + str(os.getuid()) + "/doc/"):
            raise Error("El portal no devolvió una ruta de documento válida")
        return output

    def focus(self, instance):
        # Activate only this app instance, not a class-wide or global focus policy.
        rows = [r for r in self.rows() if r[0] == instance]
        if len(rows) != 1:
            return
        pids = {int(rows[0][2]), int(rows[0][3])}
        if os.environ.get("SWAYSOCK"):
            tree = json.loads(self.run(["swaymsg", "-t", "get_tree", "-r"]).stdout)
            def windows(node):
                yield node
                for child in node.get("nodes", []) + node.get("floating_nodes", []):
                    yield from windows(child)
            matches = [n for n in windows(tree) if n.get("app_id") == APP and self.belongs_to_instance(n.get("pid"), pids)]
            if len(matches) == 1 and type(matches[0].get("id")) is int:
                self.run(["swaymsg", "[con_id=" + str(matches[0]["id"]) + "] focus"])
        elif os.environ.get("HYPRLAND_INSTANCE_SIGNATURE"):
            clients = json.loads(self.run(["hyprctl", "clients", "-j"]).stdout)
            matches = [w for w in clients if w.get("class") == APP and self.belongs_to_instance(w.get("pid"), pids)]
            if len(matches) == 1:
                address = matches[0].get("address", "")
                if address.startswith("0x") and all(c in "0123456789abcdefABCDEF" for c in address[2:]) and len(address) > 2:
                    self.run(["hyprctl", "dispatch", "focuswindow", "address:" + address])
        elif os.environ.get("I3SOCK") or "i3" in os.environ.get("XDG_CURRENT_DESKTOP", "").lower():
            tree = json.loads(self.run(["i3-msg", "-t", "get_tree"]).stdout)
            def windows(node):
                yield node
                for child in node.get("nodes", []) + node.get("floating_nodes", []):
                    yield from windows(child)
            matches = []
            for node in windows(tree):
                properties = node.get("window_properties") or {}
                app_class = str(properties.get("class", "")).lower()
                if app_class not in (APP, "cadcraft") or type(node.get("window")) is not int:
                    continue
                # _NET_WM_PID may be a sandbox PID. XRes returns the PID of the
                # actual local X connection, so another instance cannot match.
                pid = self.run(["orgm-x11-client-pid", str(node["window"])]).stdout.strip()
                if pid.isdecimal() and self.belongs_to_instance(int(pid), pids):
                    matches.append(node)
            if len(matches) == 1 and type(matches[0].get("id")) is int:
                self.run(["i3-msg", "[con_id=" + str(matches[0]["id"]) + "] focus"])

    def parent_pid(self, pid):
        try:
            proc = Path("/proc") / str(pid)
            if proc.stat().st_uid != os.getuid():
                return 0
            for line in (proc / "status").read_text().splitlines():
                if line.startswith("PPid:"):
                    return int(line.split()[1])
        except (OSError, ValueError):
            pass
        return 0

    def belongs_to_instance(self, pid, roots):
        # Flatpak child-pid identifies its sandbox init, not always the GUI PID.
        # Follow only same-user ancestry and require this exact sandbox root.
        for _ in range(32):
            if type(pid) is not int or pid <= 1:
                return False
            if pid in roots:
                return True
            pid = self.parent_pid(pid)
        return False


def main():
    try:
        if sys.argv[1:2] == ["install"]:
            from install import install
            install()
        else:
            arguments = sys.argv[1:]
            if arguments[:1] == ["--"]:
                arguments = arguments[1:]
            runtime = Path(os.environ.get("XDG_RUNTIME_DIR", "/run/user/" + str(os.getuid()))) / "orgm-cadcraft"
            open_files(arguments, Backend(), runtime)
        return 0
    except (Error, OSError, ValueError) as exc:
        message = str(exc)
        print("CADCraft: " + message, file=sys.stderr)
        try:
            subprocess.run(["notify-send", "CADCraft", message], timeout=5, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except (OSError, subprocess.SubprocessError):
            pass
        return 1


if __name__ == "__main__":
    # install imports this module; retain one Error class when invoked as a file.
    sys.modules["cadcraft"] = sys.modules[__name__]
    sys.exit(main())
