#!/usr/bin/env python3
"""Wallpaper catalog, launcher and wordexp regression tests; no real compositor."""
import contextlib
import json
import os
from pathlib import Path
import runpy
import stat
import subprocess
import tempfile
import unittest
from unittest.mock import MagicMock, call, patch

ROOT = Path(__file__).resolve().parents[1]
MODULE = runpy.run_path(str(ROOT/'dotfiles/config/profiles/sway/.local/bin/orgm-sway'))
ENV = MODULE['wallpaper_catalog'].__globals__
UI = ROOT/'dotfiles/config/profiles/sway/.config/quickshell/orgm-wallpapers'


class WallpaperTests(unittest.TestCase):
    def setUp(self):
        self.stack = contextlib.ExitStack()
        self.addCleanup(self.stack.close)
        self.home = Path(self.stack.enter_context(tempfile.TemporaryDirectory()))
        self.config = self.home/'.config'
        self.runtime = self.home/'runtime'
        self.runtime.mkdir()
        self.stack.enter_context(patch.dict(os.environ, {
            'HOME': str(self.home), 'XDG_CONFIG_HOME': str(self.config),
            'XDG_STATE_HOME': str(self.home/'.local/state'), 'XDG_RUNTIME_DIR': str(self.runtime),
            'XDG_CACHE_HOME': str(self.home/'.cache')}, clear=True))
        self.stack.enter_context(patch.object(Path, 'home', return_value=self.home))
        self.stack.enter_context(patch.dict(ENV, query=lambda _: [dict(focused=True, output='TEST-2')]))

    def file(self, relative, text=''):
        path = self.home/relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        return path

    def test_catalog_profile_shared_current_and_deduplication(self):
        self.file('.local/state/orgm-visual-profile/current', 'slc\n')
        active = self.file('Pictures/slc/nested/a.png')
        shared = self.file('Pictures/Wallpapers/b.JPG')
        external = self.file('other/current.webp')
        self.file('.config/sway/wallpaper', str(external)+'\n')
        self.file('Pictures/orgm/excluded.png')
        self.file('Pictures/slc/not-an-image.pdf')
        (active.parent/'alias.png').symlink_to(shared)
        data = MODULE['wallpaper_catalog']()
        self.assertEqual(data['profile'], 'slc')
        self.assertEqual(data['screen'], 'TEST-2')
        self.assertEqual({p['path'] for p in data['items']}, {str(active), str(shared), str(external)})
        self.assertEqual(data['current'], str(external))
        self.assertTrue(all(p['url'].startswith('file:///') for p in data['items']))

    def test_catalog_includes_videos_without_decoding_them(self):
        videos = [self.file('Pictures/orgm/'+name) for name in ('movie.MP4', 'a.webm', 'b.mkv', 'c.mov', 'd.m4v', 'e.avi')]
        current = self.file('external/current.mp4')
        self.file('.config/sway/wallpaper', str(current)+'\n')
        with patch.dict(ENV, wallpaper_preview=lambda _: self.fail('Catalog must not decode videos')):
            data = MODULE['wallpaper_catalog']()
        self.assertEqual({p['path'] for p in data['items']}, {str(p) for p in videos+[current]})
        self.assertTrue(all(p['kind'] == 'video' for p in data['items']))

    def test_video_preview_cache_invalidation_and_literal_arguments(self):
        video = self.file('Pictures/orgm/ñ $(touch BAD)  #.mp4')
        calls = []
        def ffmpeg(*args, **kwargs):
            calls.append(args)
            self.assertEqual(args[0], '/tools/ffmpeg')
            self.assertEqual(args[args.index('-i')+1], str(video))
            self.assertEqual(kwargs['timeout'], 20)
            Path(args[-1]).write_bytes(b'fake PNG for mocked decoder')
            return subprocess.CompletedProcess(args, 0, '', '')
        with patch.dict(ENV, run=ffmpeg, wallpaper_tool=lambda name: '/tools/'+name):
            first = MODULE['wallpaper_preview'](video)
            self.assertTrue(first.is_file())
            self.assertEqual(MODULE['wallpaper_preview'](video), first)
            self.assertEqual(len(calls), 1)
            video.write_text('changed size')
            self.assertNotEqual(MODULE['wallpaper_preview'](video), first)
            self.assertEqual(len(calls), 2)
        self.assertFalse((self.home/'BAD').exists())

    def test_video_preview_failure_does_not_publish_cache(self):
        video = self.file('movie.mp4')
        def fail(*args, **kwargs):
            Path(args[-1]).write_bytes(b'partial')
            raise subprocess.CalledProcessError(1, args)
        with patch.dict(ENV, run=fail, wallpaper_tool=lambda name: name):
            with self.assertRaises(subprocess.CalledProcessError):
                MODULE['wallpaper_preview'](video)
        self.assertEqual(list((self.home/'.cache/orgm-sway-wallpapers').iterdir()), [])

    def test_video_application_and_image_switch_only_stop_owned_player(self):
        video = self.file('movie.mp4')
        frame = self.file('frame.png')
        image = self.file('still.webp')
        unit = 'orgm-sway-video-' + 'a'*32 + '.service'
        calls = []
        with patch.dict(ENV, wallpaper_preview=lambda p: frame if p == video else p,
                        wallpaper_tool=lambda name: '/tools/'+name,
                        start_wallpaper_video=lambda p: calls.append(('start', p)) or unit,
                        stop_wallpaper_video=lambda u: calls.append(('stop', u)),
                        stop_session_wallpaper_players=lambda: calls.append(('clean',)),
                        ipc=lambda cmd: calls.append(('ipc', cmd))):
            MODULE['set_wallpaper'](video)
            self.assertEqual((self.config/'sway/wallpaper').read_text().strip(), str(video))
            self.assertEqual((self.config/'sway/wallpaper-preview').read_text().strip(), str(frame))
            self.assertEqual(calls, [('clean',), ('start', video)])  # no swaybg over video
            MODULE['set_wallpaper'](image)
        self.assertEqual(calls[-3:-1], [('stop', unit), ('clean',)])
        self.assertEqual(calls[-1][0], 'ipc')
        self.assertEqual((self.config/'sway/wallpaper-video-unit').read_text().strip(), '')
        self.assertEqual((self.config/'sway/wallpaper').read_text().strip(), str(image))

    def test_failed_video_start_stops_first_then_restores_previous_without_overlap(self):
        video = self.file('movie.mp4')
        old_video = self.file('previous.mp4')
        frame = self.file('frame.png')
        previous = 'orgm-sway-video-' + 'b'*32 + '.service'
        restored = 'orgm-sway-video-' + 'c'*32 + '.service'
        state = self.file('.config/sway/wallpaper', str(old_video)+'\n')
        self.file('.config/sway/wallpaper-video-unit', previous+'\n')
        calls = []
        def start(path):
            calls.append(('start', path))
            if path == video:
                raise RuntimeError('start failed')
            return restored
        with patch.dict(ENV, wallpaper_preview=lambda _: frame, wallpaper_tool=lambda name: name,
                        start_wallpaper_video=start,
                        stop_wallpaper_video=lambda unit: calls.append(('stop', unit)),
                        stop_session_wallpaper_players=lambda: calls.append(('clean',))):
            with self.assertRaisesRegex(RuntimeError, 'start failed'):
                MODULE['set_wallpaper'](video)
        self.assertEqual(calls, [('stop', previous), ('clean',), ('start', video), ('clean',), ('start', old_video)])
        self.assertEqual(state.read_text(), str(old_video)+'\n')
        self.assertEqual((self.config/'sway/wallpaper-video-unit').read_text().strip(), restored)

    def test_failure_to_stop_previous_player_never_starts_replacement(self):
        video = self.file('movie.mp4')
        previous = 'orgm-sway-video-' + 'b'*32 + '.service'
        state = self.file('.config/sway/wallpaper', 'previous.mp4\n')
        self.file('.config/sway/wallpaper-video-unit', previous+'\n')
        with patch.dict(ENV, wallpaper_preview=lambda p: p, wallpaper_tool=lambda name: name,
                        stop_wallpaper_video=MagicMock(side_effect=RuntimeError('still running')),
                        start_wallpaper_video=MagicMock()) as env:
            with self.assertRaisesRegex(RuntimeError, 'still running'):
                MODULE['set_wallpaper'](video)
            env['start_wallpaper_video'].assert_not_called()
        self.assertEqual(state.read_text(), 'previous.mp4\n')
        self.assertEqual((self.config/'sway/wallpaper-video-unit').read_text().strip(), previous)

    def test_session_player_matching_requires_executable_uid_and_wayland_endpoint(self):
        process = self.home/'proc/123'
        process.mkdir(parents=True)
        executable = self.file('bin/.swaybg-wrapped')
        (process/'exe').symlink_to(executable)
        environment = process/'environ'
        environment.write_bytes(b'WAYLAND_DISPLAY=wayland-private\0XDG_RUNTIME_DIR=/private\0')
        with patch.dict(os.environ, WAYLAND_DISPLAY='wayland-private', XDG_RUNTIME_DIR='/private'):
            self.assertTrue(MODULE['is_session_wallpaper_process'](process))
            with patch('os.getuid', return_value=os.getuid()+1):
                self.assertFalse(MODULE['is_session_wallpaper_process'](process))
            with patch.dict(os.environ, WAYLAND_DISPLAY='wayland-other'):
                self.assertFalse(MODULE['is_session_wallpaper_process'](process))
            with patch.dict(os.environ, XDG_RUNTIME_DIR='/other'):
                self.assertFalse(MODULE['is_session_wallpaper_process'](process))
            (process/'exe').unlink()
            (process/'exe').symlink_to(self.file('bin/unrelated-player'))
            self.assertFalse(MODULE['is_session_wallpaper_process'](process))

    def test_session_players_are_waited_for_and_stubborn_processes_are_killed_via_pidfd(self):
        process = Path('/proc/123')
        for responses, expected in (([[(17, 1)]], [call(17, ENV['signal'].SIGTERM)]),
                                    ([[], [(17, 1)]], [call(17, ENV['signal'].SIGTERM), call(17, ENV['signal'].SIGKILL)])):
            with patch.dict(os.environ, WAYLAND_DISPLAY='private', XDG_RUNTIME_DIR='/private'), \
                 patch.object(Path, 'iterdir', return_value=iter([process])), \
                 patch.dict(ENV, is_session_wallpaper_process=lambda _: True), \
                 patch('os.pidfd_open', return_value=17) as opened, patch('os.close') as closed, \
                 patch('signal.pidfd_send_signal') as sent, patch('select.poll') as poll:
                poll.return_value.poll.side_effect = responses
                MODULE['stop_session_wallpaper_players']()
                opened.assert_called_once_with(123)
                self.assertEqual(sent.call_args_list, expected)
                closed.assert_called_once_with(17)

    def test_transient_player_is_session_owned_and_paths_are_not_shell(self):
        video = self.file('ñ ${HOME} $(touch BAD)  #.mp4')
        calls = []
        with patch.dict(ENV, wallpaper_tool=lambda _: '/tools/mpvpaper',
                        run=lambda *a, **kw: calls.append(a)), patch('time.sleep'):
            unit = MODULE['start_wallpaper_video'](video)
        launch = calls[0]
        self.assertIn('--property=PartOf=sway-session.target', launch)
        self.assertIn('--service-type=exec', launch)
        self.assertIn('--property=KillMode=control-group', launch)
        self.assertIn('--property=TimeoutStopSec=2s', launch)
        self.assertIn('--expand-environment=no', launch)
        self.assertEqual(launch[-3:], ('no-config no-audio loop-file=inf panscan=1', 'ALL', str(video)))
        self.assertEqual(calls[-1], ('systemctl', '--user', 'is-active', '--quiet', unit))
        self.assertFalse((self.home/'BAD').exists())

    def test_offload_requires_wrapper_and_a_responsive_nvidia_driver(self):
        for wrapper, probe, code, output, expected in (
                (None, '/tools/nvidia-smi', 0, 'GPU 0: NVIDIA test', None),
                ('/tools/nvidia-offload', None, 0, 'GPU 0: NVIDIA test', None),
                ('/tools/nvidia-offload', '/tools/nvidia-smi', 9, '', None),
                ('/tools/nvidia-offload', '/tools/nvidia-smi', 0, 'No devices were found', None),
                ('/tools/nvidia-offload', '/tools/nvidia-smi', 0, 'GPU 0: NVIDIA test', '/tools/nvidia-offload')):
            with self.subTest(wrapper=wrapper, probe=probe, code=code, output=output), \
                 patch('shutil.which', side_effect=lambda name: wrapper if name == 'nvidia-offload' else probe), \
                 patch.object(subprocess, 'run', return_value=subprocess.CompletedProcess([], code, output, '')) as run:
                self.assertEqual(MODULE['wallpaper_nvidia_offload'](), expected)
                if wrapper and probe:
                    self.assertEqual(run.call_args.kwargs['timeout'], 2)
                else:
                    run.assert_not_called()

    def test_offload_probe_timeout_and_explicit_disable_use_default_gpu(self):
        with patch('shutil.which', return_value='/tools/binary'), patch.object(
                subprocess, 'run', side_effect=subprocess.TimeoutExpired('nvidia-smi', 2)):
            self.assertIsNone(MODULE['wallpaper_nvidia_offload']())
        with patch.dict(os.environ, ORGM_SWAY_WALLPAPER_OFFLOAD='0'), patch('shutil.which') as which:
            self.assertIsNone(MODULE['wallpaper_nvidia_offload']())
            which.assert_not_called()

    def test_offload_launch_and_default_gpu_retry_never_overlap(self):
        video = self.file('video.mp4')
        calls = []
        attempts = []
        stopped = []
        def run(*args, **kwargs):
            calls.append(args)
            if args[0] == 'systemd-run':
                unit = next(a.removeprefix('--unit=') for a in args if a.startswith('--unit='))
                if attempts:
                    self.assertEqual(stopped, attempts)  # failed attempt must already be gone
                attempts.append(unit)
            elif len(attempts) == 1:
                raise subprocess.CalledProcessError(1, args)
        with patch.dict(ENV, wallpaper_tool=lambda _: '/tools/mpvpaper',
                        wallpaper_nvidia_offload=lambda: '/tools/nvidia-offload',
                        run=run, stop_wallpaper_video=stopped.append), patch('time.sleep'):
            unit = MODULE['start_wallpaper_video'](video)
        launches = [c for c in calls if c[0] == 'systemd-run']
        first = launches[0][launches[0].index('--')+1:]
        second = launches[1][launches[1].index('--')+1:]
        self.assertEqual(first[:2], ('/tools/nvidia-offload', '/tools/mpvpaper'))
        self.assertEqual(second[0], '/tools/mpvpaper')
        self.assertEqual(unit, attempts[1])
        self.assertNotEqual(attempts[0], attempts[1])
        self.assertEqual(stopped, [attempts[0]])

    def test_working_offload_does_not_launch_a_second_player(self):
        calls = []
        with patch.dict(ENV, wallpaper_tool=lambda _: '/tools/mpvpaper',
                        wallpaper_nvidia_offload=lambda: '/tools/nvidia-offload',
                        run=lambda *args, **kw: calls.append(args),
                        stop_wallpaper_video=lambda _: self.fail('Successful player must stay running')), patch('time.sleep'):
            MODULE['start_wallpaper_video'](self.file('video.mp4'))
        launches = [c for c in calls if c[0] == 'systemd-run']
        self.assertEqual(len(launches), 1)
        self.assertIn('/tools/nvidia-offload', launches[0])

    def test_stop_rejects_arbitrary_units_and_accepts_collected_owner(self):
        with patch.object(subprocess, 'run') as command:
            for unit in ('ssh.service', 'orgm-sway-video-evil.service', '; exec bad', ''):
                MODULE['stop_wallpaper_video'](unit)
            command.assert_not_called()
            command.return_value = subprocess.CompletedProcess([], 5, '', 'not loaded')
            MODULE['stop_wallpaper_video']('orgm-sway-video-'+'c'*32+'.service')
            self.assertEqual(command.call_count, 2)

    def test_restore_video_does_not_record_profile(self):
        video = self.file('movie.mp4')
        self.file('.config/sway/wallpaper', str(video)+'\n')
        with patch.dict(ENV, set_wallpaper=MagicMock()) as env:
            MODULE['wallpaper']()
            env['set_wallpaper'].assert_called_once_with(video, record=False)

    def test_palette_and_override_paths_are_validated_not_executed(self):
        self.file('custom-state/current', 'osmar\n')
        image = self.file('custom-pictures/osmar/mañana "$(touch BAD)" #.png')
        self.file('.config/waybar/orgm-current.css', '@define-color base #123AbC;\n'
            '@define-color blue #abcdef;\n@define-color red url(evil);\n@define-color text #00000000;\n')
        with patch.dict(os.environ, ORGM_VISUAL_PROFILE_STATE_DIR=str(self.home/'custom-state'),
                        ORGM_VISUAL_PROFILE_PICTURES_ROOT=str(self.home/'custom-pictures')):
            data = MODULE['wallpaper_catalog']()
        self.assertEqual(data['profile'], 'osmar')
        self.assertEqual(data['items'][0]['path'], str(image))
        self.assertIn('%23', data['items'][0]['url'])
        self.assertIn('%22', data['items'][0]['url'])
        self.assertEqual(data['colors']['bg'], '#123AbC')
        self.assertEqual(data['colors']['accent'], '#abcdef')
        self.assertEqual(data['colors']['error'], '#ff8a8a')
        self.assertFalse((self.home/'BAD').exists())

    def test_invalid_profile_cannot_escape_pictures_root(self):
        self.file('.local/state/orgm-visual-profile/current', '../../escape\n')
        image = self.file('Pictures/orgm/normal.png')
        with patch.dict(ENV, query=lambda _: (_ for _ in ()).throw(RuntimeError('no IPC'))):
            data = MODULE['wallpaper_catalog']()
        self.assertEqual(data['profile'], 'orgm')
        self.assertEqual(data['screen'], '')
        self.assertEqual(data['items'][0]['path'], str(image))

    def test_alias_handles_shell_quotes_unicode_and_repeated_spaces(self):
        for name in ('simple.png', 'mañana  "$(touch BAD)" `touch BAD` ; #.png', "single'quote.png", 'a\\b.png'):
            image = self.file('images/'+name)
            alias = MODULE['wallpaper_ipc_path'](image)
            self.assertRegex(str(alias), r'^/[a-zA-Z0-9/_.-]+$')
            if name != 'simple.png':
                self.assertEqual(alias.readlink(), image)
                self.assertEqual(stat.S_IMODE(alias.parent.stat().st_mode), 0o700)
                self.assertEqual(MODULE['wallpaper_ipc_path'](image), alias)
        self.assertFalse((self.home/'BAD').exists())

    def test_alias_directory_symlink_or_nonprivate_permissions_are_rejected(self):
        image = self.file('images/a b.png')
        directory = self.runtime/f'orgm-sway-wallpapers-{os.getuid()}'
        directory.symlink_to(self.home, target_is_directory=True)
        with self.assertRaises(ValueError):
            MODULE['wallpaper_ipc_path'](image)
        directory.unlink()
        directory.mkdir(mode=0o755)
        with self.assertRaises(ValueError):
            MODULE['wallpaper_ipc_path'](image)

    def test_existing_alias_is_not_overwritten(self):
        image = self.file('images/a b.png')
        alias = MODULE['wallpaper_ipc_path'](image)
        alias.unlink()
        alias.write_text('leave intact')
        with self.assertRaises(ValueError):
            MODULE['wallpaper_ipc_path'](image)
        self.assertEqual(alias.read_text(), 'leave intact')

    def test_gui_receives_private_json_and_no_shell_command(self):
        self.file('.config/quickshell/orgm-wallpapers/shell.qml')
        seen = []
        catalog = {'items': [{'name': '"$(touch BAD)"', 'path': 'data only'}]}
        def run(args, **kwargs):
            data = Path(kwargs['env']['ORGM_WALLPAPER_DATA'])
            seen.append(data)
            self.assertEqual(json.loads(data.read_text()), catalog)
            self.assertEqual(stat.S_IMODE(data.stat().st_mode), 0o600)
            self.assertEqual(stat.S_IMODE(data.parent.stat().st_mode), 0o700)
            self.assertEqual(args, ['/fake/qs', '--no-duplicate', '--path', str(self.config/'quickshell/orgm-wallpapers')])
            self.assertNotIn('shell', kwargs)
            Path(kwargs['env']['ORGM_WALLPAPER_STATUS']).write_text('ready')
            child = MagicMock()
            child.__enter__.return_value = child
            child.poll.return_value = None
            child.wait.return_value = 0
            return child
        with patch.dict(ENV, quickshell_binary=lambda: '/fake/qs'), patch.object(subprocess, 'Popen', side_effect=run):
            self.assertTrue(MODULE['graphical_wallpaper_picker'](catalog))
        self.assertFalse(seen[0].exists())

    def test_qml_startup_failure_returns_to_fallback_and_cleans_catalog(self):
        self.file('.config/quickshell/orgm-wallpapers/shell.qml')
        seen = []
        def run(args, **kwargs):
            seen.append(Path(kwargs['env']['ORGM_WALLPAPER_DATA']))
            child = MagicMock()
            child.__enter__.return_value = child
            child.poll.return_value = 1
            child.returncode = 1
            return child
        with patch.dict(ENV, quickshell_binary=lambda: '/fake/qs'), patch.object(subprocess, 'Popen', side_effect=run):
            self.assertFalse(MODULE['graphical_wallpaper_picker']({}))
        self.assertFalse(seen[0].exists())

    def test_startup_watchdog_terminates_only_its_child(self):
        self.file('.config/quickshell/orgm-wallpapers/shell.qml')
        child = MagicMock()
        child.__enter__.return_value = child
        child.poll.return_value = None
        with patch.dict(ENV, quickshell_binary=lambda: '/fake/qs'), patch.object(
                subprocess, 'Popen', return_value=child), patch('time.monotonic', side_effect=[0, 11]):
            self.assertFalse(MODULE['graphical_wallpaper_picker']({}))
        child.terminate.assert_called_once_with()
        child.wait.assert_called_once_with(timeout=2)
        child.kill.assert_not_called()

    def test_missing_or_failed_gui_falls_back_without_changes_on_cancel(self):
        image = self.file('Pictures/orgm/a.png')
        self.file('.config/sway/wallpaper', str(image)+'\n')
        for handled in (True, False):
            calls = []
            with patch.dict(ENV, graphical_wallpaper_picker=lambda _: handled,
                            pick=lambda *args: calls.append(args) or '',
                            set_wallpaper=lambda _: self.fail('Unexpected change on cancel')):
                MODULE['wallpaper'](True)
            self.assertEqual(bool(calls), not handled)
        with patch.dict(ENV, quickshell_binary=lambda: None):
            self.assertFalse(MODULE['graphical_wallpaper_picker']({}))

    def test_gc_root_binary_fallback_and_system_preference(self):
        binary = self.file('.local/state/orgm-sway-wallpaper-quickshell/bin/qs')
        binary.chmod(0o755)
        with patch('shutil.which', return_value=None):
            self.assertEqual(MODULE['quickshell_binary'](), str(binary))
        with patch('shutil.which', return_value='/system/qs'):
            self.assertEqual(MODULE['quickshell_binary'](), '/system/qs')

    def test_wheel_receiver_is_visual_and_does_not_intercept_card_buttons(self):
        picker = (UI/'modules/WallpaperPicker.qml').read_text()
        self.assertNotIn('    WheelHandler {', picker)
        self.assertIn('id: wheelInput', picker)
        self.assertIn('acceptedButtons: Qt.NoButton', picker)
        self.assertIn('scrollGestureEnabled: true', picker)
        self.assertIn('event.pixelDelta.y || event.pixelDelta.x', picker)
        self.assertIn('event.angleDelta.y || event.angleDelta.x', picker)
        self.assertIn('Math.trunc(remainder / unit)', picker)

    def test_video_posters_are_loaded_lazily_without_qt_multimedia(self):
        picker = (UI/'modules/WallpaperPicker.qml').read_text()
        self.assertIn('"wallpaper-preview", modelData.path', picker)
        self.assertIn('visible && isVideo && !poster', picker)
        self.assertIn('card.isVideo ? card.poster', picker)
        self.assertNotIn('QtMultimedia', picker)
        package = (ROOT/'nixos/profiles/sway/quickshell.nix').read_text()
        self.assertIn('pkgs.qt6.qtimageformats', package)
        self.assertIn('QT_PLUGIN_PATH', package)

    def test_only_picker_is_vendored_and_names_are_plain_text(self):
        shell = (UI/'shell.qml').read_text()
        picker = (UI/'modules/WallpaperPicker.qml').read_text()
        self.assertIn('onDismissed: Qt.quit()', shell)
        self.assertNotIn('PowerMenu', shell)
        self.assertNotIn('WifiMenu', shell)
        self.assertIn('[catalog.backend, "wallpaper-set", files[current].path]', picker)
        self.assertNotIn('set-wallpaper.sh', picker)
        self.assertIn('textFormat: Text.PlainText', picker)
        self.assertNotIn('FolderListModel', picker)
        self.assertIn('4e61255e006de0f994ae21cfeab9bac5ccd58acc', (UI/'NOTICE.md').read_text())
        manifest = json.loads((ROOT/'dotfiles/apps/sway-wallpapers.json').read_text())
        self.assertEqual(manifest['paths'], ['.config/quickshell/orgm-wallpapers'])


if __name__ == '__main__':
    unittest.main()
