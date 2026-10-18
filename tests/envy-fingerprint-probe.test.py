#!/usr/bin/env python3
"""Test the physical-test orchestrator without D-Bus, PAM, root, or hardware."""
import contextlib
import io
import os
from pathlib import Path
import runpy
import shutil
import subprocess
import time
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
MODULE = runpy.run_path(str(ROOT/'nixos/hardware/fingerprint/synatudor-probe.py'))
ENV = MODULE['main'].__globals__


class Probe(unittest.TestCase):
    def call(self, code, **kwargs):
        with contextlib.redirect_stdout(io.StringIO()):
            return MODULE['client']([sys.executable, '-c', code], os.environ.copy(), **kwargs)

    def test_actual_cli_done_suffix_and_enroll_progress(self):
        MODULE['require_result']('Verify result: verify-match (done)\n', 'verify-match')
        MODULE['require_result']('Enroll result: enroll-stage-passed\n'
                                 'Enroll result: enroll-completed\n', 'enroll-completed')

    def test_no_match_never_passes_as_match(self):
        with self.assertRaises(RuntimeError):
            MODULE['require_result']('Verify result: verify-no-match (done)\n', 'verify-match')

    def test_final_result_is_required(self):
        with self.assertRaises(RuntimeError):
            MODULE['require_result']('Enroll result: enroll-completed\n'
                                     'Enroll result: enroll-failed\n', 'enroll-completed')

    def test_false_match_is_not_accepted_for_negative_test(self):
        with self.assertRaises(RuntimeError):
            self.call("print('Verify result: verify-match (done)'); raise SystemExit(1)",
                      allow_rejection=True)

    def test_cli_exit_one_for_expected_rejection_is_allowed(self):
        text = self.call("print('Verify result: verify-no-match (done)'); raise SystemExit(1)",
                         allow_rejection=True)
        MODULE['require_result'](text, 'verify-no-match')

    def test_unrelated_error_exit_one_is_not_an_expected_rejection(self):
        with self.assertRaises(RuntimeError):
            self.call("print('failed to claim device'); raise SystemExit(1)", allow_rejection=True)

    def test_positive_client_and_missing_results(self):
        text = self.call("print('Verify result: verify-match (done)')")
        MODULE['require_result'](text, 'verify-match')
        with self.assertRaises(RuntimeError):
            MODULE['require_result']('No devices available', 'verify-match')

    def test_client_timeout_does_not_hang(self):
        with self.assertRaisesRegex(RuntimeError, 'Tiempo agotado'):
            self.call('import time; time.sleep(60)', timeout=0.02)

    def test_private_bus_has_no_host_service_directories_and_only_root_polkit(self):
        config = ET.fromstring(MODULE['bus_config']('/run/fp-test-test/bus'))
        self.assertEqual(config.find('auth').text, 'EXTERNAL')
        self.assertEqual(config.findall('servicedir'), [])
        self.assertEqual(config.findall('standard_system_servicedirs'), [])
        default = config.find("policy[@context='default']")
        self.assertEqual([x.attrib['user'] for x in default.findall('allow')],
                         ['root', 'polkituser'])
        self.assertIsNotNone(default.find("deny[@user='*']"))
        self.assertIsNotNone(default.find("deny[@send_destination='*']"))

    @unittest.skipIf(os.geteuid() == 0 or not shutil.which('dbus-daemon'),
                     'requires unprivileged user and dbus-daemon')
    def test_real_private_bus_rejects_normal_user_without_accessing_hardware(self):
        with tempfile.TemporaryDirectory() as directory:
            socket = Path(directory)/'bus'
            config = Path(directory)/'bus.conf'
            config.write_text(MODULE['bus_config'](socket))
            process = subprocess.Popen(['dbus-daemon', '--nofork', f'--config-file={config}'],
                                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            try:
                for _ in range(50):
                    if socket.exists() or process.poll() is not None:
                        break
                    time.sleep(0.05)
                self.assertIsNone(process.poll(), 'D-Bus configuration must be valid')
                self.assertTrue(socket.exists())
                socket.chmod(0o666)
                result = subprocess.run(['dbus-send', '--system', '--print-reply',
                    '--reply-timeout=1000', '--dest=org.freedesktop.DBus',
                    '/org/freedesktop/DBus', 'org.freedesktop.DBus.NameHasOwner',
                    'string:org.freedesktop.DBus'],
                    env=os.environ | {'DBUS_SYSTEM_BUS_ADDRESS': f'unix:path={socket}'},
                    capture_output=True, text=True, timeout=5)
                self.assertNotEqual(result.returncode, 0, result.stdout)
            finally:
                MODULE['stop'](process)

    def test_private_state_refuses_symlinks(self):
        with tempfile.TemporaryDirectory() as directory:
            link = Path(directory)/'link'
            link.symlink_to(directory)
            with self.assertRaisesRegex(RuntimeError, 'enlace'):
                MODULE['private_state'](link)

    def test_root_and_terminal_are_required_before_subprocesses(self):
        with patch.object(ENV['os'], 'geteuid', return_value=1000), \
             patch.object(ENV['subprocess'], 'run') as run, \
             patch.object(ENV['sys'], 'argv', ['probe', 'osmarg']):
            with self.assertRaisesRegex(RuntimeError, 'sudo'):
                MODULE['main']()
            run.assert_not_called()

    def test_cleanup_terminates_then_reaps_daemons(self):
        process = Mock()
        process.poll.return_value = None
        MODULE['stop'](process)
        process.terminate.assert_called_once()
        process.wait.assert_called_once_with(timeout=10)

    def test_cleanup_kills_unresponsive_child(self):
        process = Mock()
        process.poll.return_value = None
        process.wait.side_effect = [subprocess.TimeoutExpired('daemon', 10), 0]
        MODULE['stop'](process)
        process.kill.assert_called_once()

    def test_no_system_activation_or_destructive_commands(self):
        text = (ROOT/'nixos/hardware/fingerprint/synatudor-probe.py').read_text()
        for forbidden in ['nixos-rebuild', 'fprintd-delete', 'clear_storage',
                          'systemctl restart', 'systemctl stop', 'systemctl mask',
                          '/etc/pam.d', 'G_MESSAGES_DEBUG']:
            self.assertNotIn(forbidden, text)
        self.assertIn("'STATE_DIRECTORY': str(STATE)", text)
        self.assertIn("'FP_DRIVERS_ALLOWLIST': 'synatlsmoc'", text)
        self.assertIn("'DBUS_SYSTEM_BUS_ADDRESS':", text)
        self.assertIn("if FINGER not in listing:", text)


if __name__ == '__main__':
    unittest.main()
