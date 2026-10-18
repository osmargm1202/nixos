"""Lenovo Windows adapter: preserve personal disks and existing containers."""
import json
import os
from pathlib import Path
import re
import stat
import sys
import tempfile

if not Path(__file__).with_name("windows_runtime.py").is_file():
    sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "containers/windows"))

from windows_runtime import (
    DIGEST, GENERATION, MODE, OWNER, Lifecycle, Refused, config_digest,
    device_ready, main as runtime_main, real_path, resolve_gpu,
)

PATH_FIELDS = ("WINDOWS_STORAGE_DIR", "WINDOWS_SHARED_DIR", "WINDOWS_OEM_DIR")
DISK_SUFFIXES = (".img", ".raw", ".qcow", ".qcow2", ".vhd", ".vhdx", ".vmdk", ".vdi")


def private_config(filename):
    """A deliberately small dotenv grammar, never a shell or dotenv evaluator.

    Quotes are literal delimiters, not shell syntax. Only path fields expand a
    leading HOME token; credentials retain dollars, hashes and other literals.
    Reject duplicates/escapes/concatenation rather than guessing their meaning.
    """
    try:
        path = real_path(filename)
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
        with os.fdopen(fd) as stream:
            info = os.fstat(stream.fileno())
            if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) & 0o077:
                raise Refused("Windows configuration must be a private user-owned regular file")
            text = stream.read()
        if "\0" in text or "\r" in text:
            raise ValueError()
        values = {}
        for line in text.split("\n"):
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            match = re.fullmatch(r"([A-Za-z_][A-Za-z_0-9]*)\s*=\s*(.*)", line)
            if not match or match[1] in values:
                raise ValueError()
            key, raw = match.groups()
            if raw.startswith("#"):
                value = ""
            elif raw.startswith(("'", '"')):
                quote = raw[0]
                end = raw.find(quote, 1)
                if end < 0 or not re.fullmatch(r"\s*(?:#.*)?", raw[end + 1:]):
                    raise ValueError()
                value = raw[1:end]
                if quote == '"' and "\\" in value:
                    raise ValueError()
            else:
                match = re.fullmatch(r"([^\s'\"\\]*)(?:\s+#.*)?\s*", raw)
                if not match:
                    raise ValueError()
                value = match[1]
            values[key] = value
        for key in PATH_FIELDS:
            value = values.get(key, "")
            if re.match(r"^\$(?:HOME|\{HOME\})(?=/|$)", value):
                home = os.environ.get("HOME", "")
                if not home or not Path(home).is_absolute():
                    raise ValueError()
                value = re.sub(r"^\$(?:HOME|\{HOME\})(?=/|$)", lambda _: home, value)
            if (not value or any(c in value for c in ("$", "`", "\\", ":", "\n", "\t"))
                or value.startswith("~") or "//" in value or "/./" in value):
                raise ValueError()
            values[key] = str(real_path(value))
        return values
    except (OSError, ValueError):
        raise Refused("private Windows configuration is missing or unsupported; check literal assignments and absolute paths") from None


class Controller(Lifecycle):
    def __init__(self, manifest):
        super().__init__(manifest)
        mode = manifest.get("mode")
        if (manifest.get("host") != "lenovo" or mode not in ("vfio", "render")
            or manifest.get("container") != ("lenovo-windows" if mode == "vfio" else "windows")
            or not re.fullmatch(r"localhost/lenovo-windows-spice:[0-9a-f]{64}", manifest.get("image", ""))):
            raise Refused("invalid Lenovo host/mode/container/image declaration")
        if (manifest.get("bdf"), manifest.get("vendor"), manifest.get("device"), manifest.get("renderBdf")) != (
            "0000:01:00.0", "0x10de", "0x1fbb", "0000:00:02.0"
        ):
            raise Refused("unsupported Lenovo PCI identity")
        if (not isinstance(manifest.get("compose"), list) or len(manifest["compose"]) != 2
            or not all(isinstance(p, str) and Path(p).is_absolute() for p in manifest["compose"])
            or not all(isinstance(manifest.get("commands", {}).get(k), str)
                       and Path(manifest["commands"][k]).is_absolute() for k in ("podman", "compose"))):
            raise Refused("Lenovo requires absolute compose templates and commands")
        real_path(manifest["runtimeDir"])
        real_path(manifest["inputIso"])
        self.config = private_config(manifest["envFile"])

    def storage_path(self):
        path = real_path(self.config["WINDOWS_STORAGE_DIR"])
        if not path.is_dir():
            raise Refused("configured Windows storage directory does not exist")
        return path

    def owned(self, container):
        labels = container.get("Config", {}).get("Labels") or {}
        if OWNER in labels and labels[OWNER] != "lenovo":
            raise Refused("container is owned by another runtime; nothing replaced")
        if MODE in labels and labels[MODE] != self.m["mode"]:
            raise Refused("container has another GPU mode; nothing replaced")
        if OWNER in labels and MODE not in labels:
            raise Refused("owned container is missing its GPU mode; nothing replaced")
        mounts = [row for row in container.get("Mounts", []) if row.get("Destination") == "/storage"]
        if len(mounts) != 1 or real_path(mounts[0]["Source"]) != self.storage_path():
            raise Refused("container has an unexpected Windows disk; nothing replaced")

    def container_mode(self, current):
        return (current["Config"]["Labels"] or {}).get(MODE, self.m["mode"])

    def pending(self, current):
        labels = current["Config"]["Labels"] or {}
        return labels.get(OWNER) != "lenovo" or super().pending(current)

    def private_password(self):
        value = self.config.get("WINDOWS_PASSWORD", "")
        if not value or any(c in value for c in ("\n", "\r", "\0")):
            raise Refused("creation requires a nonempty private WINDOWS_PASSWORD")
        return value

    def validate_storage(self):
        for key in PATH_FIELDS:
            path = real_path(self.config[key])
            if not path.is_dir() or not os.access(path, os.R_OK | os.W_OK | os.X_OK):
                raise Refused("configured Windows directories must already exist and be accessible")
        disk_found = False
        def fail(_):
            raise Refused("Windows disk directory cannot be checked safely")
        for directory, dirs, files in os.walk(self.storage_path(), followlinks=False, onerror=fail):
            for name in dirs + files:
                path = Path(directory) / name
                if path.is_symlink():
                    raise Refused("preserved guest storage link; no writes through external images")
                if path.is_file() and path.suffix.lower() in DISK_SUFFIXES and path.stat().st_size > 0:
                    disk_found = True
        if not disk_found:
            raise Refused("existing Windows disk is required; automatic fresh OS installation is disabled")

    def preflight(self):
        if self.m["mode"] == "vfio":
            hardware = resolve_gpu(self.m, self.m.get("sysfsRoot", "/sys"))
            if not Path(self.m["inputIso"]).is_file() or not os.access(self.m["inputIso"], os.R_OK):
                raise Refused("immutable input driver ISO is unavailable")
        else:
            gpu = Path(self.m.get("sysfsRoot", "/sys")) / "bus/pci/devices" / self.m["renderBdf"]
            try:
                if gpu.joinpath("vendor").read_text().strip() != "0x8086" or gpu.joinpath("driver").resolve(strict=True).name != "i915":
                    raise Refused("Lenovo render requires the declared Intel i915 GPU")
                nodes = list(gpu.joinpath("drm").glob("renderD*"))
                if len(nodes) != 1:
                    raise Refused("Intel render node is unavailable or ambiguous")
                node = Path(self.m.get("devRoot", "/dev")) / "dri" / nodes[0].name
                if not device_ready(node):
                    raise Refused("Intel render node is not accessible")
                hardware = {"mode": "render", "bdf": self.m["renderBdf"], "render": str(node)}
            except (OSError, ValueError):
                raise Refused("Intel render identity is unavailable") from None
        for relative in ("kvm", "net/tun"):
            if not device_ready(Path(self.m.get("devRoot", "/dev")) / relative):
                raise Refused("KVM/tun unavailable to the rootless user")
        self.validate_storage()
        return hardware

    def check_stopped_devices(self, hardware):
        # This is a separate, narrow query: never inspect Env or dump HostConfig.
        result = self.command("podman", "inspect", "--format", "{{json .HostConfig.Devices}}", self.m["container"])
        try:
            devices = json.loads(result.stdout)
            if not isinstance(devices, list) or not all(
                isinstance(row, dict) and isinstance(row.get("PathOnHost"), str) and row["PathOnHost"].startswith("/")
                and isinstance(row.get("PathInContainer"), str) and row["PathInContainer"].startswith("/") for row in devices
            ):
                raise ValueError()
        except (ValueError, TypeError):
            raise Refused("cannot establish existing VFIO device mappings; no recreation attempted") from None
        dev = Path(self.m.get("devRoot", "/dev"))
        required = {(str(dev / "vfio/vfio"), "/dev/vfio/vfio"),
                    (str(dev / "vfio" / hardware["group"]), "/dev/vfio/" + hardware["group"]),
                    (str(dev / "kvmfr0"), "/dev/kvmfr0")}
        actual = [(row["PathOnHost"], row["PathInContainer"]) for row in devices
                  if row["PathInContainer"].startswith("/dev/vfio/") or row["PathInContainer"] in ("/dev/vfio", "/dev/kvmfr0")
                  or row["PathOnHost"].startswith(str(dev / "vfio") + "/") or row["PathOnHost"] in (str(dev / "vfio"), str(dev / "kvmfr0"))]
        if set(actual) != required or len(actual) != len(required):
            raise Refused("existing VFIO device mappings are stale; manual review required, nothing recreated")

    def write_overlay(self, hardware):
        directory = real_path(self.m["runtimeDir"])
        directory.mkdir(mode=0o700, parents=True, exist_ok=True)
        if directory.stat().st_uid != os.getuid() or stat.S_IMODE(directory.stat().st_mode) != 0o700:
            raise Refused("runtime directory must be private and user-owned")
        target = real_path(directory / "hardware.json")
        dev = Path(self.m.get("devRoot", "/dev"))
        devices = [str(dev / "kvm") + ":/dev/kvm", str(dev / "net/tun") + ":/dev/net/tun"]
        environment = {}
        volumes = [self.config[key] + ":/" + dest for key, dest in zip(PATH_FIELDS, ("storage", "shared", "oem"))]
        if hardware["mode"] == "vfio":
            devices += [str(dev / "vfio/vfio") + ":/dev/vfio/vfio",
                        str(dev / "vfio" / hardware["group"]) + ":/dev/vfio/" + hardware["group"],
                        str(dev / "kvmfr0") + ":/dev/kvmfr0"]
            volumes.append(self.m["inputIso"] + ":/drivers.iso:ro")
        else:
            destination = "/dev/dri/" + Path(hardware["render"]).name
            devices.append(hardware["render"] + ":" + destination)
            environment["RENDERNODE"] = destination
        service = {"image": self.m["image"], "container_name": self.m["container"], "pull_policy": "never",
                   "labels": {OWNER: "lenovo", MODE: self.m["mode"], GENERATION: self.m["generation"],
                              DIGEST: config_digest(self.m, hardware)},
                   "devices": devices, "volumes": volumes, "environment": environment}
        fd, tmp = tempfile.mkstemp(dir=directory, prefix="hardware-")
        try:
            with os.fdopen(fd, "w") as out:
                json.dump({"services": {"windows": service}}, out)
            os.replace(tmp, target)
        finally:
            if os.path.exists(tmp):
                os.unlink(tmp)
        return target

    def reconcile(self):
        real_path(self.m["runtimeDir"])
        self.storage_path()
        current = self.inspect(self.m["container"])
        if current:
            self.owned(current)
        self.check_other_guests(current)
        if current and current["State"]["Running"]:
            return {"running": True, "pending": self.pending(current)}
        hardware = self.preflight()
        if current:
            if self.m["mode"] == "vfio":
                self.check_stopped_devices(hardware)
            self.start_attempted = True
            self.command("podman", "start", self.m["container"])
            self.confirm_started()
            return {"running": True, "pending": self.pending(current)}
        self.private_password()
        if self.command("podman", "image", "exists", self.m["image"], allowed=(0, 1)).returncode:
            raise Refused("Windows image is not local; provision it explicitly (no automatic pull/build)")
        overlay = self.write_overlay(hardware)
        # Environment takes precedence over dotenv interpolation. Never let a
        # caller's public WINDOWS_* values choose a different disk/image/secret.
        env = {k: v for k, v in os.environ.items() if not k.startswith(("WINDOWS_", "COMPOSE_"))}
        env.update({k: v for k, v in self.config.items() if k.startswith("WINDOWS_")})
        env.update(WINDOWS_IMAGE=self.m["image"], WINDOWS_CONTAINER_NAME=self.m["container"])
        files = [part for source in self.m["compose"] + [str(overlay)] for part in ("-f", source)]
        self.start_attempted = True
        self.command("compose", "--podman-path", self.m["commands"]["podman"], "--env-file", self.m["envFile"],
                     "-p", "windows-vm-lenovo", *files, "up", "-d", "--no-build", "--no-recreate", "windows",
                     env=env, cwd=str(overlay.parent))
        return self.confirm_started()


def main(argv=None):
    return runtime_main(Controller, argv)


if __name__ == "__main__":
    raise SystemExit(main())
