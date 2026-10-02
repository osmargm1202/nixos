# ORGM: base portable de Bash para servidores, basada en server.slci.stream.
# Los ajustes privados o específicos del host van en ~/.bashrc.local.
case $- in
  *i*) ;;
  *) return ;;
esac

# Evitar repetir hooks e integraciones al recargar o cargar perfiles de login.
[[ -z ${__ORGM_SERVER_BASHRC_SOURCED:-} ]] || return
__ORGM_SERVER_BASHRC_SOURCED=1

HISTCONTROL=ignoreboth
HISTSIZE=10000
HISTFILESIZE=20000
shopt -s histappend checkwinsize

case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

if command -v nvim >/dev/null 2>&1; then
  export EDITOR=nvim
elif command -v nano >/dev/null 2>&1; then
  export EDITOR=nano
else
  export EDITOR=vi
fi
export VISUAL="$EDITOR"

case ${TERM:-dumb} in
  dumb) PS1='\u@\h:\w\$ ' ;;
  *) PS1='\[\e[1;32m\]\u@\h\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ ' ;;
esac

alias ls='ls -l --color=auto'
alias ll='ls -la --color=auto'
alias lt='ls -lah --color=auto'
alias grep='grep --color=auto'

if command -v git >/dev/null 2>&1; then
  alias gst='git status'
  alias gdiff='git diff'
  gp() {
    git add . && git commit -m "$*" && git push
  }
fi

alias ta='tmux attach'
alias tn='tmux new -s'

if command -v rg >/dev/null 2>&1; then
  alias rg="rg --hidden --glob '!.git/*'"
fi
if command -v fd >/dev/null 2>&1; then
  alias fd='fd --hidden --exclude .git'
elif command -v fdfind >/dev/null 2>&1; then
  alias fd='fdfind --hidden --exclude .git'
fi

if command -v curl >/dev/null 2>&1; then
  alias ipinfo='curl -s https://ipinfo.io'
fi
if command -v ssh >/dev/null 2>&1; then
  alias ssh='env TERM=xterm-256color ssh'
fi

if ! shopt -oq posix; then
  if [[ -r /usr/share/bash-completion/bash_completion ]]; then
    . /usr/share/bash-completion/bash_completion
  elif [[ -r /etc/bash_completion ]]; then
    . /etc/bash_completion
  fi
fi

if [[ -r "$HOME/.local/share/blesh/ble.sh" ]]; then
  source "$HOME/.local/share/blesh/ble.sh" --attach=none
fi

if [[ ${TERM:-dumb} != dumb ]] && command -v starship >/dev/null 2>&1; then
  eval "$(starship init bash)"
fi

# Mantener el comando manual también dentro de tmux, sin banner automático.
if command -v neofetch >/dev/null 2>&1; then
  neofetch() {
    command neofetch --config none --backend ascii \
      --colors 67 250 67 67 250 252 \
      --ascii_colors 67 250 --color_blocks off "$@"
  }
  if [[ -t 1 && ${TERM:-dumb} != dumb && -z ${TMUX:-} && -z ${_SLC_NEOFETCH_SHOWN:-} ]]; then
    neofetch
    _SLC_NEOFETCH_SHOWN=1
  fi
fi

if [[ -r "$HOME/.atuin/bin/env" ]]; then
  source "$HOME/.atuin/bin/env"
fi
if command -v atuin >/dev/null 2>&1; then
  eval "$(atuin init bash)"
fi

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init bash)"
  alias cd='z'
fi

[[ ! ${BLE_VERSION-} ]] || ble-attach

# Mantener las particularidades de cada servidor fuera de los archivos compartidos.
if [[ -r "$HOME/.bashrc.local" ]]; then
  source "$HOME/.bashrc.local"
fi
