#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE="$ROOT/nixos/common-dotfiles.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

profile_paths="$(awk '/profileSpecificPaths = \{/{capture=1} /hostIconSubdirs = \[/{capture=0} capture' "$MODULE")"
host_icons="$(awk '/hostIconSubdirs = \[/{capture=1} capture{print} capture && /];/{exit}' "$MODULE")"
activation="$(awk '/home.activation.initGeneratedConfigs =/{capture=1} /# Steam \(and similar launchers\)/{capture=0} capture' "$MODULE")"

managed_gtk4=(
  '.config/gtk-4.0/noctalia.css'
  '.config/gtk-4.0/dank-colors.css'
  '.config/gtk-4.0/colors.css'
  '.config/gtk-4.0/thunar.css'
)
for path in "${managed_gtk4[@]}"; do
  if grep -Fq "$path" <<<"$profile_paths"; then
    fail "$path must not be managed by profileSpecificPaths"
  fi
done

if grep -Fq '.local/share/icons/default' <<<"$host_icons"; then
  fail '.local/share/icons/default must not be managed by hostIconSubdirs'
fi

preference_defaults=(
  '.config/gtk-3.0/settings.ini'
  '.config/gtk-4.0/settings.ini'
  '.icons/default/index.theme'
)
grep -Fq '[ -e "$dst" ] && return 0' <<<"$activation" ||
  fail 'GTK preference defaults must only initialize absent files'
grep -Fq 'gtk-icon-theme-name=Colloid-Dark' <<<"$activation" ||
  fail 'first-run GTK defaults must use the Colloid-Dark icon theme'
for path in "${preference_defaults[@]}"; do
  grep -Fq "init_file \"$path\"" <<<"$activation" ||
    fail "$path must receive a first-run user-owned default"
done

tracked_outputs=(
  'dotfiles/config/profiles/hyprland/.config/gtk-4.0/colors.css'
  'dotfiles/config/profiles/hyprland/.config/gtk-4.0/dank-colors.css'
  'dotfiles/config/profiles/hyprland/.config/gtk-4.0/noctalia.css'
  'dotfiles/config/profiles/hyprland/.config/gtk-4.0/thunar.css'
  'dotfiles/config/hosts/lenovo/.local/share/icons/default/index.theme'
  'dotfiles/config/hosts/orgm/.local/share/icons/default/index.theme'
)
for path in "${tracked_outputs[@]}"; do
  [ ! -e "$ROOT/$path" ] && [ ! -L "$ROOT/$path" ] || fail "$path must not remain in the repository"
done

runtime_inventory=(
  '.gtkrc-2.0'
  '.config/xsettingsd/xsettingsd.conf'
  '.icons/default/index.theme'
  '.config/hypr/monitors.conf'
  '.config/hypr/monitors.lua'
  '.config/hypr/workspaces.conf'
  '.config/hypr/workspaces.lua'
  '.config/nwg-displays/config'
)
for path in "${runtime_inventory[@]}"; do
  grep -Fq "\"$path\"" "$MODULE" || fail "$path must be documented as runtime-owned"
done

printf 'PASS: generated desktop and NWG config is runtime-owned\n'
