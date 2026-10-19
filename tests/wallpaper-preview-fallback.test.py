#!/usr/bin/env python3
"""Real Qt/FFmpeg preview fallback with an isolated HOME and offscreen window.

ORGM_TEST_FFMPEG selects ffmpeg when it is not installed on PATH. The visual
picker runs unchanged; only its layer-shell host is replaced by an offscreen
Window because this test exercises image decoding, not compositor input.
"""
import json
import hashlib
import os
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import time
import unittest
import zlib

ROOT = Path(__file__).resolve().parents[1]
FFMPEG = os.environ.get('ORGM_TEST_FFMPEG') or shutil.which('ffmpeg')
QS = os.environ.get('ORGM_TEST_QS') or shutil.which('qs')


@unittest.skipUnless(FFMPEG and QS, 'requires Quickshell and FFmpeg')
class PreviewFallbackTests(unittest.TestCase):
    def test_qt_rejected_png_and_video_get_bounded_posters(self):
        with tempfile.TemporaryDirectory(prefix='wallpaper-fallback-') as directory:
            home = Path(directory)
            ui = home/'ui'
            shutil.copytree(ROOT/'dotfiles/config/profiles/wayland/.config/quickshell/orgm-wallpapers', ui)
            (ui/'components/MenuWindow.qml').write_text('''import QtQuick
import Quickshell
FloatingWindow {
    implicitWidth: 1280; implicitHeight: 800
    property bool open: false
    property bool busy: false
    property real progress: open ? 1 : 0
    signal keyPressed(var event)
    signal dismissed()
    function reset() {}
    function show() { reset(); open = true; visible = true }
}
''')
            # 1200x1200 RGBA exceeds the test's 4 MiB Qt allocation limit;
            # its 800x800 poster fits. No hundreds-of-MiB fixture is needed.
            def chunk(kind, data):
                return struct.pack('!I', len(data))+kind+data+struct.pack('!I', zlib.crc32(kind+data))
            image = home/'large.png'
            image.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR', struct.pack('!2I5B', 1200,1200,8,6,0,0,0))
                +chunk(b'IDAT', zlib.compress((b'\0'+b'\xff\x40\x20\xff'*1200)*1200))+chunk(b'IEND', b''))
            original = hashlib.sha256(image.read_bytes()).digest()
            video = home/'movie.mp4'
            subprocess.run([FFMPEG, '-nostdin', '-v', 'error', '-f', 'lavfi', '-i',
                            'color=blue:size=320x200:rate=1', '-t', '1', str(video)], check=True)
            tools = home/'bin'
            tools.mkdir()
            (tools/'ffmpeg').symlink_to(FFMPEG)
            runtime = home/'runtime'
            runtime.mkdir(mode=0o700)
            data = home/'catalog.json'
            data.write_text(json.dumps(dict(backend=str(ROOT/'dotfiles/config/profiles/sway/.local/bin/orgm-sway'),
                items=[dict(path=str(p), url=p.as_uri(), name=p.name, kind=kind)
                       for p,kind in ((image,'image'), (video,'video'))])))
            env = dict(os.environ, HOME=str(home), XDG_CACHE_HOME=str(home/'cache'),
                       XDG_STATE_HOME=str(home/'state'), XDG_CONFIG_HOME=str(home/'config'),
                       XDG_RUNTIME_DIR=str(runtime), QT_QPA_PLATFORM='offscreen',
                       QT_IMAGEIO_MAXALLOC='4', ORGM_WALLPAPER_DATA=str(data),
                       ORGM_WALLPAPER_STATUS=str(home/'startup'),
                       DBUS_SESSION_BUS_ADDRESS='unix:path='+str(home/'no-bus'),
                       PATH=str(tools)+':'+os.environ['PATH'])
            with (home/'log').open('w+') as log:
                process = subprocess.Popen([QS, '--path', str(ui)], env=env, stdout=log, stderr=log)
                try:
                    deadline = time.monotonic()+15
                    state = {}
                    while time.monotonic() < deadline:
                        if process.poll() is not None:
                            break
                        result = subprocess.run([QS, '--path', str(ui), 'ipc', 'call', 'wallpaper', 'status'],
                                                env=env, capture_output=True, text=True, timeout=3)
                        if result.returncode == 0:
                            state = json.loads(result.stdout)
                            if len(state['previews']) == 2 and all(p['ready'] for p in state['previews']):
                                break
                        time.sleep(.1)
                    log.flush()
                    log.seek(0)
                    messages = log.read()
                    self.assertIn('allocation limit of 4 megabytes', messages)
                    self.assertEqual([p['ready'] for p in state.get('previews', [])], [True, True], messages)
                    self.assertEqual([p['failed'] for p in state['previews']], [False, False])
                    self.assertEqual(hashlib.sha256(image.read_bytes()).digest(), original)
                finally:
                    process.terminate()
                    process.wait(timeout=5)


if __name__ == '__main__':
    unittest.main()
