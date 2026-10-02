#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(THUNAR_TEST_ROOT="$ROOT" nix build --no-link --print-out-paths --impure --expr '
  let
    flake = builtins.getFlake ("path:" + builtins.getEnv "THUNAR_TEST_ROOT");
    system = flake.nixosConfigurations.jarq-i3;
    pkgs = system.pkgs;
    home = system.config.home-manager.users.jarq;
    thunar = builtins.head (builtins.filter
      (package: (package.pname or "") == "thunar") system.config.environment.systemPackages);
  in pkgs.writeText "i3-thunar-sort-fixture.json" (builtins.toJSON {
    activation = home.home.activation.xfconfSettings.data;
    thunar = toString thunar + "/bin/thunar";
    xfconf = toString pkgs.xfconf;
    xvfb = toString pkgs.xorg-server + "/bin/Xvfb";
    xdotool = toString pkgs.xdotool + "/bin/xdotool";
    xclip = toString pkgs.xclip + "/bin/xclip";
    dbus = toString pkgs.dbus;
    systemd = toString pkgs.systemd;
    gvfs = toString pkgs.gvfs;
    gio = toString pkgs.glib.bin + "/bin/gio";
  })
')"
python3 - "$fixture" <<'PY'
import json
import os
import pathlib
import re
import signal
import subprocess
import tempfile
import time
from urllib.parse import unquote, urlparse

fixture = json.loads(pathlib.Path(__import__('sys').argv[1]).read_text())
loader = re.search(r'(/nix/store/[^\s]+-load-xfconf)', fixture['activation']).group(1)
with tempfile.TemporaryDirectory(prefix='i3-thunar-sort-') as directory:
    root = pathlib.Path(directory)
    env = os.environ.copy()
    env.pop('DBUS_SESSION_BUS_ADDRESS', None)
    env.update(HOME=str(root), XDG_CONFIG_HOME=str(root/'config'), XDG_DATA_HOME=str(root/'data'),
               XDG_CACHE_HOME=str(root/'cache'), XDG_STATE_HOME=str(root/'state'),
               XDG_RUNTIME_DIR=str(root/'runtime'), GTK_USE_PORTAL='0', NO_AT_BRIDGE='1', GVFS_DISABLE_FUSE='1',
               XDG_DATA_DIRS=fixture['xfconf']+'/share:'+fixture['gvfs']+'/share')
    env.pop('GIO_USE_VFS', None)
    (root/'runtime').mkdir(mode=0o700)
    folders = [root/'Documents-one', root/'Documents-two']
    expected = ['m-newest.txt', 'z-middle.txt', 'a-oldest.txt']
    for folder in folders:
        folder.mkdir()
        for name, modified in [('a-oldest.txt', 1577836800), ('z-middle.txt', 1672531200), ('m-newest.txt', 1767225600)]:
            file = folder/name
            file.write_text(name)
            os.utime(file, (modified, modified))
    # Exclude ambient desktop portals: their FUSE mounts leak outside the fixture.
    bus_config = root/'bus.conf'
    bus_config.write_text('<busconfig><type>session</type><listen>unix:tmpdir=/tmp</listen><auth>EXTERNAL</auth>'
        + ''.join('<servicedir>'+fixture[pkg]+'/share/dbus-1/services</servicedir>' for pkg in ('xfconf', 'gvfs'))
        + '<policy context="default"><allow send_destination="*"/><allow receive_sender="*"/><allow own="*"/></policy></busconfig>')
    bus = subprocess.Popen([fixture['dbus']+'/bin/dbus-daemon', '--nofork', '--print-address=1', '--config-file='+str(bus_config)],
                           env=env, stdout=subprocess.PIPE, text=True)
    server = subprocess.Popen([fixture['xvfb'], '-displayfd', '1', '-screen', '0', '1000x700x24', '-nolisten', 'tcp'],
                              env=env, stdout=subprocess.PIPE, text=True)
    windows = []
    try:
        env['DBUS_SESSION_BUS_ADDRESS'] = bus.stdout.readline().strip()
        env['DISPLAY'] = ':'+server.stdout.readline().strip()
        def run(command, **kwargs):
            return subprocess.run(command, env=env, check=True, timeout=15, **kwargs)
        def bus_call(method, *args):
            return run([fixture['systemd']+'/bin/busctl', '--address='+env['DBUS_SESSION_BUS_ADDRESS'],
                        'call', 'org.freedesktop.DBus', '/org/freedesktop/DBus', 'org.freedesktop.DBus', method, *args],
                       capture_output=True, text=True).stdout.strip()
        # Seed conflicting old folder metadata, then apply the real HM loader.
        run([fixture['gio'], 'set', '-t', 'string', str(folders[0]), 'metadata::thunar-sort-column', 'THUNAR_COLUMN_NAME'])
        run([fixture['gio'], 'set', '-t', 'string', str(folders[0]), 'metadata::thunar-sort-order', 'GTK_SORT_ASCENDING'])
        run([loader])
        for index, folder in enumerate(folders):
            process = subprocess.Popen([fixture['thunar'], str(folder)], env=env)
            windows.append(process)
            window = run([fixture['xdotool'], 'search', '--sync', '--onlyvisible', '--name', folder.name],
                         capture_output=True, text=True).stdout.splitlines()[-1]
            run([fixture['xdotool'], 'windowfocus', window, 'key', 'ctrl+2'])
            # Copy all visible file rows; URI order is the real sorted selection.
            deadline = time.monotonic()+10
            observed = []
            while time.monotonic() < deadline:
                run([fixture['xdotool'], 'key', 'ctrl+a', 'ctrl+c'])
                result = subprocess.run([fixture['xclip'], '-selection', 'clipboard', '-o', '-target', 'text/uri-list'],
                                        env=env, capture_output=True, text=True, timeout=5)
                if result.returncode == 0:
                    observed = [pathlib.Path(unquote(urlparse(uri).path)).name
                                for uri in result.stdout.splitlines() if uri.startswith('file:')]
                    if len(observed) == len(expected):
                        break
                time.sleep(0.05)
            assert observed == expected, (folder.name, observed, expected)
            run([fixture['thunar'], '--quit'])
            process.wait(timeout=10)
            if index == 0:
                pid = int(bus_call('GetConnectionUnixProcessID', 's', 'org.xfce.Xfconf').split()[1])
                os.kill(pid, signal.SIGTERM)
                deadline = time.monotonic()+10
                while bus_call('NameHasOwner', 's', 'org.xfce.Xfconf') != 'b false':
                    if time.monotonic() > deadline:
                        raise RuntimeError('isolated Xfconf did not stop')
                    time.sleep(0.05)
        print('PASS: Thunar opens newest-first, ignores old folder sort metadata and persists across daemon restart')
    finally:
        subprocess.run([fixture['thunar'], '--quit'], env=env, timeout=10, check=False)
        for process in windows:
            if process.poll() is None:
                process.terminate()
            process.wait(timeout=10)
        server.terminate()
        server.wait(timeout=10)
        bus.terminate()
        bus.wait(timeout=10)
PY
