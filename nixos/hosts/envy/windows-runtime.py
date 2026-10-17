"""Envy-only Windows lifecycle. No root privileges, implicit pulls or live GPU rebinding."""
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
import tempfile
import time

OWNER = "org.orgm.windows.owner"
MODE = "org.orgm.windows.mode"
GENERATION = "org.orgm.windows.generation"
DIGEST = "org.orgm.windows.config"


def notify_ready():
    address = os.environ.get("NOTIFY_SOCKET")
    if address:
        if address.startswith("@"): address = "\0" + address[1:]
        with socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM) as sock:
            sock.connect(address)
            sock.sendall(b"READY=1")


class Refused(Exception):
    """An actionable refusal whose text must never contain credentials/tool output."""


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
            raise Refused("MX250 PCI identity mismatch")
        driver = gpu.joinpath("driver").resolve(strict=True).name
        if driver != ("nvidia" if mode == "render" else "vfio-pci"):
            raise Refused("GPU driver does not match boot mode; reboot to the appropriate mode")
        dev = Path(manifest.get("devRoot", "/dev"))
        hardware = {"mode": mode, "bdf": manifest["bdf"]}
        if mode == "render":
            nodes = list(gpu.joinpath("drm").glob("renderD*"))
            if len(nodes) != 1:
                raise Refused("MX250 render node is unavailable or ambiguous")
            node = dev / "dri" / nodes[0].name
            if not device_ready(node):
                raise Refused("MX250 render node is not accessible")
            hardware["render"] = str(node)
        else:
            group = gpu.joinpath("iommu_group").resolve(strict=True)
            if not group.name.isdigit() or group.parent.resolve() != (sysfs / "kernel/iommu_groups").resolve():
                raise Refused("invalid IOMMU group")
            members = sorted(p.name for p in group.joinpath("devices").iterdir())
            if members != [manifest["bdf"]]:
                raise Refused("IOMMU group includes devices other than the MX250; no unsafe override")
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
            hardware["group"] = group.name
        return hardware
    except (OSError, ValueError):
        raise Refused("GPU identity/group/reset information is unavailable; do not live-rebind") from None


def validate_storage(manifest, mounts):
    root = real_path(manifest["storageRoot"])
    expected = next((m for m in mounts if m.get("target") == str(root)), None)
    if not expected or (expected.get("fstype"), expected.get("fsroot"), expected.get("label")) != ("btrfs", "/@windows", "ENVY_ROOT"):
        raise Refused("Windows storage is not the mounted ENVY_ROOT/@windows subvolume")
    for name in ("storage", "shared", "oem"):
        target = real_path(root / name)
        if not target.is_dir() or not os.access(target, os.W_OK):
            raise Refused("Windows storage is not prepared/writable; run the declared storage prerequisite")
    if any(p.is_symlink() for p in root.joinpath("storage").rglob("*")):
        raise Refused("preserved guest storage link; no writes through external images")


def config_digest(manifest, hardware):
    # Public generation incorporates static templates/options, not credential bytes.
    public = {key: manifest.get(key) for key in ("generation", "image", "mode", "storageRoot", "ram", "cpus", "disk", "vram", "username")}
    public["hardware"] = hardware
    return hashlib.sha256(json.dumps(public, sort_keys=True).encode()).hexdigest()


class Controller:
    def __init__(self, manifest):
        self.m = manifest
        self.stopping = False
        self.start_attempted = False
        if manifest.get("container") != "envy-windows" or not re.fullmatch(r"docker\.io/dockurr/windows@sha256:[0-9a-f]{64}", manifest.get("image", "")):
            raise Refused("invalid Envy container/image declaration")
        if manifest.get("bdf") != "0000:02:00.0" or manifest.get("vendor") != "0x10de" or manifest.get("device") != "0x1d13":
            raise Refused("unsupported Envy PCI identity")

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
                or type(value.get("State", {}).get("Running")) is not bool
                or type(value["State"].get("ExitCode", 0)) is not int
                or not isinstance(value.get("Config"), dict)
                or not isinstance(value["Config"].get("Labels") or {}, dict)
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

    def owned(self, container):
        if (container.get("Config", {}).get("Labels") or {}).get(OWNER) != "envy":
            raise Refused("container name is owned by another runtime; nothing replaced")
        source = Path(self.m["storageRoot"]) / "storage"
        if not any(row.get("Destination") == "/storage" and Path(row.get("Source", "/")).resolve() == source.resolve() for row in container.get("Mounts", [])):
            raise Refused("container has an unexpected Windows disk; nothing replaced")

    def private_password(self):
        path = real_path(self.m["passwordFile"])
        try:
            info = path.stat()
            if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) & 0o077:
                raise Refused("Windows password must be a private user-owned file (0600 or 0400)")
            value = path.read_text().removesuffix("\n")
            if not value or "\n" in value or "\r" in value or "\0" in value:
                raise Refused("Windows password must be a nonempty single line")
            return value
        except OSError:
            raise Refused("private Windows password missing; provision it before starting the VM") from None

    def preflight(self):
        hardware = resolve_gpu(self.m, self.m.get("sysfsRoot", "/sys"))
        for relative in ("kvm", "net/tun"):
            if not device_ready(Path(self.m.get("devRoot", "/dev")) / relative):
                raise Refused("KVM/tun unavailable to the rootless user")
        mounts = json.loads(self.command("findmnt", "--json", "--target", self.m["storageRoot"], "--output", "TARGET,FSTYPE,FSROOT,LABEL").stdout)["filesystems"]
        validate_storage(self.m, mounts)
        attrs = self.command("lsattr", "-d", "--", str(Path(self.m["storageRoot"]) / "storage")).stdout.split()
        if not attrs or "C" not in attrs[0]:
            raise Refused("Windows storage is not NoCoW; no guest image will be created")
        for path in Path(self.m["storageRoot"]).joinpath("storage").rglob("*"):
            if path.is_file() and path.suffix.lower() in (".img", ".raw", ".qcow", ".qcow2", ".vhd", ".vhdx", ".vmdk", ".vdi"):
                image_attrs = self.command("lsattr", "-d", "--", str(path)).stdout.split()
                if not image_attrs or "C" not in image_attrs[0]:
                    raise Refused("existing guest image is not NoCoW; manual migration required, nothing converted")
        if self.m["mode"] == "render":
            kernel = Path(self.m.get("kernelFile", "/proc/sys/kernel/osrelease")).read_text().strip()
            version = re.match(r"(\d+)\.(\d+)", kernel)
            if not version or tuple(map(int, version.groups())) < (6, 16):
                raise Refused("NVIDIA Windows render requires host blobs/guest PAT; boot the reviewed kernel6.18 candidate")
            if "ss" not in Path(self.m.get("cpuinfo", "/proc/cpuinfo")).read_text().split():
                raise Refused("CPU self-snoop prerequisite for guest PAT is unavailable")
            sysfs = Path(self.m.get("sysfsRoot", "/sys"))
            if not sysfs.joinpath("module/nvidia/version").read_text().startswith("580.") or sysfs.joinpath("module/nvidia_drm/parameters/modeset").read_text().strip().lower() not in ("y", "1"):
                raise Refused("NVIDIA580 proprietary KMS prerequisite is not met")
            cdi = json.loads(Path(self.m["cdiFile"]).read_text())
            if cdi.get("kind") != "nvidia.com/gpu" or not any(d.get("name") == "all" for d in cdi.get("devices", [])):
                raise Refused("matching NVIDIA CDI runtime is not available")
            nvidia = [p for p in sysfs.joinpath("bus/pci/devices").iterdir() if p.joinpath("vendor").read_text().strip() == "0x10de"]
            if [p.name for p in nvidia] != [self.m["bdf"]]:
                raise Refused("CDI all would include an unexpected NVIDIA device")
        self.private_password()
        if self.command("podman", "image", "exists", self.m["image"], allowed=(0, 1)).returncode:
            raise Refused("pinned Windows image is not local; explicit provisioning required (no automatic pull)")
        return hardware

    def check_other_guests(self, current=None):
        own_id = current.get("Id") if current else None
        for name in self.command("podman", "ps", "--all", "--format", "{{.ID}}").stdout.splitlines():
            other = self.inspect(name)
            if other and other.get("Id") != own_id and other["State"]["Running"]:
                wanted = (Path(self.m["storageRoot"]) / "storage").resolve()
                if any(v["Source"] and (lambda source: source == wanted or source in wanted.parents or wanted in source.parents)(Path(v["Source"]).resolve()) for v in other["Mounts"]):
                    raise Refused("another running container owns the Windows disk")

    def write_overlay(self, hardware):
        directory = real_path(self.m["runtimeDir"])
        directory.mkdir(mode=0o700, parents=True, exist_ok=True)
        if directory.stat().st_uid != os.getuid() or stat.S_IMODE(directory.stat().st_mode) != 0o700:
            raise Refused("runtime directory must be private and user-owned")
        target = real_path(directory / "hardware.json")
        devices = []
        environment = {"RAM_SIZE": self.m.get("ram", "4G"), "CPU_CORES": str(self.m.get("cpus", 4)), "DISK_SIZE": self.m.get("disk", "96G"), "USERNAME": self.m.get("username", "osmarg")}
        if hardware["mode"] == "render":
            environment.update(RENDERNODE="/dev/dri/" + Path(hardware["render"]).name, VRAM_SIZE=self.m.get("vram", "1G"))
            devices.append(hardware["render"] + ":/dev/dri/" + Path(hardware["render"]).name)
        else:
            root = Path(self.m.get("devRoot", "/dev")) / "vfio"
            devices += [str(root / "vfio") + ":/dev/vfio/vfio", str(root / hardware["group"]) + ":/dev/vfio/" + hardware["group"]]
        labels = {OWNER: "envy", MODE: self.m["mode"], GENERATION: self.m["generation"], DIGEST: config_digest(self.m, hardware)}
        service = {"environment": environment, "labels": labels, "devices": devices,
                   "volumes": [str(Path(self.m["storageRoot"]) / name) + ":/" + ("storage" if name == "storage" else name) for name in ("storage", "shared", "oem")]}
        fd, tmp = tempfile.mkstemp(dir=directory, prefix="hardware-")
        try:
            with os.fdopen(fd, "w") as out:
                json.dump({"services": {"windows": service}}, out)
            os.replace(tmp, target)
        finally:
            if os.path.exists(tmp): os.unlink(tmp)
        return target

    def reconcile(self):
        if self.m["mode"] not in ("render", "vfio"):
            raise Refused("Windows is disabled in gaming mode")
        real_path(self.m["runtimeDir"])
        real_path(self.m["storageRoot"])
        current = self.inspect(self.m["container"])
        if current:
            self.owned(current)
        self.check_other_guests(current)
        if current:
            if current["State"]["Running"]:
                labels = current["Config"]["Labels"]
                if labels.get(MODE) != self.m["mode"]:
                    raise Refused("active guest has another GPU mode; stop cleanly and reboot")
                return {"running": True, "pending": labels.get(GENERATION) != self.m["generation"]}
        hardware = self.preflight()
        overlay = self.write_overlay(hardware)
        if current:
            if current["Config"]["Labels"].get(DIGEST) == config_digest(self.m, hardware):
                self.start_attempted = True
                self.command("podman", "start", self.m["container"])
                return self.confirm_started()
            self.command("podman", "rm", self.m["container"])  # No force/volume deletion, safe if an external start races.
        env = dict(os.environ, WINDOWS_PASSWORD=self.private_password())
        files = [part for source in self.m["compose"] + [str(overlay)] for part in ("-f", source)]
        self.start_attempted = True
        self.command("compose", "--podman-path", self.m["commands"]["podman"], "--env-file", "/dev/null", "-p", "envy-windows", *files, "up", "-d", "--no-build", "windows", env=env, cwd=str(overlay.parent))
        return self.confirm_started()

    def confirm_started(self):
        current = self.inspect(self.m["container"])
        if current is None:
            raise Refused("Windows start returned without an owned container")
        self.owned(current)
        if not current["State"]["Running"] or current["Config"]["Labels"].get(MODE) != self.m["mode"]:
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
        labels = current["Config"]["Labels"]
        return {"running": current["State"]["Running"], "mode": labels.get(MODE), "pending": labels.get(GENERATION) != self.m["generation"]}

    @contextmanager
    def lifetime_lock(self):
        directory = real_path(self.m["runtimeDir"])
        directory.mkdir(mode=0o700, parents=True, exist_ok=True)
        if directory.stat().st_uid != os.getuid() or stat.S_IMODE(directory.stat().st_mode) != 0o700:
            raise Refused("runtime directory must be private and user-owned")
        lock_path = real_path(directory / "supervisor.lock")
        with lock_path.open("a") as lock:
            try: fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError: raise Refused("another Envy Windows supervisor owns the disk; stop its service first") from None
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


def main(argv=None):
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
        print("Envy Windows: " + (str(error) if isinstance(error, Refused) else "prerequisite or engine metadata unavailable; no unsafe fallback"), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
