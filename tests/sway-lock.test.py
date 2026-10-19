#!/usr/bin/env python3
"""Fast qylock/SDDM contracts. No compositor, PAM, Polkit or physical devices."""
import fcntl
import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import stat
import subprocess
import tempfile
import types
import unittest
from unittest.mock import patch, Mock

ROOT = Path(__file__).resolve().parents[1]
loader = importlib.machinery.SourceFileLoader('orgm_qylock', str(ROOT/'dotfiles/config/profiles/sway/.local/bin/orgm-qylock'))
spec = importlib.util.spec_from_loader(loader.name, loader)
client = importlib.util.module_from_spec(spec); loader.exec_module(client)


class Qylock(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='qylock-unit-')
        self.root = Path(self.temp.name)
        self.home = self.root/'home'; self.home.mkdir()
        self.runtime = self.root/'runtime'; self.runtime.mkdir(mode=0o700)
        self.environment = patch.dict(os.environ, HOME=str(self.home), XDG_CONFIG_HOME=str(self.home/'.config'),
            XDG_STATE_HOME=str(self.home/'.local/state'), XDG_RUNTIME_DIR=str(self.runtime),
            XDG_CURRENT_DESKTOP='sway', WAYLAND_DISPLAY='wayland-private-test', SWAYSOCK=str(self.runtime/'sway-ipc.test.sock'))
        self.environment.start()
        self.package = self.root/'package'
        base = self.package/'share/orgm-qylock'; base.mkdir(parents=True)
        for slug in ('winter','forest','clockwork/orbital'):
            theme = base/'themes'/slug; theme.mkdir(parents=True)
            (theme/'Main.qml').write_text('import QtQuick\nItem {}\n')
        self.items = [dict(id=s,name=s,config={},preview=s.replace('/','--')+'.png')
                      for s in ('winter','forest','clockwork/orbital')]
        (base/'catalog.json').write_text(json.dumps(self.items))
        self.metadata = dict(defaultTheme='forest', catalog=str(base/'catalog.json'), themes=str(base/'themes'),
            previews=str(base/'previews'), qs='/nix/store/test/bin/qs', apply='/nix/store/test/bin/apply',
            pamDirectory='/nix/store/test/pam', lockQml='/nix/store/test/lock.qml')
        source = (ROOT/'nixos/profiles/sway/qylock-apply.py').read_text()
        source = source.replace('@package@',str(self.package)).replace('@default_theme@','forest').replace('@qt_environment@','{"QML_XHR_ALLOW_FILE_READ":"1"}')
        self.admin = types.ModuleType('qylock_admin_unit')
        exec(compile(source,'qylock_admin_unit','exec'), self.admin.__dict__)
        self.state = self.root/'state'
        self.dropin = self.root/'etc/90-orgm-qylock.conf'

    def tearDown(self):
        self.environment.stop();self.temp.cleanup()

    def apply(self, slug):
        self.admin.apply_theme(slug,self.package,self.state,self.dropin)

    def test_current_theme_migrates_legacy_and_validates(self):
        self.assertEqual(client.current_theme(self.metadata),'forest')
        legacy = client.config_home()/'qylock/theme';legacy.parent.mkdir(parents=True)
        legacy.write_text('winter\n');self.assertEqual(client.current_theme(self.metadata),'winter')
        legacy.write_text('../escape');self.assertEqual(client.current_theme(self.metadata),'forest')

    def test_atomic_private_text(self):
        path=self.home/'private/pref';client.atomic_text(path,'winter\n')
        self.assertEqual(path.read_text(),'winter\n')
        self.assertEqual(stat.S_IMODE(path.stat().st_mode),0o600)
        self.assertEqual(list(path.parent.glob('.pref-*')),[])

    def test_fingerprint_is_explicit_opt_in_no_default_probe(self):
        with patch.object(client.subprocess,'run') as run:
            self.assertFalse(client.fingerprint_available(dict(fingerprintList='/test/fprintd-list'),'test'))
            run.assert_not_called()

    def test_nix_fingerprint_opt_in_and_user_opt_out_do_not_probe(self):
        enabled=dict(fingerprintEnabled=True)
        with patch.object(client.subprocess,'run') as run:
            self.assertTrue(client.fingerprint_available(enabled,'test'))
            preference=client.config_home()/'orgm-qylock/fingerprint'
            preference.parent.mkdir(parents=True);preference.write_text('off\n')
            self.assertFalse(client.fingerprint_available(enabled,'test'))
            run.assert_not_called()

    def test_unknown_selection_never_invokes_polkit(self):
        with patch.object(client.subprocess,'run') as run:
            with self.assertRaises(ValueError):client.select_theme(self.metadata,'../../etc')
            run.assert_not_called()

    def test_cancelled_authorization_never_changes_selection(self):
        legacy=client.config_home()/'qylock/theme';legacy.parent.mkdir(parents=True);legacy.write_text('winter\n')
        with patch.object(Path,'resolve',return_value=Path('/nix/store/test/bin/apply')), \
                patch.object(Path,'stat',return_value=types.SimpleNamespace(st_uid=0,st_mode=0o100555)), \
                patch.object(client.subprocess,'run',return_value=subprocess.CompletedProcess([],126)) as run, \
                patch.object(client,'atomic_text') as write:
            with self.assertRaisesRegex(RuntimeError,'autorización cancelada'):
                client.select_theme(self.metadata,'forest')
            self.assertEqual(run.call_args.args[0],['/run/wrappers/bin/pkexec','/nix/store/test/bin/apply','select','forest'])
            write.assert_not_called()
        self.assertEqual(legacy.read_text(),'winter\n')

    def test_picker_catalog_only_pinned_ids_and_static_previews(self):
        with patch.object(client.subprocess,'run',side_effect=OSError):data=client.picker_catalog(self.metadata)
        self.assertEqual(len(data['items']),3)
        self.assertTrue(all(i['url'].startswith('file:///') and i['url'].endswith('.png') for i in data['items']))
        self.assertEqual(data['items'][2]['id'],'clockwork/orbital')

    def test_runtime_requires_private_real_directory(self):
        self.runtime.chmod(0o755)
        with self.assertRaises(ValueError):client.runtime_paths()
        self.runtime.chmod(0o700)
        runtime,lock,information=client.runtime_paths()
        self.assertEqual(runtime,self.runtime)
        self.assertRegex(lock.name,r'^orgm-qylock-[0-9a-f]{20}\.lock$')

    def test_duplicate_lock_waits_for_real_secure_state(self):
        _,lock,info=client.runtime_paths()
        descriptor=os.open(lock,os.O_CREAT|os.O_RDWR,0o600)
        try:
            fcntl.flock(descriptor,fcntl.LOCK_EX|fcntl.LOCK_NB)
            with patch.object(client,'compositor_secure',return_value=True) as secure, patch.object(client.subprocess,'Popen') as popen:
                self.assertEqual(client.lock(self.metadata),0)
                secure.assert_called_once_with(self.metadata,info);popen.assert_not_called()
        finally:os.close(descriptor)

    def test_launcher_hands_lock_fd_to_supervisor_and_confirms_secure(self):
        held=[]
        def spawn(args,**kwargs):
            instance=Path(args[-2]);(instance/'ready').write_text('secure')
            held.extend(kwargs['pass_fds']);self.assertTrue(kwargs['start_new_session'])
            self.assertTrue(stat.S_ISREG(os.fstat(held[0]).st_mode))
            self.assertEqual(args[-3],'_supervise')
            return types.SimpleNamespace(poll=lambda:None)
        with patch.object(client,'lock_settings',return_value={'test':'private'}), \
                patch.object(client,'compositor_secure',return_value=True), patch.object(client.subprocess,'Popen',side_effect=spawn):
            self.assertEqual(client.lock(self.metadata),0)
        with self.assertRaises(OSError):os.fstat(held[0])

    def test_native_hyprland_lock_requires_compositor_secure_ack(self):
        os.environ.pop('SWAYSOCK')
        os.environ.update(XDG_CURRENT_DESKTOP='Hyprland', HYPRLAND_INSTANCE_SIGNATURE='private-a')
        def spawn(args, **kwargs):
            (Path(args[-2])/'ready').write_text('secure')
            return types.SimpleNamespace(poll=lambda: None)
        with patch.object(client, 'lock_settings', return_value={}), \
                patch.object(client.subprocess, 'Popen', side_effect=spawn), \
                patch.object(client, 'compositor_secure', return_value=True) as secure:
            self.assertEqual(client.lock(self.metadata), 0)
            secure.assert_called_once()
        with patch.object(client, 'lock_settings', return_value={}), \
                patch.object(client.subprocess, 'Popen', side_effect=spawn), \
                patch.object(client, 'compositor_secure', return_value=False), \
                patch.object(client.time, 'monotonic', side_effect=[0, 1, 11]), \
                patch.object(client.time, 'sleep'):
            with self.assertRaises(RuntimeError):
                client.lock(self.metadata)

    def test_lock_identity_separates_hyprland_instances_and_preserves_sway(self):
        sway = client.runtime_paths()[1]
        os.environ['HYPRLAND_INSTANCE_SIGNATURE'] = 'inherited-parent'
        self.assertEqual(client.runtime_paths()[1], sway)
        os.environ['XDG_CURRENT_DESKTOP'] = 'Hyprland'
        first = client.runtime_paths()[1]
        self.assertNotEqual(first, sway)
        os.environ['HYPRLAND_INSTANCE_SIGNATURE'] = 'private-b'
        self.assertNotEqual(client.runtime_paths()[1], first)

    def test_hyprland_picker_uses_native_screen_and_palette(self):
        os.environ.update(XDG_CURRENT_DESKTOP='Hyprland', HYPRLAND_INSTANCE_SIGNATURE='private-a')
        palette = client.config_home()/'waybar-hypr/orgm-current.css'
        palette.parent.mkdir(parents=True)
        palette.write_text('@define-color base #123456;\n')
        response = subprocess.CompletedProcess([], 0, '[{"name":"DP-2","focused":true}]')
        with patch.object(client.subprocess, 'run', return_value=response) as run:
            data = client.picker_catalog(self.metadata)
        self.assertEqual(data['screen'], 'DP-2')
        self.assertEqual(data['colors']['bg'], '#123456')
        self.assertEqual(run.call_args.args[0], ['hyprctl', '-j', 'monitors'])

    def test_authenticated_exit_is_not_acknowledged_as_secure(self):
        info=self.root/'instance.json';info.write_text('{"pid":123}')
        response=subprocess.CompletedProcess([],0,'{"secure":true,"authenticated":true}')
        with patch.object(client.subprocess,'run',return_value=response):
            self.assertFalse(client.compositor_secure(self.metadata,info))

    def test_before_sleep_relocks_after_authenticated_instance_exits(self):
        _,path,info=client.runtime_paths();held=os.open(path,os.O_CREAT|os.O_RDWR,0o600)
        fcntl.flock(held,fcntl.LOCK_EX|fcntl.LOCK_NB)
        checked=[]
        def secure(*args):
            checked.append(True)
            if len(checked)==1:
                fcntl.flock(held,fcntl.LOCK_UN)
                return False
            return True
        def spawn(args,**kwargs):
            (Path(args[-2])/'ready').write_text('secure')
            return types.SimpleNamespace(poll=lambda:None)
        try:
            with patch.object(client,'compositor_secure',side_effect=secure), \
                    patch.object(client,'lock_settings',return_value={'test':'private'}), \
                    patch.object(client.subprocess,'Popen',side_effect=spawn) as popen:
                self.assertEqual(client.lock(self.metadata),0)
                popen.assert_called_once();self.assertEqual(len(checked),2)
        finally:os.close(held)

    def test_untrusted_lock_file_symlink_rejected(self):
        _,lock,_=client.runtime_paths();target=self.root/'unrelated';target.write_text('keep')
        lock.symlink_to(target)
        with self.assertRaises(OSError):client.lock(self.metadata)
        self.assertEqual(target.read_text(),'keep')

    def test_root_helper_rejects_unknown_before_any_mutation(self):
        with self.assertRaises(ValueError):self.apply('../escape')
        self.assertFalse(self.state.exists());self.assertFalse(self.dropin.exists())

    def test_root_helper_shared_atomic_selection(self):
        self.apply('winter')
        self.assertEqual((self.state/'sddm/current').resolve(),(self.package/'share/orgm-qylock/themes/winter').resolve())
        self.assertEqual((self.state/'selection').read_text(),'winter\n')
        self.assertIn('Current=current',self.dropin.read_text())
        self.assertIn('QML_XHR_ALLOW_FILE_READ=1',self.dropin.read_text())
        self.apply('clockwork/orbital')
        self.assertEqual((self.state/'selection').read_text(),'clockwork/orbital\n')
        self.assertFalse(list(self.state.rglob('.qylock-backup-*')))
        self.assertFalse(list(self.dropin.parent.glob('.qylock-backup-*')))

    def test_root_helper_never_restarts_services(self):
        with patch.object(subprocess,'run',side_effect=AssertionError('No external commands')):
            self.apply('forest')

    def test_root_helper_preserves_unmanaged_dropin(self):
        self.dropin.parent.mkdir();self.dropin.write_text('administrator configuration\n')
        with self.assertRaises(ValueError):self.apply('forest')
        self.assertEqual(self.dropin.read_text(),'administrator configuration\n')
        self.assertFalse((self.state/'selection').exists())

    def test_root_helper_rejects_writable_state(self):
        self.state.mkdir(mode=0o777);self.state.chmod(0o777)
        with self.assertRaises(ValueError):self.apply('forest')

    def test_root_helper_rejects_symlink_and_nonlink_collisions(self):
        self.state.mkdir();(self.state/'sddm').symlink_to(self.home,target_is_directory=True)
        with self.assertRaises(ValueError):self.apply('winter')
        (self.state/'sddm').unlink();(self.state/'sddm').mkdir()
        (self.state/'sddm/current').write_text('preserve')
        with self.assertRaises(ValueError):self.apply('winter')
        self.assertEqual((self.state/'sddm/current').read_text(),'preserve')

    def test_root_helper_rejects_catalog_path_escape(self):
        outside=self.root/'outside';outside.mkdir();(outside/'Main.qml').touch()
        theme=self.package/'share/orgm-qylock/themes/winter'
        (theme/'Main.qml').unlink();theme.rmdir();theme.symlink_to(outside)
        with self.assertRaises(ValueError):self.apply('winter')
        self.assertFalse(self.state.exists())

    def test_root_helper_rolls_back_partial_transaction(self):
        self.apply('winter')
        previous=self.dropin.read_bytes();old_link=os.readlink(self.state/'sddm/current')
        original=self.admin.os.replace
        def fail_commit(source,destination):
            if Path(source).name.startswith('.current-'):raise OSError('injected commit failure')
            return original(source,destination)
        with patch.object(self.admin.os,'replace',side_effect=fail_commit):
            with self.assertRaises(OSError):self.apply('forest')
        self.assertEqual(self.dropin.read_bytes(),previous)
        self.assertEqual(os.readlink(self.state/'sddm/current'),old_link)
        self.assertEqual((self.state/'selection').read_text(),'winter\n')

    def test_qml_security_contract(self):
        base=ROOT/'dotfiles/config/profiles/sway/.config/quickshell/orgm-lock'
        root=(base/'lock.qml').read_text();auth=(base/'Auth.qml').read_text()
        self.assertIn('WlSessionLock {',root);self.assertIn('session.secure',root)
        self.assertIn('Quickshell.watchFiles = false',root)
        self.assertIn('if (!root.authenticated) return',root)
        self.assertIn('PamResult.Success',auth)
        self.assertNotIn('function unlock(',root)
        self.assertNotIn('QS_TESTING',root)
        self.assertNotIn('killall',root+auth)
        self.assertNotIn('Screencopy',root+auth)
        picker=(base.parent/'orgm-locks/components/MenuWindow.qml').read_text()
        self.assertIn('&& !busy',picker)

    def test_all_lock_entrypoints_use_qylock(self):
        base=ROOT/'dotfiles/config/profiles/sway'
        config=(base/'.config/sway/config').read_text()
        self.assertEqual(config.count('bindsym $mod+l $exec orgm-qylock lock'),1)
        self.assertIn('bindsym $mod+Right focus right',config)
        idle=(base/'.config/swayidle/config').read_text()
        self.assertIn("timeout 600 'orgm-qylock lock'",idle)
        self.assertIn("before-sleep 'orgm-qylock lock'",idle)
        self.assertIn('exec orgm-qylock lock', (base/'.local/bin/orgm-sway-lock').read_text())
        self.assertFalse((ROOT/'dotfiles/apps/swaylock.json').exists())
        self.assertTrue((ROOT/'dotfiles/apps/qylock.json').is_file())

    def test_nix_declares_separate_pam_and_declarative_sddm(self):
        package=(ROOT/'nixos/profiles/sway/qylock-runtime.nix').read_text()
        module=(ROOT/'nixos/profiles/sway/qylock.nix').read_text()
        self.assertIn('orgm-qylock-pw',package);self.assertIn('orgm-qylock-fp',package)
        self.assertIn('pam_unix.so',package)
        self.assertNotIn('pam_permit.so',package)
        self.assertNotIn('qylock-test-pam',package)
        self.assertIn('auth_admin_keep',package)
        self.assertIn('quickshell-session-lock-hotplug.patch',package)
        hotplug=(ROOT/'nixos/profiles/sway/quickshell-session-lock-hotplug.patch').read_text()
        self.assertIn('delete surface->disownWindow()',hotplug)
        self.assertIn('waylandScreen->isPlaceholder()',hotplug)
        self.assertIn('environment.etc.',module)
        # The HOME helper prefers /run/current-system/sw metadata. Without
        # this export it silently keeps the provisional FP-disabled bridge.
        self.assertIn('environment.pathsToLink = [ "/share/orgm-qylock" ];',module)
        self.assertIn('deps = [ "etc" ]',module)


if __name__=='__main__':unittest.main()
