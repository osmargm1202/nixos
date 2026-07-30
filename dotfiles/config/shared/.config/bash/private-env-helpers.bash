# Age-backed private environment helpers. Plaintext files are always mode 0600.
_private_env_load_age_config() {
  local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/bash"
  if [[ -r "$config_dir/age-host.bash" ]]; then
    . "$config_dir/age-host.bash"
  elif [[ -r "$config_dir/age.bash" ]]; then
    . "$config_dir/age.bash"
  else
    printf '%s\n' 'private-env: age configuration not found' >&2
    return 1
  fi
}

_private_env_require_age() {
  _private_env_load_age_config || return

  if [[ -z ${DOT_AGE_IDENTITY:-} && -n ${AGE_KEY_FILE:-} ]]; then
    export DOT_AGE_IDENTITY="$AGE_KEY_FILE"
  fi

  if [[ -z ${DOT_AGE_IDENTITY:-} || ! -f $DOT_AGE_IDENTITY ]]; then
    printf 'private-env: age identity not found: %s\n' "${DOT_AGE_IDENTITY:-unset}" >&2
    return 1
  fi

  if ! command -v age >/dev/null; then
    printf '%s\n' 'private-env: missing dependency: age' >&2
    return 1
  fi
}

_private_env_encrypted_path() {
  printf '%s\n' "${DOT_PRIVATE_ENV_ENCRYPTED:-$HOME/.config/bash/private-env.bash.age}"
}

_private_env_plain_path() {
  printf '%s\n' "${DOT_PRIVATE_ENV_PLAIN:-$HOME/.config/bash/private-env.bash}"
}

load_private_env() {
  _private_env_load_age_config || return

  local plain
  plain=$(_private_env_plain_path)
  if [[ ! -f $plain ]]; then
    private-env-decrypt "$plain" || return
  fi
  if [[ ! -r $plain ]]; then
    printf 'load_private_env: plaintext not readable: %s\n' "$plain" >&2
    return 1
  fi

  # shellcheck source=/dev/null
  . "$plain"
}

private-env-decrypt() {
  _private_env_require_age || return

  local encrypted output
  encrypted=$(_private_env_encrypted_path)
  output=${1:--}

  if [[ ! -f $encrypted ]]; then
    printf 'private-env-decrypt: encrypted file not found: %s\n' "$encrypted" >&2
    return 1
  fi

  if [[ $output == - ]]; then
    age -d -i "$DOT_AGE_IDENTITY" "$encrypted"
    return
  fi

  local output_dir decrypted
  output_dir=$(dirname "$output")
  decrypted=$(mktemp "$output_dir/.private-env.XXXXXX") || return
  chmod 600 "$decrypted"

  if ! age -d -i "$DOT_AGE_IDENTITY" -o "$decrypted" "$encrypted"; then
    rm -f "$decrypted"
    return 1
  fi

  mv -f "$decrypted" "$output"
  chmod 600 "$output"
  printf 'decrypted -> %s\n' "$output"
}

private-env-encrypt() {
  _private_env_require_age || return

  local plain encrypted_home repo
  plain=${1:-$(_private_env_plain_path)}
  encrypted_home=$(_private_env_encrypted_path)
  repo=${DOTFILES_REPO:-$HOME/Hobby/dotfiles}

  if [[ ! -f $plain ]]; then
    printf 'private-env-encrypt: plaintext not found: %s\n' "$plain" >&2
    return 1
  fi
  if ! command -v age-keygen >/dev/null; then
    printf '%s\n' 'private-env-encrypt: missing dependency: age-keygen' >&2
    return 1
  fi

  local recipient
  recipient=$(age-keygen -y "$DOT_AGE_IDENTITY") || return
  if [[ -z $recipient ]]; then
    printf '%s\n' 'private-env-encrypt: could not derive age recipient' >&2
    return 1
  fi

  local encrypted_dir encrypted_temp
  encrypted_dir=$(dirname "$encrypted_home")
  mkdir -p "$encrypted_dir"
  encrypted_temp=$(mktemp "$encrypted_dir/.private-env.XXXXXX") || return
  chmod 600 "$encrypted_temp"

  if ! age -r "$recipient" -o "$encrypted_temp" "$plain"; then
    rm -f "$encrypted_temp"
    return 1
  fi

  mv -f "$encrypted_temp" "$encrypted_home"
  chmod 600 "$encrypted_home"
  printf 'encrypted -> %s\n' "$encrypted_home"

  if [[ -d $repo/.git ]]; then
    local encrypted_repo repo_dir repo_temp
    encrypted_repo="$repo/config/shared/.config/bash/private-env.bash.age"
    repo_dir=$(dirname "$encrypted_repo")
    mkdir -p "$repo_dir"
    repo_temp=$(mktemp "$repo_dir/.private-env.XXXXXX") || return
    chmod 600 "$repo_temp"
    cp "$encrypted_home" "$repo_temp"
    mv -f "$repo_temp" "$encrypted_repo"
    chmod 600 "$encrypted_repo"
    printf 'encrypted -> %s\n' "$encrypted_repo"
  else
    printf 'private-env-encrypt: repo not found, skipped repo copy: %s\n' "$repo" >&2
  fi

  printf 'plaintext remains local only: %s\n' "$plain"
}

private-env-edit() {
  _private_env_load_age_config || return

  local plain
  plain=$(_private_env_plain_path)
  if [[ ! -f $plain ]]; then
    private-env-decrypt "$plain" || return
  fi

  local -a editor
  read -r -a editor <<< "${EDITOR:-nano}"
  "${editor[@]}" "$plain" || return
  private-env-encrypt "$plain"
}
