# Initial Ryoku Bash bootstrap; editable after first installation.
case $- in *i*) ;; *) return ;; esac
[[ ${__ORGM_RYOKU_RC_LOADED:-0} == 1 ]] && return
__ORGM_RYOKU_RC_LOADED=1

_ryoku_etc=${ORGM_ETC_BASHRC:-/etc/bashrc}
if [[ -z ${__ETC_BASHRC_SOURCED:-} && -r $_ryoku_etc ]]; then
  . "$_ryoku_etc"
fi
_ryoku_hm=${ORGM_HM_SESSION_VARS:-/etc/profiles/per-user/$USER/etc/profile.d/hm-session-vars.sh}
[[ -r $_ryoku_hm ]] && . "$_ryoku_hm"
unset _ryoku_etc _ryoku_hm

_ryoku_native=${XDG_CONFIG_HOME:-$HOME/.config}/bash/ryoku.bash
[[ -r $_ryoku_native ]] && . "$_ryoku_native"
unset _ryoku_native
