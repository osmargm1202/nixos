# Functions whose useful behavior must affect the current interactive shell.

back-op() {
  builtin cd ..
}

backtrack-op() {
  builtin cd -
}

tre() {
  command tre "$@" -e || return

  local aliases_file="/tmp/tre_aliases_${USER:-$(id -un)}"
  [[ -r $aliases_file ]] || return 0
  # tre deliberately emits shell assignments for the caller to source.
  # shellcheck source=/dev/null
  . "$aliases_file"
}
