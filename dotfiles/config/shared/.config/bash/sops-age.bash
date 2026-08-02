# Shell-only Age identity selection for the SOPS CLI.
# sops-nix uses ~/.config/sops/age/keys.txt through nixos/sops.nix.
_sops_age_default_key_file="$HOME/Nextcloud/Documentos/keys/age.txt"
_sops_age_config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/sops/age"
_sops_age_key_file="$_sops_age_config_dir/keys.txt"

if [[ -z ${SOPS_AGE_KEY_FILE:-} ]]; then
  if [[ -r $_sops_age_key_file ]]; then
    export SOPS_AGE_KEY_FILE=$_sops_age_key_file
  else
    export SOPS_AGE_KEY_FILE=$_sops_age_default_key_file
  fi
fi

sops-age-key() {
  local default_key_file config_dir configured_key_file key_file

  default_key_file="$HOME/Nextcloud/Documentos/keys/age.txt"
  config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/sops/age"
  configured_key_file="$config_dir/keys.txt"

  case $# in
    0)
      printf '%s\n' "$SOPS_AGE_KEY_FILE"
      ;;
    1)
      if [[ $1 == --reset ]]; then
        key_file=$default_key_file
      else
        key_file=$(realpath -e -- "$1") || {
          printf 'sops-age-key: key file does not exist: %s\n' "$1" >&2
          return 1
        }
      fi

      if [[ ! -f $key_file || ! -r $key_file ]]; then
        printf 'sops-age-key: key file is not readable: %s\n' "$key_file" >&2
        return 1
      fi
      mkdir -p -- "$config_dir" || return
      chmod 700 -- "$config_dir" || return
      ln -sfn -- "$key_file" "$configured_key_file" || return
      export SOPS_AGE_KEY_FILE=$configured_key_file
      ;;
    *)
      printf 'Usage: sops-age-key [PATH|--reset]\n' >&2
      return 2
      ;;
  esac
}

unset _sops_age_default_key_file _sops_age_config_dir _sops_age_key_file
