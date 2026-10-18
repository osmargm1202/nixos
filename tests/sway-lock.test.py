#!/usr/bin/env python3
"""Exercise the lock launcher without ever locking the test runner's session."""
import os
from pathlib import Path
import runpy
import stat
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent.parent
MODULE = runpy.run_path(str(ROOT / 'dotfiles/config/profiles/sway/.local/bin/orgm-sway-lock'))
ENV = MODULE['main'].__globals__
PROFILE = ROOT / 'dotfiles/config/profiles/sway/.config/swaylock'


class SwayLock(unittest.TestCase):
    def test_effects_options_keep_values_and_order_without_shell_parsing(self):
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / 'effects.conf'
            config.write_text('# comment\nclock\ntimestr=%I:%M %p\neffect-scale=0.5\neffect-scale=2\n')
            self.assertEqual(MODULE['effects_arguments'](config),
                             ['--clock', '--timestr', '%I:%M %p', '--effect-scale', '0.5', '--effect-scale', '2'])
            config.write_text('bad option=1\n')
            with self.assertRaises(ValueError):
                MODULE['effects_arguments'](config)

    def test_skin_has_effects_without_screenshots_or_grace(self):
        args = MODULE['effects_arguments'](PROFILE / 'effects.conf')
        self.assertIn('--clock', args)
        self.assertIn('--indicator', args)
        self.assertIn('--effect-blur', args)
        self.assertEqual(args[args.index('--grace') + 1], '0')
        self.assertNotIn('--screenshots', args)
        self.assertNotIn('--effect-custom', args)
        base = (PROFILE / 'config').read_text()
        for option in ('clock', 'effect-blur', 'fade-in', 'grace'):
            self.assertFalse(any(line.startswith(option) for line in base.splitlines()))

    def test_selected_palette_is_used_and_invalid_colors_are_not_interpreted(self):
        with tempfile.TemporaryDirectory() as directory:
            palette = Path(directory) / 'palette.css'
            palette.write_text('\n'.join(f'@define-color {name} #{color};' for name, color in {
                'base': '071422', 'text': 'f4f8ff', 'blue': '71b7ff', 'green': '86efac',
                'red': 'fda4af', 'yellow': 'fde68a'}.items()))
            args = MODULE['palette_arguments'](palette)
            self.assertEqual(args[args.index('--ring-color') + 1], '71b7ff99')
            self.assertEqual(args[args.index('--inside-color') + 1], '071422b8')
            palette.write_text('@define-color base #$(touch /tmp/bad);')
            self.assertEqual(MODULE['palette_arguments'](palette), [])

    def launch(self, effects=True, image=True, failure=False):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            config = home / '.config'
            (config / 'swaylock').mkdir(parents=True)
            (config / 'sway').mkdir()
            (config / 'swaylock/config').write_text((PROFILE / 'config').read_text())
            (config / 'swaylock/effects.conf').write_text('clock\ngrace=99\n')
            picture = home / "a  b:$(never-execute);'wallpaper.jpg"
            picture.write_bytes(b'test image')
            (config / 'sway/wallpaper').write_text(str(picture if image else home / 'missing.png') + '\n')
            calls = []

            def run(args, **kwargs):
                calls.append((args, kwargs))
                self.assertEqual(args[-1], '--daemonize')
                self.assertTrue(kwargs['check'])
                self.assertNotIn('shell', kwargs)
                cwd = Path(kwargs['cwd'])
                self.assertEqual(stat.S_IMODE(cwd.stat().st_mode), 0o700)
                if image:
                    self.assertEqual(args[args.index('--image') + 1], ':background')
                    self.assertEqual((cwd / 'background').resolve(), picture)
                    self.assertNotIn(str(picture), args)
                else:
                    self.assertNotIn('--image', args)
                if failure:
                    raise subprocess.CalledProcessError(1, args)
                return subprocess.CompletedProcess(args, 0)

            with patch.dict(os.environ, XDG_CONFIG_HOME=str(config)), \
                 patch.dict(ENV, locker_binary=lambda: ('/bin/locker', effects)), \
                 patch.object(ENV['subprocess'], 'run', side_effect=run):
                if failure:
                    with self.assertRaises(subprocess.CalledProcessError):
                        MODULE['main']([])
                else:
                    MODULE['main']([])
            self.assertEqual(len(calls), 1)
            self.assertFalse(Path(calls[0][1]['cwd']).exists(), 'Temporary symlink must be cleaned up')
            return calls[0][0]

    def test_effects_launch_is_safe_with_arbitrary_wallpaper_filenames(self):
        args = self.launch()
        self.assertIn('--clock', args)
        grace = [args[i + 1] for i, arg in enumerate(args) if arg == '--grace']
        self.assertEqual(grace[-1], '0', 'Style snippets cannot enable an unlock grace period')

    def test_plain_fallback_does_not_receive_unsupported_effects(self):
        args = self.launch(effects=False)
        self.assertNotIn('--clock', args)
        self.assertNotIn('--grace', args)

    def test_missing_wallpaper_keeps_a_solid_color_lock(self):
        self.launch(image=False)

    def test_video_wallpaper_uses_only_cached_png_or_solid_color(self):
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory)
            (config/'sway').mkdir()
            video = config/'video.mp4'
            video.write_bytes(b'not an image')
            frame = config/'frame.png'
            frame.write_bytes(b'test frame')
            (config/'sway/wallpaper').write_text(str(video)+'\n')
            preview = config/'sway/wallpaper-preview'
            with patch.dict(os.environ, XDG_CONFIG_HOME=str(config)):
                self.assertIsNone(MODULE['wallpaper']())
                preview.write_text(str(frame)+'\n')
                self.assertEqual(MODULE['wallpaper'](), frame)
                frame.unlink()
                self.assertIsNone(MODULE['wallpaper']())
                preview.write_text(str(video)+'\n')
                self.assertIsNone(MODULE['wallpaper']())

    def test_locker_failure_propagates_and_cleans_up(self):
        self.launch(failure=True)

    def test_effects_binary_is_preferred_but_plain_binary_remains_a_fallback(self):
        with tempfile.TemporaryDirectory() as directory:
            fallback = Path(directory) / 'orgm-swaylock-effects-package/bin/swaylock'
            fallback.parent.mkdir(parents=True)
            fallback.write_text('test')
            fallback.chmod(0o755)
            plain = Path(directory) / 'plain-swaylock'
            plain.write_text('test')
            plain.chmod(0o755)

            def help_output(args, **kwargs):
                return subprocess.CompletedProcess(args, 1, '', '--effect-blur' if args[0] == str(fallback) else 'plain')

            with patch.dict(os.environ, XDG_STATE_HOME=directory), \
                 patch.object(ENV['shutil'], 'which', return_value=str(plain)), \
                 patch.object(ENV['subprocess'], 'run', side_effect=help_output):
                self.assertEqual(MODULE['locker_binary'](), (str(fallback), True))
                fallback.unlink()
                self.assertEqual(MODULE['locker_binary'](), (str(plain), False))

    def test_all_lock_entry_points_use_one_helper(self):
        profile = ROOT / 'dotfiles/config/profiles/sway/.config'
        config = (profile / 'sway/config').read_text()
        idle = (profile / 'swayidle/config').read_text()
        self.assertIn('bindsym $mod+Mod1+l $exec orgm-sway-lock', config)
        self.assertEqual([line for line in config.splitlines() if line.startswith('bindsym $mod+l ')],
                         ['bindsym $mod+l $exec orgm-sway-lock'])
        self.assertIn('bindsym $mod+Right focus right', config)
        self.assertIn("timeout 600 'orgm-sway-lock'", idle)
        self.assertIn("before-sleep 'orgm-sway-lock'", idle)
        self.assertNotIn('swaylock -f', idle)


if __name__ == '__main__':
    unittest.main()
