#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

WRAPPER='dotfiles/config/users/osmarg/programs/sops/.local/bin/sops-shared-env'

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
secrets_dir="$tmp/config/sops-nix/secrets"
fake_bin="$tmp/bin"
mkdir -p "$secrets_dir" "$fake_bin"
for secret in \
  OPENCODE_API_KEY \
  MINIMAX_API_KEY \
  ANTHROPIC_API_KEY \
  STITCH_API_KEY \
  INSFORGE_API_KEY \
  INSFORGE_API_BASE_URL \
  AVANTE_ANTHROPIC_API_KEY \
  ORGM_TOKEN; do
  printf '%s\n' 'value with spaces $(literal)' > "$secrets_dir/$secret"
done
ln -s "$ROOT/$WRAPPER" "$fake_bin/sops-shared-env"

cat > "$fake_bin/claude" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ ${ANTHROPIC_API_KEY-} == 'value with spaces $(literal)' ]]
[[ ${STITCH_API_KEY-} == "${EXPECTED_STITCH_API_KEY-value with spaces \$(literal)}" ]]
[[ ${INSFORGE_API_KEY-} == 'value with spaces $(literal)' ]]
[[ ${INSFORGE_API_BASE_URL-} == 'value with spaces $(literal)' ]]
[[ -z ${OPENCODE_API_KEY+x} ]]
EOF
cp "$fake_bin/claude" "$fake_bin/pi"
cat > "$fake_bin/opencode" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ ${OPENCODE_API_KEY-} == 'value with spaces $(literal)' ]]
[[ ${MINIMAX_API_KEY-} == 'value with spaces $(literal)' ]]
[[ ${ANTHROPIC_API_KEY-} == 'value with spaces $(literal)' ]]
[[ -z ${STITCH_API_KEY+x} ]]
EOF
cat > "$fake_bin/omp" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ ${ANTHROPIC_API_KEY-} == 'value with spaces $(literal)' ]]
[[ ${PI_PACKAGE_DIR-} == "${EXPECTED_PI_PACKAGE_DIR-}" || -z ${EXPECTED_PI_PACKAGE_DIR+x} ]]
[[ -z ${OPENCODE_API_KEY+x} ]]
[[ -z ${STITCH_API_KEY+x} ]]
EOF
cat > "$fake_bin/nvim" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ ${AVANTE_ANTHROPIC_API_KEY-} == "${EXPECTED_AVANTE_API_KEY-value with spaces \$(literal)}" ]]
[[ -z ${ANTHROPIC_API_KEY+x} ]]
EOF
cat > "$fake_bin/custom-command" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ ${ORGM_TOKEN-} == 'value with spaces $(literal)' ]]
[[ -z ${ANTHROPIC_API_KEY+x} ]]
EOF
chmod +x "$fake_bin/claude" "$fake_bin/pi" "$fake_bin/opencode" "$fake_bin/omp" "$fake_bin/nvim" "$fake_bin/custom-command"

for command in claude pi opencode omp nvim; do
  env -i HOME="$HOME" XDG_CONFIG_HOME="$tmp/config" PATH="$fake_bin:$PATH" "$WRAPPER" "$command"
done
rm "$secrets_dir/AVANTE_ANTHROPIC_API_KEY"
env -i HOME="$HOME" XDG_CONFIG_HOME="$tmp/config" PATH="$fake_bin:$PATH" \
  EXPECTED_AVANTE_API_KEY='' "$WRAPPER" nvim
if env -i HOME="$HOME" XDG_CONFIG_HOME="$tmp/config" PATH="$fake_bin:$PATH" \
  EXPECTED_AVANTE_API_KEY='' "$WRAPPER" --with AVANTE_ANTHROPIC_API_KEY -- nvim \
  > "$tmp/missing-secret.log" 2>&1; then
  printf '%s\n' 'Explicitly requested secrets must remain required' >&2
  exit 1
fi
env -i HOME="$HOME" XDG_CONFIG_HOME="$tmp/config" PATH="$fake_bin:$PATH" \
  "$WRAPPER" --with ORGM_TOKEN -- custom-command

env -i \
  HOME="$HOME" \
  XDG_CONFIG_HOME="$tmp/config" \
  PATH="$fake_bin:$PATH" \
  EXPECTED_PI_PACKAGE_DIR="$tmp" \
  bash -c 'source "$1"; omp' bash "$ROOT/dotfiles/config/users/osmarg/programs/shell/.config/bash/functions.bash"

# A deleted auxiliary key must not block tools with other credentials available.
rm "$secrets_dir/STITCH_API_KEY"
for command in claude pi; do
  env -i HOME="$HOME" XDG_CONFIG_HOME="$tmp/config" PATH="$fake_bin:$PATH" \
    EXPECTED_STITCH_API_KEY='' "$WRAPPER" "$command"
done

# Every supported tool must also start with no SOPS credentials at all.
empty_bin="$tmp/empty-bin"
mkdir -p "$empty_bin"
for command in claude pi opencode omp nvim; do
  cat > "$empty_bin/$command" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ ${ANTHROPIC_API_KEY-} == "${EXPECTED_INHERITED_API_KEY-}" ]]
for name in OPENCODE_API_KEY MINIMAX_API_KEY STITCH_API_KEY INSFORGE_API_KEY INSFORGE_API_BASE_URL AVANTE_ANTHROPIC_API_KEY; do
  [[ -z ${!name+x} ]]
done
[[ $# == 2 && $1 == 'file with spaces' && $2 == '--test' ]]
exit "${TEST_EXIT_CODE:-0}"
EOF
  chmod +x "$empty_bin/$command"
  env -i HOME="$HOME" XDG_CONFIG_HOME="$tmp/empty-config" PATH="$empty_bin:$PATH" \
    "$WRAPPER" "$command" 'file with spaces' --test
  env -i HOME="$HOME" XDG_CONFIG_HOME="$tmp/empty-config" PATH="$empty_bin:$PATH" \
    ANTHROPIC_API_KEY='inherited credential' EXPECTED_INHERITED_API_KEY='inherited credential' \
    "$WRAPPER" "$command" 'file with spaces' --test
done
if env -i HOME="$HOME" XDG_CONFIG_HOME="$tmp/empty-config" PATH="$empty_bin:$PATH" \
  TEST_EXIT_CODE=17 "$WRAPPER" claude 'file with spaces' --test; then
  printf '%s\n' 'The child command exit status must be preserved' >&2
  exit 1
else
  [[ $? == 17 ]]
fi
printf '%s\n' 'sops-shared-secrets: ok'
