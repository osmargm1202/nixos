#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
config="$repo_dir/dotfiles/config/shared/.config/fastfetch/hardware.jsonc"
bash_config="$repo_dir/dotfiles/config/shared/.config/bash/config.bash"


menu="$repo_dir/dotfiles/config/profiles/hyprland/.local/bin/hypr-system-menu"
temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT
cat >"$temp_dir/rofi-lib" <<'EOF'
hypr_rofi_dmenu() {
  cat >/dev/null
  printf '%s\n' '󰌢 Hardware details'
}
EOF
cat >"$temp_dir/kitty" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$KITTY_ARGS"
EOF
chmod +x "$temp_dir/kitty"
cat >"$temp_dir/fastfetch" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$FASTFETCH_ARGS"
EOF
chmod +x "$temp_dir/fastfetch"

HYPR_ROFI_LIB="$temp_dir/rofi-lib" KITTY_ARGS="$temp_dir/kitty-args" PATH="$temp_dir:$PATH" bash "$menu"
mapfile -t kitty_args <"$temp_dir/kitty-args"
[[ "${kitty_args[*]}" == *'--title hardware-fastfetch -e bash -ic'* ]]
[[ "${kitty_args[*]}" == *'fastfetch-hardware; printf "\n"; exec bash -i'* ]]
[[ -f "$config" ]]
FASTFETCH_ARGS="$temp_dir/fastfetch-args" PATH="$temp_dir:$PATH" \
  bash --noprofile --norc -ic 'source "$1"; eval fastfetch-hardware' -- "$bash_config"
mapfile -t fastfetch_args <"$temp_dir/fastfetch-args"
[[ "${fastfetch_args[0]}" == --config ]]
[[ "${fastfetch_args[1]}" == "$HOME/.config/fastfetch/hardware.jsonc" ]]

nix eval --impure --raw --expr '
  let c = (builtins.getFlake (toString ./.)).nixosConfigurations.lenovo-hyprland;
  in if builtins.elem c.pkgs.fastfetch c.config.environment.systemPackages
    then "fastfetch installed"
    else throw "fastfetch missing from system packages"
' >/dev/null

nix run nixpkgs#fastfetch -- --config "$config" >/dev/null
printf '%s\n' 'fastfetch-hardware: ok'
