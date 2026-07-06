function __dotfish_clipboard_copy_try --description 'Helper: pipe payload to command and return its status'
    set -l payload $argv[1]
    set -l cmd $argv[2..-1]
    if test (count $cmd) -eq 0
        return 1
    end
    printf '%s\n' "$payload" | $cmd
end

function clipboard_copy --description 'Copia texto de stdin al portapapeles (Hyprland+GNOME)'
    set -l payload (cat)
    if test -z "$payload"
        return 1
    end

    set -l wayland_preferred 1
    if test "$XDG_SESSION_TYPE" = 'x11'
        set wayland_preferred 0
    end

    if test $wayland_preferred -eq 1
        if __dotfish_clipboard_copy_try "$payload" env WAYLAND_DISPLAY=$WAYLAND_DISPLAY XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR wl-copy
            return 0
        end
        if __dotfish_clipboard_copy_try "$payload" env DISPLAY=$DISPLAY XAUTHORITY=$XAUTHORITY xclip -selection clipboard
            return 0
        end
    else
        if __dotfish_clipboard_copy_try "$payload" env DISPLAY=$DISPLAY XAUTHORITY=$XAUTHORITY xclip -selection clipboard
            return 0
        end
        if __dotfish_clipboard_copy_try "$payload" env WAYLAND_DISPLAY=$WAYLAND_DISPLAY XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR wl-copy
            return 0
        end
    end

    return 1
end
