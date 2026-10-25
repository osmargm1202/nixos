#!/usr/bin/env python3
"""Native session sharing and private SSH/VNC boundaries, without a user GUI."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[1]
LIB=ROOT/'dotfiles/config/programs/flatpak/.local/lib/orgm-remote-desktop/remote.py'

class Remote(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        assert LIB.is_file(), 'remote desktop helper is missing'
        spec=importlib.util.spec_from_file_location('remote',LIB)
        cls.remote=importlib.util.module_from_spec(spec);spec.loader.exec_module(cls.remote)
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name)
    def peer(self,**overrides):
        return dict(host='jarq.tailb870fa.ts.net',user='jarq',uid=1000,**overrides)
    def test_wayland_backends_share_existing_display_and_listen_only_unix(self):
        for env in ({'WAYLAND_DISPLAY':'wayland-1','SWAYSOCK':'/sway.sock'}, {'WAYLAND_DISPLAY':'wayland-1','HYPRLAND_INSTANCE_SIGNATURE':'signature'}):
            args=self.remote.server_command(env,self.root)
            self.assertEqual(args[0],'wayvnc')
            self.assertIn('unix:'+str(self.root/'server.sock'),args)
            self.assertNotIn('--exit-on-disconnect',args)
            self.assertNotIn('--desktop',args)  # composite mode crashes on nonzero-origin external-only layouts
            self.assertNotIn('--disable-input',args)
            self.assertNotIn('0.0.0.0',args)
            self.assertIn('--disable-resizing',args)
    def test_x11_shares_real_display_without_virtual_session_or_tcp(self):
        args=self.remote.server_command({'DISPLAY':':1'},self.root)
        self.assertEqual(args[0],'x0vncserver')
        self.assertIn('-rfbport=-1',args)
        self.assertIn('-rfbunixpath='+str(self.root/'server.sock'),args)
        self.assertIn('-SecurityTypes=None',args)
        self.assertNotIn('Xvnc',args)
    def test_console_cannot_start_a_desktop_or_server(self):
        with self.assertRaises(self.remote.Error):self.remote.server_command({},self.root)
    def test_private_directory_and_symlink_rejection(self):
        path=self.root/'runtime';self.remote.private_directory(path)
        self.assertEqual(path.stat().st_mode & 0o777,0o700)
        link=self.root/'link';link.symlink_to(path,target_is_directory=True)
        with self.assertRaises(self.remote.Error):self.remote.private_directory(link)
    def test_peer_validation_rejects_ssh_and_profile_injection(self):
        self.remote.validate_peer('jarq',self.peer())
        for name,row in [('bad/../name',self.peer()),('jarq',{'host':'host\npassword=bad','user':'jarq','uid':1000}),('jarq',{'host':'-oProxyCommand=evil','user':'jarq','uid':1000}),('jarq',{'host':'host','user':'jarq;evil','uid':1000}),('jarq',{'host':'host','user':'jarq','uid':True})]:
            with self.assertRaises(self.remote.Error):self.remote.validate_peer(name,row)
    def test_ssh_forwarding_is_unix_to_unix_strict_host_identity_and_dedicated_key(self):
        args=self.remote.tunnel_command('jarq',self.peer(),self.root/'runtime',self.root/'config',self.root/'state')
        self.assertEqual(args[0],'ssh')
        self.assertIn('StrictHostKeyChecking=yes',args)
        self.assertIn('IdentitiesOnly=yes',args)
        self.assertIn('BatchMode=yes',args)
        self.assertIn('HostKeyAlias=orgm-remote-desktop-jarq',args)
        forward=args[args.index('-L')+1]
        self.assertEqual(forward,str(self.root/'runtime/jarq.sock')+':/run/user/1000/orgm-remote-desktop/server.sock')
        self.assertNotIn('5900',' '.join(args))
        self.assertIn('-NT',args)
        self.assertNotIn('-fNT',args)
        self.assertTrue(args[-1].endswith('@jarq.tailb870fa.ts.net'))
    def test_remmina_profile_uses_managed_tunnel_without_broken_flatpak_hooks(self):
        text=self.remote.profile_text('jarq',self.peer(),self.root/'runtime',self.root/'home')
        self.assertIn('protocol=VNC',text)
        self.assertIn('server=unix://'+str(self.root/'runtime/jarq.sock'),text)
        self.assertNotIn('precommand=',text)
        self.assertNotIn('password=',text)
        self.assertNotIn('postcommand=',text)
    def test_do_not_remove_live_or_foreign_socket(self):
        import socket
        directory=self.root/'runtime';directory.mkdir()
        sock=socket.socket(socket.AF_UNIX);self.addCleanup(sock.close)
        sock.bind(str(directory/'server.sock'));sock.listen()
        with self.assertRaises(self.remote.Error):self.remote.clear_stale_socket(directory/'server.sock')
        target=directory/'file';target.write_text('not a socket')
        with self.assertRaises(self.remote.Error):self.remote.clear_stale_socket(target)
        self.assertEqual(target.read_text(),'not a socket')
    def test_stale_owned_socket_can_be_rebound(self):
        import socket
        path=self.root/'stale.sock';sock=socket.socket(socket.AF_UNIX);sock.bind(str(path));sock.close()
        self.remote.clear_stale_socket(path)
        self.assertFalse(path.exists())
    def test_live_tunnel_cannot_be_reused_after_peer_identity_changes(self):
        import socket
        runtime=self.root/'runtime';runtime.mkdir()
        config=self.root/'config';config.mkdir();state=self.root/'state';state.mkdir()
        for path in (config/'known_hosts',state/'id_ed25519'):
            path.write_text('test');path.chmod(0o600)
        sock=socket.socket(socket.AF_UNIX);self.addCleanup(sock.close)
        sock.bind(str(runtime/'jarq.sock'));sock.listen()
        original=self.peer();(runtime/'jarq.json').write_text(json.dumps(original))
        with patch.object(self.remote,'runtime_directory',return_value=runtime),patch.object(self.remote,'config_directory',return_value=config),patch.object(self.remote,'state_directory',return_value=state),patch.object(self.remote,'control_running',return_value=True),patch.object(self.remote,'run') as run:
            self.assertEqual(self.remote.tunnel('jarq',original),runtime/'jarq.sock')
            for field,value in [('host','other.tailnet.ts.net'),('user','other'),('uid',2000)]:
                changed={**original,field:value}
                with self.assertRaises(self.remote.Error):self.remote.tunnel('jarq',changed)
            run.assert_not_called()
    def test_client_starts_managed_tunnel_instead_of_orphaning_ssh(self):
        import socket
        runtime=self.root/'runtime';runtime.mkdir();config=self.root/'config';config.mkdir();state=self.root/'state';state.mkdir()
        for path in (config/'known_hosts',state/'id_ed25519'):
            path.write_text('test');path.chmod(0o600)
        sock=socket.socket(socket.AF_UNIX);self.addCleanup(sock.close)
        sock.bind(str(runtime/'jarq.sock'));sock.listen()
        (runtime/'jarq.json').write_text(json.dumps(self.peer()))
        with patch.object(self.remote,'runtime_directory',return_value=runtime),patch.object(self.remote,'config_directory',return_value=config),patch.object(self.remote,'state_directory',return_value=state),patch.object(self.remote,'control_running',side_effect=[False,True]),patch.object(self.remote,'run') as run:
            self.assertEqual(self.remote.tunnel('jarq',self.peer()),runtime/'jarq.sock')
            run.assert_called_once_with(['systemctl','--user','start','orgm-remote-tunnel@jarq.service'])

if __name__=='__main__':unittest.main()
