#!/usr/bin/env python3
"""Exercise lock dispatch, managed Rofi and browser focus on a private display."""
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT/'nixos/apps/browser-launch.sh'
r = subprocess.run(['nix', 'build', '--no-link', '--print-out-paths',
    f'path:{ROOT}#nixosConfigurations.orgm.config.home-manager.users.osmarg.xdg.configFile."i3/orgm-minimal.conf".source'],
    capture_output=True, text=True, check=True)
content = Path(r.stdout.strip()).read_text()
lock = next(line for line in content.splitlines() if line.startswith('bindsym $mod+l '))
match = re.fullmatch(
    r'bindsym \$mod\+l exec --no-startup-id (\S+/bin/i3lock-color) --fill -i (\S+-i3-lock-background\.png)',
    lock,
)
assert match and Path(match[1]).is_file() and Path(match[2]).is_file(), lock
rule = next(line for line in content.splitlines() if line.startswith('for_window [class="(?i)^rofi$"]'))

with tempfile.TemporaryDirectory(prefix='i3-actions-') as temporary:
    t = Path(temporary)
    env = dict(os.environ, HOME=str(t), XDG_CONFIG_HOME=str(t/'config'),
               XDG_RUNTIME_DIR=str(t), XDG_CURRENT_DESKTOP='i3', XDG_SESSION_TYPE='x11',
               LIBGL_ALWAYS_SOFTWARE='1', DBUS_SESSION_BUS_ADDRESS='unix:path='+str(t/'no-bus'))
    for key in ['DISPLAY', 'XAUTHORITY', 'I3SOCK', 'WAYLAND_DISPLAY', 'SWAYSOCK', 'HYPRLAND_INSTANCE_SIGNATURE']:
        env.pop(key, None)
    locklog = t/'lock-request'
    lockstub = t/'lock-stub'
    lockstub.write_text(f'#!/bin/sh\nprintf "%s\\n" "$@" > {locklog}\n')
    lockstub.chmod(0o755)
    browserlog = t/'browser-launches'
    browserstub = t/'browser-stub'
    browserstub.write_text(f'#!/bin/sh\nprintf "launch\\n" >> {browserlog}\n')
    browserstub.chmod(0o755)
    env.update(ORGM_BROWSER_EXECUTABLE=str(browserstub), ORGM_BROWSER_ZENITY='false')
    ipc = t/'ipc.sock'
    config = t/'i3.conf'
    config.write_text(f'font pango:monospace 10\nset $mod Mod4\nipc-socket {ipc}\nfocus_follows_mouse no\n'
        + lock.replace(match[1], str(lockstub))+'\n'+rule+'\n'
        + f'bindsym $mod+w exec --no-startup-id bash -euo pipefail {SOURCE} --restore-or-focus\n')
    children = []
    log = (t/'session.log').open('w')

    def start(args, **kwargs):
        p = subprocess.Popen(args, env=env, stderr=log, start_new_session=True, **kwargs)
        children.append(p)
        return p

    def wait(probe, label):
        deadline = time.monotonic()+10
        while time.monotonic() < deadline:
            value = probe()
            if value:
                return value
            time.sleep(.04)
        raise AssertionError(label+'\n'+(t/'session.log').read_text()[-3000:])

    def tree():
        return json.loads(subprocess.check_output(['i3-msg', '-s', str(ipc), '-t', 'get_tree'], env=env, text=True))

    def nodes(n):
        yield n
        for child in n.get('nodes', [])+n.get('floating_nodes', []):
            yield from nodes(child)

    def window(cls):
        return next((n for n in nodes(tree()) if n.get('window_properties', {}).get('class') == cls), None)

    def command(text):
        reply = json.loads(subprocess.check_output(['i3-msg', '-r', '-s', str(ipc), text], env=env, text=True))
        assert all(r['success'] for r in reply), reply

    try:
        server = start(['Xvfb', '-displayfd', '1', '-screen', '0', '1024x768x24', '-nolisten', 'tcp'], stdout=subprocess.PIPE, text=True)
        env['DISPLAY'] = ':'+server.stdout.readline().strip()
        wm = start(['i3', '-c', str(config)], stdout=log)
        wait(ipc.exists, 'private i3 socket')
        env['I3SOCK'] = str(ipc)
        for index, cls in enumerate(['control', 'Brave-origin', 'brave-fixture-Default']):
            start(['kitty', '--config', 'NONE', '--class', cls, '-o', 'linux_display_server=x11',
                   '-o', 'confirm_os_window_close=0', 'sh', '-c', 'sleep 100'], stdout=log)
            w = wait(lambda: window(cls), 'fixture '+cls)
            command(f'[con_id={w["id"]}] move container to workspace number {index+1}')
        control = window('control')['id']
        command(f'[con_id={control}] focus')
        # Key dispatch is real; its lock executable is replaced only in the
        # private fixture. No password prompt or real desktop lock is invoked.
        subprocess.run(['xdotool', 'key', '--clearmodifiers', 'super+l'], env=env, check=True)
        wait(locklog.exists, 'Win+L dispatch')
        assert locklog.read_text().splitlines() == ['--fill', '-i', match[2]]
        subprocess.run(['xdotool', 'key', '--clearmodifiers', 'super+w'], env=env, check=True)
        wait(lambda: window('Brave-origin')['focused'], 'Win+W focuses browser across workspaces')
        assert not browserlog.exists(), 'existing browser was launched again'
        command(f'[con_id={control}] focus')
        subprocess.run(['bash', '-euo', 'pipefail', str(SOURCE), '--focus'], env=env, check=True)
        assert window('Brave-origin')['focused'] and not browserlog.exists()
        # URL-app windows share the process but must not masquerade as the browser.
        command(f'[con_id={window("Brave-origin")["id"]}] kill')
        wait(lambda: window('Brave-origin') is None, 'close private browser fixture')
        subprocess.run(['bash', '-euo', 'pipefail', str(SOURCE), '--restore-or-focus'], env=env, check=True)
        assert browserlog.read_text() == 'launch\n'
        menu = start(['rofi', '-no-config', '-normal-window', '-dmenu', '-p', 'Fixture'], stdin=subprocess.PIPE, stdout=log, text=True)
        menu.stdin.write('Apps\nPower\n');menu.stdin.close()
        w = wait(lambda: next((n for n in nodes(tree()) if (n.get('window_properties', {}).get('class') or '').lower() == 'rofi'), None), 'managed Rofi menu')
        assert w['floating'] in ['auto_on', 'user_on'] and w['fullscreen_mode'] == 0, w['floating']
        print('PASS: Win+L dispatches lock; Win+W focuses an existing main browser or opens it, excluding webapps; Rofi normal-window floats')
    finally:
        for p in reversed(children):
            if p.poll() is None:
                os.killpg(p.pid, signal.SIGTERM)
                try:p.wait(timeout=5)
                except subprocess.TimeoutExpired:os.killpg(p.pid,signal.SIGKILL);p.wait()
        log.close()
