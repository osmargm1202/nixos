#!/usr/bin/env python3
import subprocess,tempfile,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
class Packaging(unittest.TestCase):
 def test_every_theme_wrapped_originals_and_assets_preserved(self):
  with tempfile.TemporaryDirectory() as tmp:
   h=Path(tmp);source=h/"source";target=h/"target"
   for slug in ("winter","clockwork/orbital"):
    d=source/slug;d.mkdir(parents=True);(d/"Main.qml").write_text("original "+slug);(d/"bg.mp4").write_bytes(b"video")
   subprocess.run(["python3",str(ROOT/"nixos/profiles/sway/qylock-keyboard-themes.py"),str(source),str(target),"/immutable/keyboard"],check=True)
   for slug in ("winter","clockwork/orbital"):
    d=target/slug
    self.assertEqual((d/"OriginalMain.qml").read_text(),"original "+slug)
    self.assertTrue((d/"bg.mp4").is_symlink())
    self.assertEqual((d/"orgmKeyboard").readlink(),Path("/immutable/keyboard"))
    text=(d/"Main.qml").read_text();self.assertIn("AuthKeyboard",text);self.assertIn("reservedHeight",text)
    for unsafe in ("sddm.login","Process","IpcHandler","authenticated"):
     self.assertNotIn(unsafe,text)
 def test_runtime_embeds_keyboard_and_fallback_uses_local_widget(self):
  runtime=(ROOT/"nixos/profiles/sway/qylock-runtime.nix").read_text()
  self.assertIn("qylock-keyboard-themes.py",runtime)
  self.assertIn("orgm-osk",runtime)
  lock=(ROOT/"dotfiles/config/profiles/sway/.config/quickshell/orgm-lock/lock.qml").read_text()
  self.assertIn("AuthKeyboard",lock)
  auth=(ROOT/"dotfiles/config/programs/shell/.config/quickshell/orgm-osk/AuthKeyboard.qml").read_text()
  self.assertNotIn("Quickshell",auth)
  self.assertNotIn("editor.text",auth)
  self.assertNotIn("console.",auth)
if __name__=="__main__":unittest.main()
