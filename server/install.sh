#!/usr/bin/env bash
# Install the portable ORGM Bash and tmux configuration for one user.
set -euo pipefail

BASE_URL=${ORGM_DOTFILES_BASE_URL:-https://raw.githubusercontent.com/osmargm1202/nixos/master}
SOURCE_DIR=
TARGET_HOME=${HOME:?HOME must be set}
DRY_RUN=0
INSTALL_PACKAGES=0
INSTALL_TMUX_ONLY=0
INSTALL_PLUGINS=1
TEMP_DIR=
BACKUP_DIR=

declare -a BACKED_UP=()
declare -a TERMINAL_SOURCES=() TERMINAL_DESTINATIONS=() TERMINAL_MODES=()
declare -A TERMINAL_STAGED=()

action() {
    printf '%s\n' "$*"
}

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

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
else
    require_command curl
fi

TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/orgm-dotfiles.XXXXXXXX")
mkdir -p -- "$TEMP_DIR/files"

fetch_file() {
    local relative=$1 output=$2
    if [[ -n $SOURCE_DIR ]]; then
        [[ -f "$SOURCE_DIR/$relative" ]] || die "source file missing: $SOURCE_DIR/$relative"
        cp -- "$SOURCE_DIR/$relative" "$output"
    else
        curl --fail --location --proto '=https' --tlsv1.2 --silent --show-error \
            "$BASE_URL/$relative" --output "$output"
    fi
}

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
        curl --fail --location --proto '=https' --tlsv1.2 --silent --show-error \
            "https://codeload.github.com/tmux-plugins/$name/tar.gz/$commit" --output "$archive"
        mkdir -p -- "$extracted"
        tar -xzf "$archive" --strip-components=1 -C "$extracted"
    }
    require_command curl
    fetch_plugin tmux-resurrect cff343cf9e81983d3da0c8562b01616f12e8d548
    fetch_plugin tmux-continuum 0698e8f4b17d6454c71bf5212895ec055c578da0
fi

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
}

deploy_file() {
    local source=$1 destination=$2 relative=$3 mode=$4
    if [[ -f $destination ]] && cmp -s -- "$source" "$destination" &&
        [[ $mode != 0755 || -x $destination ]]; then
        action "Unchanged: $destination"
        return 0
    fi
    if ((DRY_RUN)); then
        action "Would install: $destination"
        return 0
    fi
    backup_once "$destination" "$relative"
    mkdir -p -- "$(dirname -- "$destination")"
    rm -f -- "$destination"
    install -m "$mode" -- "$source" "$destination"
    action "Installed: $destination"
}

deploy_tree() {
    local source=$1 destination=$2 relative=$3
    if [[ -d $destination ]] && diff -qr --no-dereference -- "$source" "$destination" >/dev/null; then
        action "Unchanged: $destination"
        return 0
    fi
    if ((DRY_RUN)); then
        action "Would install plugin: $destination"
        return 0
    fi
    backup_once "$destination" "$relative"
    mkdir -p -- "$(dirname -- "$destination")"
    rm -rf -- "$destination"
    cp -a -- "$source" "$destination"
    action "Installed plugin: $destination"
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
            if ((EUID == 0)); then
                apt-get update
                apt-get install -y "${packages[@]}"
            else
                require_command sudo
                sudo apt-get update
                sudo apt-get install -y "${packages[@]}"
            fi
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

if ((INSTALL_PACKAGES)); then
    install_packages
fi

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
    action 'Backups:'
    printf '  %s\n' "${BACKED_UP[@]}"
fi
if ((DRY_RUN)); then
    action 'Dry run complete: no files were changed.'
else
    if ((!INSTALL_TMUX_ONLY)); then
        action 'Open a new Bash session (exec bash) to use the terminal configuration.'
        action 'Optional tools: bun-install; blesh-install; codex-install; claude-install; omp-install'
    fi
    action 'For an existing tmux server, run: tmux source-file ~/.tmux.conf'
fi
