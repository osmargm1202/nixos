set -g fish_greeting
set -Ue fish_key_bindings

# Dev environments are per-project flakes: `flakeinit` scaffolds a
# flake.nix (devShell vacio), luego `nix develop`. Para binarios sueltos:
# steam-run (FHS) o nix-ld (claude, pi, codex).

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

if status is-interactive
    type -q load_private_env; and load_private_env
end

if test -f ~/.config/fish/insforge.env
    source ~/.config/fish/insforge.env
end

# PATH
set -gx PATH $HOME/.local/bin $PATH
set -gx PATH $HOME/.cargo/bin $PATH
set -gx PATH $HOME/go/bin $PATH
set -gx PATH $HOME/.npm-global/bin $PATH
set -gx PATH $HOME/.bun/bin $PATH
set -gx PATH $HOME/.local/share/pnpm $PATH

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

# Manual version of the automated cleanup in nixos/clean.nix.
# nh clean all: generaciones sistema + usuarios + home-manager (keep 3) y GC.
function nixclean
    _orgm_sudo nh clean all --keep 3 --keep-since 30d
    _orgm_sudo nix store optimise
    _orgm_sudo journalctl --vacuum-time=30d
    flatpak uninstall --unused --assumeyes --noninteractive
    trash-empty 30 -f
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

alias yazi='nix run nixpkgs#yazi --'
alias y='yazi'

if type -q zutty-fast
    alias zutty='zutty-fast'
end

# Runner efimero: `, app [args...]` = nix run nixpkgs#app
# Apps de uso esporadico no se instalan; se corren desde cache binario
# (registry pineado al nixpkgs del sistema en common.nix).
function , --description 'nix run nixpkgs#<app>'
    if test (count $argv) -eq 0
        echo "uso: , <app> [args...]" >&2
        return 1
    end
    nix run nixpkgs#$argv[1] -- $argv[2..-1]
end

# Apps efimeras: no instaladas, corren desde cache binario con el mismo
# nixpkgs del sistema (registry pineado en common.nix) — mismo store
# path, sin descarga extra. OJO: exec directo (kitty -e app, scripts
# bash) NO pasa por estos aliases; usar `fish -lc app` o `, app`.
for app in ncdu fastfetch xclip podman-compose sops just figlet nix-search-tv dolphin-emu pcsx2 rpcs3
    alias $app="nix run nixpkgs#$app --"
end
# herdr: pineado al input del flake del sistema (no esta en nixpkgs)
alias herdr='nix run herdr --'

# caelestia writes a fully live-tuned config (incl. the caelestia colour
# theme) to its own state dir on every scheme change; use that instead of
# the static ~/.config/btop/btop.conf.
if test -f ~/.local/state/caelestia/dots/btop/btop.conf
    alias btop='nix run nixpkgs#btop -- -c ~/.local/state/caelestia/dots/btop/btop.conf'
else
    alias btop='nix run nixpkgs#btop --'
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
