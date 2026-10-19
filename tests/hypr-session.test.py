#!/usr/bin/env python3
"""Session lifetime follows a private compositor event socket, not the real user bus."""
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT/'dotfiles/config/profiles/hyprland/.local/bin/orgm-hyprland-session'


class Session(unittest.TestCase):
    def test_disconnect_stops_only_our_session_target(self):
        self.assertTrue(HELPER.is_file(), 'session supervisor missing')
        with tempfile.TemporaryDirectory(prefix='hs-') as tmp:
            base = Path(tmp)
            endpoint = base/'hypr/test/.socket2.sock'
            endpoint.parent.mkdir(parents=True)
            log = base/'calls'
            binary = base/'bin'
            binary.mkdir()
            for name in ('systemctl', 'hypr-session-import-env'):
                p = binary/name
                p.write_text('#!/usr/bin/env python3\nimport pathlib,sys,json\n'
                    f'with pathlib.Path({str(log)!r}).open("a") as f: f.write(json.dumps(sys.argv[1:])+"\\n")\n')
                p.chmod(0o755)
            server = socket.socket(socket.AF_UNIX)
            server.bind(str(endpoint))
            server.listen()
            server.settimeout(5)
            env = dict(os.environ, XDG_RUNTIME_DIR=tmp, HYPRLAND_INSTANCE_SIGNATURE='test',
                       PATH=str(binary)+os.pathsep+os.environ['PATH'])
            process = subprocess.Popen([str(HELPER)], env=env)
            try:
                peer, _ = server.accept()
                peer.sendall(b'workspace>>2\n')
                peer.close()
                self.assertEqual(process.wait(timeout=5), 0)
                calls = [json.loads(line) for line in log.read_text().splitlines()]
                self.assertIn(['--user', 'start', 'orgm-hyprland-session.target'], calls)
                self.assertEqual(calls[-1], ['--user', 'stop', 'orgm-hyprland-session.target'])
            finally:
                server.close()
                if process.poll() is None:
                    process.terminate()
                    process.wait(timeout=3)


if __name__ == '__main__':
    unittest.main()
