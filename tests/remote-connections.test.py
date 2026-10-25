#!/usr/bin/env python3
import importlib.util,json,subprocess,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[1]
LIB=ROOT/'dotfiles/config/programs/flatpak/.local/lib/orgm-remote-desktop/connections.py'
class Connections(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  spec=importlib.util.spec_from_file_location('connections',LIB);cls.m=importlib.util.module_from_spec(spec);spec.loader.exec_module(cls.m)
 def data(self):return {'BackendState':'Running','Self':{'ID':'self','DNSName':'osmar.example.ts.net.','TailscaleIPs':['100.1.1.1']},'Peer':{'a':{'ID':'a','OS':'linux','HostName':'jarq','DNSName':'jarq.example.ts.net.','TailscaleIPs':['100.1.1.2'],'Online':True},'b':{'ID':'b','OS':'linux','HostName':'orgm','DNSName':'orgm.example.ts.net.','TailscaleIPs':['100.1.1.3'],'Online':True},'self-duplicate':{'ID':'self','OS':'linux','HostName':'osmar','DNSName':'osmar.example.ts.net.','TailscaleIPs':['100.1.1.1'],'Online':True}}}
 def peers(self):return {'jarq':{'host':'jarq.example.ts.net','user':'jarq','uid':1000}}
 def test_discovery_merges_prepared_desktop_excludes_self_not_duplicate_names(self):
  rows=self.m.merge_targets(self.peers(),self.data())
  self.assertEqual(len(rows),2);self.assertEqual({r['host'] for r in rows},{'jarq.example.ts.net','orgm.example.ts.net'})
  jarq=next(r for r in rows if r['name']=='jarq');self.assertEqual(jarq['desktop'],'jarq');self.assertEqual(jarq['user'],'jarq')
  other=next(r for r in rows if r['name']=='orgm');self.assertIsNone(other['desktop'])
 def test_discovery_without_online_metadata_does_not_offer_unverified_peers(self):
  for state in (None,{'BackendState':'NeedsLogin'}):
   self.assertEqual(self.m.merge_targets(self.peers(),state),[])
 def test_untrusted_names_addresses_do_not_become_options_or_multiline_labels(self):
  d=self.data();d['Peer']['evil']={'ID':'evil','OS':'linux','HostName':'bad\nextra','DNSName':'-oProxyCommand=evil','TailscaleIPs':[';bad'],'Online':True}
  self.assertEqual(len(self.m.merge_targets(self.peers(),d)),2)
 def test_only_online_linux_no_configured_fallback_bypass(self):
  for os_name,online in [('windows',True),('darwin',True),('android',True),('iOS',True),('',True),('linux',False),('linux',None)]:
   d=self.data();d['Peer']['a'].update(OS=os_name,Online=online)
   rows=self.m.merge_targets(self.peers(),d)
   self.assertEqual([r['name'] for r in rows],['orgm'],(os_name,online,rows))
 def test_visible_shared_linux_peer_is_not_filtered_by_owner_or_dns_suffix(self):
  d=self.data();d['Self']['UserID']=1;d['Peer']['b'].update(UserID=2,DNSName='shared.other-tailnet.ts.net.')
  rows=self.m.merge_targets(self.peers(),d)
  self.assertIn('shared.other-tailnet.ts.net',{r['host'] for r in rows})
  self.assertEqual(len(rows),2)
 def test_configured_peer_absent_from_current_network_is_hidden(self):
  d=self.data();del d['Peer']['a']
  self.assertTrue(all(row['desktop'] is None for row in self.m.merge_targets(self.peers(),d)))
 def test_ssh_is_normal_authentication_strict_host_check_no_vnc_identity(self):
  cmd=self.m.ssh_command('server.example.ts.net','root')
  self.assertEqual(cmd[:3],['kitty','-e','ssh']);self.assertIn('StrictHostKeyChecking=ask',cmd)
  self.assertEqual(cmd[-3:],['-l','root','server.example.ts.net'])
  self.assertNotIn('-i',cmd);self.assertNotIn('StrictHostKeyChecking=no',cmd);self.assertNotIn('BatchMode=yes',cmd)
  for host,user in [('-oBad','root'),('host\nBad','root'),('host','-oBad'),('host','root;id')]:
   with self.assertRaises(ValueError):self.m.ssh_command(host,user)
 def test_cancel_does_not_spawn_or_start_tunnels(self):
  with patch.object(self.m,'discover',return_value=self.m.merge_targets(self.peers(),self.data())),patch.object(self.m,'choose',return_value=None),patch.object(self.m.subprocess,'Popen') as spawn:
   called=[];self.m.interactive(self.peers(),lambda *a:called.append(a));self.assertEqual(called,[]);spawn.assert_not_called()
 def test_prepared_desktop_uses_existing_controller(self):
  row=self.m.merge_targets(self.peers(),self.data())[0]
  with patch.object(self.m,'discover',return_value=[row]),patch.object(self.m,'choose',side_effect=[0,0]):
   called=[];self.m.interactive(self.peers(),lambda *a:called.append(a));self.assertEqual(called,[('jarq',)])
 def test_unprepared_target_has_only_ssh_and_asks_validated_user(self):
  row=next(r for r in self.m.merge_targets(self.peers(),self.data()) if r['desktop'] is None)
  with patch.object(self.m,'discover',return_value=[row]),patch.object(self.m,'choose',side_effect=[0,0]) as choose,patch.object(self.m,'ask_user',return_value='admin'),patch.object(self.m.subprocess,'Popen') as spawn:
   self.m.interactive(self.peers(),lambda *a:self.fail('VNC on unprepared server'))
   self.assertEqual(choose.call_args_list[1].args[1],['Terminal SSH'])
   self.assertEqual(spawn.call_args.args[0][-3:],['-l','admin','orgm.example.ts.net'])
 def test_rofi_escape_is_a_normal_cancel(self):
  result=subprocess.CompletedProcess([],1,'','')
  with patch.object(self.m.subprocess,'run',return_value=result):self.assertIsNone(self.m.choose('Equipo',['a']))
if __name__=='__main__':unittest.main()
