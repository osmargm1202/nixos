#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SECRETS='secrets/shared/api-keys.yaml'
MODULE='nixos/sops.nix'
WRAPPER='dotfiles/config/shared/.local/bin/sops-shared-env'
BASH_CONFIG='dotfiles/config/shared/.config/bash/config.bash'

[[ -f .sops.yaml ]]
[[ -f "$SECRETS" ]]
nix run nixpkgs#sops -- filestatus "$SECRETS" | jq -e '.encrypted == true' >/dev/null

for secret in \
  OPENCODE_API_KEY \
  MINIMAX_API_KEY \
  ANTHROPIC_API_KEY \
  STITCH_API_KEY \
  INSFORGE_API_KEY \
  INSFORGE_API_BASE_URL \
  AVANTE_ANTHROPIC_API_KEY; do
  grep -Fq "$secret" "$MODULE"
  grep -Fq "$secret" "$WRAPPER"
done
grep -Fq 'ORGM_TOKEN' "$MODULE"
grep -Fq -- '--with SECRET [SECRET...] -- COMMAND [ARG...]' "$WRAPPER"

grep -Fq 'Nextcloud/Documentos/keys/age.txt' "$MODULE"
grep -Fq 'inputs.sops-nix.nixosModules.sops' nixos/common.nix
grep -Fq 'inputs.sops-nix.homeManagerModules.sops' "$MODULE"
grep -Fq "PI_PACKAGE_DIR=\"\${PI_PACKAGE_DIR:-\$package_dir}\" command sops-shared-env omp" \
  dotfiles/config/shared/.config/bash/functions.bash
! grep -Fq "alias omp='sops-shared-env omp'" "$BASH_CONFIG"
! grep -Fq 'private-env-helpers' "$BASH_CONFIG"
! grep -Fq 'sops_private_env' "$BASH_CONFIG"
! [[ -e dotfiles/config/shared/.config/bash/private-env.bash.age ]]

bash -n "$WRAPPER" "$BASH_CONFIG"
SOPS_AGE_KEY_FILE="$HOME/Nextcloud/Documentos/keys/age.txt" \
  nix run nixpkgs#sops -- --decrypt "$SECRETS" >/dev/null

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
[[ ${ANTHROPIC_API_KEY-} == 'value with spaces $(literal)' ]]
[[ ${STITCH_API_KEY-} == 'value with spaces $(literal)' ]]
[[ ${INSFORGE_API_KEY-} == 'value with spaces $(literal)' ]]
[[ ${INSFORGE_API_BASE_URL-} == 'value with spaces $(literal)' ]]
[[ -z ${OPENCODE_API_KEY+x} ]]
EOF
cp "$fake_bin/claude" "$fake_bin/pi"
cat > "$fake_bin/opencode" <<'EOF'
#!/usr/bin/env bash
[[ ${OPENCODE_API_KEY-} == 'value with spaces $(literal)' ]]
[[ ${MINIMAX_API_KEY-} == 'value with spaces $(literal)' ]]
[[ ${ANTHROPIC_API_KEY-} == 'value with spaces $(literal)' ]]
[[ -z ${STITCH_API_KEY+x} ]]
EOF
cat > "$fake_bin/omp" <<'EOF'
#!/usr/bin/env bash
[[ ${ANTHROPIC_API_KEY-} == 'value with spaces $(literal)' ]]
[[ ${PI_PACKAGE_DIR-} == "${EXPECTED_PI_PACKAGE_DIR-}" || -z ${EXPECTED_PI_PACKAGE_DIR+x} ]]
[[ -z ${OPENCODE_API_KEY+x} ]]
[[ -z ${STITCH_API_KEY+x} ]]
EOF
cat > "$fake_bin/nvim" <<'EOF'
#!/usr/bin/env bash
[[ ${AVANTE_ANTHROPIC_API_KEY-} == 'value with spaces $(literal)' ]]
[[ -z ${ANTHROPIC_API_KEY+x} ]]
EOF
cat > "$fake_bin/custom-command" <<'EOF'
#!/usr/bin/env bash
[[ ${ORGM_TOKEN-} == 'value with spaces $(literal)' ]]
[[ -z ${ANTHROPIC_API_KEY+x} ]]
EOF
chmod +x "$fake_bin/claude" "$fake_bin/pi" "$fake_bin/opencode" "$fake_bin/omp" "$fake_bin/nvim" "$fake_bin/custom-command"

for command in claude pi opencode omp nvim; do
  env -i HOME="$HOME" XDG_CONFIG_HOME="$tmp/config" PATH="$fake_bin:$PATH" "$WRAPPER" "$command"
done
env -i HOME="$HOME" XDG_CONFIG_HOME="$tmp/config" PATH="$fake_bin:$PATH" \
  "$WRAPPER" --with ORGM_TOKEN -- custom-command

env -i \
  HOME="$HOME" \
  XDG_CONFIG_HOME="$tmp/config" \
  PATH="$fake_bin:$PATH" \
  EXPECTED_PI_PACKAGE_DIR="$tmp" \
  bash -c 'source "$1"; omp' bash "$ROOT/dotfiles/config/shared/.config/bash/functions.bash"
printf '%s\n' 'sops-shared-secrets: ok'