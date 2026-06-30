function private-env-edit --description 'Edit private env safely then encrypt with age'
    if test -f "$HOME/.config/fish/age-host.fish"
        source "$HOME/.config/fish/age-host.fish"
    else if test -f "$HOME/.config/fish/age.fish"
        source "$HOME/.config/fish/age.fish"
    end

    set -l plain "$HOME/.config/fish/private-env.fish"
    if set -q DOT_PRIVATE_ENV_PLAIN
        set plain "$DOT_PRIVATE_ENV_PLAIN"
    end

    if not test -f "$plain"
        private-env-decrypt "$plain"; or return 1
    end

    set -l editor "nano"
    if set -q EDITOR
        set editor "$EDITOR"
    end

    $editor "$plain"; or return 1
    private-env-encrypt "$plain"
end
