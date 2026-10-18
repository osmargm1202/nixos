#!/usr/bin/env python3
"""Inspect a built generation without activating it or opening the reader.

ENVY_FINGERPRINT_SYSTEM=/nix/store/...-nixos-system-envy-sway python3 tests/envy-fingerprint-system.test.py
"""
import json
import os
from pathlib import Path
import unittest

SYSTEM = os.environ.get('ENVY_FINGERPRINT_SYSTEM')


@unittest.skipUnless(SYSTEM, 'set ENVY_FINGERPRINT_SYSTEM to a built generation')
class SystemArtifact(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.root = Path(SYSTEM).resolve(strict=True)
        cls.metadata_file = cls.root/'sw/share/orgm-qylock/runtime.json'
        cls.metadata = json.loads(cls.metadata_file.read_text())

    def test_system_exports_immutable_metadata_with_fingerprint_enabled(self):
        self.assertTrue(self.metadata_file.resolve().is_relative_to('/nix/store'))
        self.assertIs(self.metadata['fingerprintEnabled'], True)

    def test_private_fingerprint_pam_uses_experimental_backend(self):
        text = (Path(self.metadata['pamDirectory'])/'orgm-qylock-fp').read_text()
        line = next(line for line in text.splitlines() if 'pam_fprintd.so' in line)
        module = Path(line.split()[2])
        self.assertTrue(module.is_file())
        self.assertIn('-fprintd-synatudor-', str(module))
        self.assertIn('timeout=30 max_tries=3', line)

    def test_independent_password_pam_is_preserved(self):
        text = (Path(self.metadata['pamDirectory'])/'orgm-qylock-pw').read_text()
        self.assertIn('pam_unix.so', text)
        self.assertNotIn('pam_fprintd.so', text)

    def test_no_managed_pam_service_enables_fingerprint(self):
        services = list((self.root/'etc/pam.d').iterdir())
        self.assertGreater(len(services), 10)
        for service in services:
            self.assertNotIn('pam_fprintd.so', service.read_text(), service.name)
        self.assertIn('auth substack login', (self.root/'etc/pam.d/sddm').read_text())

    def test_display_manager_is_not_restarted_for_unit_changes(self):
        text = (self.root/'etc/systemd/system/display-manager.service').read_text()
        self.assertIn('X-RestartIfChanged=false', text)

    def test_power_quirk_targets_only_the_known_usb_reader(self):
        text = (self.root/'etc/udev/rules.d/99-local.rules').read_text()
        line = next(line for line in text.splitlines()
                    if 'ATTR{idVendor}=="06cb", ATTR{idProduct}=="00c9"' in line)
        self.assertIn('SUBSYSTEM=="usb"', line)
        self.assertIn('ENV{DEVTYPE}=="usb_device"', line)
        self.assertIn('ATTR{power/control}="on"', line)

    def test_fprintd_state_list_is_reset_in_real_unit_dropin(self):
        text = (self.root/'etc/systemd/system/fprintd.service.d/overrides.conf').read_text()
        self.assertIn('StateDirectory=\nStateDirectory=fprint-synatudor-test', text)
        self.assertIn('ExecStartPre=', text)


if __name__ == '__main__':
    unittest.main()
