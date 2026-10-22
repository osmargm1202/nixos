#!/usr/bin/env python3
"""Effective Lua reservation and actual GTK dock background, in a private display."""
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]


class Dock(unittest.TestCase):
    def test_exclusive_dock_does_not_get_a_second_manual_gap(self):
        lua = os.environ.get('ORGM_TEST_LUA') or shutil.which('lua')
        if not lua:
            self.skipTest('Lua interpreter unavailable')
        script = '''local root=arg[1]
          package.path=root.."/dotfiles/config/profiles/hyprland/.config/hypr/?.lua;"..package.path
          local general
          hl={config=function(c) general=c.general end, curve=function() end, animation=function() end}
          require("lua.look-and-feel")
          local gaps=general.gaps_out
          if type(gaps)=="table" then
            assert(gaps.right==gaps.left and gaps.right==gaps.bottom,
              "exclusive-zone dock must not get an extra manual right reservation")
          end
        '''
        with tempfile.TemporaryDirectory() as tmp:
            result=subprocess.run([lua, '-', str(ROOT)], input=script, text=True, capture_output=True,
                                  env=dict(os.environ, XDG_STATE_HOME=tmp, XDG_CONFIG_HOME=tmp))
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)

    def test_gtk_window_and_box_are_transparent_not_just_buttons(self):
        python = os.environ.get('ORGM_TEST_GTK_PYTHON')
        sway = os.environ.get('ORGM_TEST_SWAY') or shutil.which('sway')
        if not python or not sway:
            self.skipTest('Requires cached Gtk3 Python and private Sway')
        with tempfile.TemporaryDirectory(prefix='dock-style-') as tmp:
            home=Path(tmp); runtime=home/'r'; runtime.mkdir(mode=0o700)
            (home/'sway.conf').write_text('xwayland disable\noutput HEADLESS-1 mode 640x480\n')
            env=dict(os.environ, HOME=tmp, XDG_RUNTIME_DIR=str(runtime), WLR_BACKENDS='headless',
                     WLR_HEADLESS_OUTPUTS='1', WLR_RENDERER='gles2', WLR_RENDERER_ALLOW_SOFTWARE='1',
                     GDK_BACKEND='wayland', GTK_THEME='Adwaita:dark')
            for key in ['SWAYSOCK','WAYLAND_DISPLAY','DISPLAY','DBUS_SESSION_BUS_ADDRESS','WAYLAND_SOCKET']:
                env.pop(key,None)
            intel=Path('/dev/dri/by-path/pci-0000:00:02.0-render')
            if intel.exists():env['WLR_RENDER_DRM_DEVICE']=str(intel.resolve())
            with (home/'log').open('w') as log:
                compositor=subprocess.Popen([sway,'-c',str(home/'sway.conf')],env=env,
                                            stdout=log,stderr=log,start_new_session=True)
                try:
                    deadline=time.monotonic()+10
                    while time.monotonic()<deadline:
                        display=next((p for p in runtime.glob('wayland-*') if p.is_socket()),None)
                        if display:break
                        assert compositor.poll() is None,(home/'log').read_text()
                        time.sleep(.05)
                    assert display,'private display did not start'
                    env['WAYLAND_DISPLAY']=display.name
                    script='''import gi,sys
gi.require_version("Gtk","3.0")
from gi.repository import Gtk
provider=Gtk.CssProvider();provider.load_from_path(sys.argv[1])
window=Gtk.Window();box=Gtk.Box();box.set_name("box");window.add(box)
Gtk.StyleContext.add_provider_for_screen(window.get_screen(),provider,Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
window.show_all()
while Gtk.events_pending():Gtk.main_iteration()
for name,widget in [("dock window",window),("dock box",box)]:
 color=widget.get_style_context().get_background_color(Gtk.StateFlags.NORMAL)
 assert color.alpha==0,(name,color.to_string())
print("PASS: actual Gtk3 dock window and box alpha=0")
window.destroy()
'''
                    style=ROOT/'dotfiles/config/profiles/hyprland/.config/nwg-dock-hyprland/style.css'
                    result=subprocess.run([python,'-',str(style)],input=script,text=True,env=env,
                                          capture_output=True,timeout=10)
                    self.assertEqual(result.returncode,0,result.stdout+result.stderr)
                finally:
                    if compositor.poll() is None:
                        os.killpg(compositor.pid,signal.SIGTERM);compositor.wait(timeout=5)


if __name__=='__main__':unittest.main()
