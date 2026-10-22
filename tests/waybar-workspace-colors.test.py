#!/usr/bin/env python3
"""Check real Gtk3 CSS cascade for Hyprland workspace states in private Sway."""
import ctypes as C
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
sway = os.environ.get('ORGM_TEST_SWAY') or shutil.which('sway')
gtk_path = os.environ.get('ORGM_TEST_GTK_LIBRARY')
if not sway or not gtk_path:
    print('SKIP: workspace colors require ORGM_TEST_SWAY and ORGM_TEST_GTK_LIBRARY')
    raise SystemExit(0)

with tempfile.TemporaryDirectory(prefix='workspace-css-') as tmp:
    home = Path(tmp)
    runtime = home/'r'
    runtime.mkdir(mode=0o700)
    (home/'sway.conf').write_text('xwayland disable\noutput HEADLESS-1 mode 640x480\n')
    env = dict(os.environ, HOME=tmp, XDG_RUNTIME_DIR=str(runtime), WLR_BACKENDS='headless',
               WLR_HEADLESS_OUTPUTS='1', WLR_RENDERER='gles2', WLR_RENDERER_ALLOW_SOFTWARE='1')
    for name in ('SWAYSOCK', 'WAYLAND_DISPLAY', 'WAYLAND_SOCKET', 'DISPLAY', 'DBUS_SESSION_BUS_ADDRESS'):
        env.pop(name, None)
    with (home/'log').open('w') as log:
        child = subprocess.Popen([sway, '-c', str(home/'sway.conf')], env=env,
                                 stdout=log, stderr=log, start_new_session=True)
        try:
            deadline = time.monotonic()+10
            display = None
            while time.monotonic() < deadline:
                display = next((p for p in runtime.glob('wayland-*') if p.is_socket()), None)
                if display:
                    break
                assert child.poll() is None, (home/'log').read_text()
                time.sleep(.05)
            assert display, 'private Sway did not start'
            os.environ.update(env, WAYLAND_DISPLAY=display.name, GDK_BACKEND='wayland')
            gtk = C.CDLL(gtk_path)

            def api(name, result, *args):
                f = getattr(gtk, name)
                f.restype, f.argtypes = result, list(args)
                return f

            ptr, string = C.c_void_p, C.c_char_p
            assert api('gtk_init_check', C.c_int, ptr, ptr)(None, None)
            window = api('gtk_window_new', ptr, C.c_int)(0)
            api('gtk_widget_set_name', None, ptr, string)(window, b'workspaces')
            box = api('gtk_box_new', ptr, C.c_int, C.c_int)(0, 0)
            api('gtk_container_add', None, ptr, ptr)(window, box)
            provider = api('gtk_css_provider_new', ptr)()
            style = ROOT/'dotfiles/config/profiles/hyprland/.config/waybar-hypr/style.css'
            assert api('gtk_css_provider_load_from_path', C.c_int, ptr, string, ptr)(provider, str(style).encode(), None)
            screen = api('gtk_widget_get_screen', ptr, ptr)(window)
            api('gtk_style_context_add_provider_for_screen', None, ptr, ptr, C.c_uint)(screen, provider, 600)

            class RGBA(C.Structure):
                _fields_ = [(key, C.c_double) for key in ('red', 'green', 'blue', 'alpha')]

            cases = [(['persistent'], '#f5f5f5'), (['persistent', 'empty'], '#b8b8b8'),
                     (['persistent', 'active'], '#8ab4f8'), (['persistent', 'empty', 'active'], '#8ab4f8')]
            buttons = []
            for classes, expected in cases:
                button = api('gtk_button_new_with_label', ptr, string)(b'1')
                api('gtk_container_add', None, ptr, ptr)(box, button)
                context = api('gtk_widget_get_style_context', ptr, ptr)(button)
                for cls in classes:
                    api('gtk_style_context_add_class', None, ptr, string)(context, cls.encode())
                buttons.append((context, classes, expected))
            api('gtk_widget_show_all', None, ptr)(window)
            while api('gtk_events_pending', C.c_int)():
                api('gtk_main_iteration', C.c_int)()
            for context, classes, expected in buttons:
                color = RGBA()
                api('gtk_style_context_get_color', None, ptr, C.c_uint, C.POINTER(RGBA))(context, 0, C.byref(color))
                actual = '#'+''.join(f'{round(v*255):02x}' for v in (color.red, color.green, color.blue))
                assert actual == expected, (classes, actual, expected)
            api('gtk_widget_destroy', None, ptr)(window)
            print('PASS: occupied white, empty gray, active blue (including empty active) in Gtk3')
        finally:
            if child.poll() is None:
                os.killpg(child.pid, signal.SIGTERM)
            child.wait(timeout=5)
