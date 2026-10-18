"""Shared rootless Windows VM lifecycle, with conservative disk/lifetime ownership."""
import argparse
from contextlib import contextmanager
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import socket
import stat
import subprocess
import sys
import time

OWNER = "org.orgm.windows.owner"
MODE = "org.orgm.windows.mode"
GENERATION = "org.orgm.windows.generation"
DIGEST = "org.orgm.windows.config"


class Refused(Exception):
    """An actionable refusal whose text must never contain credentials/tool output."""


def notify_ready():
    address = os.environ.get("NOTIFY_SOCKET")
    if address:
        if address.startswith("@"): address = "\0" + address[1:]
        with socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM) as sock:
            sock.connect(address)
            sock.sendall(b"READY=1")


def real_path(path):
    path = Path(path)
    if not path.is_absolute() or ".." in path.parts or path == Path("/"):
        raise Refused("unsafe configuration path")
    for parent in [path, *path.parents]:
        if parent.is_symlink():
            raise Refused("preserved personal directory/file link; use a real owned path")
    return path


def device_ready(path):
    try:
        return stat.S_ISCHR(Path(path).stat().st_mode) and os.access(path, os.R_OK | os.W_OK)
    except OSError:
        return False


def resolve_gpu(manifest, sysfs_root):
    mode = manifest["mode"]
    if mode not in ("render", "vfio"):
        raise Refused("Windows is disabled in this boot mode")
    sysfs = Path(sysfs_root)
    gpu = sysfs / "bus/pci/devices" / manifest["bdf"]
    try:
        if gpu.joinpath("vendor").read_text().strip() != manifest["vendor"] or gpu.joinpath("device").read_text().strip() != manifest["device"]:
            raise Refused("GPU PCI identity mismatch")
        driver = gpu.joinpath("driver").resolve(strict=True).name
        if driver != ("nvidia" if mode == "render" else "vfio-pci"):
            raise Refused("GPU driver does not match boot mode; reboot to the appropriate mode")
        dev = Path(manifest.get("devRoot", "/dev"))
        hardware = {"mode": mode, "bdf": manifest["bdf"]}
        if mode == "render":
            nodes = list(gpu.joinpath("drm").glob("renderD*"))
            if len(nodes) != 1:
                raise Refused("GPU render node is unavailable or ambiguous")
            node = dev / "dri" / nodes[0].name
            if not device_ready(node):
                raise Refused("GPU render node is not accessible")
            hardware["render"] = str(node)
        else:
            group = gpu.joinpath("iommu_group").resolve(strict=True)
            if not group.name.isdigit() or group.parent.resolve() != (sysfs / "kernel/iommu_groups").resolve():
                raise Refused("invalid IOMMU group")
            members = sorted(p.name for p in group.joinpath("devices").iterdir())
            if members != [manifest["bdf"]]:
                raise Refused("IOMMU group includes devices other than the GPU; no unsafe override")
            resets = gpu.joinpath("reset_method").read_text().split()
            if not resets:
                raise Refused("GPU reset support cannot be established")
            if "bus" in resets:
                siblings = [p for p in gpu.resolve().parent.iterdir() if re.fullmatch(r"[0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}\.[0-7]", p.name)]
                if sorted(p.name for p in siblings) != [manifest["bdf"]]:
                    raise Refused("GPU bus reset would affect other PCI devices")
            for name in ("vfio", group.name):
                if not device_ready(dev / "vfio" / name):
                    raise Refused("VFIO group is not accessible to the rootless user")
            if not device_ready(dev / "kvmfr0"):
                raise Refused("Looking Glass /dev/kvmfr0 is unavailable to the rootless user; boot the VFIO profile")
            hardware["group"] = group.name
        return hardware
    except (OSError, ValueError):
        raise Refused("GPU identity/group/reset information is unavailable; do not live-rebind") from None


def config_digest(manifest, hardware):
    # Public generation incorporates static templates/options, not credential bytes.
    public = {key: manifest.get(key) for key in ("generation", "image", "mode", "storageRoot", "ram", "cpus", "disk", "vram", "username")}
    public["hardware"] = hardware
    return hashlib.sha256(json.dumps(public, sort_keys=True).encode()).hexdigest()


class Lifecycle:
    """Adapters provide owned(), preflight() and reconcile(), plus optional hooks."""

    def __init__(self, m):
        self.m = m
        self.stopping = False
        self.start_attempted = False

    def storage_path(self):
        return Path(self.m["storageRoot"]) / "storage"

    def container_mode(self, current):
        return (current["Config"]["Labels"] or {}).get(MODE)

    def pending(self, current):
        return (current["Config"]["Labels"] or {}).get(GENERATION) != self.m["generation"]

    def command(self, name, *args, allowed=(0,), env=None, cwd=None):
        try:
            result = subprocess.run([self.m["commands"][name], *args], env=env, cwd=cwd, capture_output=True, text=True)
        except OSError:
            raise Refused(name + " invocation unavailable; retaining conservative ownership") from None
        if result.returncode not in allowed:
            raise Refused(name + " operation failed (exit " + str(result.returncode) + "); no provisioning attempted")
        return result

    def inspect(self, name):
        exists = self.command("podman", "container", "exists", name, allowed=(0, 1))
        if exists.returncode == 1:
            return None
        # Never request/print the container environment or logs.
        template = '{"Id":{{json .Id}},"State":{{json .State}},"Config":{"Labels":{{json .Config.Labels}}},"Mounts":{{json .Mounts}}}'
        try:
            value = json.loads(self.command("podman", "inspect", "--format", template, name).stdout)
            if (not isinstance(value, dict) or not isinstance(value.get("Id"), str) or not value["Id"]
                or not isinstance(value.get("State"), dict)
                or type(value["State"].get("Running")) is not bool
                or type(value["State"].get("ExitCode", 0)) is not int
                or not isinstance(value.get("Config"), dict)
                or (value["Config"].get("Labels") is not None and not isinstance(value["Config"]["Labels"], dict))
                or not isinstance(value.get("Mounts"), list)
                or not all(isinstance(row, dict)
                    and isinstance(row.get("Destination"), str) and row["Destination"].startswith("/")
                    and isinstance(row.get("Source"), str)
                    and (row["Source"].startswith("/") or (row.get("Type") == "tmpfs" and row["Source"] == ""))
                    for row in value["Mounts"])):
                raise ValueError()
        except (ValueError, AttributeError, TypeError):
            raise Refused("cannot determine container state; refusing to guess") from None
        return value

    def check_other_guests(self, current=None):
        own_id = current.get("Id") if current else None
        for name in self.command("podman", "ps", "--all", "--format", "{{.ID}}").stdout.splitlines():
            other = self.inspect(name)
            if other and other.get("Id") != own_id and other["State"]["Running"]:
                wanted = self.storage_path().resolve()
                if any(v["Source"] and (lambda source: source == wanted or source in wanted.parents or wanted in source.parents)(Path(v["Source"]).resolve()) for v in other["Mounts"]):
                    raise Refused("another running container owns the Windows disk")

    def confirm_started(self):
        current = self.inspect(self.m["container"])
        if current is None:
            raise Refused("Windows start returned without an owned container")
        self.owned(current)
        if not current["State"]["Running"] or self.container_mode(current) != self.m["mode"]:
            raise Refused("Windows did not remain running in the requested GPU mode")
        return {"running": True, "pending": False}

    def started(self):
        result = self.status()
        if not result["running"] or result["mode"] != self.m["mode"]:
            raise Refused("Windows is not running in the requested mode; inspect the user service")
        return result

    def status(self):
        current = self.inspect(self.m["container"])
        if not current: return {"running": False, "mode": self.m["mode"], "pending": False}
        self.owned(current)
        return {"running": current["State"]["Running"], "mode": self.container_mode(current), "pending": self.pending(current)}

    @contextmanager
    def lifetime_lock(self):
        directory = real_path(self.m["runtimeDir"])
        directory.mkdir(mode=0o700, parents=True, exist_ok=True)
        if directory.stat().st_uid != os.getuid() or stat.S_IMODE(directory.stat().st_mode) != 0o700:
            raise Refused("runtime directory must be private and user-owned")
        lock_path = real_path(directory / "supervisor.lock")
        with lock_path.open("a") as lock:
            try: fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError: raise Refused("another Windows VM supervisor owns the disk; stop its service first") from None
            yield

    def stop(self):
        # Called after systemctl stop, including recovery from a crashed owner.
        # Serialize with supervisor starts; never claim that inactive means stopped.
        with self.lifetime_lock():
            current = self.inspect(self.m["container"])
            if current:
                self.owned(current)
                if current["State"]["Running"]:
                    self.command("podman", "stop", "--time=-1", self.m["container"])
                after = self.inspect(self.m["container"])
                if after:
                    self.owned(after)
                    if after["State"]["Running"]:
                        raise Refused("Windows remains running; ownership retained during graceful stop")

    def supervise(self):
        with self.lifetime_lock():
            old_term = signal.signal(signal.SIGTERM, lambda *_: setattr(self, "stopping", True))
            old_int = signal.signal(signal.SIGINT, lambda *_: setattr(self, "stopping", True))
            stopper = None
            retry_at = 0.0
            stop_backoff = 0.5
            stop_started = None
            warned = False
            try:
                try:
                    result = self.reconcile()
                except Refused:
                    # Compose can fail after starting QEMU. Never leave a live
                    # guest unmonitored merely because the tool returned failure.
                    try:
                        current = self.inspect(self.m["container"])
                    except Refused:
                        if not self.start_attempted:
                            raise
                    else:
                        if current is None or not current["State"]["Running"]:
                            raise Refused("Windows start failed; no active guest was established")
                        try:
                            self.owned(current)
                        except Refused:
                            if not self.start_attempted:
                                raise
                            # Ownership may change between a successful engine
                            # start and its confirmation. Never stop the stranger,
                            # but retain our lifetime lock while state is uncertain.
                    print("Reconciliation failed; retaining lifetime ownership until guest exit", file=sys.stderr, flush=True)
                    result = {"running": None, "pending": True, "blocked": True}
                print(json.dumps(result), flush=True)
                if not result.get("blocked"):
                    try: notify_ready()
                    except OSError:
                        print("Readiness notification unavailable; retaining lifetime ownership", file=sys.stderr, flush=True)
                while True:
                    # On query failure keep the lock: a missing monitor is not a stopped VM.
                    owned_now = False
                    current = None
                    try:
                        current = self.inspect(self.m["container"])
                        if current is None: break
                        self.owned(current)
                        if not current["State"]["Running"]:
                            if current["State"].get("ExitCode", 0) != 0:
                                raise Refused("Windows guest exited unsuccessfully")
                            break
                        owned_now = True
                    except Refused:
                        if current is not None and isinstance(current, dict) and current.get("State", {}).get("Running") is False:
                            raise
                        print("Windows state query failed; retaining supervisor lock", file=sys.stderr, flush=True)
                    now = time.monotonic()
                    if stopper is not None and stopper.poll() is not None:
                        code = stopper.wait()
                        stopper = None
                        retry_at = now + stop_backoff
                        stop_backoff = min(stop_backoff * 2, 15.0)
                        print("Windows stop request ended (exit " + str(code) + "); retry if guest is still running", file=sys.stderr, flush=True)
                    if self.stopping and owned_now and stopper is None and now >= retry_at:
                        if stop_started is None: stop_started = now
                        try:
                            stopper = subprocess.Popen([self.m["commands"]["podman"], "stop", "--time=-1", self.m["container"]], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                        except OSError:
                            retry_at = now + stop_backoff
                            stop_backoff = min(stop_backoff * 2, 15.0)
                            print("Windows stop invocation failed; retry pending", file=sys.stderr, flush=True)
                    if stop_started is not None and not warned and now - stop_started >= 120:
                        print("Windows graceful stop exceeds two minutes; still waiting, no forced kill", file=sys.stderr, flush=True)
                        warned = True
                    time.sleep(0.25)
            finally:
                signal.signal(signal.SIGTERM, old_term)
                signal.signal(signal.SIGINT, old_int)
                if stopper is not None and stopper.poll() is not None: stopper.wait()


def main(Controller, argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True)
    parser.add_argument("action", choices=["preflight", "supervise", "stop", "status", "started"])
    args = parser.parse_args(argv)
    try:
        controller = Controller(json.loads(Path(args.manifest).read_text()))
        result = getattr(controller, args.action)()
        if result is not None: print(json.dumps(result))
        return 0
    except (Refused, OSError, ValueError, KeyError):
        error = sys.exc_info()[1]
        print("Windows VM: " + (str(error) if isinstance(error, Refused) else "prerequisite or engine metadata unavailable; no unsafe fallback"), file=sys.stderr)
        return 1
