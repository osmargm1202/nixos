# Shared age defaults. Host-specific override lives in ~/.config/fish/age-host.fish.
if test -f "$HOME/.config/fish/age-host.fish"
    source "$HOME/.config/fish/age-host.fish"
else
    set -gx AGE_KEY_FILE "$HOME/Nextcloud/Documentos/keys/age.txt"
    set -gx DOT_AGE_IDENTITY "$AGE_KEY_FILE"
    set -gx CHEZMOI_AGE_IDENTITY "$AGE_KEY_FILE"
    set -gx DOT_PRIVATE_ENV_PLAIN "$HOME/.config/fish/private-env.fish"
    set -gx DOT_PRIVATE_ENV_ENCRYPTED "$HOME/.config/fish/private-env.fish.age"
    set -gx DOTFILES_REPO "$HOME/Hobby/dotfiles"
end
