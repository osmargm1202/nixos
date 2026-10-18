#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE="$ROOT/dotfiles/config/users/osmarg/programs/shell/.config/bash/sops-age.bash"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[[ -f $MODULE ]] || fail 'SOPS Age shell module is missing'

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
home="$tmp/home"
config="$home/.config"
default_key="$home/Nextcloud/Documentos/keys/age.txt"
custom_key="$tmp/custom-age.txt"
explicit_key="$tmp/explicit-age.txt"
mkdir -p "$(dirname "$default_key")" "$config"
mkdir -p "$tmp/bin"
cat > "$tmp/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$SOPS_TEST_SYSTEMCTL_LOG"
EOF
chmod +x "$tmp/bin/systemctl"
export PATH="$tmp/bin:$PATH"
export SOPS_TEST_SYSTEMCTL_LOG="$tmp/systemctl.log"
printf '%s\n' 'AGE-SECRET-KEY-default' > "$default_key"
printf '%s\n' 'AGE-SECRET-KEY-custom' > "$custom_key"
printf '%s\n' 'AGE-SECRET-KEY-explicit' > "$explicit_key"

env -u SOPS_AGE_KEY_FILE HOME="$home" XDG_CONFIG_HOME="$config" bash -c '
  source "$1"
  [[ $SOPS_AGE_KEY_FILE == "$HOME/Nextcloud/Documentos/keys/age.txt" ]]
  sops-age-key "$2"
  [[ $SOPS_AGE_KEY_FILE == "$XDG_CONFIG_HOME/sops/age/keys.txt" ]]
  [[ ! -L $SOPS_AGE_KEY_FILE ]]
  cmp "$SOPS_AGE_KEY_FILE" "$2"
  [[ $(stat -c %a "$SOPS_AGE_KEY_FILE") == 600 ]]
  [[ $(stat -c %a "$(dirname "$SOPS_AGE_KEY_FILE")") == 700 ]]
' bash "$MODULE" "$custom_key"

env -u SOPS_AGE_KEY_FILE HOME="$home" XDG_CONFIG_HOME="$config" bash -c '
  source "$1"
  [[ $SOPS_AGE_KEY_FILE == "$XDG_CONFIG_HOME/sops/age/keys.txt" ]]
  [[ ! -L $SOPS_AGE_KEY_FILE ]]
  cmp "$SOPS_AGE_KEY_FILE" "$2"
' bash "$MODULE" "$custom_key"

rm -f "$custom_key"
env -u SOPS_AGE_KEY_FILE HOME="$home" XDG_CONFIG_HOME="$config" bash -c '
  source "$1"
  [[ $SOPS_AGE_KEY_FILE == "$XDG_CONFIG_HOME/sops/age/keys.txt" ]]
  [[ $(<"$SOPS_AGE_KEY_FILE") == AGE-SECRET-KEY-custom ]]
  sops-age-key "$SOPS_AGE_KEY_FILE"
  [[ $(<"$SOPS_AGE_KEY_FILE") == AGE-SECRET-KEY-custom ]]
' bash "$MODULE"

rm -f "$config/sops/age/keys.txt"
env -u SOPS_AGE_KEY_FILE HOME="$home" XDG_CONFIG_HOME="$config" bash -c '
  source "$1"
  [[ $SOPS_AGE_KEY_FILE == "$HOME/Nextcloud/Documentos/keys/age.txt" ]]
' bash "$MODULE"

HOME="$home" XDG_CONFIG_HOME="$config" SOPS_AGE_KEY_FILE="$explicit_key" bash -c '
  source "$1"
  [[ $SOPS_AGE_KEY_FILE == "$2" ]]
' bash "$MODULE" "$explicit_key"

env -u SOPS_AGE_KEY_FILE HOME="$home" XDG_CONFIG_HOME="$config" bash -c '
  source "$1"
  sops-age-key --reset
  [[ $SOPS_AGE_KEY_FILE == "$XDG_CONFIG_HOME/sops/age/keys.txt" ]]
  [[ ! -L $SOPS_AGE_KEY_FILE ]]
  cmp "$SOPS_AGE_KEY_FILE" "$HOME/Nextcloud/Documentos/keys/age.txt"
' bash "$MODULE"

[[ $(rg -c -- '--user restart sops-nix.service' "$SOPS_TEST_SYSTEMCTL_LOG") == 3 ]] || fail 'key changes must refresh the decrypted secrets'

printf '%s\n' 'sops-age-key: ok'
