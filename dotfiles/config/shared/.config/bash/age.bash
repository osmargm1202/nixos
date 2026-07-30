# Shared age defaults. A host-specific override may live in ~/.config/bash/age-host.bash.
if [[ -r "$HOME/.config/bash/age-host.bash" ]]; then
  . "$HOME/.config/bash/age-host.bash"
else
  export AGE_KEY_FILE="$HOME/Nextcloud/Documentos/keys/age.txt"
  export DOT_AGE_IDENTITY="$AGE_KEY_FILE"
  export CHEZMOI_AGE_IDENTITY="$AGE_KEY_FILE"
  export DOT_PRIVATE_ENV_PLAIN="$HOME/.config/bash/private-env.bash"
  export DOT_PRIVATE_ENV_ENCRYPTED="$HOME/.config/bash/private-env.bash.age"
  export DOTFILES_REPO="$HOME/Hobby/dotfiles"
fi
