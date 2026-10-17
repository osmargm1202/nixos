# Personal imports only. Remove or reorder these here; deployment preserves it.
_orgm_imports=${XDG_CONFIG_HOME:-$HOME/.config}/orgm-shell
for _orgm_file in workflows.bash functions.bash completions.bash sops-age.bash "host-$(hostname).bash"; do
  [[ -r $_orgm_imports/$_orgm_file ]] && . "$_orgm_imports/$_orgm_file"
done
unset _orgm_file _orgm_imports
