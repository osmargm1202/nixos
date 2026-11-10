#!/usr/bin/env python3
"""Exercise the menu contract and real callers without touching user data."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
menu = root / 'nixos/profiles/gnome/menu.sh'
with tempfile.TemporaryDirectory(prefix='gnome-menus-') as tmp:
    work = Path(tmp)
    binary = work / 'bin'
    binary.mkdir()
    (binary / 'zenity').write_text('''#!/usr/bin/env python3
import json,os,sys
from pathlib import Path
Path(os.environ['CAPTURE']).write_text(json.dumps({'args':sys.argv[1:],'stdin':sys.stdin.read()}))
print(os.environ.get('ANSWER',''))
sys.exit(int(os.environ.get('STATUS','0')))
''')
    (binary / 'zenity').chmod(0o755)
    env = dict(os.environ, PATH=f'{binary}:'+os.environ['PATH'], CAPTURE=str(work/'capture'), ANSWER='1')
    def run(args, data='', **extra):
        return subprocess.run(['bash', str(menu), *args], input=data, text=True, capture_output=True, env=env | extra)
    payload = '10\tduplicado\n20\tduplicado\n$(touch SHOULD_NOT_EXIST) <b>texto</b>\n'
    r = run(['-dmenu','-no-custom','-p','Lista'], payload)
    assert r.returncode == 0 and r.stdout == '20\tduplicado\n', r
    captured = json.loads((work/'capture').read_text())
    assert '--list' in captured['args'] and '--print-column=1' in captured['args']
    assert 'duplicado' not in ' '.join(captured['args']), 'values must not leak into argv'
    r = run(['-dmenu','-format','i'], payload)
    assert r.stdout == '1\n'
    r = run(['-dmenu','-password','-p','Clave'], ANSWER='dummy-private')
    assert r.returncode == 0 and r.stdout == 'dummy-private\n'
    captured = json.loads((work/'capture').read_text())
    assert '--hide-text' in captured['args'] and 'dummy-private' not in str(captured)
    r = run(['-dmenu'], 'first\nsecond\n', STATUS='1', ANSWER='0')
    assert r.returncode == 1 and r.stdout == '', 'cancel must never select a row'
    for invalid in ('500', '-1', '1|0', 'arbitrary'):
        r = run(['-dmenu'], payload, ANSWER=invalid)
        assert r.returncode == 1 and not r.stdout
    assert run(['-dmenu','-only-match'], '').returncode == 1
    assert run(['-unsupported']).returncode == 2
    # Verify a GNOME bookmark action copies text without injecting keystrokes.
    for name, code in {
        'orgm-menu': 'cat >/dev/null; printf "elegido\\n"',
        'wl-copy': 'cat > "$COPIED"',
        'notify-send': 'exit 0',
        'wtype': 'exit 99',
        'rofi': 'exit 98',
    }.items():
        p = binary/name
        p.write_text('#!/bin/sh\n'+code+'\n')
        p.chmod(0o755)
    (work/'.bookmarks').write_text('elegido\n')
    env |= {'HOME':str(work), 'XDG_CURRENT_DESKTOP':'ubuntu:GNOME', 'COPIED':str(work/'copied')}
    script = root/'dotfiles/config/users/osmarg/common/.local/bin/bookmark_to_type'
    r = subprocess.run(['bash',str(script)], cwd=work, env=env, capture_output=True, text=True)
    assert r.returncode == 0 and (work/'copied').read_text() == 'elegido', r
    # GNOME history operations must use the existing indicator, never cliphist.
    p = binary/'orgm-clipboard-menu'; p.write_text('#!/bin/sh\nexit 0\n'); p.chmod(0o755)
    for name in ('clipboard_to_type','clipboard_to_wlcopy','clipboard_delete_item'):
        r = subprocess.run(['bash',str(script.with_name(name))], cwd=work, env=env, capture_output=True, text=True)
        assert r.returncode == 0 and not r.stderr, r
    # GNOME visual profiles use GSettings, never compositor commands or real processes.
    picture = work/'wall paper.png'
    picture.write_bytes(b'fixture')
    for name, code in {
        'pgrep': 'exit 1', 'i3-msg': 'exit 99', 'hyprctl': 'exit 99',
        'gsettings': 'if [ "$1" = get ]; then printf "\\047%s\\047\\n" "$WALLPAPER_URI"; else printf "%s\\n" "$*" >> "$SETTINGS_LOG"; fi',
    }.items():
        p = binary/name; p.write_text('#!/bin/sh\n'+code+'\n'); p.chmod(0o755)
    env |= {'XDG_CONFIG_HOME':str(work/'config'), 'XDG_STATE_HOME':str(work/'state'),
            'ORGM_VISUAL_PROFILE_BACKEND':'gnome', 'ORGM_VISUAL_PROFILE_PICTURES_ROOT':str(work/'pictures'),
            'WALLPAPER_URI':picture.as_uri(), 'SETTINGS_LOG':str(work/'settings-log')}
    visual = root/'dotfiles/config/users/osmarg/programs/orgm/.local/bin/orgm-visual-profile'
    r = subprocess.run(['bash',str(visual),'set','slc'], env=env, capture_output=True, text=True)
    assert r.returncode == 0, r
    assert (work/'state/orgm-visual-profile/current').read_text().strip() == 'slc'
    assert 'org.gnome.desktop.interface color-scheme' in (work/'settings-log').read_text()
print('PASS: GTK selection/index/cancel/password contracts; GNOME copy and native history routing')
