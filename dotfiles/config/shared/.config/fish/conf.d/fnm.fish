
# fnm
set -l FNM_PATH "$HOME/.local/share/fnm"

if command -q fnm
    fnm env --shell fish | source
else if test -d "$FNM_PATH"
    fish_add_path "$FNM_PATH"
    if command -q fnm
        fnm env --shell fish | source
    end
end
