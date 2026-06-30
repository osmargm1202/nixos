function load_private_env --description 'Decrypt age-encrypted fish env vars and source them'
    if test -f "$HOME/.config/fish/age-host.fish"
        source "$HOME/.config/fish/age-host.fish"
    else if test -f "$HOME/.config/fish/age.fish"
        source "$HOME/.config/fish/age.fish"
    end

    set -l encrypted "$HOME/.config/fish/private-env.fish.age"
    set -l legacy "$HOME/.config/fish/encrypted_private_private-env.fish.age"

    if set -q DOT_PRIVATE_ENV_ENCRYPTED
        set encrypted "$DOT_PRIVATE_ENV_ENCRYPTED"
    end

    if not test -f "$encrypted"; and test -f "$legacy"
        set encrypted "$legacy"
    end

    if not test -f "$encrypted"
        return 0
    end

    if not set -q DOT_AGE_IDENTITY
        if set -q AGE_KEY_FILE
            set -gx DOT_AGE_IDENTITY "$AGE_KEY_FILE"
        else
            echo "load_private_env: DOT_AGE_IDENTITY/AGE_KEY_FILE missing" >&2
            return 1
        end
    end

    if not test -f "$DOT_AGE_IDENTITY"
        echo "load_private_env: age identity not found: $DOT_AGE_IDENTITY" >&2
        return 1
    end

    if not type -q age
        echo "load_private_env: missing dependency: age" >&2
        return 1
    end

    # Secrets may use `set -x`, which would become function-local here.
    # Promote exported vars to global scope while loading from inside function.
    source (age -d -i "$DOT_AGE_IDENTITY" "$encrypted" \
        | string replace -r '^set -x ' 'set -gx ' \
        | psub)
    or return 1
end
