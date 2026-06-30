function tmuxfd
    if not __tmux_init
        return 1
    end

    if not type -q fzf
        echo "Error: fzf no está instalado."
        return 1
    end

    if not type -q fd
        echo "Error: fd no está instalado."
        return 1
    end

    # Base de búsqueda: cwd actual
    set -l base_dir (pwd)

    # Patrón de búsqueda para fd (tmuxfd <busqueda>)
    set -l query "."
    if test (count $argv) -gt 0
        set query (string join ' ' -- $argv)
    end

    # Buscar con fd y filtrar con fzf
    set -l selected_rel (begin
        printf '.\n'
        fd --type d --hidden --exclude .git -- "$query" . 2>/dev/null
    end | fzf --prompt "Directorio (fd '$query' desde $base_dir): " --height 50% --reverse --query "$query")

    set -l selected ""
    if test -n "$selected_rel"
        if test "$selected_rel" = "."
            set selected "$base_dir"
        else
            set selected (realpath "$selected_rel" 2>/dev/null; or echo "$base_dir/$selected_rel")
        end
    end

    if test -z "$selected"
        echo "No se seleccionó ningún directorio."
        return 0
    end

    __tmux_dir_history_append $selected

    # Reutilizar sesión existente
    set -l existing (__tmux_find_session $selected)
    if test -n "$existing"
        echo "Entrando a la sesión existente '$existing' en: $selected"
        tmux attach-session -t $existing
        return 0
    end

    set -l session_name (__tmux_session_name $selected)
    __tmux_create_session $session_name $selected
end
