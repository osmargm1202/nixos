#!/usr/bin/env python3
"""Exercise boot entry migration in a private ESP, including bootctl's order."""
import json
import os
from pathlib import Path
import runpy
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent.parent
order_entries = runpy.run_path(str(ROOT/'nixos/hosts/envy/boot-menu-order.py'))['order_entries']


class BootOrder(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.esp = Path(self.temporary.name)
        self.entries = self.esp/'loader/entries'
        self.entries.mkdir(parents=True)
        (self.esp/'EFI/nixos').mkdir(parents=True)
        (self.esp/'EFI/nixos/linux.efi').touch()

    def entry(self, generation, mode='normal', key='nixos-00-normal'):
        name = f'nixos-generation-{generation}'
        if mode != 'normal':
            name += '-specialisation-' + mode
        path = self.entries/(name + '.conf')
        path.write_text(f'title NixOS ({mode})\nsort-key {key}\n'
                        f'version Generation {generation} Build date\n'
                        'linux /EFI/nixos/linux.efi\ninitrd /EFI/nixos/initrd.efi\n'
                        'options init=/nix/store/original/init quiet\n')
        path.chmod(0o640)
        return path

    def test_old_generation_entries_migrate_without_changing_boot_content(self):
        originals = {}
        expected = []
        for generation in [100, 10, 9]:
            for index, mode in enumerate(['normal', 'windows-vfio', 'gaming', 'server']):
                path = self.entry(generation, mode, f'nixos-{index:02d}-{mode}')
                originals[path] = path.read_text()
                expected.append(path.name)
        order_entries(self.entries)
        keys = {}
        for path, original in originals.items():
            current = path.read_text()
            without_key = lambda text: [line for line in text.splitlines() if not line.startswith('sort-key ')]
            self.assertEqual(without_key(current), without_key(original))
            self.assertEqual(path.stat().st_mode & 0o777, 0o640)
            keys[path.name] = next(line[9:] for line in current.splitlines() if line.startswith('sort-key '))
        self.assertEqual(sorted(keys, key=keys.get), expected)
        before = {path: (path.read_bytes(), path.stat().st_mtime_ns) for path in originals}
        order_entries(self.entries)
        self.assertEqual(before, {path: (path.read_bytes(), path.stat().st_mtime_ns) for path in originals})

    @unittest.skipUnless(shutil.which('bootctl'), 'systemd bootctl unavailable')
    def test_native_bootctl_lists_each_generation_in_requested_order(self):
        expected = []
        for generation in [100, 10, 9]:
            for mode in ['normal', 'windows-vfio', 'gaming', 'server']:
                expected.append(self.entry(generation, mode).name)
        order_entries(self.entries)
        # These documented systemd overrides select a private ESP without mounting it.
        env = dict(os.environ, SYSTEMD_ESP_PATH=str(self.esp), SYSTEMD_XBOOTLDR_PATH=str(self.esp))
        result = subprocess.run(['bootctl', '--no-variables', '--json=short', 'list'],
                                env=env, text=True, capture_output=True, check=True)
        self.assertEqual([entry['id'] for entry in json.loads(result.stdout)], expected)

    def test_other_os_profiles_and_symlinks_are_untouched(self):
        self.entry(10)
        originals = {}
        loader = self.esp/'loader/loader.conf'
        loader.write_text('timeout 1\ndefault nixos-generation-10.conf\n')
        originals[loader] = loader.read_bytes()
        for name in ['windows.conf', 'nixos-other-generation-99.conf']:
            path = self.entries/name
            path.write_text('title Other\nsort-key original\n')
            originals[path] = path.read_bytes()
        outside = self.esp/'outside.conf'
        outside.write_text('title External\nsort-key original\n')
        (self.entries/'nixos-generation-999.conf').symlink_to(outside)
        order_entries(self.entries)
        for path, content in originals.items():
            self.assertEqual(path.read_bytes(), content)
        self.assertEqual(outside.read_text(), 'title External\nsort-key original\n')
        self.assertTrue((self.entries/'nixos-generation-999.conf').is_symlink())


if __name__ == '__main__':
    unittest.main()
