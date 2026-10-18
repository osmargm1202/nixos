#!/usr/bin/env python3
"""Lenovo lifecycle fixtures: no VM, hardware changes, builds or real engine."""
import copy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "nixos/hosts/lenovo/windows-runtime.py"
spec = importlib.util.spec_from_file_location("lenovo_windows", SCRIPT)
MOD = importlib.util.module_from_spec(spec)
spec.loader.exec_module(MOD)

ENGINE = r'''#!/usr/bin/env python3
import json,os,sys,time
from pathlib import Path
p=Path(os.environ['FAKE_ENGINE_STATE']);s=json.loads(p.read_text());a=sys.argv[1:]
with open(os.environ['FAKE_ENGINE_LOG'],'a') as f:f.write(json.dumps(a)+'\n')
if s.get('error') or a[0] in s.get('fail_commands',[]):
 print('tool-output-private-sentinel');sys.exit(125)
def save():p.write_text(json.dumps(s))
if '--podman-path' in a:
 if s.get('fail_before_create'):sys.exit(125)
 files=[a[i+1] for i,x in enumerate(a) if x=='-f'];h=json.loads(Path(files[-1]).read_text())['services']['windows']
 name=h['container_name']
 s['compose_env']={k:os.environ.get(k) for k in ['WINDOWS_IMAGE','WINDOWS_CONTAINER_NAME','WINDOWS_STORAGE_DIR','WINDOWS_SHARED_DIR','WINDOWS_OEM_DIR']}
 s['containers'][name]={'Id':name,'State':{'Running':True,'ExitCode':0},'Config':{'Labels':h['labels']},'Mounts':[{'Source':s['storage'],'Destination':'/storage'}]}
 save();sys.exit(125 if s.get('fail_after_create') else 0)
if a[:2]==['container','exists']:sys.exit(0 if a[-1] in s['containers'] else 1)
if a[:2]==['image','exists']:sys.exit(0 if s.get('image',True) else 1)
if a[0]=='inspect':
 if s.get('malformed_inspect'):print('not-json-private-sentinel');sys.exit(0)
 if a[-1] not in s['containers']:sys.exit(125)
 if a[2]=='{{json .HostConfig.Devices}}':print(json.dumps(s.get('devices')))
 else:print(json.dumps(s['containers'][a[-1]]))
 sys.exit(0)
if a[0]=='ps':print('\n'.join(s['containers']));sys.exit(0)
if a[0]=='start':s['containers'][a[-1]]['State']['Running']=True;save();sys.exit(0)
if a[0]=='stop':
 if s.get('stop_fails'):sys.exit(125)
 s['containers'][a[-1]]['State']['Running']=False;save();sys.exit(0)
sys.exit(125)
'''


class Runtime(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        self.sys = self.root / "sys"
        self.dev = self.root / "dev"
        self.storage = self.root / "windows"
        for name in ("storage", "shared", "oem"):
            (self.storage / name).mkdir(parents=True)
        self.disk = self.storage / "storage/data.img"
        self.disk.write_text("persistent Windows disk")
        self.envfile = self.root / ".env"
        self.password = 'fixture-$HOME-$(false)-#-"-secret'
        self.write_config()
        self.engine = self.root / "podman"
        self.engine.write_text(ENGINE)
        self.engine.chmod(0o755)
        self.state = self.root / "engine.json"
        self.log = self.root / "engine.log"
        self.state.write_text(json.dumps({"containers": {}, "image": True, "storage": str(self.storage / "storage")}))
        self.env = dict(os.environ, HOME=str(self.root), FAKE_ENGINE_STATE=str(self.state), FAKE_ENGINE_LOG=str(self.log))
        self.patch = patch.dict(os.environ, self.env)
        self.patch.start()
        self.addCleanup(self.patch.stop)
        self.gpu = self.pci("0000:01:00.0", "0x10de", "0x1fbb", "vfio-pci")
        self.intel = self.pci("0000:00:02.0", "0x8086", "0x9a49", "i915")
        (self.intel / "drm/renderD173").mkdir(parents=True)
        for name in ("kvm", "net/tun", "dri/renderD173", "vfio/vfio", "vfio/71", "kvmfr0"):
            path = self.dev / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.symlink_to("/dev/null")
        group = self.sys / "kernel/iommu_groups/71"
        (group / "devices").mkdir(parents=True)
        (group / "devices/0000:01:00.0").symlink_to(self.gpu)
        (self.gpu / "iommu_group").symlink_to(group)
        (self.gpu / "reset_method").write_text("bus")
        iso = self.root / "virtio-input.iso"
        iso.write_text("fixture ISO")
        self.m = {"host": "lenovo", "mode": "render", "container": "windows", "bdf": "0000:01:00.0",
                  "vendor": "0x10de", "device": "0x1fbb", "renderBdf": "0000:00:02.0",
                  "runtimeDir": str(self.root / "runtime"), "envFile": str(self.envfile), "inputIso": str(iso),
                  "image": "localhost/lenovo-windows-spice:" + "a" * 64, "generation": "one",
                  "compose": [str(self.root / "base.yml"), str(self.root / "mode.yml")],
                  "commands": {"podman": str(self.engine), "compose": str(self.engine)},
                  "sysfsRoot": str(self.sys), "devRoot": str(self.dev)}
        self.c = MOD.Controller(self.m)

    def write_config(self, password=True):
        text = "# private fixture\n" + "\n".join("WINDOWS_" + n.upper() + "_DIR='" + str(self.storage / n) + "' # literal path" for n in ("storage", "shared", "oem"))
        if password:
            text += "\nWINDOWS_PASSWORD='" + self.password + "'\n"
        self.envfile.write_text(text)
        self.envfile.chmod(0o600)

    def set_config(self, **values):
        lines = [line for line in self.envfile.read_text().splitlines()
                 if line.split("=", 1)[0] not in values]
        lines += [key + "='" + value + "'" for key, value in values.items()]
        self.envfile.write_text("\n".join(lines) + "\n")
        self.reload()

    def pci(self, bdf, vendor, device, driver):
        gpu = self.sys / "devices" / bdf / bdf
        gpu.mkdir(parents=True)
        pci = self.sys / "bus/pci/devices"
        pci.mkdir(parents=True, exist_ok=True)
        (pci / bdf).symlink_to(gpu)
        (gpu / "vendor").write_text(vendor)
        (gpu / "device").write_text(device)
        target = self.sys / "bus/pci/drivers" / driver
        target.mkdir(parents=True, exist_ok=True)
        (gpu / "driver").symlink_to(target)
        return gpu

    def vfio(self):
        self.m.update(mode="vfio", container="lenovo-windows")
        self.c = MOD.Controller(self.m)

    def reload(self):
        self.c = MOD.Controller(self.m)

    def data(self):
        return json.loads(self.state.read_text())

    def update(self, **values):
        state = self.data()
        state.update(values)
        self.state.write_text(json.dumps(state))

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    def seed(self, running=True, legacy=False, owner="lenovo", mode=None, generation="old"):
        labels = {} if legacy else {MOD.OWNER: owner, MOD.MODE: mode or self.m["mode"], MOD.GENERATION: generation}
        self.update(containers={self.m["container"]: {"Id": "a" * 64, "State": {"Running": running, "ExitCode": 0},
                    "Config": {"Labels": labels}, "Mounts": [{"Source": str(self.storage / "storage"), "Destination": "/storage"}]}})

    def devices(self, group="71"):
        return [{"PathOnHost": str(self.dev / source), "PathInContainer": target, "CgroupPermissions": "rwm"}
                for source, target in (("vfio/vfio", "/dev/vfio/vfio"), ("vfio/" + group, "/dev/vfio/" + group), ("kvmfr0", "/dev/kvmfr0"))]

    def overlay(self):
        return json.loads((Path(self.m["runtimeDir"]) / "hardware.json").read_text())["services"]["windows"]

    def no_destructive_calls(self):
        self.assertFalse(any(a[0] in ("rm", "build", "pull", "kill", "restart") for a in self.calls()))
        self.assertEqual(self.disk.read_text(), "persistent Windows disk")

    def test_render_uses_unique_intel_bdf_not_nvidia_or_index(self):
        h = self.c.preflight()
        self.assertEqual(h, {"mode": "render", "bdf": "0000:00:02.0", "render": str(self.dev / "dri/renderD173")})

    def test_render_wrong_identity_driver_and_ambiguous_node(self):
        for filename, bad in (("vendor", "0x10de"),):
            path = self.intel / filename
            old = path.read_text()
            path.write_text(bad)
            with self.assertRaises(MOD.Refused): self.c.preflight()
            path.write_text(old)
        (self.intel / "driver").unlink()
        (self.intel / "driver").symlink_to(self.sys / "bus/pci/drivers/vfio-pci")
        with self.assertRaises(MOD.Refused): self.c.preflight()
        (self.intel / "driver").unlink()
        (self.intel / "driver").symlink_to(self.sys / "bus/pci/drivers/i915")
        (self.intel / "drm/renderD128").mkdir()
        with self.assertRaises(MOD.Refused): self.c.preflight()

    def test_inaccessible_render_node(self):
        (self.dev / "dri/renderD173").unlink()
        with self.assertRaises(MOD.Refused): self.c.preflight()

    def test_vfio_resolves_dynamic_group(self):
        self.vfio()
        old = self.sys / "kernel/iommu_groups/71"
        old.rename(old.with_name("93"))
        (self.gpu / "iommu_group").unlink()
        (self.gpu / "iommu_group").symlink_to(old.with_name("93"))
        (self.dev / "vfio/71").rename(self.dev / "vfio/93")
        self.c.reconcile()
        self.assertIn(str(self.dev / "vfio/93") + ":/dev/vfio/93", self.overlay()["devices"])
        self.assertFalse(any("/vfio/71" in d for d in self.overlay()["devices"]))

    def test_vfio_identity_and_driver_mismatch(self):
        self.vfio()
        (self.gpu / "device").write_text("0x1d13")
        with self.assertRaises(MOD.Refused): self.c.preflight()
        (self.gpu / "device").write_text("0x1fbb")
        (self.gpu / "driver").unlink()
        (self.gpu / "driver").symlink_to(self.sys / "bus/pci/drivers/i915")
        with self.assertRaises(MOD.Refused): self.c.preflight()

    def test_vfio_group_neighbors_reset_and_bus_siblings(self):
        self.vfio()
        group = self.sys / "kernel/iommu_groups/71/devices"
        (group / "0000:01:00.1").symlink_to(self.gpu)
        with self.assertRaises(MOD.Refused): self.c.preflight()
        (group / "0000:01:00.1").unlink()
        (self.gpu / "reset_method").write_text("")
        with self.assertRaises(MOD.Refused): self.c.preflight()
        (self.gpu / "reset_method").write_text("bus")
        (self.gpu.parent / "0000:01:01.0").mkdir()
        with self.assertRaises(MOD.Refused): self.c.preflight()

    def test_kvm_tun_and_kvmfr_must_be_accessible_devices(self):
        self.vfio()
        for name in ("kvm", "net/tun", "vfio/71", "vfio/vfio", "kvmfr0"):
            with self.subTest(name=name):
                path = self.dev / name
                path.unlink()
                path.write_text("not a character device")
                with self.assertRaises(MOD.Refused): self.c.preflight()
                path.unlink()
                path.symlink_to("/dev/null")

    def test_render_creation_pins_image_container_paths_and_no_build_pull(self):
        with patch.dict(os.environ, {"WINDOWS_STORAGE_DIR": "/wrong", "WINDOWS_IMAGE": "public:latest", "WINDOWS_PASSWORD": "wrong"}):
            self.c.reconcile()
        service = self.overlay()
        self.assertEqual(service["image"], self.m["image"])
        self.assertEqual(service["container_name"], "windows")
        self.assertEqual(service["pull_policy"], "never")
        self.assertIn(str(self.storage / "storage") + ":/storage", service["volumes"])
        self.assertEqual(service["environment"]["RENDERNODE"], "/dev/dri/renderD173")
        self.assertFalse(any("kvmfr" in d or "vfio" in d for d in service["devices"]))
        self.assertFalse(any("drivers.iso" in v for v in service["volumes"]))
        self.assertEqual(self.data()["compose_env"]["WINDOWS_IMAGE"], self.m["image"])
        self.assertEqual(self.data()["compose_env"]["WINDOWS_STORAGE_DIR"], str(self.storage / "storage"))
        self.assertEqual(service["labels"][MOD.OWNER], "lenovo")
        self.no_destructive_calls()

    def test_vfio_creation_maps_group_kvmfr_and_iso(self):
        self.vfio()
        self.c.reconcile()
        service = self.overlay()
        self.assertIn(str(self.dev / "vfio/71") + ":/dev/vfio/71", service["devices"])
        self.assertIn(str(self.dev / "kvmfr0") + ":/dev/kvmfr0", service["devices"])
        self.assertIn(self.m["inputIso"] + ":/drivers.iso:ro", service["volumes"])
        self.assertEqual(service["container_name"], "lenovo-windows")
        self.no_destructive_calls()

    def test_compose_exact_private_file_and_immutable_template_order(self):
        self.c.reconcile()
        call = next(a for a in self.calls() if "--podman-path" in a)
        self.assertEqual(call, ["--podman-path", str(self.engine), "--env-file", str(self.envfile), "-p", "windows-vm-lenovo",
                               "-f", self.m["compose"][0], "-f", self.m["compose"][1], "-f", str(Path(self.m["runtimeDir"]) / "hardware.json"),
                               "up", "-d", "--no-build", "--no-recreate", "windows"])

    def test_overlay_is_private_atomic_and_secret_free(self):
        self.c.reconcile()
        directory = Path(self.m["runtimeDir"])
        overlay = directory / "hardware.json"
        self.assertEqual(directory.stat().st_mode & 0o777, 0o700)
        self.assertEqual(overlay.stat().st_mode & 0o777, 0o600)
        self.assertEqual(list(directory.iterdir()), [overlay])
        self.assertNotIn(self.password, overlay.read_text() + self.log.read_text())

    def test_public_settings_digest_normalizes_compose_defaults_and_paths(self):
        defaults = {"WINDOWS_RAM_SIZE": "4G", "WINDOWS_CPU_CORES": "6", "WINDOWS_DISK_SIZE": "64G",
                    "WINDOWS_USERNAME": "osmarg", "WINDOWS_LANGUAGE": "English", "WINDOWS_REGION": "es-DO",
                    "WINDOWS_KEYBOARD": "es-US", "WINDOWS_WEB_PORT": "8006", "WINDOWS_RDP_PORT": "3389"}
        public = dict(defaults, **{key: str(self.storage / name)
                                  for key, name in zip(MOD.PATH_FIELDS, ("storage", "shared", "oem"))})
        expected = hashlib.sha256(json.dumps(public, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
        self.assertEqual(self.c.settings_digest(), expected)
        self.set_config(**defaults)
        self.assertEqual(self.c.settings_digest(), expected)
        self.set_config(**{key: "" for key in defaults})
        self.assertEqual(self.c.settings_digest(), expected)
        self.set_config(**{key: "${HOME}/windows/" + name + "/"
                           for key, name in zip(MOD.PATH_FIELDS, ("storage", "shared", "oem"))})
        self.assertEqual(self.c.settings_digest(), expected)
        for key in defaults:
            with self.subTest(key=key):
                self.set_config(**{key: "changed"})
                self.assertNotEqual(self.c.settings_digest(), expected)
                self.set_config(**{key: ""})

    def test_managed_settings_changes_are_pending_without_recreation(self):
        self.c.reconcile()
        before = copy.deepcopy(self.data()["containers"])
        overlay = (Path(self.m["runtimeDir"]) / "hardware.json").read_bytes()
        baseline = self.envfile.read_text()
        self.assertEqual(self.c.status(), {"running": True, "mode": "render", "pending": False})
        for name in ("shared-new", "oem-new"):
            (self.storage / name).mkdir()
        changes = {"WINDOWS_RAM_SIZE": "8G", "WINDOWS_CPU_CORES": "8",
                   "WINDOWS_SHARED_DIR": str(self.storage / "shared-new"),
                   "WINDOWS_OEM_DIR": str(self.storage / "oem-new")}
        for key, value in changes.items():
            with self.subTest(key=key):
                self.envfile.write_text(baseline)
                self.set_config(**{key: value})
                self.assertEqual(self.c.status(), {"running": True, "mode": "render", "pending": True})
                self.assertEqual(self.c.reconcile(), {"running": True, "pending": True})
                self.assertEqual(self.data()["containers"], before)
                stopped = copy.deepcopy(before)
                stopped["windows"]["State"]["Running"] = False
                self.update(containers=stopped)
                self.assertEqual(self.c.status(), {"running": False, "mode": "render", "pending": True})
                self.assertEqual(self.c.reconcile(), {"running": True, "pending": True})
                self.assertEqual(self.data()["containers"], before)
                self.assertEqual((Path(self.m["runtimeDir"]) / "hardware.json").read_bytes(), overlay)
        self.assertEqual(sum("--podman-path" in a for a in self.calls()), 1)
        self.assertEqual(sum(a[0] == "start" for a in self.calls()), len(changes))
        self.no_destructive_calls()

    def test_password_and_unknown_secret_changes_do_not_affect_public_labels(self):
        self.c.reconcile()
        before = copy.deepcopy(self.data()["containers"])
        labels = self.overlay()["labels"]
        self.assertRegex(labels[MOD.SETTINGS], r"^[0-9a-f]{64}$")
        original = self.c.settings_digest()
        self.set_config(WINDOWS_PASSWORD="changed-password-private-sentinel",
                        WINDOWS_UNKNOWN_SECRET="unknown-private-sentinel", API_TOKEN="token-private-sentinel")
        self.assertEqual(self.c.settings_digest(), original)
        self.assertFalse(self.c.status()["pending"])
        self.assertFalse(self.c.reconcile()["pending"])
        stopped = copy.deepcopy(before)
        stopped["windows"]["State"]["Running"] = False
        self.update(containers=stopped)
        self.assertFalse(self.c.reconcile()["pending"])
        self.assertEqual(self.data()["containers"], before)
        self.c.write_overlay(self.c.preflight())
        self.assertEqual(self.overlay()["labels"], labels)
        serialized = json.dumps(labels) + (Path(self.m["runtimeDir"]) / "hardware.json").read_text()
        for secret in (self.password, "changed-password-private-sentinel", "unknown-private-sentinel", "token-private-sentinel"):
            self.assertNotIn(secret, serialized)
        self.assertEqual(sum("--podman-path" in a for a in self.calls()), 1)
        self.no_destructive_calls()

    def test_managed_container_without_settings_label_is_pending(self):
        self.c.reconcile()
        containers = self.data()["containers"]
        del containers["windows"]["Config"]["Labels"][MOD.SETTINGS]
        self.update(containers=containers)
        self.assertTrue(self.c.status()["pending"])
        self.assertTrue(self.c.reconcile()["pending"])
        self.assertEqual(self.data()["containers"], containers)
        self.assertEqual(sum("--podman-path" in a for a in self.calls()), 1)
        self.no_destructive_calls()

    def test_active_legacy_adopted_without_password_or_hardware(self):
        self.seed(legacy=True)
        self.write_config(password=False)
        self.reload()
        (self.dev / "kvm").unlink()
        self.assertEqual(self.c.reconcile(), {"running": True, "pending": True})
        self.assertEqual(self.c.status(), {"running": True, "mode": "render", "pending": True})
        self.assertFalse(any(a[0] == "start" or "--podman-path" in a for a in self.calls()))
        self.no_destructive_calls()

    def test_active_legacy_vfio_adopts_without_device_reconfiguration(self):
        self.vfio()
        self.seed(legacy=True)
        self.write_config(password=False)
        self.reload()
        (self.dev / "vfio/71").unlink()
        self.assertTrue(self.c.reconcile()["pending"])
        self.assertFalse(any("{{json .HostConfig.Devices}}" in a or a[0] == "start" for a in self.calls()))
        self.c.stop()
        self.assertFalse(self.c.status()["running"])
        self.no_destructive_calls()

    def test_stopped_legacy_render_starts_existing_without_new_credentials_or_image(self):
        self.seed(running=False, legacy=True)
        before = copy.deepcopy(self.data()["containers"])
        self.write_config(password=False)
        self.reload()
        self.update(image=False)
        result = self.c.reconcile()
        self.assertTrue(result["pending"])
        self.assertIn(["start", "windows"], self.calls())
        self.assertEqual(self.data()["containers"]["windows"]["Id"], before["windows"]["Id"])
        self.assertFalse(any("--podman-path" in a or a[:2] == ["image", "exists"] for a in self.calls()))
        self.no_destructive_calls()

    def test_stopped_legacy_vfio_queries_devices_then_starts_without_compose(self):
        self.vfio()
        self.seed(running=False, legacy=True)
        self.update(devices=self.devices(), image=False)
        self.write_config(password=False)
        self.reload()
        self.assertTrue(self.c.reconcile()["pending"])
        self.assertIn(["inspect", "--format", "{{json .HostConfig.Devices}}", "lenovo-windows"], self.calls())
        self.assertIn(["start", "lenovo-windows"], self.calls())
        self.assertFalse(any("--podman-path" in a for a in self.calls()))
        self.no_destructive_calls()

    def test_stopped_vfio_stale_missing_extra_and_malformed_mappings_refused(self):
        self.vfio()
        self.seed(running=False)
        for devices in (None, {}, ["bad"], self.devices("32"), self.devices()[:-1], self.devices() + self.devices()[:1],
                        self.devices() + [{"PathOnHost": str(self.dev / "vfio"), "PathInContainer": "/dev/vfio"}],
                        self.devices() + [{"PathOnHost": str(self.dev / "vfio/32"), "PathInContainer": "/dev/vfio/32"}]):
            with self.subTest(devices=devices):
                self.update(devices=devices)
                with self.assertRaises(MOD.Refused): self.c.reconcile()
        self.assertFalse(any(a[0] == "start" or "--podman-path" in a for a in self.calls()))
        self.no_destructive_calls()

    def test_stopped_preflight_failure_preserves_container(self):
        self.seed(running=False)
        (self.dev / "kvm").unlink()
        before = self.data()["containers"]
        with self.assertRaises(MOD.Refused): self.c.reconcile()
        self.assertEqual(before, self.data()["containers"])
        self.no_destructive_calls()

    def test_inactive_other_runtime_is_never_removed(self):
        self.update(containers={"lenovo-windows": {"Id": "other", "State": {"Running": False}, "Config": {"Labels": {}},
                    "Mounts": [{"Source": str(self.storage / "storage"), "Destination": "/storage"}]}})
        self.c.reconcile()
        self.assertFalse(self.data()["containers"]["lenovo-windows"]["State"]["Running"])
        self.no_destructive_calls()

    def test_overlapping_running_guest_refused_parent_exact_and_child_mounts(self):
        for source in (self.storage, self.storage / "storage", self.disk):
            self.update(containers={"other": {"Id": "b" * 64, "State": {"Running": True}, "Config": {"Labels": {}},
                        "Mounts": [{"Source": str(source), "Destination": "/data"}]}})
            with self.assertRaises(MOD.Refused): self.c.reconcile()
        self.assertFalse(any("--podman-path" in a for a in self.calls()))
        self.no_destructive_calls()

    def test_real_ids_do_not_hide_other_owner_when_adopting(self):
        self.seed()
        containers = self.data()["containers"]
        containers["other"] = copy.deepcopy(containers["windows"])
        containers["other"]["Id"] = "b" * 64
        self.update(containers=containers)
        with self.assertRaises(MOD.Refused): self.c.reconcile()

    def test_foreign_owner_and_wrong_label_mode_refused_even_stopped(self):
        for running in (True, False):
            for owner, mode in (("envy", "render"), ("", "render"), ("lenovo", "vfio")):
                self.seed(running=running, owner=owner, mode=mode)
                with self.assertRaises(MOD.Refused): self.c.reconcile()
                with self.assertRaises(MOD.Refused): self.c.stop()
        self.no_destructive_calls()

    def test_owned_without_mode_is_not_legacy(self):
        self.seed()
        containers = self.data()["containers"]
        del containers["windows"]["Config"]["Labels"][MOD.MODE]
        self.update(containers=containers)
        with self.assertRaises(MOD.Refused): self.c.status()

    def test_null_labels_are_legacy_only_with_matching_disk(self):
        self.seed(legacy=True)
        containers = self.data()["containers"]
        containers["windows"]["Config"]["Labels"] = None
        self.update(containers=containers)
        self.assertTrue(self.c.status()["pending"])
        containers["windows"]["Mounts"][0]["Source"] = str(self.root / "wrong")
        self.update(containers=containers)
        with self.assertRaises(MOD.Refused): self.c.status()

    def test_duplicate_storage_mounts_refused(self):
        self.seed(legacy=True)
        containers = self.data()["containers"]
        containers["windows"]["Mounts"] *= 2
        self.update(containers=containers)
        with self.assertRaises(MOD.Refused): self.c.reconcile()

    def test_missing_image_never_pulls_or_builds(self):
        self.update(image=False)
        with self.assertRaises(MOD.Refused): self.c.reconcile()
        self.assertEqual(self.data()["containers"], {})
        self.no_destructive_calls()

    def test_missing_or_empty_password_refuses_creation(self):
        for password in (False, True):
            self.password = ""
            self.write_config(password=password)
            self.reload()
            with self.assertRaises(MOD.Refused): self.c.reconcile()
        self.assertEqual(self.data()["containers"], {})
        self.no_destructive_calls()

    def test_missing_disk_refuses_fresh_install_and_stopped_restart(self):
        self.disk.unlink()
        for stopped in (False, True):
            with self.subTest(stopped=stopped):
                if stopped:
                    self.seed(running=False)
                before = copy.deepcopy(self.data()["containers"])
                with self.assertRaisesRegex(MOD.Refused, "existing Windows disk"): self.c.reconcile()
                self.assertEqual(self.data()["containers"], before)
        self.assertFalse(any(a[0] == "start" or "--podman-path" in a for a in self.calls()))
        self.assertEqual(list((self.storage / "storage").iterdir()), [])

    def test_only_exact_root_primary_names_are_accepted_even_on_stopped_restart(self):
        self.disk.unlink()
        storage = self.storage / "storage"
        # Every formerly accepted suffix, auxiliary media, nested primary names,
        # case variants and unsupported data formats must not trigger creation.
        names = ("setup.img", "boot.qcow2", "firmware.img", "OVMF_CODE.fd", "OVMF_VARS.fd",
                 "backup/data.img", "backup/data.qcow2", "backup/old.vhdx",
                 "other.img", "other.raw", "other.qcow", "other.qcow2", "other.vhd",
                 "other.vhdx", "other.vmdk", "other.vdi", "data.raw", "data.qcow",
                 "data.vhd", "data.vhdx", "data.vmdk", "data.vdi", "DATA.IMG", "data.IMG")
        for name in names:
            candidate = storage / name
            candidate.parent.mkdir(parents=True, exist_ok=True)
            candidate.write_text("preserved auxiliary or backup")
            for stopped in (False, True):
                with self.subTest(name=name, stopped=stopped):
                    self.update(containers={})
                    if stopped:
                        self.seed(running=False, generation=self.m["generation"])
                    before = copy.deepcopy(self.data()["containers"])
                    with self.assertRaises(MOD.Refused): self.c.reconcile()
                    self.assertEqual(self.data()["containers"], before)
                    self.assertEqual(candidate.read_text(), "preserved auxiliary or backup")
            candidate.unlink()
        self.assertFalse(any(a[0] == "start" or "--podman-path" in a for a in self.calls()))
        self.assertFalse(Path(self.m["runtimeDir"]).exists())

    def test_empty_nonregular_and_ambiguous_primary_disks_refused(self):
        self.disk.unlink()
        storage = self.storage / "storage"
        for primary in ("data.img", "data.qcow2"):
            candidate = storage / primary
            for kind in ("empty", "directory", "fifo"):
                with self.subTest(primary=primary, kind=kind):
                    if kind == "empty": candidate.touch()
                    elif kind == "directory": candidate.mkdir()
                    else: os.mkfifo(candidate)
                    self.update(containers={})
                    with self.assertRaises(MOD.Refused): self.c.reconcile()
                    self.seed(running=False)
                    before = copy.deepcopy(self.data()["containers"])
                    with self.assertRaises(MOD.Refused): self.c.reconcile()
                    self.assertEqual(self.data()["containers"], before)
                    if kind == "directory": candidate.rmdir()
                    else: candidate.unlink()
        for raw, qcow in (("raw", "qcow"), ("raw", ""), ("", "qcow")):
            with self.subTest(raw=raw, qcow=qcow):
                self.disk.write_text(raw)
                other = storage / "data.qcow2"
                other.write_text(qcow)
                self.update(containers={})
                with self.assertRaises(MOD.Refused): self.c.reconcile()
                self.seed(running=False)
                before = copy.deepcopy(self.data()["containers"])
                with self.assertRaises(MOD.Refused): self.c.reconcile()
                self.assertEqual(self.data()["containers"], before)
                self.assertEqual(self.disk.read_text(), raw)
                self.assertEqual(other.read_text(), qcow)
        self.assertFalse(any(a[0] == "start" or "--podman-path" in a for a in self.calls()))

    def test_primary_format_is_explicit_and_disk_is_never_converted(self):
        # Auxiliary and nested backup disks may coexist, but are never selected.
        auxiliary = [self.disk.parent / name for name in ("setup.img", "boot.qcow2", "firmware.img", "backup/data.img")]
        for path in auxiliary:
            path.parent.mkdir(exist_ok=True)
            path.write_text("untouched auxiliary")
        for name, expected in (("data.img", "raw"), ("data.qcow2", "qcow2")):
            with self.subTest(name=name):
                if self.disk.name != name:
                    self.disk = self.disk.rename(self.disk.with_name(name))
                self.update(containers={})
                before = self.disk.stat()
                contents = self.disk.read_bytes()
                self.assertEqual(self.c.reconcile(), {"running": True, "pending": False})
                env = self.overlay()["environment"]
                self.assertEqual(env["DISK_NAME"], "data")
                self.assertEqual(env["DISK_FMT"], expected)
                overlay = (Path(self.m["runtimeDir"]) / "hardware.json").read_bytes()
                existing = copy.deepcopy(self.data()["containers"])
                stopped = copy.deepcopy(existing)
                stopped["windows"]["State"]["Running"] = False
                self.update(containers=stopped)
                self.assertEqual(self.c.reconcile(), {"running": True, "pending": False})
                self.assertEqual(self.data()["containers"], existing)
                self.assertEqual((Path(self.m["runtimeDir"]) / "hardware.json").read_bytes(), overlay)
                self.assertEqual(self.disk.stat().st_ino, before.st_ino)
                self.assertEqual(self.disk.stat().st_mtime_ns, before.st_mtime_ns)
                self.assertEqual(self.disk.read_bytes(), contents)
                self.assertEqual(set(self.disk.parent.iterdir()), {self.disk, *[p for p in auxiliary if p.parent == self.disk.parent], self.disk.parent / "backup"})
                for path in auxiliary:
                    self.assertEqual(path.read_text(), "untouched auxiliary")
                self.no_destructive_calls()
        self.assertEqual(sum("--podman-path" in a for a in self.calls()), 2)
        self.assertEqual(sum(a[0] == "start" for a in self.calls()), 2)

    def test_recursive_symlinks_refused_even_with_valid_primary(self):
        backup = self.disk.parent / "backup"
        backup.mkdir()
        external = self.root / "external"
        external.mkdir()
        (external / "data.img").write_text("untouched")
        for target in (external, external / "data.img", external / "missing.img"):
            with self.subTest(target=target):
                link = backup / "link"
                link.symlink_to(target)
                with self.assertRaises(MOD.Refused): self.c.preflight()
                self.seed(running=False)
                with self.assertRaises(MOD.Refused): self.c.reconcile()
                self.assertEqual((external / "data.img").read_text(), "untouched")
                link.unlink()
        self.assertFalse(any(a[0] == "start" or "--podman-path" in a for a in self.calls()))
        self.no_destructive_calls()

    def test_missing_directory_does_not_create_storage(self):
        (self.storage / "shared").rmdir()
        with self.assertRaises(MOD.Refused): self.c.reconcile()
        self.assertFalse((self.storage / "shared").exists())

    def test_external_disk_and_directory_symlinks_are_preserved(self):
        external = self.root / "external"
        external.write_text("untouched")
        self.disk.unlink()
        self.disk.symlink_to(external)
        with self.assertRaises(MOD.Refused): self.c.preflight()
        self.assertEqual(external.read_text(), "untouched")
        self.disk.unlink()
        (self.storage / "storage").rmdir()
        (self.storage / "storage").symlink_to(self.root)
        with self.assertRaises(MOD.Refused): self.reload()

    def test_runtime_symlink_no_external_overlay_write(self):
        external = self.root / "outside"
        external.mkdir()
        Path(self.m["runtimeDir"]).symlink_to(external)
        with self.assertRaises(MOD.Refused): self.c.reconcile()
        self.assertEqual(list(external.iterdir()), [])

    def test_nonprivate_runtime_refused(self):
        Path(self.m["runtimeDir"]).mkdir(mode=0o755)
        with self.assertRaises(MOD.Refused): self.c.reconcile()

    def test_wrong_host_identity_mode_container_and_image_refused(self):
        for key, bad in (("host", "envy"), ("bdf", "0000:02:00.0"), ("vendor", "0x8086"), ("device", "0x1d13"),
                         ("renderBdf", "0000:00:03.0"), ("mode", "disabled"), ("container", "envy-windows"), ("image", "public:latest")):
            m = dict(self.m, **{key: bad})
            with self.subTest(key=key), self.assertRaises(MOD.Refused): MOD.Controller(m)
        self.assertFalse(self.calls())

    def test_relative_command_and_compose_paths_refused(self):
        m = copy.deepcopy(self.m)
        m["commands"]["compose"] = "podman-compose"
        with self.assertRaises(MOD.Refused): MOD.Controller(m)
        m = copy.deepcopy(self.m)
        m["compose"][0] = "./base.yml"
        with self.assertRaises(MOD.Refused): MOD.Controller(m)

    def test_engine_failure_and_malformed_inspect_never_treated_as_absence(self):
        self.update(error=True)
        with self.assertRaises(MOD.Refused): self.c.reconcile()
        self.update(error=False, malformed_inspect=True)
        self.seed()
        with self.assertRaises(MOD.Refused): self.c.reconcile()
        self.assertFalse(any("--podman-path" in a for a in self.calls()))
        self.no_destructive_calls()

    def test_ps_or_inspect_failure_blocks_adoption(self):
        self.seed()
        for command in ("ps", "inspect"):
            self.update(fail_commands=[command])
            with self.assertRaises(MOD.Refused): self.c.reconcile()
        self.no_destructive_calls()

    def test_missing_engine_is_safe_refusal(self):
        self.m["commands"]["podman"] = str(self.root / "missing")
        with self.assertRaises(MOD.Refused): self.c.reconcile()

    def test_status_started_and_graceful_stop_do_not_inspect_env(self):
        self.seed(legacy=True)
        self.assertTrue(self.c.started()["running"])
        self.c.stop()
        self.assertFalse(self.c.status()["running"])
        with self.assertRaises(MOD.Refused): self.c.started()
        self.assertIn(["stop", "--time=-1", "windows"], self.calls())
        self.assertFalse(any(".Env" in " ".join(a) for a in self.calls()))
        self.no_destructive_calls()

    def test_stop_failure_does_not_claim_guest_stopped(self):
        self.seed()
        self.update(stop_fails=True)
        with self.assertRaises(MOD.Refused): self.c.stop()
        self.assertTrue(self.c.status()["running"])

    def test_render_and_vfio_share_lifetime_lock(self):
        render = self.c
        self.vfio()
        self.assertEqual(render.m["runtimeDir"], self.c.m["runtimeDir"])
        with render.lifetime_lock():
            with self.assertRaises(MOD.Refused):
                with self.c.lifetime_lock():
                    self.fail("mode change acquired another lifetime lock")

    def test_stop_and_supervisor_use_same_lifetime_lock(self):
        self.seed()
        with self.c.lifetime_lock():
            with self.assertRaises(MOD.Refused): self.c.stop()
        self.assertTrue(self.c.status()["running"])

    def cli(self, action):
        manifest = self.root / "manifest.json"
        manifest.write_text(json.dumps(self.m))
        return [sys.executable, str(SCRIPT), "--manifest", str(manifest), action]

    def spawn(self):
        p = subprocess.Popen(self.cli("supervise"), env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        self.addCleanup(lambda: p.poll() is not None or p.kill())
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline and not self.data()["containers"]:
            time.sleep(.05)
        self.assertTrue(self.data()["containers"])
        return p

    def test_real_supervisor_lock_readiness_and_clean_stop(self):
        notify = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
        self.addCleanup(notify.close)
        address = self.root / "notify"
        notify.bind(str(address))
        notify.settimeout(5)
        self.env["NOTIFY_SOCKET"] = str(address)
        p = self.spawn()
        self.assertEqual(notify.recv(1024), b"READY=1")
        second = subprocess.run(self.cli("supervise"), env=self.env, capture_output=True, text=True, timeout=5)
        self.assertNotEqual(second.returncode, 0)
        p.terminate()
        out, err = p.communicate(timeout=5)
        self.assertEqual(p.returncode, 0, err)
        self.assertFalse(self.data()["containers"]["windows"]["State"]["Running"])
        self.assertNotIn(self.password, out + err)
        self.no_destructive_calls()

    def test_partial_compose_failure_retains_lock_without_readiness(self):
        self.update(fail_after_create=True)
        p = self.spawn()
        time.sleep(.3)
        self.assertIsNone(p.poll())
        second = subprocess.run(self.cli("supervise"), env=self.env, capture_output=True, text=True, timeout=5)
        self.assertNotEqual(second.returncode, 0)
        p.terminate()
        out, err = p.communicate(timeout=5)
        self.assertEqual(p.returncode, 0, err)
        self.assertNotIn(self.password, out + err)
        self.assertIn("retaining lifetime ownership", err)

    def test_cli_engine_errors_are_secret_safe(self):
        self.update(error=True)
        result = subprocess.run(self.cli("supervise"), env=self.env, capture_output=True, text=True, timeout=5)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("private-sentinel", result.stdout + result.stderr)
        self.assertNotIn(self.password, result.stdout + result.stderr)

    def test_parser_preserves_literal_password_and_home_path_expansion(self):
        self.envfile.write_text("# comment\nWINDOWS_STORAGE_DIR='${HOME}/windows/storage' # comment\n"
                                'WINDOWS_SHARED_DIR="$HOME/windows/shared"\nWINDOWS_OEM_DIR=$HOME/windows/oem\n'
                                "WINDOWS_PASSWORD='" + self.password + "' # literal\n")
        self.reload()
        self.assertEqual(self.c.private_password(), self.password)
        self.assertEqual(self.c.storage_path(), self.storage / "storage")

    def test_parser_rejects_shell_grammar_and_ambiguous_expansions_secret_safely(self):
        baseline = self.envfile.read_text()
        for extra in ("export KEY=value", "KEY=$(touch sentinel)", 'KEY="escaped\\nvalue"', "KEY='one'bad",
                      "KEY='unterminated", "KEY=first\nKEY=second", "not an assignment", "KEY=a b",
                      "WINDOWS_STORAGE_DIR=/other", "WINDOWS_STORAGE_DIR=$OTHER/disk"):
            self.envfile.write_text(baseline + "\n" + extra + "\n")
            with self.subTest(extra=extra), self.assertRaises(MOD.Refused) as caught: self.reload()
            self.assertNotIn(extra, str(caught.exception))
            self.assertNotIn(self.password, str(caught.exception))
        self.assertFalse((self.root / "sentinel").exists())

    def test_parser_rejects_ambiguous_path_fields(self):
        baseline = self.envfile.read_text()
        for value in ("relative", "/tmp/../disk", "$HOME_SUFFIX/disk", "$HOME/${OTHER}", "~/disk", "/tmp/disk:ro", "$(false)", "`false`"):
            text = baseline.replace(str(self.storage / "storage"), value)
            self.envfile.write_text(text)
            with self.subTest(value=value), self.assertRaises(MOD.Refused): self.reload()

    def test_home_expansion_requires_nonempty_absolute_home(self):
        self.envfile.write_text(self.envfile.read_text().replace(str(self.storage), "$HOME/windows"))
        for home in ("", "relative"):
            with patch.dict(os.environ, HOME=home):
                with self.assertRaises(MOD.Refused): self.reload()

    def test_empty_commented_password_is_allowed_for_adoption_only(self):
        self.write_config(password=False)
        self.envfile.write_text(self.envfile.read_text() + "\nWINDOWS_PASSWORD= # not provisioned\n")
        self.reload()
        with self.assertRaises(MOD.Refused): self.c.private_password()
        self.seed(legacy=True)
        self.assertTrue(self.c.reconcile()["pending"])

    def test_shared_gpu_resolver_is_reexported_by_envy(self):
        spec = importlib.util.spec_from_file_location("envy_adapter_fixture", ROOT / "nixos/hosts/envy/windows-runtime.py")
        envy = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(envy)
        self.assertIs(envy.resolve_gpu, MOD.resolve_gpu)
        self.assertEqual(MOD.resolve_gpu.__module__, "windows_runtime")

    def test_private_config_missing_world_readable_symlink_and_wrong_owner(self):
        self.envfile.chmod(0o644)
        with self.assertRaises(MOD.Refused): self.reload()
        self.envfile.chmod(0o600)
        real = self.envfile.with_name("real-env")
        self.envfile.rename(real)
        self.envfile.symlink_to(real)
        with self.assertRaises(MOD.Refused): self.reload()
        self.envfile.unlink()
        with self.assertRaises(MOD.Refused): self.reload()
        real.rename(self.envfile)
        with patch.object(MOD.os, "getuid", return_value=os.getuid() + 1):
            with self.assertRaises(MOD.Refused): self.reload()

    def test_bad_private_file_cli_never_echoes_contents(self):
        self.envfile.write_text("BAD " + self.password)
        result = subprocess.run(self.cli("status"), env=self.env, capture_output=True, text=True, timeout=5)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn(self.password, result.stdout + result.stderr)
        self.assertNotIn("Traceback", result.stderr)


if __name__ == "__main__":
    unittest.main()
