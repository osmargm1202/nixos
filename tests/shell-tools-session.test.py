#!/usr/bin/env python3
"""Native Bash REPL in a private PTY/HOME; never touches the parent terminal."""
import os, pathlib, shlex, shutil, subprocess, sys, tempfile
root=pathlib.Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='shell-native-') as tmp:
    home=pathlib.Path(tmp);(home/'.cache').mkdir()
    env=dict(os.environ,HOME=tmp,XDG_CONFIG_HOME=tmp+'/.config',XDG_CACHE_HOME=tmp+'/.cache',XDG_STATE_HOME=tmp+'/.state',XDG_DATA_HOME=tmp+'/.data',HISTFILE=tmp+'/history',_ZO_DATA_DIR=tmp+'/zoxide',TERM='xterm-256color')
    for key in list(env):
        if key.startswith(('BLE_','_ble_','ATUIN_','__ORGM','__RYOKU','__DOTFILES','__ETC_BASHRC')) or key in ('BASH_ENV','NOSYSBASHRC'):env.pop(key,None)
    env['ATUIN_CONFIG_DIR']=tmp+'/.config/atuin'
    subprocess.run(['orgm-dot','--repo',str(root),'--home',tmp,'--host','orgm','--profile','hyprland','pull','bash'],env=env,check=True,capture_output=True)
    (home/'probe.bash').write_text(r"""
for fn in z zi __zoxide_hook ble-attach atuin-bind fzf-history-widget fzf-file-preview-widget fzf-cd-preview-widget fzf-ps-widget _orgm_aichat_widget _fzf_complete; do
  declare -F "$fn" >/dev/null || { printf 'MISSING:%s\n' "$fn"; exit 61; }
done
ble-bind -m emacs -P > "$HOME/bindings"
mkdir -p "$HOME/unique project with spaces"
zoxide add -- "$HOME/unique project with spaces"
z 'unique project' || exit 62
[[ $PWD == "$HOME/unique project with spaces" ]] || exit 63
builtin cd "$HOME"
export _ZO_FZF_OPTS='--filter=unique'
zi 'unique project' || exit 64
[[ $PWD == "$HOME/unique project with spaces" ]] || exit 65
printf 'NATIVE_PASS\n' > "$HOME/result"
exit 0
""")
    result=subprocess.run(['script','-q','-e','-c','bash --noprofile -i','/dev/null'],env=env,input='source "$HOME/probe.bash"\n',capture_output=True,text=True,timeout=30)
    if result.returncode or not (home/'result').exists():
        print(result.stdout[-1600:],result.stderr[-500:]);raise SystemExit(result.returncode or 1)
    bindings=[shlex.split(line) for line in (home/'bindings').read_text().splitlines() if line.startswith('ble-bind ')]
    for key,action in [('M-r','fzf-history-widget'),('M-f','fzf-file-preview-widget'),('M-c','fzf-cd-preview-widget'),('M-p','fzf-ps-widget'),('M-a','_orgm_aichat_widget')]:
        assert any(row[-2:]==[key,action] for row in bindings),(key,[r for r in bindings if key in r])
    control_r=[row for row in bindings if row[-2]=='C-r']
    assert control_r and any('atuin' in r[-1] or r[-3]=='-s' for r in control_r),control_r
    print('PASS: real interactive PTY startup, Blesh/FZF custom bindings, Atuin, z and zi navigation with spaces')
