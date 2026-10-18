#!/usr/bin/env python3
"""Use pinned native files and the real CLI; no live session is required."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

class NativeResources(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        expr = '''let f=builtins.getFlake ("path:"+builtins.getEnv "RYOKU_TEST_REPO");
          c=f.nixosConfigurations.lenovo.config; lib=f.inputs.nixpkgs.lib;
          p=(import (builtins.getEnv "RYOKU_TEST_REPO"+"/nixos/profiles/ryoku/provider-compat.nix")
            {inputs=f.inputs; pkgs=f.nixosConfigurations.lenovo.pkgs; inherit lib;}).packages;
          tools=builtins.filter (p: builtins.elem (lib.getName p) ["mise" "zoxide" "fzf" "blesh" "atuin" "lsd" "chafa" "ouch" "aichat"])
            (c.environment.systemPackages ++ c.home-manager.users.osmarg.home.packages);
          in lib.unique ([p.ryoku-desktop-data p.ryoku-cli] ++ tools)'''
        packages = subprocess.check_output(["nix","build","--impure","--no-link","--print-out-paths","--expr",expr],env=dict(os.environ,RYOKU_TEST_REPO=str(ROOT)),text=True).splitlines()
        cls.data = next(Path(p) for p in packages if (Path(p)/"share/ryoku/config").is_dir())
        cls.cli = next(Path(p)/"bin/.ryoku-wrapped" for p in packages if (Path(p)/"bin/.ryoku-wrapped").exists())
        cls.tools = {name: next(Path(p)/"bin"/name for p in packages if (Path(p)/"bin"/name).is_file())
                     for name in ("mise", "zoxide", "fzf", "atuin", "lsd", "chafa", "ouch", "aichat")}
        cls.blesh = next(Path(p)/"share/blesh/ble.sh" for p in packages if (Path(p)/"share/blesh/ble.sh").is_file())

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.config = self.home/".config"; self.config.mkdir()
        self.base = self.home/"base"; self.base.mkdir()
        self.bin = self.home/"bin"; self.bin.mkdir()
        self.cache = self.home/"cache"; self.cache.mkdir()
        self.runtime = self.home/"run"; self.runtime.mkdir(mode=0o700)
        self.env = dict(os.environ,HOME=str(self.home),XDG_CONFIG_HOME=str(self.config),XDG_STATE_HOME=str(self.home/"state"),XDG_DATA_HOME=str(self.home/"data"),XDG_CACHE_HOME=str(self.cache),XDG_RUNTIME_DIR=str(self.runtime),RYOKU_CONFIG_BASE=str(self.base),WAYLAND_DISPLAY="",HYPRLAND_INSTANCE_SIGNATURE="",DBUS_SESSION_BUS_ADDRESS="unix:path="+str(self.home/"no-bus"))
        for command in ("systemctl", "hyprctl", "ryoku-fastfetch", "ryoku-rashin"):
            p=self.bin/command; p.write_text("#!/bin/sh\nexit 0\n");p.chmod(0o755)
        self.env["PATH"]=str(self.bin)+":"+os.environ["PATH"]

    def materialize(self):
        result=subprocess.run([str(self.cli),"materialize"],env=self.env,capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stderr)

    def write(self, root, relative, data):
        p=root/relative;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(data);return p

    def test_real_materializer_refuses_directory_links_before_any_copy(self):
        for relative in ("ryoku-terminal", "hypr/modules", "ryoku/user_edits/hypr"):
            with self.subTest(relative=relative):
                self.setUp()  # Each link case gets an independent configuration tree.
                self.write(self.base,"ryoku-terminal/env.sh","native runtime")
                self.write(self.base,"hypr/modules/env.lua","native runtime")
                target=self.config/relative;target.parent.mkdir(parents=True,exist_ok=True)
                outside_tmp=tempfile.TemporaryDirectory(prefix="ryoku-external-")
                self.addCleanup(outside_tmp.cleanup)
                outside=Path(outside_tmp.name)
                self.write(outside,"env.sh","personal environment")
                target.symlink_to(outside,target_is_directory=True)
                result=subprocess.run([str(self.cli),"materialize"],env=self.env,capture_output=True,text=True)
                self.assertNotEqual(result.returncode,0)
                self.assertIn("preserved personal directory link",result.stderr)
                self.assertTrue(target.is_symlink())
                self.assertEqual((outside/"env.sh").read_text(),"personal environment")
                self.assertEqual(sorted(p.name for p in outside.iterdir()),["env.sh"])
                target.unlink()

    def test_native_bash_environment_and_rashin_are_packaged(self):
        for name in ("bash/ryoku.bash","bash/rashin.bash","ryoku-terminal/env.sh"):
            self.assertTrue((self.data/"share/ryoku/config"/name).is_file(),name)

    def test_real_materializer_preserves_app_preferences_and_updates_runtime(self):
        prefs=("starship.toml","btop/btop.conf","btop/themes/personal.theme","fastfetch/config.jsonc")
        for rel in prefs:self.write(self.base,rel,"initial")
        runtime=self.write(self.base,"hypr/modules/env.lua","runtime v1")
        self.materialize()
        for rel in prefs:self.write(self.config,rel,"user edited")
        runtime.write_text("runtime v2")
        self.materialize()
        for rel in prefs:self.assertEqual((self.config/rel).read_text(),"user edited",rel)
        self.assertEqual((self.config/"hypr/modules/env.lua").read_text(),"runtime v2")
        # No frozen overlays may restore older values over a later Hub edit.
        for rel in prefs:self.write(self.config,rel,"later Hub edit")
        self.materialize()
        for rel in prefs:self.assertEqual((self.config/rel).read_text(),"later Hub edit",rel)

    def test_native_seed_slots_preserve_arbitrary_and_dangling_symlinks(self):
        for rel in ("starship.toml","btop/btop.conf"):
            self.write(self.base,rel,"shipped")
            target=self.config/rel;target.parent.mkdir(parents=True,exist_ok=True)
            target.symlink_to(self.home/"missing-user-file")
        self.materialize()
        for rel in ("starship.toml","btop/btop.conf"):
            self.assertTrue((self.config/rel).is_symlink(),rel)
        self.assertFalse((self.home/"missing-user-file").exists())

    def test_native_bash_banner_and_user_import_load_once_and_not_noninteractive(self):
        native=self.data/"share/ryoku/config/bash/ryoku.bash"
        self.assertTrue(native.is_file(),"native Bash missing")
        import shutil
        shutil.copytree(self.data/"share/ryoku/config/bash",self.config/"bash")
        shutil.copytree(self.data/"share/ryoku/config/ryoku-terminal",self.config/"ryoku-terminal")
        for directory in (self.config/"bash", self.config/"ryoku-terminal"):
            directory.chmod(0o755)
        self.write(self.config,"bash/user.bash",'printf "IMPORT\\n"\n')
        fastfetch=self.bin/"ryoku-fastfetch"; fastfetch.write_text('#!/bin/sh\nprintf "BANNER\\n"\n');fastfetch.chmod(0o755)
        env=dict(self.env,PATH=str(self.bin)+":/bin:/usr/bin",TERM="dumb")
        command='. "$1"; . "$1"'
        result=subprocess.run([shutil.which("bash"),"--noprofile","--norc","-ic",command,"_",str(self.config/"bash/ryoku.bash")],env=env,capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(result.stdout.count("BANNER"),1,result.stdout)
        self.assertEqual(result.stdout.count("IMPORT"),1,result.stdout)
        result=subprocess.run([shutil.which("bash"),"--noprofile","--norc","-c",command,"_",str(self.config/"bash/ryoku.bash")],env=env,capture_output=True,text=True)
        self.assertNotIn("BANNER",result.stdout);self.assertNotIn("IMPORT",result.stdout)

    def test_real_mise_and_zoxide_keep_cd_z_and_single_directory_hook(self):
        import shutil
        shutil.copytree(self.data/"share/ryoku/config/bash",self.config/"bash")
        (self.config/"bash").chmod(0o755)
        for name, source in self.tools.items():
            (self.bin/name).symlink_to(source)
        self.write(self.config,"bash/user.bash",'. "$WORKFLOWS"\n')
        project=self.home/"projects/unique-zoxide-project";project.mkdir(parents=True)
        env=dict(self.env,TERM="dumb",WORKFLOWS=str(ROOT/"dotfiles/config/profiles/ryoku/.config/orgm-shell/workflows.bash"),PROJECT=str(project))
        command='''
          . "$1"
          . "$1"
          [[ $(declare -f cd) == *'__zoxide_z'* ]] || exit 31
          declare -F z zi __zoxide_hook >/dev/null || exit 32
          zoxide add -- "$PROJECT"
          builtin cd "$HOME"
          cd unique-zoxide-project || exit 33
          [[ $PWD == "$PROJECT" ]] || exit 34
          cd .. || exit 35
          [[ $PWD == "$HOME/projects" ]] || exit 36
          builtin cd "$HOME"
          z unique-zoxide-project || exit 37
          [[ $PWD == "$PROJECT" ]] || exit 38
          builtin cd "$HOME"
          z unique-zoxide-project
          hooks=$(declare -p PROMPT_COMMAND)
          [[ ${hooks//__zoxide_hook/} != "$hooks" ]] || exit 39
          tail=${hooks#*__zoxide_hook}
          [[ $tail != *'__zoxide_hook'* ]] || exit 40
        '''
        result=subprocess.run([shutil.which("bash"),"--noprofile","--norc","-ic",command,"_",str(self.config/"bash/ryoku.bash")],env=env,capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)

    def test_personal_fzf_widgets_work_in_blesh_after_native_initialization(self):
        import shutil
        shutil.copytree(self.data/"share/ryoku/config/bash",self.config/"bash")
        (self.config/"bash").chmod(0o755)
        for name, source in self.tools.items():
            (self.bin/name).symlink_to(source)
        widgets=ROOT/"dotfiles/config/users/osmarg/programs/shell/.config/bash/fzf-widgets.bash"
        self.write(self.config,"orgm-shell/fzf-widgets.bash",widgets.read_text())
        self.write(self.config,"bash/user.bash",'. "$WORKFLOWS"\n')
        # A line selection exercises the widget without a terminal or live files.
        env=dict(self.env,TERM="xterm",WORKFLOWS=str(ROOT/"dotfiles/config/profiles/ryoku/.config/orgm-shell/workflows.bash"),BLESH=str(self.blesh))
        command='''
          source "$BLESH" --lib --noattach --norc
          ble-attach() { :; }
          eval "$(atuin init bash)"
          ble-bind -m emacs -P
          printf '\\nAFTER_BINDINGS\\n'
          . "$1"
          declare -F fzf-history-widget fzf-file-preview-widget fzf-cd-preview-widget fzf-ps-widget _orgm_aichat_widget >/dev/null || exit 41
          function fd { printf 'selected.txt\\n'; }
          function fzf { cat; }
          READLINE_LINE='edit '; READLINE_POINT=5
          fzf-file-preview-widget
          [[ $READLINE_LINE == 'edit selected.txt' ]] || exit 42
          ble-bind -m emacs -P
        '''
        result=subprocess.run([shutil.which("bash"),"--noprofile","--norc","-ic",command,"_",str(self.config/"bash/ryoku.bash")],env=env,capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        import shlex
        before, after=result.stdout.split("AFTER_BINDINGS\n",1)
        initial=[shlex.split(line) for line in before.splitlines() if line.startswith("ble-bind ")]
        bindings=[shlex.split(line) for line in after.splitlines() if line.startswith("ble-bind ")]
        for key, action in (("M-r","fzf-history-widget"),("M-f","fzf-file-preview-widget"),
                            ("M-c","fzf-cd-preview-widget"),("M-p","fzf-ps-widget"),("M-a","_orgm_aichat_widget")):
            self.assertTrue(any(row[-2:]==[key,action] for row in bindings),(key,bindings))
        self.assertEqual([row for row in initial if row[-2]=="C-r"],
                         [row for row in bindings if row[-2]=="C-r"])

    def test_memory_cleanup_does_not_restart_another_desktop_in_ryoku(self):
        source=ROOT/"dotfiles/config/users/osmarg/programs/personal-development/.local/bin/memclean-dev"
        # Load only definitions. Never execute cleanup, inspect processes or stop containers.
        definitions=source.read_text().rsplit('\ncase "$MODE" in',1)[0]
        command=definitions+'''
          systemctl() { [[ $* == '--user cat ryoku-shell.service' ]]; }
          hyprctl() { printf 'unexpected reload'; }
          waybar-watch() { printf 'unexpected waybar'; }
          pkill() { printf 'unexpected kill'; }
          conky() { printf 'unexpected conky'; }
          sleep() { :; }
          desktop_restarted=0
          restart_legacy_desktop
          [[ $desktop_restarted == 0 ]]
        '''
        result=subprocess.run(["bash","--noprofile","--norc","-c",command],env=self.env,capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(result.stdout,"")

    def test_personal_previews_run_with_their_declared_dependencies(self):
        import struct
        import zipfile
        import zlib
        for name, source in self.tools.items():
            (self.bin/name).symlink_to(source)
        scripts=ROOT/"dotfiles/config/users/osmarg/programs/personal-development/.local/bin"
        for name in ("switch-preview","file-preview","dir-preview","archive-preview","image-preview","list-op"):
            (self.bin/name).symlink_to(scripts/name)
        text=self.home/"sample.txt";text.write_text("preview text\n")
        def png_chunk(kind, data):
            return struct.pack(">I",len(data))+kind+data+struct.pack(">I",zlib.crc32(kind+data))
        image=self.home/"sample.png"
        image.write_bytes(b'\x89PNG\r\n\x1a\n'+png_chunk(b'IHDR',struct.pack(">IIBBBBB",1,1,8,2,0,0,0))
                          +png_chunk(b'IDAT',zlib.compress(b'\x00\x00\x78\xff'))+png_chunk(b'IEND',b''))
        archive=self.home/"sample.zip"
        with zipfile.ZipFile(archive,"w") as out:
            out.writestr("sample.txt","archive preview")
        for command, argument, expected in (("switch-preview",text,"preview text"),
                                            ("switch-preview",self.home,"sample.txt"),
                                            ("switch-preview",archive,"sample.txt"),
                                            ("switch-preview",image,None)):
            with self.subTest(command=command,argument=argument.name):
                result=subprocess.run([str(self.bin/command),str(argument)],env=dict(self.env,TERM="xterm"),capture_output=True,text=True,timeout=15)
                self.assertEqual(result.returncode,0,result.stdout+result.stderr)
                if expected is not None:self.assertIn(expected,result.stdout)
        result=subprocess.run([str(self.bin/"aichat"),"--version"],env=self.env,capture_output=True,text=True,timeout=15)
        self.assertEqual(result.returncode,0,result.stderr)

if __name__=="__main__":unittest.main()
