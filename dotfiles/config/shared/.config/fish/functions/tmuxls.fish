function tmuxls
    # Verificar que estamos en un entorno interactivo
    if not status is-interactive
        return 1
    end

    # Verificar que gum está instalado
    if not type -q gum
        echo "Error: gum no está instalado. Instálalo primero."
        return 1
    end

    # Verificar que tmux está disponible
    if not type -q tmux
        echo "Error: tmux no está instalado."
        return 1
    end

    # Obtener la lista de sesiones de tmux
    # Formato: nombre (ventanas activas) - creada: fecha
    set -l sessions (tmux list-sessions -F '#{session_name}|#{session_windows} windows|#{session_created}' 2>/dev/null)

    # Verificar si hay sesiones activas
    if test -z "$sessions"
        echo "No hay sesiones de tmux activas."
        return 0
    end

    # Preparar las opciones para gum
    set -l options
    for session in $sessions
        set -l parts (string split '|' $session)
        set -l name $parts[1]
        set -l windows $parts[2]
        set -l created $parts[3]
        
        # Formatear la fecha de creación (timestamp a fecha legible)
        set -l date_str (date -d @$created '+%Y-%m-%d %H:%M' 2>/dev/null; or date -r $created '+%Y-%m-%d %H:%M' 2>/dev/null; or echo $created)
        
        set -a options "$name ($windows) - $date_str"
    end

    # Mostrar menú con gum
    set -l selected (printf '%s\n' $options | gum choose --header "Selecciona una sesión de tmux:" --height 10)

    # Si el usuario canceló o no seleccionó nada
    if test -z "$selected"
        echo "No se seleccionó ninguna sesión."
        return 0
    end

    # Extraer el nombre de la sesión (primera parte antes del primer espacio o paréntesis)
    set -l session_name (string match -r '^[^\s(]+' $selected)

    # Verificar que obtuvimos un nombre válido
    if test -z "$session_name"
        echo "Error: No se pudo determinar el nombre de la sesión."
        return 1
    end

    # Adjuntarse a la sesión seleccionada
    echo "Conectando a la sesión '$session_name'..."
    tmux attach-session -t $session_name
end
