#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
functions="$root/dotfiles/config/users/osmarg/programs/shell/.config/bash/functions.bash"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/package/bin"
cat >"$tmp/package/bin/omp" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$PI_PACKAGE_DIR" >"$OMP_CAPTURE"
EOF
chmod +x "$tmp/package/bin/omp"
ln -s "$root/dotfiles/config/users/osmarg/programs/sops/.local/bin/sops-shared-env" "$tmp/package/bin/sops-shared-env"
export XDG_CONFIG_HOME="$tmp/config"
mkdir -p "$XDG_CONFIG_HOME/sops-nix/secrets"
printf 'test-only-api-key\n' > "$XDG_CONFIG_HOME/sops-nix/secrets/ANTHROPIC_API_KEY"

PATH="$tmp/package/bin:$PATH"
# shellcheck source=/dev/null
. "$functions"

unset PI_PACKAGE_DIR
OMP_CAPTURE="$tmp/default" omp
[[ "$(<"$tmp/default")" == "$tmp/package" ]]

PI_PACKAGE_DIR="$tmp/override" OMP_CAPTURE="$tmp/override-result" omp
[[ "$(<"$tmp/override-result")" == "$tmp/override" ]]
printf '%s\n' 'omp-package-dir: ok'
