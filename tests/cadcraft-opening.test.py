#!/usr/bin/env python3
"""Single-instance policy without accessing a real user desktop."""
import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
import subprocess
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "dotfiles/config/programs/flatpak/.local/lib/orgm-artcraft/cadcraft.py"

class Opening(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        assert MODULE.is_file(), "CADCraft reusable-window launcher is missing"
        sys.path.insert(0, str(MODULE.parent))
        spec = importlib.util.spec_from_file_location("cadcraft", MODULE)
        cls.cad = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.cad)

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.file = self.home / "plano ñ con espacios.dwg"
        self.file.write_bytes(b"AC1018")

    def backend(self, instances=()):
        class Fake:
            def __init__(self):
                self.instances=list(instances); self.calls=[]; self.started=0;self.inflight=False
            def discover(self):return self.instances
            def pending(self,runtime):return self.inflight
            def ready(self,runtime):self.inflight=False
            def start(self, runtime):
                self.started+=1;self.instances=["123"]
            def rpc(self, instance, op, path=None):
                self.calls.append((instance,op,path))
                return {"ok":True,"result":"pong" if op=="ping" else {"index":1}}
            def export(self, path):return "/run/user/1000/doc/abcd/"+Path(path).name
            def focus(self, instance):self.calls.append((instance,"compositor-focus",None))
        return Fake()

    def test_reuses_existing_window_for_multiple_files(self):
        b=self.backend(["42"])
        self.cad.open_files([str(self.file),self.file.as_uri()],b,self.home/"runtime")
        self.assertEqual(b.started,0)
        self.assertEqual([c for c in b.calls if c[1]=="open"],[("42","open",str(self.file))]*2)

    def test_focuses_hidden_window_before_ping_or_open(self):
        b=self.backend(["42"])
        self.cad.open_files([str(self.file)],b,self.home/"runtime")
        self.assertEqual(b.calls[0],("42","compositor-focus",None))

    def test_sandbox_init_descendants_are_matched_but_other_apps_are_not(self):
        b=self.cad.Backend()
        statuses={111:110,110:100,100:1,222:200,200:1}
        with patch.object(b,"parent_pid",side_effect=lambda pid:statuses.get(pid,0)):
            self.assertTrue(b.belongs_to_instance(111,{100}))
            self.assertFalse(b.belongs_to_instance(222,{100}))

    def test_i3_focus_uses_xres_host_pid_and_exact_container(self):
        b = self.cad.Backend()
        calls = []
        tree = {"nodes": [
            {"id": 41, "window": 123, "window_properties": {"class": "CADCraft"}},
            {"id": 42, "window": 124, "window_properties": {"class": "CADCraft"}},
            {"id": 43, "window": 125, "window_properties": {"class": "Other"}},
        ]}
        def run(args):
            calls.append(args)
            if args == ["i3-msg", "-t", "get_tree"]:
                return subprocess.CompletedProcess(args, 0, json.dumps(tree))
            pid = {"123": "111", "124": "999"}.get(args[-1], "")
            return subprocess.CompletedProcess(args, 0, pid)
        with patch.dict(os.environ, {"I3SOCK": "/tmp/test-i3"}, clear=True), \
             patch.object(b, "rows", return_value=[["42", self.cad.APP, "100", "110"]]), \
             patch.object(b, "run", side_effect=run), \
             patch.object(b, "belongs_to_instance", side_effect=lambda pid, roots: pid == 111):
            b.focus("42")
        self.assertEqual(calls[-1], ["i3-msg", "[con_id=41] focus"])
        self.assertNotIn(["orgm-x11-client-pid", "125"], calls)

    def test_i3_does_not_focus_an_unrelated_cadcraft_instance(self):
        b = self.cad.Backend()
        tree = {"floating_nodes": [{"id": 7, "window": 10, "window_properties": {"class": self.cad.APP}}]}
        calls = []
        def run(args):
            calls.append(args)
            return subprocess.CompletedProcess(args, 0, json.dumps(tree) if args[0] == "i3-msg" else "999")
        with patch.dict(os.environ, {"XDG_CURRENT_DESKTOP": "i3"}, clear=True), \
             patch.object(b, "rows", return_value=[["42", self.cad.APP, "100", "110"]]), \
             patch.object(b, "run", side_effect=run), \
             patch.object(b, "belongs_to_instance", return_value=False):
            b.focus("42")
        self.assertFalse(any("focus" in arg for call in calls for arg in call))

    def test_starts_once_only_when_absent(self):
        b=self.backend()
        self.cad.open_files([str(self.file)],b,self.home/"runtime")
        self.cad.open_files([str(self.file)],b,self.home/"runtime")
        self.assertEqual(b.started,1)

    def test_undiscoverable_pending_start_is_not_launched_twice(self):
        b=self.backend()
        def start(runtime):b.started+=1;b.inflight=True
        b.start=start
        with patch.object(self.cad.time,"monotonic",side_effect=[0,46]):
            with self.assertRaises(self.cad.Error):self.cad.open_files([],b,self.home/"runtime")
        with patch.object(self.cad.time,"monotonic",side_effect=[0,46]):
            with self.assertRaises(self.cad.Error):self.cad.open_files([],b,self.home/"runtime")
        self.assertEqual(b.started,1)

    def test_cold_start_focuses_new_window_before_ping(self):
        b=self.backend();original=b.rpc
        def rpc(instance,op,path=None):
            if op=="ping" and not any(c[1]=="compositor-focus" for c in b.calls):
                raise self.cad.Error("hidden window")
            return original(instance,op,path)
        b.rpc=rpc
        with patch.object(self.cad.time,"monotonic",side_effect=[0,46]):
            self.cad.open_files([],b,self.home/"runtime")
        self.assertEqual(b.started,1)

    def test_pending_launch_checks_pid_start_time_and_unknown_state(self):
        runtime=self.home/"runtime";runtime.mkdir()
        pending=runtime/"launch.json"
        b=self.cad.Backend()
        pending.write_text(json.dumps({"pid":os.getpid(),"stamp":"old"}))
        with patch.object(b,"process_stamp",return_value="current"):
            self.assertFalse(b.pending(runtime))
        pending.write_text(json.dumps({"pid":os.getpid(),"stamp":"current"}))
        with patch.object(b,"process_stamp",return_value="current"):
            self.assertTrue(b.pending(runtime))
        pending.write_text("{}")
        self.assertTrue(b.pending(runtime))

    def test_unmanaged_or_unresponsive_instance_never_duplicated(self):
        b=self.backend(["42"])
        b.rpc=lambda *a: (_ for _ in ()).throw(self.cad.Error("connection refused"))
        with self.assertRaisesRegex(self.cad.Error,"cierra|close"):
            self.cad.open_files([str(self.file)],b,self.home/"runtime")
        self.assertEqual(b.started,0)

    def test_ambiguous_instances_fail_closed(self):
        b=self.backend(["42","43"])
        with self.assertRaises(self.cad.Error):self.cad.open_files([str(self.file)],b,self.home/"runtime")
        self.assertEqual((b.started,b.calls),(0,[]))

    def test_invalid_paths_have_no_effect(self):
        for path in ("https://host/drawing.dwg","file://host/tmp/a.dwg",str(self.home/"missing.dwg"),str(self.home)):
            b=self.backend()
            with self.assertRaises(self.cad.Error):self.cad.open_files([str(self.file),path],b,self.home/"runtime")
            self.assertEqual((b.started,b.calls),(0,[]))

    def test_portal_export_only_after_in_sandbox_preflight(self):
        b=self.backend(["42"]); original=b.rpc
        def rpc(instance,op,path=None):
            if op=="open" and path==str(self.file):
                b.calls.append((instance,op,path));return {"needs_export":True}
            return original(instance,op,path)
        b.rpc=rpc
        self.cad.open_files([str(self.file)],b,self.home/"runtime")
        self.assertEqual([c[2] for c in b.calls if c[1]=="open"],[str(self.file),"/run/user/1000/doc/abcd/"+self.file.name])

    def test_uncertain_open_never_retried_or_relaunched(self):
        b=self.backend(["42"]); original=b.rpc
        def rpc(instance,op,path=None):
            if op=="open":
                b.calls.append((instance,op,path));raise self.cad.Error("timeout may-have-run")
            return original(instance,op,path)
        b.rpc=rpc
        with self.assertRaises(self.cad.Error):self.cad.open_files([str(self.file)],b,self.home/"runtime")
        self.assertEqual(len([c for c in b.calls if c[1]=="open"]),1)
        self.assertEqual(b.started,0)

    def test_lock_is_private_and_symlinks_rejected(self):
        b=self.backend(["42"])
        self.cad.open_files([],b,self.home/"runtime")
        self.assertEqual((self.home/"runtime").stat().st_mode & 0o777,0o700)
        self.assertEqual((self.home/"runtime/open.lock").stat().st_mode & 0o777,0o600)
        (self.home/"link").symlink_to(self.home/"runtime",target_is_directory=True)
        with self.assertRaises(self.cad.Error):self.cad.open_files([],b,self.home/"link")

    def test_wrapper_does_not_create_bytecode_in_managed_dotfiles(self):
        helper=ROOT/"dotfiles/config/programs/flatpak/.local/bin/orgm-cadcraft"
        fake=self.home/"python3"
        shell=subprocess.check_output(["which","sh"],text=True).strip()
        fake.write_text("#!"+shell+"\nprintf '%s\\n' \"$@\"\n");fake.chmod(0o755)
        result=subprocess.check_output([str(helper),"--",str(self.file)],env=dict(os.environ,HOME=str(self.home),PATH=str(self.home)+":"+os.environ["PATH"]),text=True).splitlines()
        self.assertEqual(result[0],"-B")

if __name__=="__main__":unittest.main()
