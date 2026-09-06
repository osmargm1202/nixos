# Shared interactive Bash configuration. Loaded from ~/.bashrc only.
case $- in
  *i*) ;;
  *) return ;;
esac

bash_config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/bash"
if [[ -r "$bash_config_dir/functions.bash" ]]; then
  . "$bash_config_dir/functions.bash"
fi

if [[ -r "$bash_config_dir/completions.bash" ]]; then
  . "$bash_config_dir/completions.bash"
fi

host_config="$bash_config_dir/host-$(hostname).bash"
if [[ -r "$host_config" ]]; then
  . "$host_config"
fi
unset host_config

if [[ -r "$bash_config_dir/sops-age.bash" ]]; then
  . "$bash_config_dir/sops-age.bash"
fi

# API credentials are injected only into the child process by sops-shared-env.

# Keep user-local tool locations ahead of the NixOS system profile.  The
# system profile contains an unprivileged sudo binary; retain its wrapper
# directory first so interactive privilege escalation resolves correctly.
export PATH="/run/wrappers/bin:$HOME/.local/bin:$HOME/.cargo/bin:$HOME/go/bin:$HOME/.npm-global/bin:$HOME/.bun/bin:$HOME/.local/share/pnpm:$PATH"
if command -v sops-shared-env >/dev/null; then
  alias claude='sops-shared-env claude'
  alias opencode='sops-shared-env opencode'
  alias pi='sops-shared-env pi'
  alias nvim-ai='sops-shared-env nvim'
  alias pypi-publish='sops-shared-env --with UV_PUBLISH_TOKEN -- uv publish dist/*'
fi
# Keep fnm's managed Node versions available when fnm is installed locally.
if ! command -v fnm >/dev/null && [[ -x $HOME/.local/share/fnm/fnm ]]; then
  export PATH="$HOME/.local/share/fnm:$PATH"
fi
if command -v fnm >/dev/null; then
  eval "$(fnm env --shell bash)"
fi


_orgm_sudo() {
  if [[ -x /run/wrappers/bin/sudo ]]; then
    command /run/wrappers/bin/sudo "$@"
  elif command -v sudo >/dev/null; then
    command sudo "$@"
  else
    printf '%s\n' 'sudo not found' >&2
    return 127
  fi
}

alias nixgc='_orgm_sudo nix-collect-garbage -d'
nixg() {
  local keep=2
  if (($# > 0)); then
    keep=$1
  fi
  _orgm_sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations "+$keep"
}

nixclean() {
  _orgm_sudo nh clean all --keep 3 --keep-since 30d
  _orgm_sudo nix store optimise
  _orgm_sudo journalctl --vacuum-time=30d
  flatpak uninstall --unused --assumeyes --noninteractive
  trash-empty 30 -f
}

if command -v git >/dev/null; then
  alias gst='git status'
  alias gdiff='git diff'
  gp() {
    git add . && git commit -m "$*" && git push
  }
fi

if command -v eza >/dev/null; then
  alias ls='eza --group-directories-first --icons'
  alias ll='eza -la --group-directories-first --icons'
  alias lt='eza --tree --group-directories-first --icons'
else
  alias ls='ls -l'
  alias ll='ls -la'
  alias lt='ls -lah'
fi

if command -v rg >/dev/null; then
  alias rg="rg --hidden --glob '!.git/*'"
fi

if command -v fd >/dev/null; then
  alias fd='fd --hidden --exclude .git'
fi

if command -v curl >/dev/null; then
  alias ipinfo='curl -s ipinfo.io'
fi

if command -v ssh >/dev/null; then
  alias ssh='env TERM=xterm-256color ssh'
fi

export EDITOR=nvim
export VISUAL=nvim
alias bashconfig='nvim ~/.bashrc'
alias kittyconfig='nvim ~/.config/kitty/kitty.conf'
alias ffconfig='nvim ~/.config/fastfetch/config.jsonc'
alias fastfetch-hardware='fastfetch --config "$HOME/.config/fastfetch/hardware.jsonc"'


alias y='yazi'

if command -v zutty-fast >/dev/null; then
  alias zutty='zutty-fast'
fi

# Runner efímero para aplicaciones grandes o de uso ocasional:
# `, app [args...]` = nix run nixpkgs#app.
function , {
  if (($# == 0)); then
    printf '%s\n' 'uso: , <app> [args...]' >&2
    return 1
  fi
  nix run "nixpkgs#$1" -- "${@:2}"
}

# Flatpak-backed emulators. Their desktop entries are installed declaratively
# by nixos/gaming/emulators.nix; aliases retain the familiar terminal commands.
alias dolphin-emu='flatpak run org.DolphinEmu.dolphin-emu --'
alias pcsx2='flatpak run net.pcsx2.PCSX2 --'
alias rpcs3='flatpak run net.rpcs3.RPCS3 --'
alias herdr='nix run herdr --'
alias za='zellij attach'

if command -v curl >/dev/null && command -v fzf >/dev/null && command -v bat >/dev/null; then
  cheat() {
    curl -s cheat.sh/:list | fzf --preview 'curl -s cheat.sh/{}' --preview-window=right:70% | xargs -r -I {} curl -s cheat.sh/{} | bat --language=markdown --paging=always
  }
fi

g() {
  local query
  query=$(IFS=+; printf '%s' "$*")
  xdg-open "https://www.google.com/search?q=$query"
}

yt() {
  local query
  query=$(IFS=+; printf '%s' "$*")
  xdg-open "https://www.youtube.com/results?search_query=$query"
}



if [[ $TERM != dumb ]] && command -v starship >/dev/null; then
  eval "$(starship init bash)"
fi

unset bash_config_dir

if command -v zoxide >/dev/null; then
  alias cd='z'
  eval "$(zoxide init bash)"
fi
