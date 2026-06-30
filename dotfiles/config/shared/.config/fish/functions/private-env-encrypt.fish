function private-env-encrypt --description 'Encrypt private fish env file with age for dotfiles'
    if test -f "$HOME/.config/fish/age-host.fish"
        source "$HOME/.config/fish/age-host.fish"
    else if test -f "$HOME/.config/fish/age.fish"
        source "$HOME/.config/fish/age.fish"
    end

    set -l plain "$HOME/.config/fish/private-env.fish"
    set -l encrypted_home "$HOME/.config/fish/private-env.fish.age"
    set -l repo "$HOME/Hobby/dotfiles"

    if set -q DOT_PRIVATE_ENV_PLAIN
        set plain "$DOT_PRIVATE_ENV_PLAIN"
    end
    if set -q DOT_PRIVATE_ENV_ENCRYPTED
        set encrypted_home "$DOT_PRIVATE_ENV_ENCRYPTED"
    end
    if set -q DOTFILES_REPO
        set repo "$DOTFILES_REPO"
    end
    if test (count $argv) -gt 0
        set plain "$argv[1]"
    end

    set -l encrypted_repo "$repo/config/shared/.config/fish/private-env.fish.age"

    if not test -f "$plain"
        echo "private-env-encrypt: plaintext not found: $plain" >&2
        return 1
    end
    if not set -q DOT_AGE_IDENTITY; or not test -f "$DOT_AGE_IDENTITY"
        echo "private-env-encrypt: age identity not found: $DOT_AGE_IDENTITY" >&2
        return 1
    end
    if not type -q age; or not type -q age-keygen
        echo "private-env-encrypt: missing dependency: age/age-keygen" >&2
        return 1
    end

    set -l recipient (age-keygen -y "$DOT_AGE_IDENTITY")
    if test -z "$recipient"
        echo "private-env-encrypt: could not derive age recipient" >&2
        return 1
    end

    mkdir -p (dirname "$encrypted_home")
    age -r "$recipient" -o "$encrypted_home.tmp" "$plain"; or return 1
    mv "$encrypted_home.tmp" "$encrypted_home"
    chmod 600 "$encrypted_home"
    echo "encrypted -> $encrypted_home"

    if test -d "$repo/.git"
        mkdir -p (dirname "$encrypted_repo")
        cp "$encrypted_home" "$encrypted_repo"
        echo "encrypted -> $encrypted_repo"
    else
        echo "private-env-encrypt: repo not found, skipped repo copy: $repo" >&2
    end

    echo "plaintext remains local only: $plain"
end
