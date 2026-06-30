# __tmux_shared.fish — Helper functions compartidos para tmuxnew/tmuxnewz/tmuxfd

function __tmux_find_session -d "Busca sesión tmux existente por directorio @tmuxnew_dir"
    set -l target_dir $argv[1]
    for s in (tmux list-sessions -F '#{session_name}' 2>/dev/null)
        set -l s_dir (tmux show-options -t $s -vq @tmuxnew_dir 2>/dev/null)
        if test -z "$s_dir"
            set s_dir (tmux display-message -p -t "$s:0.0" '#{pane_current_path}' 2>/dev/null)
        end
        if test "$s_dir" = "$target_dir"
            echo $s
            return 0
        end
    end
    return 1
end

function __tmux_session_name -d "Genera nombre de sesión tmux desde un directorio (últimas 3 carpetas)"
    set -l target_dir $argv[1]

    set -l parts (string split '/' -- $target_dir)
    set -l clean_parts
    for p in $parts
        if test -n "$p"
            set -a clean_parts $p
        end
    end

    set -l tail_parts
    if test (count $clean_parts) -ge 3
        set tail_parts $clean_parts[-3..-1]
    else
        set tail_parts $clean_parts
    end

    set -l session_base (string join '_' $tail_parts | string replace -ar '[^a-zA-Z0-9_-]' '_')
    if test -z "$session_base"
        set session_base "workspace"
    end

    set -l session_name $session_base

    if tmux has-session -t $session_name 2>/dev/null
        set -l i 2
        while tmux has-session -t "$session_base"_"$i" 2>/dev/null
            set i (math $i + 1)
        end
        set session_name "$session_base"_"$i"
    end

    echo $session_name
end

function __tmux_create_session -d "Crea sesión tmux con una sola ventana en el directorio objetivo"
    set -l session_name $argv[1]
    set -l target_dir $argv[2]

    echo "Creando sesión tmux '$session_name' en: $target_dir"

    # Ventana inicial única en directorio objetivo
    tmux new-session -d -s $session_name -c $target_dir
    tmux set-option -t $session_name @tmuxnew_dir "$target_dir" >/dev/null

    tmux attach-session -t $session_name
end

function __tmux_dir_history_select -d "Selecciona directorio desde dir.txt con fzf"
    set -l dir_file "$HOME/.config/fish/functions/dir.txt"

    if not test -f $dir_file
        echo "No hay directorios guardados. Usa: tmuxnew <ruta>" >&2
        return 1
    end

    if not type -q fzf
        echo "Error: fzf no está instalado. Necesario para filtrar directorios." >&2
        return 1
    end

    set -l dirs (tac $dir_file 2>/dev/null | awk '!seen[$0]++')

    if test -z "$dirs"
        echo "No hay directorios guardados. Usa: tmuxnew <ruta>" >&2
        return 1
    end

    printf '%s\n' $dirs | fzf --prompt "Selecciona directorio: " --height 40% --reverse
end

function __tmux_dir_history_append -d "Agrega directorio al historial dir.txt"
    set -l dir_file "$HOME/.config/fish/functions/dir.txt"
    set -l target_dir $argv[1]

    if not test -f $dir_file
        touch $dir_file
    end

    echo $target_dir >> $dir_file
end
