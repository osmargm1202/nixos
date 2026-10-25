#!/usr/bin/env python3
"""Exercise the fixed client against a disposable, test-owned TCP endpoint."""
import importlib.util
import json
from pathlib import Path
import socket
import tempfile
import threading
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[1]
PATH=ROOT/'dotfiles/config/programs/flatpak/.local/lib/orgm-artcraft/sandbox.py'
spec=importlib.util.spec_from_file_location('sandbox',PATH)
sandbox=importlib.util.module_from_spec(spec);spec.loader.exec_module(sandbox)

class Client(unittest.TestCase):
    def request(self,operation='ping',**kwargs):
        return {'host_netns':'net:[11111]','operation':operation,'port':47835,**kwargs}
    def test_shared_host_network_is_rejected_before_connect(self):
        with patch.object(sandbox.os,'readlink',return_value='net:[11111]'),patch.object(sandbox.socket,'create_connection') as connect:
            with self.assertRaisesRegex(ValueError,'aislamiento'):sandbox.call(self.request())
            connect.assert_not_called()
    def test_no_arbitrary_control_or_destructive_methods(self):
        with patch.object(sandbox.os,'readlink',return_value='net:[22222]'),patch.object(sandbox.socket,'create_connection') as connect:
            for method in ('app.quit','engine.execute','ui.text','exec','save'):
                with self.assertRaises(ValueError):sandbox.call(self.request(method))
            connect.assert_not_called()
    def test_inaccessible_file_returns_export_without_contacting_server(self):
        with patch.object(sandbox.os,'readlink',return_value='net:[22222]'),patch.object(sandbox.socket,'create_connection') as connect:
            result=sandbox.call(self.request('open',path='/not/existing/test.dwg'))
            self.assertEqual(result,{'needs_export':True});connect.assert_not_called()
    def exchange(self,respond):
        server=socket.socket();server.bind(('127.0.0.1',0));server.listen(1)
        self.addCleanup(server.close)
        requests=[]
        def serve():
            with server.accept()[0] as connection:
                request=json.loads(connection.makefile('rb').readline());requests.append(request)
                connection.sendall((json.dumps(respond(request))+'\n').encode())
        thread=threading.Thread(target=serve,daemon=True);thread.start()
        return server.getsockname()[1],requests,thread
    def test_open_preserves_unicode_and_quotes_without_input_injection(self):
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)/'plano ñ "quote".dwg';path.write_bytes(b'AC1018')
            port,requests,thread=self.exchange(lambda q:{'id':q['id'],'ok':True,'result':{'index':2}})
            with patch.object(sandbox.os,'readlink',return_value='net:[22222]'):
                result=sandbox.call(self.request('open',path=str(path),port=port))
            thread.join(2)
            self.assertEqual(result['result']['index'],2)
            self.assertEqual(requests[0]['method'],'app.open')
            self.assertEqual(requests[0]['params'],{'path':str(path)})
    def test_wrong_response_id_fails_not_retried(self):
        port,requests,thread=self.exchange(lambda q:{'id':'wrong','ok':True})
        with patch.object(sandbox.os,'readlink',return_value='net:[22222]'):
            with self.assertRaisesRegex(ValueError,'corresponde'):sandbox.call(self.request(port=port))
        thread.join(2);self.assertEqual(len(requests),1)

if __name__=='__main__':unittest.main()
