config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
state="${XDG_STATE_HOME:-$HOME/.local/state}/orgm-ryoku"
# Do not let a native materialization follow a personal directory link.
for directory in hypr niri quickshell matugen qt6ct gtk-3.0 gtk-4.0 btop fastfetch kitty fish wireplumber yazi nvim bash ryoku; do
  if [[ -L "$config_home/$directory" ]]; then
    printf 'Ryoku: preserved personal directory link %s; materialization needs a writable directory\n' "$directory" >&2
    exit 1
  fi
done
mkdir -p "$state" "$config_home/hypr" "$config_home/ryoku/user_edits/hypr/modules"

# HM calls this before withdrawing old links; session preparation also seeds
# newly absent files. Only the manifest knows which legacy links we owned.
if [[ -f "$config_home/orgm-ryoku/seed.py" && -f "$config_home/orgm-ryoku/seed-manifest.json" ]]; then
  python3 "$config_home/orgm-ryoku/seed.py" "$config_home" "$state" "$HOME" \
    "$config_home/orgm-ryoku/seed-manifest.json" || exit $?
fi

seed_override() {
  local source="$1" target="$2"
  if [[ ! -e "$target" && ! -L "$target" ]]; then
    install -m0644 "$source" "$target"
  fi
}
seed_override "$config_home/orgm-ryoku/rebind.lua" \
  "$config_home/ryoku/user_edits/hypr/modules/rebind.lua"
seed_override "$config_home/orgm-ryoku/user.lua" "$config_home/hypr/user.lua"

if [[ -f "$config_home/orgm-ryoku/matugen-config.toml" ]]; then
  mkdir -p "$config_home/ryoku/user_edits/matugen"
  seed_override "$config_home/orgm-ryoku/matugen-config.toml" \
    "$config_home/ryoku/user_edits/matugen/config.toml"
fi

mkdir -p "$config_home/kitty"
seed_override "$config_home/orgm-ryoku/kitty.conf" "$config_home/kitty/orgm-ryoku.conf"
kitty_user="$config_home/kitty/user.conf"
if [[ ! -e "$kitty_user" && ! -L "$kitty_user" ]]; then
  printf '# Initial personal override; editable in place.\ninclude orgm-ryoku.conf\n' > "$kitty_user"
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

# Versioned migration is separate from the old one-shot appearance seed. It
# edits only supported session/keybinding keys, preserving all other Hub data.
if [[ -f "$config_home/orgm-ryoku/native-session.json" ]]; then
  python3 "$config_home/orgm-ryoku/native-session.py" "$config_home" "$state" || exit $?
fi

# Initial policy only: later Hub keyring choices win. PAM stays declarative.
if [[ ! -e "$config_home/ryoku/keyring.json" && ! -L "$config_home/ryoku/keyring.json" ]]; then
  printf '%s\n' '{"mode":"unlock-on-login"}' > "$config_home/ryoku/keyring.json"
fi

# Migrate only our retired default alias. Never delete or re-key collections.
keyring_dir="${XDG_DATA_HOME:-$HOME/.local/share}/keyrings"
if [[ ! -e "$state/keyring-alias-v1.applied" ]]; then
  if [[ -f "$keyring_dir/default" && ! -L "$keyring_dir/default" && -f "$keyring_dir/login.keyring" ]] &&
     [[ "$(cat "$keyring_dir/default")" == orgm-never-ask ]]; then
    printf '%s\n' login > "$keyring_dir/default"
    if busctl --user --quiet status org.freedesktop.secrets >/dev/null 2>&1; then
      busctl --user call org.freedesktop.secrets /org/freedesktop/secrets \
        org.freedesktop.Secret.Service SetAlias so default /org/freedesktop/secrets/collection/login
    fi
  fi
  touch "$state/keyring-alias-v1.applied"
fi
touch "$state/active"
