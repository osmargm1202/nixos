"""Native Hyprland JSON/dispatch adapter for the shared Wayland desktop."""
import json
import os
from pathlib import Path
import re
import subprocess


def request(kind):
    result = subprocess.run(['hyprctl', '-j', kind], check=True, capture_output=True, text=True, timeout=3)
    return json.loads(result.stdout)


def dispatch(*args):
    subprocess.run(['hyprctl', 'dispatch', *args], check=True, capture_output=True, text=True, timeout=3)


class Backend:
    def __init__(self, request=request, dispatch=dispatch):
        self.request = request
        self.dispatch = dispatch

    def outputs(self):
        return self.request('monitors')

    def active_output(self):
        return next((o['name'] for o in self.outputs() if o.get('focused')), '')

    def windows(self):
        outputs = self.outputs()
        active = self.request('activewindow').get('address')
        items = []
        for c in self.request('clients'):
            address = c.get('address', '')
            if not c.get('mapped') or not re.fullmatch(r'0x[0-9a-fA-F]+', address):
                continue
            monitor = next((m for m in outputs if m['id'] == c.get('monitor')), {})
            workspace = c.get('workspace', {})
            shown = {monitor.get('activeWorkspace', {}).get('name'), monitor.get('specialWorkspace', {}).get('name')}
            at, size = c.get('at', [0, 0]), c.get('size', [0, 0])
            items.append(dict(id=address, name=' '.join((c.get('title') or c.get('class') or 'Ventana').split()),
                app=c.get('class', ''), workspace=workspace.get('name', ''),
                output=monitor.get('name', ''), focused=address == active,
                visible=not c.get('hidden', False) and workspace.get('name') in shown,
                rect=dict(x=at[0], y=at[1], width=size[0], height=size[1]), preview='',
                focus_order=c.get('focusHistoryID', 999999)))
        return sorted(items, key=lambda i: (not i['focused'], i['focus_order'] if i['focus_order'] >= 0 else 999999))

    def workspace_groups(self, items):
        groups = {}
        for item in items:
            name = item['workspace']
            if name not in groups:
                groups[name] = dict(name=name, number=int(name) if name.isdecimal() else -1, focused=False, items=[])
            groups[name]['items'].append(item)
            groups[name]['focused'] |= item['focused']
        return sorted(groups.values(), key=lambda g: (g['number'] < 0, g['number'], g['name']))

    def focus_window(self, address):
        if address in {item['id'] for item in self.windows()}:
            self.dispatch('focuswindow', 'address:'+address)

    def focus_selection(self, selection):
        if selection.startswith('workspace:'):
            name = selection.removeprefix('workspace:')
            if name in {item['workspace'] for item in self.windows()}:
                if name.startswith('special:'):
                    self.dispatch('togglespecialworkspace', name.removeprefix('special:'))
                else:
                    self.dispatch('workspace', name)
        else:
            self.focus_window(selection)

    def logout(self):
        self.dispatch('exit')

    def capture_window(self, address, destination):
        # No window-export client in this profile yet. Never substitute a region
        # of the desktop: it can show unrelated/private windows or lock content.
        return False


def install_shell(namespace, backend=None):
    backend = backend or Backend()
    g = namespace['main'].__globals__
    original_main = g['main']
    run = g['run']

    def menu_context():
        return dict(screen=backend.active_output(), colors=g['menu_colors']())

    def ipc(command):
        if command != 'exit':
            raise ValueError('Comando de compositor no válido')
        backend.logout()

    def choose_window(action='focus'):
        items = backend.windows()
        selected = g['pick']('Ventanas', [i['name'] for i in items], True)
        if selected.isdecimal() and int(selected) < len(items):
            backend.focus_window(items[int(selected)]['id'])

    def set_wallpaper(value, record=True):
        path = Path(value).expanduser().resolve(strict=True)
        if not path.is_file() or path.suffix.lower() not in g['MEDIA_SUFFIXES']:
            raise ValueError('Formato de fondo no admitido')
        run('hypr-wallpaper', 'set', str(path))

    def wallpaper(choose=False):
        if not choose:
            run('hypr-wallpaper', 'restore')
            return
        if not g['graphical_wallpaper_picker'](g['wallpaper_catalog']()):
            value = g['pick']('Fondo de pantalla', [str(p) for p in g['wallpaper_images'](Path.home()/'Pictures'/g['current_visual_profile']())])
            if value:
                set_wallpaper(value)

    def game_mode_active():
        path = Path(os.environ.get('XDG_STATE_HOME', Path.home()/'.local/state'))/'hypr/game-mode'
        return path.is_file() and path.read_text().strip() == 'activated'

    def main(args):
        action = args[0] if args else 'menu'
        desktop = str(Path(g['ENTRYPOINT']).with_name('orgm-hyprland-desktop'))
        if action in ('control', 'audio', 'clipboard', 'windows'):
            run(desktop, *args)
        elif action == 'menu':
            run(desktop, 'control')
        elif action == 'menu-fallback':
            run('hypr-app-launcher')
        elif action == 'help':
            run('hypr-keybindings-help')
        elif action == 'screenshot':
            mode = args[1] if len(args) > 1 else 'region'
            if mode not in ('region', 'full', 'window'):
                raise ValueError('Modo de captura no válido')
            run('hyprshot', '-m', {'region': 'region', 'full': 'output', 'window': 'window'}[mode], '--clipboard-only')
        elif action in ('appearance', 'wallpaper-restore'):
            wallpaper()
        else:
            original_main(args)

    hooks = dict(COMPOSITOR='hyprland', main=main, ipc=ipc, choose_window=choose_window,
                 menu_context=menu_context, set_wallpaper=set_wallpaper, wallpaper=wallpaper,
                 game_mode_active=game_mode_active, game_mode_helper='hypr-game-mode', compositor='hyprland')
    g.update(hooks)
    namespace.update(hooks)
    return namespace


def install_desktop(namespace, backend=None):
    backend = backend or Backend()
    g = namespace['main'].__globals__
    hooks = dict(window_items=backend.windows, workspace_groups=backend.workspace_groups,
                 focus_selection=backend.focus_selection,
                 capture_previews=lambda *a, **kw: None,
                 capture_allowed=lambda: False)
    g.update(hooks)
    namespace.update(hooks)
    return namespace
