# Host-specific age secret config for dotfiles.
# Keep identity file outside git; only its path is synced.
export AGE_KEY_FILE="$HOME/Nextcloud/Documentos/keys/age.txt"
export DOT_AGE_IDENTITY="$AGE_KEY_FILE"
export CHEZMOI_AGE_IDENTITY="$AGE_KEY_FILE"
export DOT_PRIVATE_ENV_PLAIN="$HOME/.config/bash/private-env.bash"
export DOT_PRIVATE_ENV_ENCRYPTED="$HOME/.config/bash/private-env.bash.age"
export DOTFILES_REPO="$HOME/Hobby/dotfiles"
