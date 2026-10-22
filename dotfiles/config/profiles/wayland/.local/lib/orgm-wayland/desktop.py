#!/usr/bin/env python3
"""On-demand desktop panels and session-local Sway window thumbnails."""
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import runpy
import select
import shutil
import subprocess
import sys
import tempfile
import time

SWAY = SHELL if 'SHELL' in globals() else runpy.run_path(str(Path(ENTRYPOINT).with_name('orgm-sway')))
run = SWAY['run']
query = SWAY['query']
ipc = SWAY['ipc']


def catalog(kind, **values):
    return dict(kind=kind, backend=str(Path(ENTRYPOINT).resolve()), **SWAY['menu_context'](), **values)


def waybar_service():
    return 'orgm-'+('hyprland' if SWAY.get('compositor') == 'hyprland' else 'sway')+'-waybar.service'


def caffeine_state():
    # Persistence alone is not an inhibitor: only offer the toggle with its
    # session-owned Waybar alive. Never stop idle/lock services for Caffeine.
    available = False
    if shutil.which('waybar-caffeine-state'):
        try:
            available = run('systemctl', '--user', 'is-active', '--quiet', waybar_service(),
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=2).returncode == 0
        except (OSError, subprocess.SubprocessError):
            pass
    state = Path(os.environ.get('XDG_STATE_HOME', Path.home()/'.local/state'))/'waybar/caffeine'
    try:
        active = available and state.read_text().strip() == 'activated'
    except OSError:
        active = False
    return dict(caffeine=active, caffeineAvailable=available)


def control_commands():
    comp = 'hyprland' if SWAY.get('compositor') == 'hyprland' else 'sway'
    shell = 'orgm-'+comp
    commands = {
        'apps': [('hypr' if comp == 'hyprland' else 'sway')+'-app-launcher'],
        'windows': [shell, 'windows'], 'audio': [shell, 'audio'],
        'advanced-audio': ['pavucontrol'], 'terminal-mixer': ['kitty','-e','pulsemixer'],
        'clipboard': [shell, 'clipboard'], 'profiles': [shell, 'profiles'],
        'wallpaper': [shell, 'wallpaper-pick'], 'power': [shell, 'power'],
        'help': [shell, 'help'], 'themes': ['orgm-qylock', 'themes'],
        'widgets': ['orgm-desktop-widgets', 'edit'], 'wifi': ['nm-connection-editor'],
        'bluetooth': ['blueman-manager'], 'notifications': ['swaync-client', '--toggle-panel', '--skip-wait'],
        'accounts': ['gnome-online-accounts-gtk'], 'monitor': ['gnome-system-monitor'],
        'files': ['nautilus', '--new-window'],
        'displays': ['nwg-displays', '-o', str(Path.home()/'.config'/('hypr/monitors.conf' if comp=='hyprland' else 'sway/outputs.conf')), '-n', '10'],
    }
    if comp == 'hyprland':
        commands['displays'] = ['nwg-displays']
        commands['gaming-options'] = ['hypr-game-mode','settings']
    return commands


def control_controls():
    groups = [
        ('Sesión y entrada', [('tablet','Modo tablet','tablet','toggle'), ('keyboard','Teclado táctil','keyboard','toggle'),
         ('apps','Aplicaciones'), ('windows','Ventanas'), ('layout','Cambiar idioma','layout',''), ('scratchpad','Scratchpad','scratchpad','')]),
        ('Conexiones y sonido', [('wifi','Red / Wi-Fi'), ('bluetooth','Bluetooth'), ('audio','Audio y micrófono'), ('advanced-audio','Audio avanzado / aplicaciones'), ('terminal-mixer','Mezclador de terminal'), ('notifications','Notificaciones'), ('dnd','No molestar','dnd','')]),
        ('Reproducción', [('previous','Anterior','media','previous'), ('play-pause','Reproducir / pausar','media','play-pause'), ('next','Siguiente','media','next')]),
        ('Energía', [('caffeine','Mantener despierto','caffeine',''), ('gaming','Gaming','gaming',''),
         *([('gaming-options','Opciones de juegos')] if SWAY.get('compositor')=='hyprland' else []),
         ('power-saver','Ahorro','profile','power-saver'), ('balanced','Equilibrado','profile','balanced'), ('performance','Rendimiento','profile','performance')]),
        ('Espacios de trabajo', [('workspace-'+str(i),str(i),'workspace',str(i)) for i in range(1,11)]),
        ('Apariencia', [('profiles','Perfil visual'), ('wallpaper','Elegir fondo'), ('random-wallpaper','Fondo aleatorio','random-wallpaper',''),
         ('appearance','Claro / oscuro','appearance',''), ('themes','Inicio y bloqueo'), ('widgets','Editar widgets'), ('displays','Pantallas')]),
        ('Herramientas y sesión', [('clipboard','Portapapeles'), ('files','Archivos'), ('accounts','Cuentas en línea'), ('monitor','Monitor del sistema'), ('help','Atajos'), ('power','Bloquear / salir / apagar')]),
    ]
    commands=control_commands()
    tools={'tablet':'orgm-tablet','keyboard':'orgm-osk','layout':'hyprctl' if SWAY.get('compositor')=='hyprland' else 'swaymsg',
           'scratchpad':'hyprctl' if SWAY.get('compositor')=='hyprland' else 'swaymsg',
           'workspace':'hyprctl' if SWAY.get('compositor')=='hyprland' else 'swaymsg',
           'media':'playerctl','profile':'powerprofilesctl','dnd':'swaync-client','caffeine':'waybar-caffeine-state',
           'gaming':SWAY.get('game_mode_helper','sway-game-mode'),'appearance':'orgm-visual-profile','random-wallpaper':'orgm-visual-profile'}
    result=[]
    for section,items in groups:
        for item in items:
            key,label=item[:2];action=item[2] if len(item)>2 else '';value=item[3] if len(item)>3 else ''
            tool=tools[action] if action else commands[key][0]
            result.append(dict(id=key,label=label,section=section,action=action,value=value,
                               available=shutil.which(tool) is not None and (key!='terminal-mixer' or shutil.which('pulsemixer') is not None)))
    return result


def tablet_state():
    return runpy.run_path(str(Path(__file__).with_name('tablet.py')))['state']()


def optional_output(*args):
    try:
        result=run(*args,capture_output=True,text=True,timeout=1)
        return result.stdout.strip() if result.returncode==0 else ''
    except (OSError,subprocess.SubprocessError): return ''


def workspace_state():
    try:
        if SWAY.get('compositor')=='hyprland':
            return int(json.loads(optional_output('hyprctl','-j','activeworkspace')).get('id',0))
        return next((int(w['num']) for w in json.loads(optional_output('swaymsg','-r','-t','get_workspaces')) if w.get('focused')),0)
    except (ValueError,KeyError,TypeError): return 0


def battery_state():
    values=[]
    for battery in Path('/sys/class/power_supply').glob('*'):
        try:
            if (battery/'type').read_text().strip()=='Battery':
                values.append(str(int((battery/'capacity').read_text()))+'% · '+(battery/'status').read_text().strip())
        except (OSError,ValueError): pass
    return ' / '.join(values) or 'Sin batería'


def control_state():
    brightness = None
    try:
        result = run('brightnessctl', '-m', capture_output=True, text=True, timeout=2)
        brightness = int(result.stdout.split(',')[3].strip().removesuffix('%'))
    except (OSError, ValueError, IndexError, subprocess.SubprocessError):
        pass
    dnd = False
    try:
        dnd = run('swaync-client', '--get-dnd', capture_output=True, text=True, timeout=2).stdout.strip() == 'true'
    except (OSError, subprocess.SubprocessError):
        pass
    return dict(brightness=brightness, dnd=dnd, gaming=SWAY['game_mode_active'](), **caffeine_state(),
                tablet=tablet_state(),controls=control_controls(),battery=battery_state(),workspace=workspace_state(),
                mediaAvailable=bool(optional_output('playerctl','status')),
                network=optional_output('nmcli','-t','-f','STATE','general') or 'Red no disponible',
                powerProfile=optional_output('powerprofilesctl','get'),
                media=optional_output('playerctl','metadata','--format','{{artist}} — {{title}}'))


def control_action(action, value=''):
    if action == 'gaming':
        run(str(Path(ENTRYPOINT).with_name(SWAY.get('game_mode_helper', 'sway-game-mode'))), 'toggle')
    elif action == 'dnd':
        run('swaync-client', '--toggle-dnd', '--skip-wait', stdout=subprocess.DEVNULL)
    elif action == 'caffeine':
        if not caffeine_state()['caffeineAvailable']:
            raise RuntimeError('Caffeine requiere la barra de esta sesión activa')
        run('waybar-caffeine-state', 'toggle', stdout=subprocess.DEVNULL)
        try:
            # Stock Waybar has no idle_inhibitor RT signal handler. Its supported
            # start-activated setting is generated from the shared state file.
            run('systemctl', '--user', 'restart', waybar_service(), timeout=10)
        except (OSError, subprocess.SubprocessError):
            run('waybar-caffeine-state', 'toggle', stdout=subprocess.DEVNULL)
            raise
    elif action == 'brightness' and value.isdecimal() and 5 <= int(value) <= 100:
        run('brightnessctl', '-q', 'set', value+'%')
    elif action == 'tablet' and value in ('on','off','toggle'):
        run('orgm-tablet','mode',value,timeout=35,stdout=subprocess.DEVNULL)
    elif action == 'keyboard' and value in ('show','hide','toggle'):
        run('orgm-osk',value,timeout=3,stdout=subprocess.DEVNULL)
    elif action == 'media' and value in ('previous','play-pause','next'):
        run('playerctl',value)
    elif action == 'profile' and value in ('power-saver','balanced','performance'):
        run('powerprofilesctl','set',value)
    elif action == 'layout' and not value:
        if SWAY.get('compositor') == 'hyprland': run('hyprctl','switchxkblayout','all','next')
        else: run('swaymsg','input type:keyboard xkb_switch_layout next')
    elif action == 'scratchpad' and not value:
        if SWAY.get('compositor') == 'hyprland': run('hyprctl','dispatch','hl.dsp.workspace.toggle_special("magic")')
        else: run('swaymsg','scratchpad show')
    elif action == 'workspace' and value.isdecimal() and 1 <= int(value) <= 10:
        if SWAY.get('compositor') == 'hyprland': run('hyprctl','dispatch','hl.dsp.focus({workspace="'+str(int(value))+'"})')
        else: run('swaymsg','workspace number '+str(int(value)))
    elif action in ('appearance','random-wallpaper') and not value:
        run('orgm-visual-profile','toggle-mode' if action=='appearance' else 'random-wallpaper',
            env=dict(os.environ,ORGM_VISUAL_PROFILE_BACKEND=SWAY.get('compositor','sway')))
    else:
        raise ValueError('Acción de control no válida')
    return control_state()


def control_choice(selection):
    commands=control_commands()
    if selection not in commands: raise ValueError('Control no válido')
    if selection in ('audio','clipboard','windows'): main([selection])
    elif selection in ('profiles','power'): SWAY['main']([selection])
    else: run(*commands[selection])


def control():
    handled, selection = SWAY['graphical_selection'](catalog('control', state=control_state()))
    if not handled:
        options=[c for c in control_controls() if c['available']]
        selected=SWAY['pick']('Centro de control',[c['label'] for c in options],True)
        if selected.isdecimal() and int(selected)<len(options):
            item=options[int(selected)]
            if item['action']: control_action(item['action'],item['value'])
            else: control_choice(item['id'])
    elif selection: control_choice(selection)


def audio():
    handled, _ = SWAY['graphical_selection'](catalog('audio'))
    if not handled:
        run('pavucontrol')


def clipboard_items(directory):
    result = run('cliphist', 'list', capture_output=True, text=True, errors='replace')
    items = []
    image_count = 0
    for line in result.stdout.splitlines():
        key, separator, label = line.partition('\t')
        if not separator or not key.isdecimal():
            continue
        preview = ''
        if '[[ binary data' in label and re.search(r'\b(png|jpg|jpeg|gif|webp)\b', label, re.I) and image_count < 20:
            image_count += 1
            data = run('cliphist', 'decode', input=key.encode(), capture_output=True).stdout
            # Decode only images; never render clipboard text as HTML or QML.
            if data.startswith((b'\x89PNG\r\n\x1a\n', b'\xff\xd8\xff', b'GIF8', b'RIFF')):
                image = directory/(key+'.image')
                image.write_bytes(data)
                image.chmod(0o600)
                preview = image.as_uri()
        if label.startswith('[[ binary data'):
            image_type = re.search(r'\b(png|jpg|jpeg|gif|webp)\b\s+(\d+x\d+)', label, re.I)
            label = ('Imagen '+image_type[1].upper()+' · '+image_type[2]) if image_type else 'Contenido binario'
        items.append(dict(id=key, name=label, preview=preview))
    return items


def copy_clipboard(key):
    if not re.fullmatch(r'\d+', key):
        raise ValueError('Entrada del portapapeles no válida')
    data = run('cliphist', 'decode', input=key.encode(), capture_output=True).stdout
    args = ['wl-copy']
    if data.startswith(b'\x89PNG\r\n\x1a\n'):
        args += ['--type', 'image/png']
    run(*args, input=data)


def clipboard():
    with tempfile.TemporaryDirectory(prefix='orgm-clipboard-') as directory:
        items = clipboard_items(Path(directory))
        handled, selection = SWAY['graphical_selection'](catalog('clipboard', items=items))
        if not handled:
            rows = [item['id']+'\t'+item['name'] for item in items]
            selection = SWAY['pick']('Portapapeles', rows).partition('\t')[0]
        if selection and selection in {item['id'] for item in items}:
            copy_clipboard(selection)


def preview_directory():
    runtime = Path(os.environ.get('XDG_RUNTIME_DIR', f'/run/user/{os.getuid()}'))
    key = hashlib.sha256((os.environ.get('SWAYSOCK') or os.environ.get('HYPRLAND_INSTANCE_SIGNATURE', '')).encode()).hexdigest()[:20]
    directory = runtime/('orgm-sway-previews-'+key)
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    if directory.is_symlink() or directory.stat().st_uid != os.getuid():
        raise ValueError('Directorio de miniaturas no válido')
    directory.chmod(0o700)
    return directory


def window_items():
    items = []
    def visit(node, workspace='', visible=False):
        if node.get('type') == 'workspace':
            workspace = node.get('name', '')
            visible = node.get('visible', False)
        if node.get('app_id') or node.get('window'):
            app = node.get('app_id') or node.get('window_properties', {}).get('class', '')
            items.append(dict(id=str(node['id']), name=SWAY['clean'](node.get('name') or app),
                app=app, workspace=workspace, focused=node.get('focused', False),
                visible=node.get('visible', visible), rect=node.get('rect', {}), preview=''))
        children = node.get('nodes', [])+node.get('floating_nodes', [])
        order = {key: index for index, key in enumerate(node.get('focus', []))}
        for child in sorted(children, key=lambda child: order.get(child['id'], len(order))):
            visit(child, workspace, visible)
    visit(query('get_tree'))
    # get_tree doesn't mark workspace visibility on every Sway version.
    visible_workspaces = {w['name'] for w in query('get_workspaces') if w.get('visible')}
    for item in items:
        item['visible'] = item['visible'] and item['workspace'] in visible_workspaces
    return items


def workspace_groups(items):
    metadata = {workspace['name']: workspace for workspace in query('get_workspaces')}
    groups = {}
    for item in items:
        name = item['workspace']
        info = metadata.get(name, {})
        if name not in groups:
            groups[name] = dict(name=name, number=info.get('num', -1),
                                focused=info.get('focused', False), items=[])
        groups[name]['items'].append(item)
    return sorted(groups.values(), key=lambda group: (
        group['number'] < 0, group['number'] if group['number'] >= 0 else 0, group['name'].casefold()))


def focus_selection(selection):
    items = window_items()
    if selection.startswith('workspace:'):
        name = selection.removeprefix('workspace:')
        matches = [item for item in items if item['workspace'] == name]
        if matches and name != '__i3_scratch':
            ipc('workspace '+json.dumps(name))
        elif matches:
            ipc(f"[con_id={int(matches[0]['id'])}] scratchpad show")
    elif selection in {item['id'] for item in items}:
        item = next(item for item in items if item['id'] == selection)
        ipc(f'[con_id={int(selection)}] '+('scratchpad show' if item['workspace'] == '__i3_scratch' else 'focus'))


def capture_allowed():
    if SWAY['game_mode_active']():
        return False
    runtime = Path(os.environ.get('XDG_RUNTIME_DIR', f'/run/user/{os.getuid()}'))
    # The lock supervisor owns this file throughout lock acquisition and use.
    key = hashlib.sha256((os.environ.get('WAYLAND_DISPLAY', '')+'\0'+os.environ.get('SWAYSOCK', '')).encode()).hexdigest()[:20]
    lockfile = runtime/('orgm-qylock-'+key+'.lock')
    if lockfile.exists():
        with lockfile.open('a') as lock:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                return False
    for output in query('get_outputs'):
        for layer in output.get('layer_shell_surfaces', []):
            namespace = layer.get('namespace', '')
            # Permanent bottom-layer widgets are not private popup content.
            if namespace in ('orgm-desktop-clock', 'orgm-desktop-calendar'):
                continue
            if namespace.startswith(('orgm-', 'swaync-control')) or namespace == 'rofi':
                return False
    return True


def capture_previews(directory, items, *, all_visible=False):
    if not capture_allowed():
        return
    deadline = time.monotonic()+2
    for item in items:
        if not item['visible'] or (not all_visible and not item['focused']):
            continue
        r = item['rect']
        if r.get('width', 0) < 2 or r.get('height', 0) < 2:
            continue
        with tempfile.NamedTemporaryFile(dir=directory, suffix='.png', delete=False) as output:
            temporary = Path(output.name)
        try:
            run('grim', '-s', '0.25', '-g', f"{r['x']},{r['y']} {r['width']}x{r['height']}",
                str(temporary), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=2)
            temporary.replace(directory/(item['id']+'.png'))
        except (OSError, subprocess.SubprocessError):
            temporary.unlink(missing_ok=True)
        if time.monotonic() >= deadline:
            break


def previews():
    directory = preview_directory()
    with (directory/'recorder.lock').open('a') as instance:
        try:
            fcntl.flock(instance, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        with subprocess.Popen(['swaymsg', '-r', '-m', '-t', 'subscribe', '["window","workspace","shutdown"]'],
                              stdout=subprocess.PIPE, stderr=subprocess.DEVNULL) as events:
            try:
                last_capture = 0
                while events.poll() is None:
                    with (directory/'capture.lock').open('a') as lock:
                        try:
                            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                        except BlockingIOError:
                            pass
                        else:
                            if time.monotonic() - last_capture >= 3:
                                items = window_items()
                                capture_previews(directory, items)
                                last_capture = time.monotonic()
                                live = {item['id']+'.png' for item in items}
                                for image in directory.glob('*.png'):
                                    if image.name not in live:
                                        image.unlink(missing_ok=True)
                    ready, _, _ = select.select([events.stdout], [], [], 3)
                    if ready:
                        line = events.stdout.readline()
                        if not line or json.loads(line).get('change') == 'exit':
                            break
            finally:
                events.terminate()
                events.wait(timeout=3)


def advance_window_menu(direction):
    binary = SWAY['quickshell_binary']()
    config = Path(os.environ.get('XDG_CONFIG_HOME', Path.home()/'.config'))/'quickshell/orgm-wallpapers/menus.qml'
    if binary:
        status = subprocess.run([binary, '--path', str(config), 'ipc', 'call', 'menu', 'status'],
                                capture_output=True, text=True, timeout=2)
        try:
            state = json.loads(status.stdout) if status.returncode == 0 else {}
        except json.JSONDecodeError:
            # An IPC instance can disappear while its close animation finishes.
            return False
        if state.get('kind') == 'windows' and state.get('choice'):
            run(binary, '--path', str(config), 'ipc', 'call', 'menu', 'advance', str(direction),
                stdout=subprocess.DEVNULL)
            return True
    return False


def resident_windows(direction):
    binary = SWAY['quickshell_binary']()
    config = Path(os.environ.get('XDG_CONFIG_HOME', Path.home()/'.config'))/'quickshell/orgm-wallpapers/daemon.qml'
    if not binary or not config.is_file():
        return False
    items = window_items()
    directory = preview_directory()
    for item in items:
        image = directory/(item['id']+'.png')
        if image.is_file():
            item['preview'] = image.as_uri()
    payload = catalog('windows', items=items, groups=workspace_groups(items), direction=direction)
    try:
        result = subprocess.run([binary, '--path', str(config), 'ipc', 'call', 'menu', 'open',
                                 json.dumps(payload, ensure_ascii=False)],
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=2)
        return result.returncode == 0
    except (OSError, subprocess.SubprocessError):
        return False


def menus_daemon():
    binary = SWAY['quickshell_binary']()
    if not binary:
        raise RuntimeError('Quickshell no está disponible')
    config = Path(os.environ.get('XDG_CONFIG_HOME', Path.home()/'.config'))/'quickshell/orgm-wallpapers/daemon.qml'
    os.environ['ORGM_SWAY_DESKTOP_BACKEND'] = str(Path(ENTRYPOINT).resolve())
    os.environ['ORGM_DESKTOP_COMPOSITOR'] = SWAY.get('compositor', 'sway')
    if os.environ.get('SWAYSOCK'):
        os.environ['I3SOCK'] = os.environ['SWAYSOCK']
    os.execv(binary, [binary, '--no-duplicate', '--path', str(config)])


def windows(direction=1):
    if resident_windows(direction):
        return
    if advance_window_menu(direction):
        return
    directory = preview_directory()
    with (directory/'capture.lock').open('a') as lock:
        # Repeated Alt+Tab can arrive before Qt has mapped the first panel.
        # Wait for that panel and advance it, rather than queue another popup.
        deadline = time.monotonic()+5
        while True:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except BlockingIOError:
                if advance_window_menu(direction) or time.monotonic() >= deadline:
                    return
                time.sleep(.04)
        items = window_items()
        capture_previews(directory, items, all_visible=True)
        for item in items:
            image = directory/(item['id']+'.png')
            if image.is_file():
                item['preview'] = image.as_uri()
        handled, selection = SWAY['graphical_selection'](catalog('windows', items=items,
            groups=workspace_groups(items), direction=direction))
    if not handled:
        SWAY['choose_window']()
    elif selection:
        focus_selection(selection)


def main(args):
    action = args[0] if args else 'control'
    if action == 'control':
        control()
    elif action == 'control-state':
        print(json.dumps(control_state()))
    elif action == 'control-action':
        print(json.dumps(control_action(*args[1:])))
    elif action == 'audio':
        audio()
    elif action == 'clipboard':
        clipboard()
    elif action == 'clipboard-delete' and len(args) == 2 and args[1].isdecimal():
        run('cliphist', 'delete', input=args[1].encode())
    elif action == 'windows':
        windows(-1 if len(args) > 1 and args[1] == 'prev' else 1)
    elif action in ('menus-daemon', 'windows-daemon'):
        menus_daemon()
    elif action == 'windows-focus' and len(args) == 2:
        focus_selection(args[1])
    elif action == 'previews':
        previews()
    else:
        raise ValueError('Acción no válida')


if __name__ == '__main__':
    try:
        main(sys.argv[1:])
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print('orgm-sway-desktop:', error, file=sys.stderr)
        sys.exit(1)
