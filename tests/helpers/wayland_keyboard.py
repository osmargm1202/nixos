"""Virtual keyboard with real evdev keycodes, on an explicit private connection.

wtype's compact, dynamically numbered keymap can trigger the wrong Hyprland
binding when the compositor resolves keys against its primary evdev keymap.
"""
import array
import ctypes as C
import glob
import os
import socket
import struct
import time


class Keyboard:
    def __init__(self, connection):
        self.connection = connection

        def bind(interface):
            object_id = connection.next_id
            connection.next_id += 1
            encoded = interface.encode()+b'\0'
            name = struct.pack('=I', len(encoded))+encoded+b'\0'*(-len(encoded) % 4)
            connection.send(2, 0, struct.pack('=I', connection.globals[interface])
                            +name+struct.pack('=II', 1, object_id))
            return object_id

        manager = bind('zwp_virtual_keyboard_manager_v1')
        seat = bind('wl_seat')
        self.object_id = connection.next_id
        connection.next_id += 1
        connection.send(manager, 0, struct.pack('=II', seat, self.object_id))
        xkb = C.CDLL(glob.glob('/nix/store/*-libxkbcommon-*/lib/libxkbcommon.so.0')[0])
        xkb.xkb_context_new.restype = C.c_void_p
        xkb.xkb_keymap_new_from_names.argtypes = [C.c_void_p, C.c_void_p, C.c_int]
        xkb.xkb_keymap_new_from_names.restype = C.c_void_p
        xkb.xkb_keymap_get_as_string.argtypes = [C.c_void_p, C.c_int]
        xkb.xkb_keymap_get_as_string.restype = C.c_void_p
        xkb.xkb_keymap_unref.argtypes = [C.c_void_p]
        xkb.xkb_context_unref.argtypes = [C.c_void_p]
        context = xkb.xkb_context_new(0)
        keymap = xkb.xkb_keymap_new_from_names(context, None, 0)
        assert keymap, 'compile full evdev keyboard keymap'
        string = xkb.xkb_keymap_get_as_string(keymap, 1)
        data = C.string_at(string)+b'\0'
        libc = C.CDLL(None)
        libc.free.argtypes = [C.c_void_p]
        libc.free(string)
        xkb.xkb_keymap_unref(keymap)
        xkb.xkb_context_unref(context)
        fd = os.memfd_create('private-test-keymap')
        try:
            os.write(fd, data)
            body = struct.pack('=II', 1, len(data))
            header = struct.pack('=II', self.object_id, (len(body)+8) << 16)
            connection.socket.sendmsg([header+body], [(socket.SOL_SOCKET, socket.SCM_RIGHTS, array.array('i', [fd]))])
            self.sync()
        finally:
            os.close(fd)

    def sync(self):
        self.connection.sync(self.connection.next_id)
        self.connection.next_id += 1

    def key(self, code, pressed):
        self.connection.send(self.object_id, 1, struct.pack('=III', int(time.monotonic()*1000) & 0xffffffff,
                                                           code, int(pressed)))
        self.sync()

    def modifiers(self, depressed):
        self.connection.send(self.object_id, 2, struct.pack('=IIII', depressed, 0, 0, 0))
        self.sync()
