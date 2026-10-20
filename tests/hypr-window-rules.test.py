#!/usr/bin/env python3
"""Execute effective Lua rules against representative RE2-compatible fixtures.

This checks registration/order/selection, not live mapping or late-title events.
The real-parser test is tests/hypr-sway-session.test.py.
"""
import glob
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
lua = os.environ.get('ORGM_TEST_LUA') or shutil.which('lua')
if not lua:
    lua = next(iter(glob.glob('/nix/store/*-lua-5.*/bin/lua')), None)
assert lua, 'Lua interpreter required (ORGM_TEST_LUA)'
recorder = r'''
local root = arg[1]
package.path = root .. "/dotfiles/config/users/osmarg/profiles/hyprland/.config/hypr/?.lua;"
  .. root .. "/dotfiles/config/profiles/hyprland/.config/hypr/?.lua;" .. package.path
package.preload["lua.game-mode"] = function() return {enabled=function() return false end} end
local function json(value)
  if type(value) == "string" then
    return '"' .. value:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\t', '\\t') .. '"'
  elseif type(value) == "boolean" or type(value) == "number" then return tostring(value)
  elseif type(value) == "table" then
    local fields = {}
    for key, item in pairs(value) do fields[#fields+1] = json(key) .. ':' .. json(item) end
    return '{' .. table.concat(fields, ',') .. '}'
  end
  error("unsupported JSON value")
end
hl = {window_rule=function(rule) print(json(rule)) end}
require("lua.windows-workspaces")
'''
with tempfile.TemporaryDirectory(prefix='hypr-rule-test-') as tmp:
    script = Path(tmp)/'record.lua'
    script.write_text(recorder)
    result = subprocess.run([lua, str(script), str(ROOT)], capture_output=True, text=True,
                            env=dict(os.environ, HOME=tmp, XDG_STATE_HOME=tmp), check=True)
rules = [json.loads(line) for line in result.stdout.splitlines()]


def effects(cls, title='', **props):
    window = dict({'class': cls, 'title': title, 'modal': False, 'xwayland': False,
                   'float': False, 'fullscreen': False, 'pin': False}, **props)
    applied, tags = {}, set()
    for rule in rules:
        if all((window.get(key) == expected if isinstance(expected, bool)
                else re.fullmatch(expected, str(window.get(key, ''))) is not None)
               for key, expected in rule['match'].items()):
            applied.update({k: v for k, v in rule.items() if k not in ('match', 'name', 'tag')})
            if rule.get('tile'): window['float'] = False
            if 'float' in rule: window['float'] = rule['float']
            if 'pin' in rule: window['pin'] = rule['pin']
            if rule.get('tag', '').startswith('+'): tags.add(rule['tag'][1:])
            if rule.get('tag', '').startswith('-'): tags.discard(rule['tag'][1:])
    applied['floating_result'] = window['float']
    applied['tags'] = tags
    return applied


# Removing a family, changing its fractional size or breaking order fails here.
for cls in ['firefox', 'Firefox', 'org.mozilla.firefox', 'chromium', 'Chromium',
            'org.chromium.Chromium', 'google-chrome-stable', 'com.google.Chrome',
            'brave-origin', 'com.brave.Browser', 'opera', 'vivaldi-stable',
            'chrome-chatgpt.com__-Default', 'chrome-web.whatsapp.com__-Default',
            'orgm-webapp-whatsapp']:
    assert effects(cls).get('scrolling_width') == 1, (cls, 'must start at 100% column width')
    assert 'scrolling_width' not in effects(cls, 'Save File', modal=True), 'modal dialogs must keep their geometry'
for cls in ['kitty', 'org.gnome.Nautilus', 'org.gnome.Loupe',
            'chrome-nngceckbapebfimnlniiiahkandclblb-Default']:
    assert 'scrolling_width' not in effects(cls), (cls, 'not a full-width browser/PWA')
families = [
    (['org.gnome.Nautilus', 'nautilus', 'NAUTILUS'], 78, 78),
    (['org.gnome.Calculator', 'qalculate-gtk', 'qalculate-qt'], 22, 60),
    (['pavucontrol', 'Pavucontrol', 'org.pulseaudio.pavucontrol', 'blueman-manager', 'Blueman-manager'], 40, 48),
    (['bluetui', 'nmtui', 'nm-connection-editor', 'org.gnome.FileRoller', 'file-roller'], 44, 52),
    (['orgmai-chat'], 71, 76), (['orgmai-config'], 58, 69),
    (['swappy', 'satty', 'com.gabm.satty'], 80, 80),
    (['nwg-displays', 'nwg-look', 'org.gnome.OnlineAccounts', 'gnome-online-accounts-gtk'], 65, 75),
    (['ryoport-ssh'], 47, 52), (['spicy', 'Spicy', 'looking-glass-client', 'Qemu-system-x86_64'], 83, 83),
]
for classes, width, height in families:
    for cls in classes:
        actual = effects(cls)
        assert actual['floating_result'], (cls, 'should float', actual)
        assert actual.get('center') is True, (cls, actual)
        assert actual.get('size') == f'monitor_w*{width/100:g} monitor_h*{height/100:g}', (cls, actual)

for cls in ['nextcloud', 'com.nextcloud.desktopclient.nextcloud']:
    assert effects(cls, 'Preferences')['floating_result']
    assert 'size' not in effects(cls, 'Preferences')
    assert effects(cls, 'Nextcloud')['size'] == 'monitor_w*0.3 monitor_h*0.63'
for cls in ['', 'syncthingtray', 'com.github.martchus.syncthingtray']:
    assert effects(cls, 'Syncthing Tray')['size'] == 'monitor_w*0.4 monitor_h*0.56'
for cls in ['ghosttype-app', 'ryotunes']:
    assert effects(cls)['floating_result']
for cls in ['org.gnome.Loupe', 'org.gnome.loupe', 'loupe']:
    actual = effects(cls)
    assert actual['floating_result'], (cls, 'image viewer must float')
    assert actual.get('center') is True, (cls, actual)
    assert 'size' not in actual, (cls, 'preserve image viewer client size')
assert not effects('firefox', 'Loupe')['floating_result']
for cls in ['vlc', 'Vlc', 'VLC', 'org.videolan.VLC']:
    actual = effects(cls)
    assert actual['floating_result'], (cls, 'VLC must float')
    assert actual.get('center') is True, (cls, actual)
    assert 'size' not in actual and 'fullscreen' not in actual, (cls, 'keep media geometry and fullscreen controls')
assert not effects('firefox', 'VLC')['floating_result']
assert effects('org.quickshell', 'Ryotunes')['floating_result']
assert effects('windows-rdp').get('fullscreen') is True
assert effects('kitty', 'hardware-fastfetch').get('maximize') is True
for cls, title in [('firefox', 'Extension: (Bitwarden Password Manager) - Mozilla Firefox'),
                   ('org.mozilla.firefox', 'Extensión: (Bitwarden Password Manager) - Firefox'),
                   ('chrome-nngceckbapebfimnlniiiahkandclblb-Default', 'Bitwarden')]:
    assert effects(cls, title)['floating_result'], (cls, title)
    assert effects(cls, title)['size'] == 'monitor_w*0.25 monitor_h*0.63'
for cls in ['hyprpolkitagent', 'Polkit-gnome-authentication-agent-1',
            'org.kde.polkit-kde-authentication-agent-1', 'xdg-desktop-portal-gtk']:
    assert effects(cls)['floating_result'], cls
for title in ['Open File', 'Save As', 'Guardar como', 'Abrir carpeta']:
    assert effects('chromium', title)['floating_result']
    assert 'hyprglass_enabled' not in effects('chromium', title)['tags']
    assert effects('chromium', title)['opacity'] == '1.0 override 1.0 override 1.0 override'
assert effects('chrome-web.whatsapp.com-Default', 'Save File', modal=True)['floating_result']
assert effects('firefox', 'Authentication', modal=True)['floating_result']

# Utility or notification words must not float ordinary browser/PWA windows.
for cls, title in [('firefox', 'Bitwarden'), ('firefox', 'Notifications - Mozilla Firefox'),
                   ('brave-browser', 'Notificación de prueba'), ('firefox', 'Syncthing Tray'),
                   ('chromium', 'Nautilus'), ('spotify', 'Spotify'),
                   ('chrome-web.whatsapp.com-Default', 'WhatsApp'),
                   ('org.quickshell', 'Not Ryotunes')]:
    assert not effects(cls, title)['floating_result'], (cls, title, effects(cls, title))
for cls in ['steam', 'steam_app_1234', 'gamescope', 'EtG.x86_64']:
    actual = effects(cls)
    assert actual.get('no_blur') and actual.get('no_shadow'), (cls, actual)
    assert actual.get('idle_inhibit') == 'fullscreen', (cls, actual)
    assert actual.get('opacity') == '1.0 override 1.0 override 1.0 override'
    assert 'hyprglass_enabled' not in actual['tags']
assert effects('', '', xwayland=True, float=True).get('no_focus') is True
print(f'PASS: {len(rules)} effective Lua rules; utility families, dialogs, games and browser negatives')
