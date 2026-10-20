#!/usr/bin/env python3
"""Exercise migration behavior at the Sway/desktop command boundary."""
import json
import os
import shutil
from pathlib import Path
import re
import runpy
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent.parent
MODULE = runpy.run_path(str(ROOT / 'dotfiles/config/profiles/sway/.local/bin/orgm-sway'))
ENV = MODULE['main'].__globals__


class SwayWorkflows(unittest.TestCase):
    def test_bindings_find_helpers_without_an_interactive_shell(self):
        config = (ROOT / 'dotfiles/config/profiles/sway/.config/sway/config').read_text()
        wrapper = next(line.removeprefix('set $exec ') for line in config.splitlines()
                       if line.startswith('set $exec '))
        self.assertIn('bindsym $mod+space $exec sway-app-launcher', config)
        self.assertIn('bindsym $mod+w $exec sway-firefox-open-tab --restore-or-focus', config)
        self.assertIn('bindsym $mod+e $exec nautilus --new-window', config)
        self.assertIn('bindsym $mod+b $exec chromium', config)
        self.assertFalse(any(' exec ' in line for line in config.splitlines()
                             if line.startswith('bindsym ')))
        with tempfile.TemporaryDirectory(prefix='sway-path-') as temp:
            helper = Path(temp) / '.local/bin/sway-path-probe'
            helper.parent.mkdir(parents=True)
            helper.write_text(f'#!{shutil.which("sh")}\nprintf "helper-found"\n')
            helper.chmod(0o755)
            # Reproduce SDDM's PATH, not the interactive shell running this test.
            path = os.pathsep.join(p for p in os.get_exec_path() if '/.local/bin' not in p)
            result = subprocess.run(['sh', '-c', wrapper + ' sway-path-probe'],
                                    env=dict(os.environ, HOME=temp, PATH=path),
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, 'helper-found')

    def test_floating_toggle_does_not_repeat_when_space_is_held(self):
        config = (ROOT / 'dotfiles/config/profiles/sway/.config/sway/config').read_text()
        bindings = [line for line in config.splitlines()
                    if line.startswith('bindsym ') and '$mod+Shift+space' in line]
        self.assertEqual(bindings, ['bindsym --no-repeat $mod+Shift+space floating toggle'])

    def test_keyboard_focus_changes_carry_the_pointer_to_the_window(self):
        config = (ROOT / 'dotfiles/config/profiles/sway/.config/sway/config').read_text()
        self.assertIn('mouse_warping container', config)
        self.assertIn('focus_follows_mouse yes', config)
        self.assertNotIn('mouse_warping none', config)

    def window_actions(self, kind='for_window', **properties):
        rules = (ROOT / 'dotfiles/config/profiles/sway/.config/sway/window-rules.conf').read_text()
        actions = []
        for line in rules.splitlines():
            rule = re.fullmatch(rf'{re.escape(kind)} \[(.+)\](?: (.+))?', line)
            if not rule:
                continue
            criteria = re.findall(r'(\w+)="([^"]*)"', rule[1])
            if criteria and all(key in properties and re.search(pattern, properties[key])
                                for key, pattern in criteria):
                actions.append(rule[2] or kind)
        return ', '.join(actions)

    def test_utility_rules_cover_wayland_and_xwayland(self):
        config = (ROOT / 'dotfiles/config/profiles/sway/.config/sway/config').read_text()
        self.assertIn('include ~/.config/sway/window-rules.conf', config)
        for app in ('org.gnome.Nautilus', 'org.gnome.Calculator', 'Qalculate-gtk',
                    'qalculate-qt', 'com.nextcloud.desktopclient.nextcloud', 'Nextcloud',
                    'org.gnome.FileRoller', 'pavucontrol', 'org.pulseaudio.pavucontrol',
                    'blueman-manager', 'nmtui', 'bluetui', 'nm-connection-editor',
                    'orgmai-chat', 'orgmai-config', 'swappy', 'com.gabm.satty',
                    'ghosttype-app', 'ryotunes', 'looking-glass-client', 'qemu-system-x86_64', 'spicy'):
            for protocol in ('app_id', 'class'):
                with self.subTest(app=app, protocol=protocol):
                    actions = self.window_actions(**{protocol: app})
                    self.assertIn('floating enable', actions)
                    self.assertIn('move position center', actions)
        self.assertIn('floating enable', self.window_actions(app_id='', title='Syncthing Tray'))
        self.assertNotIn('floating enable', self.window_actions(app_id='chromium', title='Syncthing Tray'))
        tray = self.window_actions(app_id='com.nextcloud.desktopclient.nextcloud', title='Nextcloud')
        settings = self.window_actions(app_id='com.nextcloud.desktopclient.nextcloud', title='Nextcloud Preferences')
        self.assertIn('resize set', tray)
        self.assertIn('floating enable', settings)
        self.assertNotIn('resize set', settings)

    def test_image_viewer_floats_without_resizing_browser_windows(self):
        for app in ('org.gnome.Loupe', 'org.gnome.loupe', 'loupe'):
            for protocol in ('app_id', 'class'):
                with self.subTest(app=app, protocol=protocol):
                    actions = self.window_actions(**{protocol: app})
                    self.assertIn('floating enable', actions)
                    self.assertIn('move position center', actions)
                    self.assertNotIn('resize set', actions)
        self.assertNotIn('floating enable', self.window_actions(app_id='firefox', title='Loupe'))

    def test_vlc_floats_without_forcing_size_or_fullscreen(self):
        for app in ('vlc', 'Vlc', 'VLC', 'org.videolan.VLC'):
            for protocol in ('app_id', 'class'):
                with self.subTest(app=app, protocol=protocol):
                    actions = self.window_actions(**{protocol: app})
                    self.assertIn('floating enable', actions)
                    self.assertIn('move position center', actions)
                    self.assertNotIn('resize set', actions)
                    self.assertNotIn('fullscreen enable', actions)
        self.assertNotIn('floating enable', self.window_actions(app_id='firefox', title='VLC'))

    def test_main_music_and_whatsapp_windows_tile_but_their_dialogs_float(self):
        for app in ('Spotify', 'spotify', 'com.spotify.Client', 'orgm-webapp-whatsapp',
                    'chrome-web.whatsapp.com__-Default'):
            for protocol in ('app_id', 'class'):
                with self.subTest(app=app, protocol=protocol):
                    properties = {protocol: app}
                    if protocol == 'class':
                        # Chromium --app uses pop-up even for its NORMAL main window.
                        properties.update(window_type='normal', window_role='pop-up')
                    self.assertNotIn('floating enable', self.window_actions(**properties))
                    if protocol == 'class':
                        properties['window_type'] = 'dialog'
                        self.assertIn('floating enable', self.window_actions(**properties))
        # A role alone cannot distinguish a PWA from a dialog.
        self.assertNotIn('floating enable', self.window_actions(
            window_type='normal', window_role='pop-up'))

    def test_bitwarden_popouts_do_not_float_regular_browser_tabs(self):
        for protocol in ('app_id', 'class'):
            for title in ('Extension: (Bitwarden Password Manager) - Bitwarden',
                          'Extensión: (Bitwarden Password Manager) - Bitwarden'):
                actions = self.window_actions(**{protocol: 'firefox', 'title': title})
                self.assertIn('floating enable', actions)
                self.assertIn(', focus', actions)
            extension = 'chrome-nngceckbapebfimnlniiiahkandclblb-Default'
            self.assertIn('floating enable', self.window_actions(**{protocol: extension}))
            for app, title in (('firefox', 'Bitwarden — Mozilla Firefox'),
                               ('firefox', 'Nextcloud — Mozilla Firefox'),
                               ('chromium', 'Bitwarden'), ('kitty', 'Nextcloud')):
                self.assertNotIn('floating enable', self.window_actions(**{protocol: app, 'title': title}))

    def test_browser_notifications_require_a_real_notification_type(self):
        for protocol in ('app_id', 'class'):
            properties = {protocol: 'firefox', 'title': 'Web Notifications — Mozilla Firefox'}
            self.assertNotIn('floating enable', self.window_actions(**properties))
            self.assertNotIn('no_focus', self.window_actions(kind='no_focus', **properties))
        properties = {'class': 'firefox', 'window_type': 'notification'}
        self.assertIn('sticky enable', self.window_actions(**properties))
        self.assertIn('no_focus', self.window_actions(kind='no_focus', **properties))

    def test_dialogs_and_game_rules_keep_their_native_behavior(self):
        self.assertIn('opacity 1', self.window_actions(window_type='dialog'))
        self.assertIn('floating enable', self.window_actions(window_role='GtkFileChooserDialog'))
        for protocol in ('app_id', 'class'):
            self.assertIn('fullscreen enable', self.window_actions(**{protocol: 'windows-rdp'}))
            actions = self.window_actions(**{protocol: 'steam_app_12345'})
            for action in ('opacity 1', 'blur disable', 'shadows disable', 'inhibit_idle fullscreen'):
                self.assertIn(action, actions)
            self.assertNotIn('floating enable', actions)
        # Browser/PWA tiling remains the default, without forcing their modal dialogs to tile.
        self.assertNotIn('floating disable', self.window_actions(app_id='chrome-example.org-Default'))

    def test_waybar_ports_hyprland_layout_to_native_sway_modules(self):
        path = ROOT / 'dotfiles/config/profiles/sway/.config/waybar/config'
        bar = json.loads(path.read_text())
        modules = bar['modules-left'] + bar['modules-center'] + bar['modules-right']
        for name in ['sway/workspaces', 'sway/scratchpad', 'sway/language', 'sway/window',
                     'pulseaudio#microphone', 'mpris', 'custom/keybindings_help']:
            self.assertIn(name, modules)
        self.assertEqual(set(bar['sway/workspaces']['persistent-workspaces']),
                         {str(i) for i in range(1, 11)})
        self.assertNotIn('hypr', path.read_text().lower())
        self.assertNotIn('hyprctl', path.read_text())

    def test_swayfx_effects_are_enabled_without_global_window_transparency(self):
        config = (ROOT / 'dotfiles/config/profiles/sway/.config/sway/config').read_text()
        self.assertIn('blur enable', config)
        self.assertIn('shadows enable', config)
        self.assertIn('layer_effects "waybar"', config)
        self.assertIn('layer_effects "rofi"', config)
        self.assertIn('opacity 0.94', config)
        self.assertNotIn('for_window [all] opacity', config)

    def test_compact_bar_hides_empty_scratchpad_and_windows_have_no_borders(self):
        profile = ROOT / 'dotfiles/config/profiles/sway/.config'
        bar = json.loads((profile / 'waybar/config').read_text())
        css = (profile / 'waybar/style.css').read_text()
        self.assertFalse(bar['sway/scratchpad']['show-empty'])
        self.assertLessEqual(bar['height'], 30)
        self.assertLessEqual(bar['tray']['icon-size'], 16)
        self.assertIn('font-size: 12px', css)
        self.assertIn('@import "orgm-current.css"', css)
        self.assertIn('custom/visual-profile', bar['modules-left'])
        config = (profile / 'sway/config').read_text()
        self.assertIn('default_border none', config)
        self.assertIn('default_floating_border none', config)
        self.assertIn('background: transparent', (profile / 'nwg-dock/current-theme.css').read_text())

    def test_swaync_provides_notification_history_and_dnd_without_osd_spam(self):
        profile = ROOT / 'dotfiles/config/profiles/sway/.config'
        config = (profile / 'sway/config').read_text()
        self.assertIn('bindsym $mod+n $exec swaync-client --toggle-panel --skip-wait', config)
        self.assertIn('bindsym $mod+Shift+n $exec swaync-client --toggle-dnd --skip-wait', config)
        bar = json.loads((profile / 'waybar/config').read_text())
        self.assertIn('custom/notifications', bar['modules-right'])
        module = bar['custom/notifications']
        self.assertIn('--subscribe-waybar', module['exec'])
        self.assertNotIn('interval', module)
        self.assertEqual(module['restart-interval'], 2)
        self.assertIn('--toggle-panel', module['on-click'])
        self.assertIn('--toggle-dnd', module['on-click-right'])
        notifications = json.loads((profile / 'swaync/config.json').read_text())
        self.assertEqual(notifications['widgets'], ['title', 'dnd', 'notifications'])
        self.assertGreaterEqual(notifications['control-center-margin-right'], 60)
        rule = notifications['notification-visibility']['osd']
        self.assertEqual(rule['state'], 'transient')
        for app in ('osd-volume', 'osd-mic', 'osd-brightness'):
            self.assertRegex(app, rule['app-name'])
        self.assertIsNone(re.search(rule['app-name'], 'Firefox'))
        self.assertNotIn('scripts', notifications)
        self.assertIn('@import "orgm-current.css"', (profile / 'swaync/style.css').read_text())
        manifest = json.loads((ROOT / 'dotfiles/apps/swaync.json').read_text())
        self.assertEqual(manifest['paths'], ['.config/swaync'])

    def test_dock_space_is_reserved_by_sway_without_narrowing_waybar(self):
        profile = ROOT / 'dotfiles/config/profiles/sway/.config'
        config = (profile / 'sway/config').read_text()
        self.assertIn('set $dock_gap 60', config)
        self.assertIn('gaps right $dock_gap', config)
        self.assertIn('sway-game-mode sync', config)
        self.assertNotIn('exec_always swaymsg gaps right', config)
        bar = json.loads((profile / 'waybar/config').read_text())
        self.assertTrue(bar['exclusive'])
        self.assertEqual(bar['position'], 'top')
        self.assertNotIn('width', bar)

    def test_profile_selector_uses_sway_backend_and_ignores_custom_input(self):
        for selection in ('slc', 'cancelled', '../../bad'):
            with patch.dict(ENV, pick=lambda *a: selection,
                            graphical_selection=lambda _: (False, ''), profile_catalog=lambda: {},
                            run=lambda *args, **kwargs: calls.append((args, kwargs))):
                calls = []
                MODULE['main'](['profiles'])
            if selection == 'slc':
                self.assertEqual(calls[0][0][1:], ('set', 'slc'))
                self.assertEqual(calls[0][1]['env']['ORGM_VISUAL_PROFILE_BACKEND'], 'sway')
            else:
                self.assertFalse(calls)

    def test_wallpaper_backend_failure_keeps_saved_state(self):
        with tempfile.TemporaryDirectory() as temp:
            home = Path(temp)
            image = home / 'new.png'
            image.touch()
            state = home / '.config/sway/wallpaper'
            state.parent.mkdir(parents=True)
            state.write_text('previous wallpaper\n')
            def fail(_):
                raise RuntimeError('IPC failure')
            with patch.object(Path, 'home', return_value=home), patch.dict(
                    os.environ, XDG_CONFIG_HOME=str(home / '.config')), patch.dict(
                    ENV, ipc=fail, stop_session_wallpaper_players=lambda: None):
                with self.assertRaises(RuntimeError):
                    MODULE['set_wallpaper'](image)
            self.assertEqual(state.read_text(), 'previous wallpaper\n')

    def test_wallpaper_button_is_random_and_picker_is_secondary(self):
        bar = json.loads((ROOT / 'dotfiles/config/profiles/sway/.config/waybar/config').read_text())
        self.assertIn('random-wallpaper', bar['custom/wallpaper']['on-click'])
        self.assertNotIn('wallpaper-pick', bar['custom/wallpaper']['on-click'])
        self.assertEqual(bar['custom/wallpaper']['on-click-right'], 'orgm-sway wallpaper-pick')

    def test_random_wallpaper_prefers_profile_and_avoids_the_current_image(self):
        with tempfile.TemporaryDirectory() as temp:
            home = Path(temp)
            profile = home / 'Pictures/slc'
            profile.mkdir(parents=True)
            current, other = profile/'current.png', profile/'other.jpg'
            current.touch()
            other.touch()
            state = home / '.config/sway/wallpaper'
            state.parent.mkdir(parents=True)
            state.write_text(str(current))
            with patch.object(Path, 'home', return_value=home), patch.dict(
                    os.environ, XDG_CONFIG_HOME=str(home/'.config')), patch.dict(
                    ENV, set_wallpaper=(calls := []).append, wallpaper_directories=lambda: self.fail('Unexpected fallback')):
                MODULE['random_wallpaper'](profile)
            self.assertEqual(calls, [other])

    def test_empty_profile_uses_shared_wallpapers_without_opening_a_menu(self):
        with tempfile.TemporaryDirectory() as temp:
            home = Path(temp)
            shared = home / 'Pictures/Wallpapers'
            shared.mkdir(parents=True)
            image = shared/'shared.webp'
            image.touch()
            (shared/'not-an-image.pdf').touch()
            with patch.object(Path, 'home', return_value=home), patch.dict(
                    os.environ, XDG_CONFIG_HOME=str(home/'.config')), patch.dict(
                    ENV, set_wallpaper=(calls := []).append, pick=lambda *a: self.fail('Unexpected picker')):
                MODULE['random_wallpaper'](home/'Pictures/slc')
            self.assertEqual(calls, [image])

    def test_first_boot_keeps_ryoku_files_and_installs_independent_helpers(self):
        cli = os.environ.get("ORGM_DOT_BINARY") or shutil.which("orgm-dot")
        if not cli:
            self.skipTest("orgm-dot binary required for bootstrap integration")
        with tempfile.TemporaryDirectory(prefix="sway-bootstrap-") as temp:
            home = Path(temp)
            existing = [home / ".config/rofi/config.rasi", home / ".local/bin/hypr-rofi-lib"]
            for path in existing:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("existing Ryoku file\n")
            context = home / "context.json"
            context.write_text(json.dumps({
                "repository": str(ROOT), "user": "osmarg", "host": "envy", "profile": "sway",
                "programs": ["shell", "git", "kitty", "orgm", "webapps"],
            }))
            result = subprocess.run([cli, "--home", str(home), "--context", str(context), "bootstrap"], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            for path in existing:
                self.assertEqual(path.read_text(), "existing Ryoku file\n")
            self.assertTrue((home / ".config/rofi-sway/sway-menu.rasi").is_file())
            for name in ["sway-app-launcher", "orgm-sway-lock", "orgm-qylock", "sway-rofi-lib", "sway-volume-osd", "sway-firefox-open-tab", "sway-firefox-tabs", "sway-video-timer"]:
                path = home / ".local/bin" / name
                self.assertTrue(path.is_file() and os.access(path, os.X_OK), name)
                self.assertFalse(path.is_symlink(), name)
            self.assertTrue((home / ".local/share/nwg-dock/images/grid.svg").is_file())
            self.assertTrue((home / '.config/swaync/config.json').is_file())
            self.assertTrue((home / '.config/quickshell/orgm-wallpapers/shell.qml').is_file())
            self.assertTrue((home / '.config/quickshell/orgm-lock/lock.qml').is_file())
            self.assertTrue((home / '.config/quickshell/orgm-locks/shell.qml').is_file())
            self.assertFalse((home / '.config/swaylock').exists())

    def test_legacy_appearance_file_gets_default_icon_theme(self):
        with tempfile.TemporaryDirectory() as temp:
            home = Path(temp)
            config = home/'.config/sway/appearance.ini'
            config.parent.mkdir(parents=True)
            config.write_text('[Appearance]\ncolor-scheme=prefer-dark\ngtk-theme=Adwaita-dark\n')
            with patch.object(Path, 'home', return_value=home), patch.dict(
                    ENV, run=lambda *args: calls.append(args)):
                calls = []
                MODULE['apply_appearance']()
            self.assertIn(('dconf', 'write', '/org/gnome/desktop/interface/icon-theme',
                           '"Colloid-Dark"'), calls)
            self.assertIn(('dconf', 'write', '/org/gnome/nautilus/preferences/show-image-thumbnails',
                           '"always"'), calls)

    def test_appearance_reload_preserves_waybar_and_caffeine(self):
        with tempfile.TemporaryDirectory() as temp:
            home = Path(temp)
            config = home/'.config/sway/appearance.ini'
            config.parent.mkdir(parents=True)
            config.write_text('[Appearance]\ncolor-scheme=prefer-dark\ngtk-theme=Adwaita-dark\n')
            helper = home/'.local/bin/orgm-visual-profile'
            helper.parent.mkdir(parents=True)
            helper.touch()
            calls = []
            with patch.object(Path, 'home', return_value=home), patch.dict(
                    ENV, run=lambda *args, **kwargs: calls.append((args, kwargs))):
                MODULE['apply_appearance']()
            args, kwargs = calls[-1]
            self.assertEqual(args, (str(helper), 'apply'))
            self.assertEqual(kwargs['env']['ORGM_VISUAL_PROFILE_KEEP_WAYBAR'], '1')

    def test_thumbnail_policy_is_editable_and_rejects_invalid_values(self):
        for mode in ('always', 'local-only', 'never', 'invalid'):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as temp:
                home = Path(temp)
                config = home / '.config/sway/appearance.ini'
                config.parent.mkdir(parents=True)
                config.write_text('[Appearance]\ncolor-scheme=prefer-dark\ngtk-theme=Adwaita-dark\n'
                                  '[Files]\nshow-image-thumbnails=' + mode + '\n')
                calls = []
                with patch.object(Path, 'home', return_value=home), patch.dict(
                        ENV, run=lambda *args: calls.append(args)):
                    if mode == 'invalid':
                        with self.assertRaises(ValueError):
                            MODULE['apply_appearance']()
                        self.assertEqual(calls, [])
                    else:
                        MODULE['apply_appearance']()
                        self.assertIn(('dconf', 'write', '/org/gnome/nautilus/preferences/show-image-thumbnails',
                                       json.dumps(mode)), calls)
                        self.assertFalse(any('thumbnail-limit' in str(call) for call in calls))

    def test_dark_preference_is_restored_on_session_reload(self):
        if not shutil.which("dbus-run-session") or not shutil.which("dconf"):
            self.skipTest("D-Bus and dconf required for appearance integration")
        with tempfile.TemporaryDirectory(prefix="sway-appearance-") as temporary:
            home = Path(temporary)
            appearance = home / ".config/sway/appearance.ini"
            appearance.parent.mkdir(parents=True)
            appearance.write_text((ROOT / "dotfiles/config/profiles/sway/.config/sway/appearance.ini").read_text())
            profile = home / "dconf-profile"
            profile.write_text("user-db:swaytest\n")
            script = """
                dconf write /org/gnome/desktop/interface/icon-theme "'ryoku-folders'"
                dconf write /org/gnome/nautilus/preferences/show-image-thumbnails "'never'"
                dconf write /org/gnome/nautilus/preferences/thumbnail-limit 'uint64 17'
                "$1" appearance
                test "$(dconf read /org/gnome/desktop/interface/icon-theme)" = "'Colloid-Dark'"
                test "$(dconf read /org/gnome/desktop/interface/color-scheme)" = "'prefer-dark'"
                test "$(dconf read /org/gnome/desktop/interface/gtk-theme)" = "'Adwaita-dark'"
                test "$(dconf read /org/gnome/nautilus/preferences/show-image-thumbnails)" = "'always'"
                test "$(dconf read /org/gnome/nautilus/preferences/thumbnail-limit)" = 'uint64 17'
                dconf write /org/gnome/desktop/interface/color-scheme "'prefer-light'"
                "$1" appearance
                test "$(dconf read /org/gnome/desktop/interface/color-scheme)" = "'prefer-dark'"
            """
            result = subprocess.run([
                "dbus-run-session", "--", "sh", "-eu", "-c", script, "_",
                str(ROOT / "dotfiles/config/profiles/sway/.local/bin/orgm-sway"),
            ], env=dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(home / ".config"),
                        DCONF_PROFILE=str(profile)), capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_window_titles_cannot_become_ipc_commands(self):
        tree = {'nodes': [
            {'id': 42, 'app_id': 'kitty', 'name': 'bad\n[con_id=1] kill; exec evil'},
            {'floating_nodes': [{'id': 71, 'app_id': 'firefox', 'name': 'Browser'}]},
        ]}
        with patch.dict(ENV, query=lambda _: tree, pick=lambda *a: '0', ipc=(calls := []).append):
            MODULE['choose_window']()
        self.assertEqual(calls, ['[con_id=42] focus'])

    def test_cancelled_window_picker_has_no_effect(self):
        with patch.dict(ENV, query=lambda _: {'nodes': []}, pick=lambda *a: '', ipc=(calls := []).append):
            MODULE['choose_window']()
        self.assertEqual(calls, [])

    def test_scratchpad_windows_are_visible_to_picker(self):
        tree = {'nodes': [{'nodes': [{'floating_nodes': [{'id': 9, 'app_id': 'kitty'}]}]}]}
        self.assertEqual([w['id'] for w in MODULE['windows'](tree)], [9])

    def test_suspend_locks_before_requesting_sleep(self):
        with patch.dict(ENV, run=lambda *args, **kw: self.calls.append(args)):
            self.calls = []
            MODULE['power']('Suspender')
        self.assertEqual(self.calls, [('orgm-qylock', 'lock'), ('systemctl', 'suspend')])

    def test_lock_failure_prevents_suspend(self):
        def fail(*args, **kwargs):
            self.assertEqual(args, ('orgm-qylock', 'lock'))
            raise subprocess.CalledProcessError(1, args)
        with patch.dict(ENV, run=fail), self.assertRaises(subprocess.CalledProcessError):
            MODULE['power']('Suspender')

    def test_cancelled_screenshot_does_not_capture(self):
        with patch.dict(ENV, run=lambda *a, **k: self.fail('Unexpected capture')), patch.object(
            subprocess, 'run', return_value=subprocess.CompletedProcess(['slurp'], 1, '', '')
        ):
            MODULE['screenshot']('region')

    def test_full_screenshot_passes_png_to_the_editor(self):
        calls = []
        def run(*args, **kwargs):
            calls.append((args, kwargs))
            return subprocess.CompletedProcess(args, 0, b'PNG image')
        with patch.dict(ENV, run=run):
            MODULE['screenshot']('full')
        self.assertEqual(calls, [(('grim', '-'), {'capture_output': True}),
                                 (('swappy', '-f', '-'), {'input': b'PNG image'})])

    def test_region_screenshot_passes_selected_geometry_and_png_to_editor(self):
        calls = []
        def run(*args, **kwargs):
            calls.append((args, kwargs))
            return subprocess.CompletedProcess(args, 0, b'PNG region')
        with patch.dict(ENV, run=run), patch.object(subprocess, 'run', return_value=
                subprocess.CompletedProcess(['slurp'], 0, '10,20 300x200\n', '')):
            MODULE['screenshot']('region')
        self.assertEqual(calls, [(('grim', '-g', '10,20 300x200', '-'), {'capture_output': True}),
                                 (('swappy', '-f', '-'), {'input': b'PNG region'})])

    def test_relative_move_wraps_ten_workspaces(self):
        for current, direction, destination in [(1, 'prev', 10), (10, 'next', 1), (4, 'next', 5)]:
            with patch.dict(ENV, query=lambda _: [{'num': current, 'focused': True}], ipc=(calls := []).append):
                MODULE['main'](['move-workspace', direction])
            self.assertEqual(calls, [f'move container to workspace number {destination}; workspace number {destination}'])

    def test_wallpaper_paths_are_quoted_not_executed(self):
        with tempfile.TemporaryDirectory() as temp:
            home = Path(temp)
            wallpaper = home / 'name with "quotes"; exec bad.png'
            wallpaper.touch()
            state = home / '.config/sway/wallpaper'
            state.parent.mkdir(parents=True)
            state.write_text(str(wallpaper))
            runtime = home/'runtime'
            runtime.mkdir()
            with patch.object(Path, 'home', return_value=home), patch.dict(
                    os.environ, XDG_CONFIG_HOME=str(home/'.config'), XDG_RUNTIME_DIR=str(runtime)), patch.dict(
                    ENV, ipc=(calls := []).append, stop_session_wallpaper_players=lambda: None):
                MODULE['wallpaper']()
            alias = next(runtime.glob('orgm-sway-wallpapers-*/*'))
            self.assertEqual(alias.readlink(), wallpaper)
            self.assertEqual(calls, ['output * bg ' + json.dumps(str(alias)) + ' fill'])
            self.assertNotIn(';', calls[0])


if __name__ == '__main__':
    unittest.main()
