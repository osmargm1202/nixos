#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$ROOT/dotfiles/config/shared/.local/bin/rofi-menu-lib"
SYMBOLS="$ROOT/dotfiles/config/shared/.local/bin/rofi-symbols"
I3_THEME="$ROOT/dotfiles/config/profiles/i3/.config/rofi/i3-menu.rasi"
HYPR_THEME="$ROOT/dotfiles/config/profiles/hyprland/.config/rofi/hypr-menu.rasi"
I3_CONFIG="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
HYPR_BINDINGS="$ROOT/dotfiles/config/profiles/hyprland/.config/hypr/lua/keybindings.lua"
I3_PROFILE="$ROOT/nixos/profiles/i3/i3.nix"
HYPR_PROFILE="$ROOT/nixos/profiles/hyprland/hyprland.nix"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

[[ -x "$LIB" ]] || { echo 'missing shared Rofi menu library' >&2; exit 1; }
[[ -x "$SYMBOLS" ]] || { echo 'missing symbol picker' >&2; exit 1; }

diff -u <(sed '3d' "$HYPR_THEME") <(sed '3d' "$I3_THEME")

i3_theme="$(XDG_CURRENT_DESKTOP=i3 HOME="$tmp/home" bash -c '. "$1"; rofi_menu_theme' -- "$LIB")"
hypr_theme="$(XDG_CURRENT_DESKTOP=Hyprland HOME="$tmp/home" bash -c '. "$1"; rofi_menu_theme' -- "$LIB")"
[[ "$i3_theme" == "$tmp/home/.config/rofi/i3-menu.rasi" ]]
[[ "$hypr_theme" == "$tmp/home/.config/orgm-hypr/rofi/hypr-menu.rasi" ]]

mkdir -p "$tmp/bin" "$tmp/home"
cat >"$tmp/bin/rofimoji" <<'EOF'
#!/usr/bin/env bash
printf '<%s>\n' "$@" >"$ROFIMOJI_ARGS"
EOF
chmod +x "$tmp/bin/rofimoji"
PATH="$tmp/bin:$PATH" HOME="$tmp/home" XDG_CURRENT_DESKTOP=i3 ROFI_MENU_LIB="$LIB" ROFIMOJI_ARGS="$tmp/args" "$SYMBOLS"
for argument in \
  '<rofi>' \
  '<clipboard>' \
  '<emojis_*>' '<nerd_font>' '<math>' '<miscellaneous_symbols>' '<miscellaneous_symbols_and_arrows>' \
  "<--selector-args=-theme $tmp/home/.config/rofi/i3-menu.rasi>"; do
  grep -Fx -- "$argument" "$tmp/args" >/dev/null
done

grep -Fq 'rofimoji' "$I3_PROFILE"
grep -Fq 'rofimoji' "$HYPR_PROFILE"
grep -Fq 'bindsym $mod+Ctrl+period exec --no-startup-id $run rofi-symbols' "$I3_CONFIG"
grep -Fq 'hl.bind(mainMod .. " + CTRL + period", hl.dsp.exec_cmd("rofi-symbols"))' "$HYPR_BINDINGS"

bash -n "$LIB" "$SYMBOLS"
printf '%s\n' 'rofi-menus: ok'
