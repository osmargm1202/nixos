function __tmux_init -d "Valida dependencia tmux para helpers tmux"
    # Verificar entorno interactivo
    if not status is-interactive
        return 1
    end

    # Dependencias obligatorias comunes
    set -l missing 0
    for cmd in tmux
        if not type -q $cmd
            echo "Error: $cmd no está instalado."
            set missing 1
        end
    end

    if test $missing -eq 1
        return 1
    end

    return 0
end
