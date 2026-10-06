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

# Ryoku's overlay scanner accepts regular files only, not Home Manager links.
# Materialize our generated palette hook as a user-owned overlay before Ryoku
# lays its base. Keep the declarative source outside Ryoku's config roots.
if [[ -f "$config_home/orgm-ryoku/matugen-config.toml" ]]; then
  mkdir -p "$config_home/ryoku/user_edits/matugen"
  install_override "$config_home/orgm-ryoku/matugen-config.toml" \
    "$config_home/ryoku/user_edits/matugen/config.toml" matugen
fi

# Dedicated Kitty user config is never shipped by Ryoku. Keep palette/font
# updates in its normal config and append our include without losing other
# user settings or writing through an old Home Manager link.
mkdir -p "$config_home/kitty"
install_override "$config_home/orgm-ryoku/kitty.conf" "$config_home/kitty/orgm-ryoku.conf" kitty-opacity
kitty_user="$config_home/kitty/user.conf"
if [[ -L "$kitty_user" ]]; then
  cp -a -- "$kitty_user" "$state/kitty-user.before-ryoku"
  kitty_tmp="$(mktemp "$config_home/kitty/user.conf.XXXXXX")"
  cat "$kitty_user" > "$kitty_tmp"
  chmod 0644 "$kitty_tmp"
  mv -f -- "$kitty_tmp" "$kitty_user"
fi
touch "$kitty_user"
if ! grep -Fxq 'include orgm-ryoku.conf' "$kitty_user"; then
  printf '\n# ORGM Ryoku terminal preferences\ninclude orgm-ryoku.conf\n' >> "$kitty_user"
fi

# Hardware defaults are seeded only when no personal override exists. The
# monitor daemon and Hub remain the owners of hotplug detection and layouts.
monitor_defaults="$config_home/orgm-ryoku/monitors_user.lua"
if [[ -f "$monitor_defaults" && ! -e "$config_home/hypr/monitors_user.lua" && ! -L "$config_home/hypr/monitors_user.lua" ]]; then
  install -m0644 "$monitor_defaults" "$config_home/hypr/monitors_user.lua"
fi

# Seed the two keyboard layouts once; subsequent keyboard changes belong to Ryoku.
if [[ ! -e "$config_home/hypr/keyboard.lua" && ! -L "$config_home/hypr/keyboard.lua" ]]; then
  install -m0644 "$config_home/orgm-ryoku/keyboard.lua" "$config_home/hypr/keyboard.lua"
fi

# Hypridle 0.1.7 calls findConfig("hypridle") during initialization even when
# Ryoku supplies -c. Expose the generated policy at the default lookup path.
# Preserve an existing user configuration; Ryoku still owns the actual policy.
if [[ ! -e "$config_home/hypr/hypridle.conf" && ! -L "$config_home/hypr/hypridle.conf" ]]; then
  ln -s ../ryoku/hypridle.conf "$config_home/hypr/hypridle.conf"
fi

# Seed personal preferences through Ryoku's store, keeping later Hub edits.
desktop_store="$config_home/ryoku/desktop.json"
desktop_defaults="$config_home/orgm-ryoku/desktop-defaults.json"
if [[ ! -e "$state/desktop-defaults.seeded" ]]; then
  if [[ -e "$desktop_store" || -L "$desktop_store" ]]; then
    cp -a -- "$desktop_store" "$state/desktop.before-defaults.json"
    desktop_tmp=$(mktemp "$config_home/ryoku/desktop.json.XXXXXX")
    jq -s '.[0] * .[1]' "$desktop_defaults" "$desktop_store" > "$desktop_tmp"
    chmod 0644 "$desktop_tmp"
    mv -f -- "$desktop_tmp" "$desktop_store"
  else
    install -m0644 "$desktop_defaults" "$desktop_store"
  fi
  touch "$state/desktop-defaults.seeded"
fi

# Keep the encrypted login collection; PAM reuses the SDDM login password.
printf '%s\n' '{"mode":"unlock-on-login"}' > "$state/keyring.json"
install_override "$state/keyring.json" "$config_home/ryoku/keyring.json" keyring-policy

# Migrate only our retired default alias. Never delete or re-key collections.
keyring_dir="${XDG_DATA_HOME:-$HOME/.local/share}/keyrings"
if [[ -f "$keyring_dir/default" && -f "$keyring_dir/login.keyring" ]] &&
   [[ "$(cat "$keyring_dir/default")" == orgm-never-ask ]]; then
  printf '%s\n' login > "$keyring_dir/default"
  if busctl --user --quiet status org.freedesktop.secrets >/dev/null 2>&1; then
    busctl --user call org.freedesktop.secrets /org/freedesktop/secrets \
      org.freedesktop.Secret.Service SetAlias so default /org/freedesktop/secrets/collection/login
  fi
fi
touch "$state/active"
