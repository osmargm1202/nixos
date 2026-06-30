set -g fish_greeting
set -Ue fish_key_bindings

# Auto-enter dev environment on interactive shells.
# Skip with: NO_DEV_SHELL=1 fish  (or set it in terminal profile)
if status is-interactive; and not set -q IN_DEV_SHELL; and not set -q NO_DEV_SHELL
    if type -q dev
        exec dev
    end
end

# if not set -q TMUX
#     if type -q fastfetch
#         # Fastfetch local disponible
#         fastfetch
#     end
# end

if test -f ~/.config/fish/age.fish
    source ~/.config/fish/age.fish
end

if test -f ~/.config/fish/age-host.fish
    source ~/.config/fish/age-host.fish
end

set -l host_config ~/.config/fish/host-(hostname).fish
if test -f $host_config
    source $host_config
end

type -q load_private_env; and load_private_env

if test -f ~/.config/fish/insforge.env
    source ~/.config/fish/insforge.env
end

# PATH
set -gx PATH $HOME/.local/bin $PATH
set -gx PATH $HOME/.cargo/bin $PATH
set -gx PATH $HOME/go/bin $PATH

alias npm="pnpm"

# Nix cleanup helpers.
# En NixOS, sudo con setuid vive en /run/wrappers/bin/sudo. Algunas apps
# gráficas pueden heredar un PATH donde gana /run/current-system/sw/bin/sudo,
# que no tiene setuid y falla. Para tareas Nix usamos el wrapper explícito.
function _orgm_sudo
    if test -x /run/wrappers/bin/sudo
        command /run/wrappers/bin/sudo $argv
    else if command -q sudo
        command sudo $argv
    else
        echo "sudo not found" >&2
        return 127
    end
end

alias nixgc='_orgm_sudo nix-collect-garbage -d'
function nixg
    set -l keep 2
    if test (count $argv) -gt 0
        set keep $argv[1]
    end
    _orgm_sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations +$keep
end

function nixclean
    nixg 2
    nixgc
    _orgm_sudo nix store optimise
    flatpak uninstall --unused --assumeyes --noninteractive
    trash-empty 30 -f
    _orgm_sudo journalctl --vacuum-time=7d
end

# Prompt más vistoso (starship opcional)
if type -q starship
    starship init fish | source
end

# zoxide (cd inteligente)
if type -q zoxide
    zoxide init fish | source
    alias cd="z"
end

if type -q git
    function dotpush
        cd ~/Hobby/dotfiles && git add . && git commit -m "$argv" && git push
    end
    alias gst="git status"
    alias gdiff="git diff"
    function gp
        git add .
        git commit -m "$argv"
        git push
    end
end

# eza (ls mejorado), solo si está instalado
if type -q eza
    alias ls="eza --group-directories-first --icons"
    alias ll="eza -la --group-directories-first --icons"
    alias lt="eza --tree --group-directories-first --icons"

else
    alias ll="ls -la"
    alias ls="ls -l"
    alias lt="ls -lah"
end

# ripgrep (buscar rápido), solo si está instalado
if type -q rg
    alias rg="rg --hidden --glob '!.git/*'"
end

# fd (buscar archivos mejor que find), solo si está instalado
if type -q fd
    alias fd="fd --hidden --exclude .git"
end

# ipinfo (información de IP), solo si 'curl' está instalado
if type -q curl
    alias ipinfo="curl -s ipinfo.io"
end

if type -q ssh
    alias ssh='env TERM=xterm-256color ssh'
end

# set TERM xterm-256color

if type -q nano
    set EDITOR nano
    alias fishconfig='nano ~/.config/fish/config.fish'
    alias kittyconfig='nano ~/.config/kitty/kitty.conf'
    alias ffconfig='nano ~/.config/fastfetch/config.jsonc'
end

#if type -q vim
#   set EDITOR vim
#   alias fishconfig='vim ~/.config/fish/config.fish'
#   alias kittyconfig='vim ~/.config/kitty/kitty.conf'
#   alias ffconfig='vim ~/.config/fastfetch/config.jsonc'
#end
#
if type -q nvim
    set EDITOR nvim
    alias fishconfig='nvim ~/.config/fish/config.fish'
end

# history search (ctrl+r mejorado con fzf si lo instalas)
if type -q fzf
    set FZF_DEFAULT_OPTS "--height=50% --reverse --inline-info --border --color=fg:15,bg:0"
    function fish_user_key_bindings
        bind \cr fzf_history
    end
end

if type -q yazi
    alias y='yazi'
end

# Tmux session selector con gum
if type -q gum; and type -q tmux
    source ~/.config/fish/functions/tmuxls.fish
    source ~/.config/fish/functions/tmuxdel.fish
end

# Helper compartido (valida tmux para helpers tmux)
source ~/.config/fish/functions/__tmux_init.fish
source ~/.config/fish/functions/__tmux_shared.fish

# Tmux new session (ventana única)
source ~/.config/fish/functions/tmuxnew.fish

# Tmux selector de directorios desde cwd con fzf + fd
if type -q fzf; and type -q fd
    source ~/.config/fish/functions/tmuxfd.fish
end

# Tmux new session usando zoxide + fzf
if type -q zoxide; and type -q fzf
    source ~/.config/fish/functions/tmuxnewz.fish
end

# Deshabilitar mensaje de ayuda de fish
# Ejecutado una vez como variable universal, no en cada inicio.

if type -q curl; and type -q fzf; and type -q bat
    function cheat
        curl -s cheat.sh/:list | fzf --preview "curl -s cheat.sh/{}" --preview-window=right:70% | xargs -I {} curl -s cheat.sh/{} | bat --language=markdown --paging=always
    end
end

function g
    set -l query (string join '+' $argv)
    xdg-open "https://www.google.com/search?q=$query"
    exit
end

function yt
    set -l query (string join '+' $argv)
    xdg-open "https://www.youtube.com/results?search_query=$query"
    exit
end
