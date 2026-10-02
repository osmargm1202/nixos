config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
state="${XDG_STATE_HOME:-$HOME/.local/state}/orgm-ryoku"
mkdir -p "$state" "$config_home/hypr" "$config_home/ryoku/user_edits/hypr/modules"

install_override() {
  local source="$1" target="$2" name="$3"
  if [[ -e "$target" || -L "$target" ]] && [[ ! -e "$state/$name.saved" ]]; then
    cp -a -- "$target" "$state/$name.before-ryoku"
    touch "$state/$name.saved"
  fi
  # Replace the link itself, never write through a Home Manager store link.
  rm -f -- "$target"
  install -m0644 "$source" "$target"
}
install_override "$config_home/orgm-ryoku/rebind.lua" \
  "$config_home/ryoku/user_edits/hypr/modules/rebind.lua" rebind
install_override "$config_home/orgm-ryoku/user.lua" "$config_home/hypr/user.lua" user

# Seed the two keyboard layouts once; subsequent keyboard changes belong to Ryoku.
if [[ ! -e "$config_home/hypr/keyboard.lua" && ! -L "$config_home/hypr/keyboard.lua" ]]; then
  install -m0644 "$config_home/orgm-ryoku/keyboard.lua" "$config_home/hypr/keyboard.lua"
fi

# Record the preference without modifying an existing encrypted collection.
printf '%s\n' '{"mode":"never-ask"}' > "$state/keyring.json"
install_override "$state/keyring.json" "$config_home/ryoku/keyring.json" keyring-policy
touch "$state/active"
