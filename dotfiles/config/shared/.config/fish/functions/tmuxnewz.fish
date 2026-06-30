function tmuxnewz
    if not __tmux_init
        return 1
    end

    if not type -q zoxide
        echo "Error: zoxide no está instalado."
        return 1
    end
    if not type -q fzf
        echo "Error: fzf no está instalado."
        return 1
    end

    set -l target_dir

    # Seleccionar directorio desde zoxide
    set -l zoxide_dirs (zoxide query -l 2>/dev/null)
    if test -z "$zoxide_dirs"
        echo "No hay directorios en el historial de zoxide."
        return 1
    end

    set target_dir (printf '%s\n' $zoxide_dirs | fzf --prompt "Selecciona directorio (zoxide): " --height 50% --reverse --preview 'ls -la {}' --preview-window=right:30%)

    if test -z "$target_dir"
        echo "No se seleccionó ningún directorio."
        return 0
    end

    set target_dir (realpath $target_dir 2>/dev/null; or echo $target_dir)

    if not test -d $target_dir
        echo "Error: El directorio '$target_dir' no existe."
        return 1
    end

    __tmux_dir_history_append $target_dir

    # Reutilizar sesión existente
    set -l existing (__tmux_find_session $target_dir)
    if test -n "$existing"
        echo "Entrando a la sesión existente '$existing' en: $target_dir"
        tmux attach-session -t $existing
        return 0
    end

    set -l session_name (__tmux_session_name $target_dir)
    __tmux_create_session $session_name $target_dir
end
