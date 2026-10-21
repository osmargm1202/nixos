#!/usr/bin/env python3
"""Real selected Bash integrations, using private HOME/history/zoxide databases."""
import glob
import json
import os
from pathlib import Path
import shutil
import shlex
import subprocess
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]

class ShellTools(unittest.TestCase):
    def test_selected_shell_includes_preview_file_dependency(self):
        expression="""let f=builtins.getFlake "path:__ROOT__";
        c=f.nixosConfigurations.orgm; in builtins.elem c.pkgs.file
          (c.config.home-manager.users.osmarg.home.packages ++ c.config.environment.systemPackages)"""
        result=subprocess.check_output(['nix','eval','--impure','--json','--expr',expression.replace('__ROOT__',str(ROOT))],text=True)
        self.assertTrue(json.loads(result),'shell preview dispatcher requires file, but selected packages omit it')

    def test_real_blesh_atuin_fzf_zoxide_and_reload(self):
        blesh=glob.glob('/nix/store/*-blesh-0.4.0-devel3/share/blesh/ble.sh')
        required=('bash','orgm-dot','atuin','fzf','zoxide','fd','starship')
        self.assertTrue(blesh and all(shutil.which(c) for c in required),'real shell tools must be supplied on PATH')
        with tempfile.TemporaryDirectory(prefix='shell-tools-') as tmp:
            home=Path(tmp)
            (home/".cache").mkdir()
            env=dict(os.environ,HOME=tmp,XDG_CONFIG_HOME=tmp+'/.config',XDG_DATA_HOME=tmp+'/.data',
                     XDG_STATE_HOME=tmp+'/.state',XDG_CACHE_HOME=tmp+'/.cache',TERM='xterm-256color',
                     HISTFILE=tmp+'/history',_ZO_DATA_DIR=tmp+'/zoxide',BLESH=blesh[0],ATUIN_CONFIG_DIR=tmp+'/.config/atuin')
            for key in list(env):
                if key.startswith(('BLE_', '_ble_', 'ATUIN_')) and key!='ATUIN_CONFIG_DIR':env.pop(key,None)
            subprocess.run(['orgm-dot','--repo',str(ROOT),'--home',tmp,'--host','orgm','--profile','hyprland','pull','bash'],env=env,check=True,capture_output=True)
            command=r"""
source "$BLESH" --lib --noattach --norc
ble-attach() { :; }
ble-bind -m emacs -P >/dev/null
source "$HOME/.blerc"
eval "$(atuin init bash)"
[[ $__atuin_bind_ctrl_r == true ]] || exit 43
ble-bind -m emacs -P > "$HOME/atuin-bindings"
source "$HOME/.bashrc"
for fn in z zi __zoxide_hook fzf-history-widget fzf-file-preview-widget fzf-cd-preview-widget fzf-ps-widget _orgm_aichat_widget _fzf_complete; do
  declare -F "$fn" >/dev/null || { printf 'Missing integration: %s\n' "$fn"; exit 41; }
done
ble-bind -m emacs -P > "$HOME/bindings"
first=$PATH; hooks=$(declare -p PROMPT_COMMAND)
source "$HOME/.bashrc"
[[ $first == "$PATH" && $hooks == "$(declare -p PROMPT_COMMAND)" ]] || exit 44
[[ $(declare -p PROMPT_COMMAND) == *'__zoxide_hook'* ]] || exit 45
mkdir -p "$HOME/unique project with spaces"
zoxide add -- "$HOME/unique project with spaces"
builtin cd "$HOME"
z 'unique project' || exit 46
[[ $PWD == "$HOME/unique project with spaces" ]] || exit 47
builtin cd "$HOME"
export _ZO_FZF_OPTS='--filter=unique'
zi 'unique project' || exit 48
[[ $PWD == "$HOME/unique project with spaces" ]] || exit 49
# Use real fd+fzf with deterministic noninteractive selection; no mocks or AI calls.
builtin cd "$HOME"
export FZF_DEFAULT_OPTS='--filter=unique'
fzf-cd-preview-widget || exit 50
[[ $PWD == "$HOME/unique project with spaces" ]] || exit 51
printf 'PASS: real z/zi, Blesh FZF widgets/completion, Atuin Ctrl+R, reload and directory selection\n'
"""
            result=subprocess.run(['bash','--noprofile','--norc','-ic',command],env=env,capture_output=True,text=True,timeout=30)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
            self.assertIn('PASS: real z/zi',result.stdout)
            bindings=[shlex.split(line) for line in (home/'bindings').read_text().splitlines() if line.startswith('ble-bind ')]
            for key,action in [('M-r','fzf-history-widget'),('M-f','fzf-file-preview-widget'),('M-c','fzf-cd-preview-widget'),('M-p','fzf-ps-widget'),('M-a','_orgm_aichat_widget')]:
                self.assertTrue(any(row[-2:]==[key,action] for row in bindings),(key,action))
            initial=[shlex.split(line) for line in (home/'atuin-bindings').read_text().splitlines() if line.startswith('ble-bind ')]
            self.assertEqual([r for r in initial if r[-2]=='C-r'],[r for r in bindings if r[-2]=='C-r'],'Atuin macro or widget binding must be preserved')
            result=subprocess.run(['bash','--noprofile','--norc','-c','source "$HOME/.bashrc"; declare -F z zi'],env=env,capture_output=True,text=True,timeout=5)
            self.assertNotEqual(result.returncode,0)
            self.assertEqual(result.stdout,'','noninteractive Bash must remain untouched')

if __name__=='__main__':unittest.main()
