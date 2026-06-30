function tmuxdel
    # Verificar que estamos en un entorno interactivo
    if not status is-interactive
        return 1
    end

    # Dependencias
    if not type -q gum
        echo "Error: gum no está instalado."
        return 1
    end

    if not type -q tmux
        echo "Error: tmux no está instalado."
        return 1
    end

    # Listar sesiones
    set -l sessions (tmux list-sessions -F '#{session_name}|#{session_windows}|#{session_created}|#{?session_attached,attached,detached}' 2>/dev/null)

    if test -z "$sessions"
        echo "No hay sesiones de tmux activas."
        return 0
    end

    # Armar opciones visuales para gum
    set -l options
    for session in $sessions
        set -l parts (string split '|' -- $session)
        set -l name $parts[1]
        set -l windows $parts[2]
        set -l created $parts[3]
        set -l attached $parts[4]

        set -l date_str (date -d @$created '+%Y-%m-%d %H:%M' 2>/dev/null; or date -r $created '+%Y-%m-%d %H:%M' 2>/dev/null; or echo $created)
        set -a options "$name | $windows windows | $attached | $date_str"
    end

    # Elegir sesión a borrar
    set -l selected (printf '%s\n' $options | gum choose --header "Seleccioná la sesión de tmux a BORRAR:" --height 12)

    if test -z "$selected"
        echo "No se seleccionó ninguna sesión."
        return 0
    end

    # Nombre de sesión = primer campo antes de " | "
    set -l session_name (string split ' | ' -- $selected)[1]

    if test -z "$session_name"
        echo "Error: no se pudo determinar la sesión a borrar."
        return 1
    end

    # Confirmación explícita
    if not gum confirm "¿Borrar la sesión '$session_name'?"
        echo "Cancelado."
        return 0
    end

    # Borrar sesión
    if tmux kill-session -t "$session_name" 2>/dev/null
        echo "Sesión '$session_name' borrada correctamente."
        return 0
    end

    echo "Error al borrar la sesión '$session_name'."
    return 1
end
