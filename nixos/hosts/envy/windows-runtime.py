"""Envy-only Windows adapter. No root privileges, implicit pulls or live GPU rebinding."""
import json
import os
from pathlib import Path
import re
import stat
import sys
import tempfile

# Packaged runtimes have the shared core beside this adapter; source runs do not.
if not Path(__file__).with_name("windows_runtime.py").is_file():
    sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "containers/windows"))

from windows_runtime import (
    DIGEST, GENERATION, MODE, OWNER, Lifecycle, Refused, config_digest,
    device_ready, main as runtime_main, notify_ready, real_path, resolve_gpu,
)


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


class Controller(Lifecycle):
    def __init__(self, manifest):
        super().__init__(manifest)
        if manifest.get("container") != "envy-windows" or not re.fullmatch(r"docker\.io/dockurr/windows@sha256:[0-9a-f]{64}", manifest.get("image", "")):
            raise Refused("invalid Envy container/image declaration")
        if not re.fullmatch(r"localhost/envy-windows-spice:[0-9a-f]{64}", manifest.get("vfioImage", "")):
            raise Refused("invalid Envy Looking Glass image declaration")
        if manifest.get("bdf") != "0000:02:00.0" or manifest.get("vendor") != "0x10de" or manifest.get("device") != "0x1d13":
            raise Refused("unsupported Envy PCI identity")

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
        image = self.m["vfioImage"] if self.m["mode"] == "vfio" else self.m["image"]
        if self.command("podman", "image", "exists", image, allowed=(0, 1)).returncode:
            raise Refused("Windows image is not local; provision the pinned base and run envy-windows prepare-image for VFIO (no automatic pull/build)")
        return hardware

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
            dev = Path(self.m.get("devRoot", "/dev"))
            root = dev / "vfio"
            devices += [str(root / "vfio") + ":/dev/vfio/vfio", str(root / hardware["group"]) + ":/dev/vfio/" + hardware["group"], str(dev / "kvmfr0") + ":/dev/kvmfr0"]
        labels = {OWNER: "envy", MODE: self.m["mode"], GENERATION: self.m["generation"], DIGEST: config_digest(self.m, hardware)}
        service = {"environment": environment, "labels": labels, "devices": devices,
                   "volumes": [str(Path(self.m["storageRoot"]) / name) + ":/" + ("storage" if name == "storage" else name) for name in ("storage", "shared", "oem")]}
        if hardware["mode"] == "vfio":
            service["image"] = self.m["vfioImage"]
            service["volumes"].append(self.m["inputIso"] + ":/drivers.iso:ro")
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


def main(argv=None):
    return runtime_main(Controller, argv)


if __name__ == "__main__":
    raise SystemExit(main())
