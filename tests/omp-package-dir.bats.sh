#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
functions="$root/dotfiles/config/shared/.config/bash/functions.bash"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/package/bin"
cat >"$tmp/package/bin/omp" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$PI_PACKAGE_DIR" >"$OMP_CAPTURE"
EOF
chmod +x "$tmp/package/bin/omp"

PATH="$tmp/package/bin:$PATH"
# shellcheck source=/dev/null
. "$functions"

unset PI_PACKAGE_DIR
OMP_CAPTURE="$tmp/default" omp
[[ "$(<"$tmp/default")" == "$tmp/package" ]]

PI_PACKAGE_DIR="$tmp/override" OMP_CAPTURE="$tmp/override-result" omp
[[ "$(<"$tmp/override-result")" == "$tmp/override" ]]
printf '%s\n' 'omp-package-dir: ok'
