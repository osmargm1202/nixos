# Shared by the Nix package and the portable launcher, which set plugin paths.
umask 077
tmux_cmd() { tmux -u "$@"; }
case "${1:-}" in
  plugins)
    "$RESURRECT/resurrect.tmux"
    tmux_cmd set-option -g @resurrect-save-script-path "$SAVE_PROXY"
    read -ra save_keys <<< "$(tmux_cmd show-option -gqv @resurrect-save)"
    if (( ${#save_keys[@]} == 0 )); then save_keys=(C-s); fi
    for key in "${save_keys[@]}"; do
      tmux_cmd bind-key "$key" run-shell "$SAVE_PROXY"
    done
    "$CONTINUUM/continuum.tmux"
    ;;
  start)
    # A rebuild or repeated start must leave an existing server alone.
    if existing=$(tmux_cmd list-sessions -F '#S' 2>/dev/null); then
      [[ $existing == __orgm_restore__ ]] || exit 0
    else
      tmux_cmd -f /dev/null new-session -d -s __orgm_restore__ -c "$HOME"
    fi
    # Load the real config only after marking this as a managed restore.
    # persistence.conf disables continuum's competing asynchronous restore.
    tmux_cmd set-option -g @orgm-managed-restore on
    tmux_cmd source-file "$HOME/.tmux.conf"
    # run-shell in the config is queued; a following client waits for it.
    tmux_cmd show-option -gqv @resurrect-restore-script-path >/dev/null
    if [[ -z $(tmux_cmd show-option -gqv @resurrect-restore-script-path) ]]; then
      echo 'tmux-session: resurrect plugin did not load' >&2
      exit 1
    fi
    export TMUX
    TMUX=$(tmux_cmd display-message -p '#{socket_path},#{pid},0')
    "$RESURRECT/scripts/restore.sh"
    # Keep a usable shell on the first boot without a snapshot.
    if (( $(tmux_cmd list-sessions -F '#S' | wc -l) > 1 )); then
      tmux_cmd kill-session -t =__orgm_restore__
    else
      tmux_cmd rename-session -t =__orgm_restore__ main
    fi
    ;;
  save)
    tmux_cmd list-sessions >/dev/null 2>&1 || exit 0
    # Do not let timer/manual/shutdown saves collide at the same timestamp.
    exec 9>"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/orgm-tmux-save.lock"
    flock -w 20 9
    export TMUX
    TMUX=$(tmux_cmd display-message -p '#{socket_path},#{pid},0')
    "$RESURRECT/scripts/save.sh" quiet
    ;;
  *) echo 'Usage: tmux-session {start|save|plugins}' >&2; exit 2 ;;
esac
