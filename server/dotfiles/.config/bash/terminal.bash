# Modern terminal clients support UTF-8 even when SSH does not forward a locale.
# Keep this at the command boundary: reloading tmux.conf cannot change client UTF-8.
tmux() { command tmux -u "$@"; }

# Portable counterparts of the interactive NixOS terminal configuration.
_orgm_path_with() {
  local dir joined= IFS=:
  local -A seen=()
  for dir in "$@" $PATH; do
    [[ -z $dir || -n ${seen[$dir]:-} ]] && continue
    seen[$dir]=1
    joined+="${joined:+:}$dir"
  done
  printf '%s' "$joined"
}
export PATH="$(_orgm_path_with "$HOME/.local/bin" "${BUN_INSTALL:-$HOME/.bun}/bin" "${NPM_CONFIG_PREFIX:-$HOME/.npm-global}/bin" "${PNPM_HOME:-$HOME/.local/share/pnpm}" "$HOME/.cargo/bin" "$HOME/go/bin" "$HOME/.opencode/bin")"
if ! command -v fnm >/dev/null && [[ -x $HOME/.local/share/fnm/fnm ]]; then
  export PATH="$(_orgm_path_with "$HOME/.local/share/fnm")"
fi
unset -f _orgm_path_with
if command -v fnm >/dev/null; then
  eval "$(fnm env --shell bash)"
fi

# Functions remain available when a CLI is installed later in this session.
# Utility subcommands keep their original flags (including remote pairing).
codex() {
  case ${1:-} in
    login|logout|update|completion|mcp|plugin|features|doctor|help|app-server|remote-control|exec-server|agents|queue|archive|delete|unarchive|migrate-rollouts|cloud|debug|sandbox|apply|--help|-h|--version|-V)
      command codex "$@" ;;
    *) command codex --dangerously-bypass-approvals-and-sandbox "$@" ;;
  esac
}
claude() {
  case ${1:-} in
    auth|install|update|doctor|mcp|plugin|plugins|remote-control|setup-token|--help|-h|--version|-v)
      command claude "$@" ;;
    *) command claude --dangerously-skip-permissions "$@" ;;
  esac
}
omp() {
  local omp_bin package_dir
  omp_bin=$(type -P omp) || {
    printf '%s\n' 'omp not found; run bun-install and omp-install' >&2
    return 127
  }
  # Bun's package launcher needs its asset root; native binaries do not.
  omp_bin=$(readlink -f -- "$omp_bin") || return
  if [[ $omp_bin == */dist/cli.js ]]; then
    package_dir=${omp_bin%/dist/cli.js}
    PI_PACKAGE_DIR="${PI_PACKAGE_DIR:-$package_dir}" "$omp_bin" "$@"
  else
    "$omp_bin" "$@"
  fi
}

back-op() { builtin cd ..; }
backtrack-op() { builtin cd -; }
if command -v tre >/dev/null; then
  tre() {
    command tre "$@" -e || return
    local aliases_file="/tmp/tre_aliases_${USER:-$(id -un)}"
    [[ ! -r $aliases_file ]] || . "$aliases_file"
  }
fi
if command -v zellij >/dev/null; then
  alias za='zellij attach'
fi
if ! command -v bat >/dev/null && command -v batcat >/dev/null; then
  bat() { command batcat "$@"; }
fi
if command -v curl >/dev/null && command -v fzf >/dev/null && command -v bat >/dev/null; then
  cheat() {
    local topic
    topic=$(curl -fsSL https://cheat.sh/:list | fzf --preview 'curl -fsSL https://cheat.sh/{}' --preview-window=right:70%) || return
    [[ -n $topic ]] || return
    curl -fsSL "https://cheat.sh/$topic" | bat --language=markdown --paging=always
  }
fi
