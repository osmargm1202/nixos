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

if [[ -r "$bash_config_dir/age.bash" ]]; then
  . "$bash_config_dir/age.bash"
fi

host_config="$bash_config_dir/host-$(hostname).bash"
if [[ -r "$host_config" ]]; then
  . "$host_config"
fi
unset host_config

if [[ -r "$bash_config_dir/private-env-helpers.bash" ]]; then
  . "$bash_config_dir/private-env-helpers.bash"
  private_env_plain=$(_private_env_plain_path)
  if [[ -r "$private_env_plain" ]]; then
    # shellcheck source=/dev/null
    . "$private_env_plain"
  elif declare -F load_private_env >/dev/null; then
    load_private_env
  fi
  unset private_env_plain
fi

if [[ -r "$bash_config_dir/insforge.env" ]]; then
  . "$bash_config_dir/insforge.env"
fi

# Keep user-local tool locations ahead of the NixOS system profile.
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/go/bin:$HOME/.npm-global/bin:$HOME/.bun/bin:$HOME/.local/share/pnpm:$PATH"
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

if command -v nano >/dev/null; then
  export EDITOR=nano
  alias bashconfig='nano ~/.bashrc'
  alias kittyconfig='nano ~/.config/kitty/kitty.conf'
  alias ffconfig='nano ~/.config/fastfetch/config.jsonc'
fi

if command -v nvim >/dev/null; then
  export EDITOR=nvim
  alias bashconfig='nvim ~/.bashrc'
fi

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

for app in dolphin-emu pcsx2 rpcs3; do
  alias "$app=nix run nixpkgs#$app --"
done
unset app
alias herdr='nix run herdr --'

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


if command -v zoxide >/dev/null; then
  eval "$(zoxide init bash)"
  alias cd='z'
fi

if [[ $TERM != dumb ]] && command -v starship >/dev/null; then
  eval "$(starship init bash)"
fi


unset bash_config_dir
