# blesh widgets for fzf bindings in the Emacs keymap.
# Load only after blesh and its fzf integration are initialized.

_orgm_fzf_insert() {
  local selected=$1
  if [[ -v READLINE_LINE ]]; then
    READLINE_LINE="${READLINE_LINE:0:READLINE_POINT}${selected}${READLINE_LINE:READLINE_POINT}"
    (( READLINE_POINT += ${#selected} ))
  else
    printf '%s' "$selected"
  fi
}

fzf-file-preview-widget() {
  local selected
  selected=$(fd --hidden --no-ignore --exclude .git --exclude .direnv | fzf --height 40% --reverse --preview-window=right:40% --preview 'switch-preview {}') || return
  [[ -n $selected ]] && _orgm_fzf_insert "$selected"
}

fzf-cd-preview-widget() {
  local selected_dir
  selected_dir=$(fd --type d --hidden --no-ignore --exclude .git --exclude .direnv | fzf --height 40% --reverse --preview-window=right:40% --preview 'dir-preview {}') || return
  [[ -n $selected_dir ]] && builtin cd -- "$selected_dir"
}

fzf-ps-widget() {
  local selected
  selected=$(pgrep -a . | fzf --height 40%) || return
  [[ -n $selected ]] && _orgm_fzf_insert "$selected"
}

_orgm_aichat_widget() {
  local translated
  [[ -n ${READLINE_LINE:-} ]] || return
  translated=$(command aichat -e "$READLINE_LINE") || return
  READLINE_LINE=$translated
  READLINE_POINT=${#READLINE_LINE}
}

ble-bind -m emacs -x M-r fzf-history-widget
ble-bind -m emacs -x M-f fzf-file-preview-widget
ble-bind -m emacs -x M-c fzf-cd-preview-widget
ble-bind -m emacs -x M-p fzf-ps-widget
ble-bind -m emacs -x M-a _orgm_aichat_widget
