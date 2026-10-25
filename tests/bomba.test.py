"""Pump command behavior against a simulated Home Assistant and relay."""

import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


SCRIPT = Path(__file__).resolve().parents[1] / "nixos/apps/bomba/bomba.py"
spec = importlib.util.spec_from_file_location("bomba", SCRIPT)
bomba = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bomba)


class SimulatedHA(bomba.HomeAssistant):
    def __init__(self):
        self.switch = "switch.bomba"
        self.countdown = "number.bomba_countdown"
        self.state = "off"
        self.seconds = 0
        self.calls = []
        self.timer_fails = False

    def request(self, path, body=None):
        if path.startswith("states/"):
            return {"state": self.state if path.endswith(self.switch) else str(self.seconds)}
        self.calls.append((path, body))
        if path == "services/number/set_value":
            if body["value"] and self.timer_fails:
                raise bomba.PumpError("Simulated timer failure")
            self.seconds = body["value"]
        elif path == "services/switch/turn_on":
            self.state = "on"
        elif path == "services/switch/turn_off":
            self.state = "off"
        return []


class PumpTests(unittest.TestCase):
    def test_local_instance_is_preferred_without_contacting_orgm(self):
        from unittest.mock import patch
        ha = SimulatedHA()
        with tempfile.TemporaryDirectory() as directory, \
             patch.object(bomba, "HomeAssistant", return_value=ha), \
             patch.object(bomba.subprocess, "run") as remote:
            config = {"mode": "failover", "primary": {"mode": "local", "state_dir": directory}, "fallback": {"mode": "ssh"}}
            result = bomba.execute(config, {"action": "time", "minutes": 10})
            self.assertEqual(result["controller"], "jarq")
            self.assertFalse(result["fallback"])
            self.assertEqual(result["remaining_seconds"], 600)
            remote.assert_not_called()

    def test_missing_local_token_uses_orgm_without_transferring_credentials(self):
        from types import SimpleNamespace
        from unittest.mock import patch
        reply = {"ok": True, "result": {"state": "off", "remaining_seconds": 0, "native_timer": True}}
        with tempfile.TemporaryDirectory() as directory, \
             patch.object(bomba, "HomeAssistant", side_effect=bomba.PumpError("Missing local token")), \
             patch.object(bomba.subprocess, "run", return_value=SimpleNamespace(stdout=json.dumps(reply))) as remote:
            config = {"mode": "failover", "primary": {"mode": "local", "state_dir": directory},
                      "fallback": {"mode": "ssh", "host": "orgm", "identity": "/private/client-key", "known_hosts": "/private/known_hosts"}}
            result = bomba.execute(config, {"action": "down"})
            self.assertEqual(result["controller"], "orgm")
            self.assertTrue(result["fallback"])
            self.assertEqual(json.loads(remote.call_args.kwargs["input"]), {"action": "down"})

    def test_failed_local_write_is_not_replayed_on_a_second_controller(self):
        from unittest.mock import patch
        ha = SimulatedHA()
        ha.timer_fails = True
        with tempfile.TemporaryDirectory() as directory, \
             patch.object(bomba, "HomeAssistant", return_value=ha), \
             patch.object(bomba.subprocess, "run") as remote:
            config = {"mode": "failover", "primary": {"mode": "local", "state_dir": directory}, "fallback": {"mode": "ssh"}}
            with self.assertRaises(bomba.PumpError):
                bomba.execute(config, {"action": "time", "minutes": 10})
            remote.assert_not_called()
            self.assertEqual(ha.state, "off")

    def test_native_timer_and_minutes_conversion(self):
        ha = SimulatedHA()
        result = ha.execute({"action": "time", "minutes": 10})
        self.assertEqual(result["state"], "on")
        self.assertEqual(result["remaining_seconds"], 600)
        self.assertEqual([path for path, _ in ha.calls], [
            "services/number/set_value", "services/switch/turn_on", "services/number/set_value",
        ])
        self.assertTrue(all(body["entity_id"] in {ha.switch, ha.countdown} for _, body in ha.calls))

    def test_replacement_does_not_toggle_an_already_running_pump(self):
        ha = SimulatedHA()
        ha.state, ha.seconds = "on", 600
        result = ha.execute({"action": "time", "minutes": 5})
        self.assertEqual(result["remaining_seconds"], 300)
        self.assertEqual(len(ha.calls), 1)
        self.assertEqual(ha.calls[0][0], "services/number/set_value")

    def test_manual_commands_clear_the_previous_timer(self):
        ha = SimulatedHA()
        ha.seconds = 600
        result = ha.execute({"action": "up"})
        self.assertEqual(result["state"], "on")
        self.assertEqual(result["remaining_seconds"], 0)
        result = ha.execute({"action": "down"})
        self.assertEqual(result["state"], "off")
        self.assertEqual(ha.seconds, 0)

    def test_timer_failure_requests_off_instead_of_leaving_it_running(self):
        ha = SimulatedHA()
        ha.timer_fails = True
        with self.assertRaises(bomba.PumpError):
            ha.execute({"action": "time", "minutes": 10})
        self.assertEqual(ha.state, "off")
        self.assertEqual(ha.seconds, 0)

    def test_interruption_while_programming_requests_off(self):
        ha = SimulatedHA()
        original = ha.set_timer
        def interrupted(seconds):
            if seconds:
                raise KeyboardInterrupt
            original(seconds)
        ha.set_timer = interrupted
        with self.assertRaises(KeyboardInterrupt):
            ha.execute({"action": "time", "minutes": 10})
        self.assertEqual(ha.state, "off")

    def test_invalid_or_arbitrary_commands_cannot_reach_the_device(self):
        for payload in [
            {}, [], {"action": "exec"}, {"action": "time", "minutes": True},
            {"action": "time", "minutes": "10"}, {"action": "time", "minutes": 0},
            {"action": "time", "minutes": 1441}, {"action": "up", "minutes": 10},
            {"action": "down", "entity_id": "switch.casa_switch"},
        ]:
            with self.subTest(payload=payload), self.assertRaises(bomba.PumpError):
                bomba.validate(payload)

    def test_system_config_works_when_the_home_directory_is_protected(self):
        from unittest.mock import patch
        with patch.dict(bomba.os.environ, {}, clear=True), \
             patch.object(Path, "is_file", side_effect=PermissionError), \
             patch.object(Path, "read_text", return_value='{"mode":"unix"}'):
            self.assertEqual(bomba.load_config(), {"mode": "unix"})

    def test_http_authentication_and_gateway_json(self):
        ha = SimulatedHA()
        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass

            def do_GET(self):
                self.respond()

            def do_POST(self):
                self.respond(json.loads(self.rfile.read(int(self.headers["Content-Length"]))))

            def respond(self, body=None):
                if self.headers.get("Authorization") != "Bearer test-private-token":
                    self.send_error(401)
                    return
                result = ha.request(self.path.removeprefix("/api/"), body)
                self.send_response(200)
                self.end_headers()
                self.wfile.write(json.dumps(result).encode())

        server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        worker = threading.Thread(target=server.serve_forever, daemon=True)
        worker.start()
        try:
            with tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                token = root / "token"
                token.write_text("test-private-token")
                token.chmod(0o600)
                config = root / "config.json"
                config.write_text(json.dumps({"mode": "local", "token_file": str(token), "url": f"http://127.0.0.1:{server.server_port}"}))
                result = subprocess.run(
                    ["python3", str(SCRIPT), "--config", str(config), "gateway"],
                    input=json.dumps({"action": "status"}), text=True, capture_output=True, check=True,
                )
                self.assertEqual(json.loads(result.stdout)["result"]["state"], "off")
                self.assertNotIn("test-private-token", result.stdout + result.stderr)
                token.chmod(0o644)
                with self.assertRaises(bomba.PumpError):
                    bomba.HomeAssistant(json.loads(config.read_text()))
        finally:
            server.shutdown()
            server.server_close()
            worker.join(timeout=2)


if __name__ == "__main__":
    unittest.main()
