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

# Nix/Guix package wrappers need OMP's asset root explicitly. Resolve the
# executable first: it is a symlink to dist/cli.js for Bun and bin/omp in a
# store package, so its parent directory is always the package root.
omp() {
  local omp_bin package_dir

  omp_bin="$(type -P omp)" || {
    printf '%s\n' 'omp not found' >&2
    return 127
  }
  omp_bin="$(readlink -f "$omp_bin")" || return
  package_dir="$(cd "$(dirname "$omp_bin")/.." && pwd -P)" || return

  PI_PACKAGE_DIR="${PI_PACKAGE_DIR:-$package_dir}" command "$omp_bin" "$@"
}
