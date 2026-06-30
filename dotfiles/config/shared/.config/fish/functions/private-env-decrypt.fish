function private-env-decrypt --description 'Decrypt private fish env file to stdout or target path'
    if test -f "$HOME/.config/fish/age-host.fish"
        source "$HOME/.config/fish/age-host.fish"
    else if test -f "$HOME/.config/fish/age.fish"
        source "$HOME/.config/fish/age.fish"
    end

    set -l encrypted "$HOME/.config/fish/private-env.fish.age"
    set -l legacy "$HOME/.config/fish/encrypted_private_private-env.fish.age"
    set -l output "-"

    if set -q DOT_PRIVATE_ENV_ENCRYPTED
        set encrypted "$DOT_PRIVATE_ENV_ENCRYPTED"
    end
    if not test -f "$encrypted"; and test -f "$legacy"
        set encrypted "$legacy"
    end
    if test (count $argv) -gt 0
        set output "$argv[1]"
    end

    if not test -f "$encrypted"
        echo "private-env-decrypt: encrypted file not found: $encrypted" >&2
        return 1
    end
    if not set -q DOT_AGE_IDENTITY; or not test -f "$DOT_AGE_IDENTITY"
        echo "private-env-decrypt: age identity not found: $DOT_AGE_IDENTITY" >&2
        return 1
    end
    if not type -q age
        echo "private-env-decrypt: missing dependency: age" >&2
        return 1
    end

    if test "$output" = "-"
        age -d -i "$DOT_AGE_IDENTITY" "$encrypted"
    else
        age -d -i "$DOT_AGE_IDENTITY" -o "$output" "$encrypted"
        chmod 600 "$output"
        echo "decrypted -> $output"
    end
end
