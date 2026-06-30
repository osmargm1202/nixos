# Host-specific age secret config for dotfiles.
# Keep identity file outside git; only path is synced.
set -gx AGE_KEY_FILE "$HOME/Nextcloud/Documentos/keys/age.txt"
set -gx DOT_AGE_IDENTITY "$AGE_KEY_FILE"
set -gx CHEZMOI_AGE_IDENTITY "$AGE_KEY_FILE"
set -gx DOT_PRIVATE_ENV_PLAIN "$HOME/.config/fish/private-env.fish"
set -gx DOT_PRIVATE_ENV_ENCRYPTED "$HOME/.config/fish/private-env.fish.age"
set -gx DOTFILES_REPO "$HOME/Hobby/dotfiles"

if test -f ~/.config/fish/host-lenovo.fish
    source ~/.config/fish/host-lenovo.fish
end
