#!/usr/bin/env python3
"""Temporarily disable/restore Envy's broken built-in Up key, without root.

The persistent equivalent is keyboard.nix. This helper changes only scan
code 0xc8 on the model-specific AT keyboard; it never grabs input or logs text.
Access requires the existing input group permissions.
"""
import argparse
import fcntl
import json
import os
from pathlib import Path
import struct

DEVICE = '/dev/input/by-path/platform-i8042-serio-0-event-kbd'
MODEL = 'HP ENVY Laptop 17m-ce1xxx'
ENTRY = struct.Struct('=BBHI32s')
SCAN_CODE = 0xC8
KEY_UP = 103
KEY_RESERVED = 0


def ioctl_code(direction, number, size):
    return (direction << 30) | (size << 16) | (ord('E') << 8) | number


def key_entry(keycode=0):
    scan = SCAN_CODE.to_bytes(4, 'little').ljust(32, b'\0')
    return bytearray(ENTRY.pack(0, 4, 0, keycode, scan))


def current_keycode(fd):
    entry = key_entry()
    fcntl.ioctl(fd, ioctl_code(2, 4, ENTRY.size), entry, True)
    return ENTRY.unpack(entry)[3]


def up_pressed(fd):
    bitmap = bytearray(96)
    fcntl.ioctl(fd, ioctl_code(2, 0x18, len(bitmap)), bitmap, True)
    return bool(bitmap[KEY_UP // 8] & (1 << (KEY_UP % 8)))


def apply(action):
    if Path('/sys/devices/virtual/dmi/id/product_name').read_text().strip() != MODEL:
        raise RuntimeError('Refusing to modify a keyboard on a different laptop model')
    mode = os.O_RDONLY if action == 'status' else os.O_RDWR
    fd = os.open(DEVICE, mode | os.O_CLOEXEC)
    try:
        name = bytearray(256)
        fcntl.ioctl(fd, ioctl_code(2, 6, len(name)), name, True)
        if bytes(name).split(b'\0', 1)[0] != b'AT Translated Set 2 keyboard':
            raise RuntimeError('Not the expected built-in AT keyboard')
        before = current_keycode(fd)
        if before not in (KEY_RESERVED, KEY_UP):
            raise RuntimeError(f'Scan code has another custom mapping ({before}); refusing to overwrite it')
        if action != 'status':
            target = KEY_RESERVED if action == 'disable' else KEY_UP
            fcntl.ioctl(fd, ioctl_code(1, 4, ENTRY.size), key_entry(target), True)
            if current_keycode(fd) != target:
                raise RuntimeError('Kernel keymap verification failed')
        result = dict(device=DEVICE, scancode=hex(SCAN_CODE), before=before,
                      keycode=current_keycode(fd), up_pressed=up_pressed(fd))
        if action == 'disable' and result['up_pressed']:
            raise RuntimeError('Mapping changed, but the kernel still reports Up pressed')
        return result
    finally:
        os.close(fd)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('status', 'disable', 'restore'))
    args = parser.parse_args()
    try:
        print(json.dumps(apply(args.action)))
    except (OSError, RuntimeError) as error:
        parser.exit(1, f'{error}\n')


if __name__ == '__main__':
    main()
