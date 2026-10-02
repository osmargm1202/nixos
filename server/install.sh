#!/usr/bin/env bash
# Install the portable ORGM Bash and tmux configuration for one user.
set -Eeuo pipefail

BASE_URL=${ORGM_DOTFILES_BASE_URL:-https://raw.githubusercontent.com/osmargm1202/nixos/master}
SOURCE_DIR=
TARGET_HOME=${HOME:?HOME must be set}
DRY_RUN=0
INSTALL_PACKAGES=0
INSTALL_TMUX_ONLY=0
INSTALL_PLUGINS=1
TEMP_DIR=
BACKUP_DIR=
CURRENT_STAGE='Preparación'

declare -a BACKED_UP=()
declare -a TERMINAL_SOURCES=() TERMINAL_DESTINATIONS=() TERMINAL_MODES=()
declare -A TERMINAL_STAGED=()

action() {
    printf '%s\n' "$*"
}

stage() {
    CURRENT_STAGE=$2
    printf '\n[%s/5] %s\n' "$1" "$CURRENT_STAGE"
}

die() {
    printf 'Error [%s]: %s\n' "$CURRENT_STAGE" "$*" >&2
    exit 1
}

report_error() {
    local status=$?
    printf '\nError [%s]: la operación falló (código %s). Instalación interrumpida.\n' \
        "$CURRENT_STAGE" "$status" >&2
    exit "$status"
}
trap report_error ERR

usage() {
    cat <<'EOF'
Usage: install.sh [options]

Install ORGM Bash/tmux, AI install/update commands, blesh settings and FZF widgets.
Agent binaries and blesh are installed only when their helper is invoked.
It does not change shells, Fish, NixOS configuration, DNS, or services.

Options:
  --tmux-only    Install tmux, its helper, and optional plugins only.
                 Leave Bash and login profiles unchanged.
  --source DIR   Read files from a local checkout instead of GitHub.
  --home DIR     Install into DIR (useful for an isolated test home).
  --packages     Install optional baseline tools with apt or pacman.
  --no-plugins   Skip tmux-resurrect and tmux-continuum installation.
  --dry-run      Show planned changes without writing HOME or installing packages.
  --help         Show this help.

Remote source defaults to:
  https://raw.githubusercontent.com/osmargm1202/nixos/master
Override it with ORGM_DOTFILES_BASE_URL. Downloads use HTTPS and fail closed.
EOF
}

while (($#)); do
    case $1 in
        --source)
            (($# >= 2)) || die '--source requires a directory'
            SOURCE_DIR=$2
            shift 2
            ;;
        --home)
            (($# >= 2)) || die '--home requires a directory'
            TARGET_HOME=$2
            shift 2
            ;;
        --packages) INSTALL_PACKAGES=1; shift ;;
        --no-plugins) INSTALL_PLUGINS=0; shift ;;
        --tmux-only) INSTALL_TMUX_ONLY=1; shift ;;
        --dry-run) DRY_RUN=1; shift ;;
        --help|-h) usage; exit 0 ;;
        *) die "unknown option: $1 (use --help)" ;;
    esac
done

action 'ORGM — Configuración de terminal para servidores'
action "Destino: $TARGET_HOME"
if ((DRY_RUN)); then
    action 'Modo: simulación; no se modificarán archivos ni se instalarán paquetes.'
elif ((INSTALL_TMUX_ONLY)); then
    action 'Modo: solo tmux.'
else
    action 'Modo: Bash y tmux, con helpers de herramientas y agentes.'
fi
stage 1 'Preparar instalación'

cleanup() {
    [[ -z ${TEMP_DIR:-} ]] || rm -rf -- "$TEMP_DIR"
}
trap cleanup EXIT HUP INT TERM

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

if [[ -n $SOURCE_DIR ]]; then
    [[ -d $SOURCE_DIR ]] || die "--source is not a directory: $SOURCE_DIR"
    SOURCE_DIR=$(cd -- "$SOURCE_DIR" && pwd -P)
    action "Origen local: $SOURCE_DIR"
else
    require_command curl
    action "Origen HTTPS: $BASE_URL"
fi

TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/orgm-dotfiles.XXXXXXXX")
mkdir -p -- "$TEMP_DIR/files"

download() {
    local url=$1 output=$2 label=$3
    local -a display=(--silent --show-error)
    [[ ! -t 2 ]] || display=(--progress-bar --show-error)
    action "Descargando: $label"
    curl --fail --location --proto '=https' --proto-redir '=https' --tlsv1.2 \
        --connect-timeout 15 --max-time 300 --speed-limit 1 --speed-time 30 \
        "${display[@]}" "$url" --output "$output"
    action "Descarga completa: $label"
}

fetch_file() {
    local relative=$1 output=$2
    if [[ -n $SOURCE_DIR ]]; then
        action "Preparando archivo local: $relative"
        [[ -f "$SOURCE_DIR/$relative" ]] || die "source file missing: $SOURCE_DIR/$relative"
        cp -- "$SOURCE_DIR/$relative" "$output"
    else
        download "$BASE_URL/$relative" "$output" "$relative"
    fi
}

stage 2 'Obtener configuraciones y plugins'
if ((!INSTALL_TMUX_ONLY)); then
    fetch_file 'server/dotfiles/.bashrc' "$TEMP_DIR/files/bashrc"
    TERMINAL_SOURCES=(
        'server/dotfiles/.config/bash/terminal.bash'
        'server/dotfiles/.config/bash/fzf-widgets.bash'
        'dotfiles/config/users/osmarg/programs/shell/.config/bash/completions.bash'
        'dotfiles/config/users/osmarg/programs/shell/.blerc'
        'dotfiles/config/users/osmarg/common/.config/starship.toml'
        'server/dotfiles/.local/bin/terminal-preview'
        'server/dotfiles/.local/bin/terminal-preview'
    )
    TERMINAL_DESTINATIONS=(
        '.config/bash/terminal.bash' '.config/bash/fzf-widgets.bash'
        '.config/bash/completions.bash' '.blerc'
        '.config/starship.toml'
        '.local/bin/switch-preview' '.local/bin/dir-preview'
    )
    TERMINAL_MODES=(0644 0644 0644 0644 0644 0755 0755)
    for cli in bun-install blesh-install blesh-update codex-install codex-update claude-install claude-update omp-install omp-update; do
        TERMINAL_SOURCES+=('server/dotfiles/.local/bin/cli-install')
        TERMINAL_DESTINATIONS+=(".local/bin/$cli")
        TERMINAL_MODES+=(0755)
    done
    for index in "${!TERMINAL_SOURCES[@]}"; do
        relative=${TERMINAL_SOURCES[$index]}
        if [[ -n ${TERMINAL_STAGED[$relative]:-} ]]; then
            cp -- "${TERMINAL_STAGED[$relative]}" "$TEMP_DIR/files/terminal-$index"
        else
            fetch_file "$relative" "$TEMP_DIR/files/terminal-$index"
            TERMINAL_STAGED[$relative]=$TEMP_DIR/files/terminal-$index
        fi
    done
fi
fetch_file 'dotfiles/config/users/osmarg/programs/tmux/.tmux.conf' "$TEMP_DIR/files/tmux.conf"
fetch_file 'dotfiles/config/users/osmarg/programs/tmux/.local/bin/tmux-spanish-date' "$TEMP_DIR/files/tmux-spanish-date"

if ((INSTALL_PLUGINS)); then
    require_command tar
    mkdir -p -- "$TEMP_DIR/plugins"
    fetch_plugin() {
        local name=$1 commit=$2
        local archive="$TEMP_DIR/plugins/$name.tar.gz" extracted="$TEMP_DIR/plugins/$name-extracted"
        download "https://codeload.github.com/tmux-plugins/$name/tar.gz/$commit" "$archive" "$name"
        action "Extrayendo plugin: $name"
        mkdir -p -- "$extracted"
        tar -xzf "$archive" --strip-components=1 -C "$extracted"
        action "Plugin preparado: $name"
    }
    require_command curl
    fetch_plugin tmux-resurrect cff343cf9e81983d3da0c8562b01616f12e8d548
    fetch_plugin tmux-continuum 0698e8f4b17d6454c71bf5212895ec055c578da0
else
    action 'Plugins de tmux omitidos (--no-plugins).'
fi

stage 3 'Verificar destinos y preparar perfiles'
if [[ -d $TARGET_HOME ]]; then
    TARGET_HOME=$(cd -- "$TARGET_HOME" && pwd -P)
elif ((DRY_RUN)); then
    if [[ $TARGET_HOME == /* ]]; then
        :
    else
        TARGET_HOME=$PWD/$TARGET_HOME
    fi
else
    mkdir -p -- "$TARGET_HOME"
    TARGET_HOME=$(cd -- "$TARGET_HOME" && pwd -P)
fi

is_nix_managed() {
    local path=$1 resolved
    [[ -e $path || -L $path ]] || return 1
    resolved=$(readlink -f -- "$path" 2>/dev/null || true)
    [[ $resolved == /nix/store/* ]] && return 0
    if [[ -L $path ]]; then
        resolved=$(readlink -- "$path" 2>/dev/null || true)
        [[ $resolved == /nix/store/* ]] && return 0
    fi
    return 1
}

check_not_nix_managed() {
    local path
    for path in "$@"; do
        if is_nix_managed "$path"; then
            die "refusing to manage Nix/Home Manager destination: $path"
        fi
    done
}

TMUX_CONF_DIR=$TARGET_HOME/.config/tmux
HELPER_DEST=$TARGET_HOME/.local/bin/tmux-spanish-date
PLUGIN_ROOT=$TARGET_HOME/.local/share/orgm-dotfiles/tmux
PLUGINS_CONF=$TMUX_CONF_DIR/plugins.conf

# Check every possible managed destination before making any change under HOME.
check_not_nix_managed "$TARGET_HOME/.tmux.conf" "$HELPER_DEST" "$PLUGINS_CONF"
if ((!INSTALL_TMUX_ONLY)); then
    check_not_nix_managed "$TARGET_HOME/.bashrc"
    for relative in "${TERMINAL_DESTINATIONS[@]}"; do
        check_not_nix_managed "$TARGET_HOME/$relative"
    done
fi
if ((INSTALL_PLUGINS)); then
    check_not_nix_managed "$PLUGIN_ROOT/tmux-resurrect" "$PLUGIN_ROOT/tmux-continuum"
fi

login_loads_bashrc() {
    local login_file=$1 profile_file=$TARGET_HOME/.profile
    [[ -f $login_file ]] || return 1
    grep -Eq '^[[:space:]]*(source|\.)[[:space:]]+[^#]*\.bashrc["'\''[:space:]]*$' "$login_file" && return 0
    grep -Eq '^[[:space:]]*(source|\.)[[:space:]]+[^#]*\.profile["'\''[:space:]]*$' "$login_file" &&
        [[ -f $profile_file ]] &&
        grep -Eq '^[[:space:]]*(source|\.)[[:space:]]+[^#]*\.bashrc["'\''[:space:]]*$' "$profile_file"
}

LOGIN_FILE=
if ((!INSTALL_TMUX_ONLY)); then
    if [[ -f $TARGET_HOME/.bash_profile ]]; then
        LOGIN_FILE=$TARGET_HOME/.bash_profile
    elif [[ -f $TARGET_HOME/.bash_login ]]; then
        LOGIN_FILE=$TARGET_HOME/.bash_login
    elif [[ -f $TARGET_HOME/.profile ]]; then
        LOGIN_FILE=$TARGET_HOME/.profile
    else
        LOGIN_FILE=$TARGET_HOME/.bash_profile
    fi
fi
if [[ -n $LOGIN_FILE ]] && ! login_loads_bashrc "$LOGIN_FILE"; then
    check_not_nix_managed "$LOGIN_FILE"
    if [[ -f $LOGIN_FILE ]]; then
        cp -- "$LOGIN_FILE" "$TEMP_DIR/files/login-profile"
    fi
    cat >>"$TEMP_DIR/files/login-profile" <<'EOF'

# ORGM portable Bash configuration: keep login Bash sessions interactive.
if [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi
EOF
    LOGIN_UPDATE=$TEMP_DIR/files/login-profile
else
    LOGIN_UPDATE=
fi

backup_once() {
    local destination=$1 relative=$2 backup
    [[ -e $destination || -L $destination ]] || return 0
    [[ -n $BACKUP_DIR ]] || BACKUP_DIR=$TARGET_HOME/.local/share/orgm-dotfiles/backups/$(date +%Y%m%d-%H%M%S)-$$
    backup=$BACKUP_DIR/$relative
    mkdir -p -- "$(dirname -- "$backup")"
    cp -a -- "$destination" "$backup"
    BACKED_UP+=("$backup")
    action "Respaldo creado: $backup"
}

deploy_file() {
    local source=$1 destination=$2 relative=$3 mode=$4
    if [[ -f $destination ]] && cmp -s -- "$source" "$destination" &&
        [[ $mode != 0755 || -x $destination ]]; then
        action "Sin cambios: $destination"
        return 0
    fi
    if ((DRY_RUN)); then
        action "Se instalaría: $destination"
        return 0
    fi
    backup_once "$destination" "$relative"
    mkdir -p -- "$(dirname -- "$destination")"
    rm -f -- "$destination"
    install -m "$mode" -- "$source" "$destination"
    action "Instalado: $destination"
}

deploy_tree() {
    local source=$1 destination=$2 relative=$3
    if [[ -d $destination ]] && diff -qr --no-dereference -- "$source" "$destination" >/dev/null; then
        action "Sin cambios: $destination"
        return 0
    fi
    if ((DRY_RUN)); then
        action "Se instalaría el plugin: $destination"
        return 0
    fi
    backup_once "$destination" "$relative"
    mkdir -p -- "$(dirname -- "$destination")"
    rm -rf -- "$destination"
    cp -a -- "$source" "$destination"
    action "Plugin instalado: $destination"
}

install_packages() {
    local -a packages
    if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
    else
        die 'cannot identify package manager: /etc/os-release is unavailable'
    fi
    case ${ID:-} in
        ubuntu|debian)
            packages=(tmux git curl bash-completion neovim ripgrep fd-find fzf zoxide btop jq rsync bat file tree unzip xz-utils)
            if ((DRY_RUN)); then
                action "Would run: apt-get update && apt-get install ${packages[*]}"
                return
            fi
            action 'Actualizando índice de paquetes con apt-get; puede solicitar sudo.'
            if ((EUID == 0)); then
                apt-get update
                action "Instalando paquetes: ${packages[*]}"
                apt-get install -y "${packages[@]}"
            else
                require_command sudo
                sudo apt-get update
                action "Instalando paquetes: ${packages[*]}"
                sudo apt-get install -y "${packages[@]}"
            fi
            action "Instalando paquetes con pacman: ${packages[*]} (puede solicitar sudo)."
            ;;
        arch|manjaro)
            packages=(tmux git curl bash-completion neovim ripgrep fd fzf zoxide btop jq rsync bat file tree unzip xz)
            if ((DRY_RUN)); then
                action "Would run: pacman -S --needed ${packages[*]}"
                return
            fi
            if ((EUID == 0)); then
                pacman -S --needed --noconfirm "${packages[@]}"
            else
                require_command sudo
                sudo pacman -S --needed --noconfirm "${packages[@]}"
            fi
            ;;
        *) die "--packages supports Debian/Ubuntu and Arch only (found: ${ID:-unknown})" ;;
    esac
}

stage 4 'Instalar dependencias'
if ((INSTALL_PACKAGES)); then
    install_packages
    if ((DRY_RUN)); then
        action 'Plan de dependencias preparado.'
    else
        action 'Dependencias instaladas.'
    fi
else
    action 'Paquetes del sistema omitidos; usa --packages para instalarlos.'
fi

stage 5 'Aplicar configuración y respaldar archivos anteriores'
if ((!INSTALL_TMUX_ONLY)); then
    deploy_file "$TEMP_DIR/files/bashrc" "$TARGET_HOME/.bashrc" '.bashrc' 0644
    for index in "${!TERMINAL_DESTINATIONS[@]}"; do
        relative=${TERMINAL_DESTINATIONS[$index]}
        deploy_file "$TEMP_DIR/files/terminal-$index" "$TARGET_HOME/$relative" "$relative" "${TERMINAL_MODES[$index]}"
    done
fi
deploy_file "$TEMP_DIR/files/tmux.conf" "$TARGET_HOME/.tmux.conf" '.tmux.conf' 0644
deploy_file "$TEMP_DIR/files/tmux-spanish-date" "$HELPER_DEST" '.local/bin/tmux-spanish-date' 0755

if [[ -n $LOGIN_UPDATE ]]; then
    deploy_file "$LOGIN_UPDATE" "$LOGIN_FILE" "${LOGIN_FILE#"$TARGET_HOME"/}" 0644
fi

if ((INSTALL_PLUGINS)); then
    deploy_tree "$TEMP_DIR/plugins/tmux-resurrect-extracted" "$PLUGIN_ROOT/tmux-resurrect" '.local/share/orgm-dotfiles/tmux/tmux-resurrect'
    deploy_tree "$TEMP_DIR/plugins/tmux-continuum-extracted" "$PLUGIN_ROOT/tmux-continuum" '.local/share/orgm-dotfiles/tmux/tmux-continuum'
fi
{
    printf '# Generated by ORGM server/install.sh; local plugin paths.\n'
    if ((INSTALL_PLUGINS)); then
        for plugin in "$PLUGIN_ROOT/tmux-resurrect/resurrect.tmux" "$PLUGIN_ROOT/tmux-continuum/continuum.tmux"; do
            printf -v shell_path '%q' "$plugin"
            shell_path=${shell_path//\\/\\\\}
            shell_path=${shell_path//\"/\\\"}
            shell_path=${shell_path//\$/\\\$}
            printf 'run-shell "%s"\n' "$shell_path"
        done
    fi
} >"$TEMP_DIR/files/plugins.conf"
deploy_file "$TEMP_DIR/files/plugins.conf" "$PLUGINS_CONF" '.config/tmux/plugins.conf' 0644



if ((${#BACKED_UP[@]})); then
    action 'Respaldos:'
    printf '  %s\n' "${BACKED_UP[@]}"
fi
if ((DRY_RUN)); then
    action 'Simulación completada: no se modificaron archivos.'
else
    action 'Instalación completada correctamente.'
    if ((!INSTALL_TMUX_ONLY)); then
        action 'Abre una nueva sesión Bash (exec bash) para cargar la configuración.'
        action 'Herramientas opcionales: bun-install; blesh-install; codex-install; claude-install; omp-install'
    fi
    action 'Para recargar una sesión tmux existente: tmux source-file ~/.tmux.conf'
fi
