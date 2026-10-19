#!/usr/bin/env python3
"""Evaluate the real Hyprland target's Polkit-agent wiring; no builds or sessions."""
import json
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


class PolkitAgent(unittest.TestCase):
    def test_hyprland_target_starts_and_owns_the_installed_authentication_agent(self):
        expression = '''let
          system = (builtins.getFlake %s).nixosConfigurations.orgm;
          cfg = system.config;
        in {
          enabled = cfg.security.polkit.enable;
          agent = if cfg.systemd.user.services ? hyprpolkitagent then
            let service = cfg.systemd.user.services.hyprpolkitagent;
            in { inherit (service) wantedBy partOf unitConfig serviceConfig; }
            else null;
          executable = "${system.pkgs.hyprpolkitagent}/libexec/hyprpolkitagent";
        }''' % json.dumps(str(ROOT))
        result = subprocess.run(['nix', 'eval', '--json', '--impure', '--option',
                                 'allow-import-from-derivation', 'false', '--expr', expression],
                                capture_output=True, text=True, timeout=90)
        self.assertEqual(result.returncode, 0, result.stderr)
        data = json.loads(result.stdout)
        self.assertTrue(data['enabled'])
        agent = data['agent']
        self.assertIsNotNone(agent, 'Hyprland installs an agent but its session never starts it')
        self.assertIn('orgm-hyprland-session.target', agent['wantedBy'])
        self.assertIn('orgm-hyprland-session.target', agent['partOf'])
        self.assertEqual(agent['unitConfig']['ConditionEnvironment'], 'HYPRLAND_INSTANCE_SIGNATURE')
        self.assertEqual(agent['serviceConfig']['ExecStart'], data['executable'])
        self.assertEqual(agent['serviceConfig']['Restart'], 'on-failure')


if __name__ == '__main__':
    unittest.main()
