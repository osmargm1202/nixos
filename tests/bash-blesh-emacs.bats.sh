#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BLERC="$ROOT/dotfiles/config/users/osmarg/programs/shell/.blerc"
WIDGETS="$ROOT/dotfiles/config/users/osmarg/programs/shell/.config/bash/fzf-widgets.bash"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

grep -Fqx 'bleopt default_keymap=emacs' "$BLERC" ||
  fail 'Blesh must default to the Emacs keymap'
! grep -Fq 'vi_nmap' "$BLERC" || fail 'Blesh must not configure Vi normal mode'
! grep -Fq 'vi_imap' "$BLERC" || fail 'Blesh must not configure Vi insert mode'
[[ "$(grep -Fc 'ble-bind -m emacs' "$WIDGETS")" -eq 5 ]] ||
  fail 'all FZF widgets must be bound in the Emacs keymap'
! grep -Fq 'ble-bind -m vi_' "$WIDGETS" ||
  fail 'FZF widgets must not retain Vi bindings'
bash -n "$WIDGETS"

python3 - "$ROOT" <<'PY'
import pathlib
import os
import subprocess
import sys
import tempfile

root = pathlib.Path(sys.argv[1])
configs = [root/'dotfiles/config/programs/shell/.blerc',
           *sorted((root/'dotfiles/config/users').glob('*/programs/shell/.blerc'))]
for config in configs:
    for modern in (False, True):
        # The stable API deliberately lacks ble-face/blehook and contrib imports.
        setup = 'bleopt() { :; }; ble-color-setface() { printf "FACE:%s:%s\\n" "$1" "$2"; }; '
        if modern:
            setup += ('ble-face() { printf "FACE:%s\\n" "$1"; }; '
                      'blehook() { printf "HOOK:%s\\n" "$1"; }; ')
        setup += 'fzf() { :; }; ble-import() { printf "IMPORT:%s\\n" "$1"; }; '
        with tempfile.TemporaryDirectory(prefix='orgm-blerc-') as home:
            env = os.environ.copy()
            env.update(HOME=home, XDG_CONFIG_HOME=home+'/.config', ORGM_BASH_CONFIG_DIR=home+'/.config/bash')
            result = subprocess.run(['bash', '--noprofile', '--norc', '-c',
                                     setup + 'source "$1"', '_', str(config)], env=env,
                                    capture_output=True, text=True, timeout=10)
        assert result.returncode == 0 and not result.stderr, (config, result)
        if modern:
            assert 'FACE:auto_complete=fg=242' in result.stdout, result
            assert 'HOOK:PRECMD+=_orgm_command_separator' in result.stdout, result
            assert 'IMPORT:contrib/integration/fzf-key-bindings' in result.stdout, result
        else:
            assert result.stdout == 'FACE:auto_complete:fg=242\n', result
print('PASS: shared/user blesh configs support stable 0.3 and current 0.4 APIs')
PY

printf 'PASS: Bash uses Blesh Emacs editing without Vi mode\n'
