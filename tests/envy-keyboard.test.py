#!/usr/bin/env python3
"""Check the hardware workaround without touching real keyboard devices."""
import fnmatch
from pathlib import Path
import runpy
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent.parent
MODULE = runpy.run_path(str(ROOT / 'nixos/hosts/envy/keyboard-up.py'))
ENV = MODULE['apply'].__globals__


class EnvyKeyboard(unittest.TestCase):
    def exercise(self, action, initial=103, name=b'AT Translated Set 2 keyboard'):
        state = {'code': initial, 'writes': []}
        entry = MODULE['ENTRY']
        ioc = MODULE['ioctl_code']

        def ioctl(fd, request, buffer, mutate):
            self.assertEqual(fd, 77)
            if request == ioc(2, 6, 256):
                buffer[:len(name)] = name
            elif request == ioc(2, 4, entry.size):
                buffer[:] = MODULE['key_entry'](state['code'])
            elif request == ioc(1, 4, entry.size):
                flags, length, index, keycode, scan = entry.unpack(buffer)
                self.assertEqual((flags, length, index), (0, 4, 0))
                self.assertEqual(int.from_bytes(scan[:length], 'little'), 0xC8)
                state['writes'].append(keycode)
                state['code'] = keycode
            elif request == ioc(2, 0x18, 96):
                if state['code'] == 103:
                    buffer[103 // 8] |= 1 << (103 % 8)
            else:
                self.fail(f'Unexpected ioctl: {request:#x}')

        with patch.object(Path, 'read_text', return_value=MODULE['MODEL']), \
             patch.object(ENV['os'], 'open', return_value=77), \
             patch.object(ENV['os'], 'close') as close, \
             patch.object(ENV['fcntl'], 'ioctl', side_effect=ioctl):
            try:
                result = MODULE['apply'](action)
            finally:
                close.assert_called_once_with(77)
        return result, state

    def test_disable_maps_only_up_to_reserved_and_releases_pressed_state(self):
        result, state = self.exercise('disable')
        self.assertEqual(result['before'], 103)
        self.assertEqual(result['keycode'], 0)
        self.assertFalse(result['up_pressed'])
        self.assertEqual(state['writes'], [0])

    def test_restore_is_reversible(self):
        result, state = self.exercise('restore', initial=0)
        self.assertEqual(result['keycode'], 103)
        self.assertEqual(state['writes'], [103])

    def test_status_does_not_write(self):
        result, state = self.exercise('status')
        self.assertTrue(result['up_pressed'])
        self.assertEqual(state['writes'], [])

    def test_refuses_to_overwrite_another_custom_mapping(self):
        with self.assertRaisesRegex(RuntimeError, 'another custom mapping'):
            self.exercise('disable', initial=42)

    def test_wrong_keyboard_is_not_modified(self):
        with self.assertRaisesRegex(RuntimeError, 'expected built-in'):
            self.exercise('disable', name=b'USB keyboard')

    def test_other_laptop_models_are_rejected_before_opening_device(self):
        with patch.object(Path, 'read_text', return_value='Other laptop'), \
             patch.object(ENV['os'], 'open') as open_device:
            with self.assertRaisesRegex(RuntimeError, 'different laptop model'):
                MODULE['apply']('disable')
            open_device.assert_not_called()

    def test_hwdb_targets_only_this_models_at_keyboard(self):
        text = (ROOT / 'nixos/hosts/envy/keyboard.nix').read_text()
        match = next(line.strip() for line in text.splitlines() if 'evdev:atkbd:' in line)
        self.assertIn('KEYBOARD_KEY_c8=reserved', text)
        dmi = 'dmi:bvnInsyde:bvrF.05:bd05/28/2020:br15.5:efr84.15:svnHP:pnHPENVYLaptop17m-ce1xxx:pvrType1ProductConfigId:'
        self.assertTrue(fnmatch.fnmatchcase('evdev:atkbd:' + dmi, match))
        self.assertFalse(fnmatch.fnmatchcase('evdev:input:b0003v3151p3020e0111', match))
        self.assertFalse(fnmatch.fnmatchcase('evdev:atkbd:' + dmi.replace('17m-ce1xxx', 'OtherModel'), match))


if __name__ == '__main__':
    unittest.main()
