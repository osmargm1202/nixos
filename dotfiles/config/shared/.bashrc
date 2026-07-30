# Shared Bash entrypoint. Keep non-interactive commands free of user-shell setup.
case $- in
  *i*) ;;
  *) return ;;
esac

export XDG_CONFIG_HOME="$HOME/.config"

if [[ -n ${__DOTFILES_BASHRC_SOURCED:-} ]]; then
  return
fi
__DOTFILES_BASHRC_SOURCED=1

# NixOS generates /etc/bashrc with bash-completion and blesh from installed
# packages. Source it for non-login interactive Bash sessions.
if [[ -z ${__ETC_BASHRC_SOURCED:-} && -r /etc/bashrc ]]; then
  . /etc/bashrc
fi

bash_config="${XDG_CONFIG_HOME:-$HOME/.config}/bash/config.bash"
if [[ -r "$bash_config" ]]; then
  . "$bash_config"
fi
unset bash_config
