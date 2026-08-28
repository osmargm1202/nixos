#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
profile="$repo_dir/dotfiles/config/profiles/hyprland"
bin="$profile/.local/bin"
obsidian_helper="$bin/hypr-obsidian-open-or-focus"
dank_window_switcher="$repo_dir/dotfiles/config/hosts/orgm/.config/DankMaterialShell/plugins/.repos/0026f1eba8dedaec/DankHyprlandWindows/DankHyprlandWindows.qml"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

bash -n "$bin"/hypr-*
bash -n "$bin"/waybar-*

grep -Fq 'PATH = path' "$profile/.config/hypr/lua/environment.lua"
if grep -Fq 'SDL_VIDEODRIVER' "$profile/.config/hypr/lua/environment.lua" ||
  grep -Fq 'SDL_VIDEODRIVER' "$repo_dir/nixos/profiles/hyprland.nix"; then
  printf '%s\n' 'Hyprland must not globally force an SDL video backend' >&2
  exit 1
fi
grep -Fq 'waybar-watch' "$profile/.config/hypr/lua/autostart.lua"
grep -Fq 'dunstctl reload >/dev/null 2>&1 || exec dunst' "$profile/.config/hypr/lua/autostart.lua"
grep -Fq 'hl.dsp.focus({ window = "address:${address}" })' "$dank_window_switcher"
! grep -Fq 'focuswindow address:' "$dank_window_switcher"
grep -Fxq '    bluetui' "$repo_dir/nixos/profiles/hyprland.nix"
grep -Fxq '    nwg-displays' "$repo_dir/nixos/profiles/hyprland.nix"
grep -Fxq '    pulsemixer' "$repo_dir/nixos/profiles/hyprland.nix"
grep -Fxq '    waybarWithCaffeineSignal' "$repo_dir/nixos/profiles/hyprland.nix"
grep -Fxq '    woomer' "$repo_dir/nixos/profiles/hyprland.nix"
grep -Fxq '  "hypridle",' "$profile/.config/hypr/lua/autostart.lua"
grep -Fq 'timeout = 600' "$profile/.config/hypr/hypridle.conf"
grep -Fq 'timeout = 900' "$profile/.config/hypr/hypridle.conf"
! grep -Fq 'dispatch dpms' "$profile/.config/hypr/hypridle.conf"
keybindings="$profile/.config/hypr/lua/keybindings.lua"
grep -Fq 'hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd(program("app_launcher", "hypr-app-launcher")))' "$keybindings"
grep -Fq 'hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("hypr-rofi-calc"))' "$keybindings"
grep -Fq 'hl.bind(mainMod .. " + Z", hl.dsp.exec_cmd("woomer"))' "$keybindings"
grep -Fq 'hl.bind(mainMod .. " + CTRL + C", hl.dsp.window.center())' "$keybindings"
grep -Fq 'hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("firefox-open-tab --restore-or-focus"))' "$keybindings"
grep -Fq 'hl.bind(mainMod .. " + CTRL + Return", hl.dsp.exec_cmd("kitty -e tmux new-session -A -s main"))' "$keybindings"
grep -Fq 'bindsym $mod+Ctrl+Return exec --no-startup-id kitty -e tmux new-session -A -s main' "$repo_dir/dotfiles/config/profiles/i3/.config/i3/config"
grep -Fq "entry 'Win+Ctrl+Enter' 'Kitty con tmux main' 'kitty -e tmux new-session -A -s main'" "$bin/hypr-keybindings-help"
grep -Fq "entry 'Alt+Tab' 'Vista de workspaces' 'ScrollOverview'" "$bin/hypr-keybindings-help"

test_bin="$tmp/bin"
home="$tmp/home"
mkdir -p "$test_bin" "$home/.config/orgm-hypr/rofi"
cat >"$test_bin/rofi" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$ROFI_ARGS"
if [ -n "${ROFI_OUTPUT:-}" ]; then
  printf '%s\n' "$ROFI_OUTPUT"
fi
EOF
cat >"$test_bin/cliphist" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat >"$test_bin/pgrep" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
cat >"$test_bin/hyprlock" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$HYPRLOCK_ARGS"
EOF
cat >"$test_bin/kitty" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$KITTY_ARGS"
EOF
cat >"$test_bin/firefox" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$FIREFOX_ARGS"
EOF
cat >"$test_bin/firefox-open-tab" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$FIREFOX_ARGS"
EOF
cat >"$test_bin/nwg-displays" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$NWG_DISPLAYS_ARGS"
EOF
cat >"$test_bin/waybar-watch" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$WAYBAR_WATCH_ARGS"
EOF
cat >"$test_bin/hypr-nwg-dock-reload" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$NWG_DOCK_RELOAD_ARGS"
EOF
cat >"$test_bin/hyprctl" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "-j" ]]; then
  printf '%s\n' '[]'
  exit 0
fi
printf '%s\n' "$*" >"${HYPRCTL_ARGS:-/dev/null}"
EOF
cat >"$test_bin/loginctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${LOGINCTL_ARGS:-/dev/null}"
EOF
cat >"$test_bin/jq" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' '0xobsidian'
EOF
chmod +x "$test_bin"/*
chmod +x "$test_bin/loginctl"

HOME="$home" PATH="$test_bin:$bin:/run/current-system/sw/bin:/usr/bin:/bin" HYPR_ROFI_LIB="$bin/hypr-rofi-lib" ROFI_ARGS="$tmp/rofi-args" "$bin/hypr-app-launcher"
grep -Fq -- '-show drun' "$tmp/rofi-args"
grep -Fq -- "-theme $home/.config/orgm-hypr/rofi/hypr-menu.rasi" "$tmp/rofi-args"
mkdir -p "$home/.config/hypr"
mkdir -p "$home/Hobby/nixos/dotfiles/config/profiles/hyprland/.config"
ln -s "$profile/.config/hypr" "$home/Hobby/nixos/dotfiles/config/profiles/hyprland/.config/hypr"
rofi_helpers=(
  hypr-apps-menu hypr-config-editor hypr-devices-menu hypr-help-menu
  hypr-keybindings-help hypr-keyboard-menu hypr-main-menu hypr-pi-prompt
  hypr-power-menu hypr-rofi-calc hypr-rofi-clipboard hypr-rofi-open-file
  hypr-rofi-open-file-dir hypr-rofi-open-file-terminal hypr-rofi-ssh-host
  hypr-rofi-window hypr-system-menu hypr-theme-chooser hypr-tools-menu
  hypr-transition-menu hypr-tweaks-menu
)
for helper in "${rofi_helpers[@]}"; do
  HOME="$home" PATH="$test_bin:$bin:/run/current-system/sw/bin:/usr/bin:/bin" HYPR_ROFI_LIB="$bin/hypr-rofi-lib" ROFI_ARGS="$tmp/rofi-args" "$bin/$helper"
done
HOME="$home" PATH="$test_bin:$bin:/run/current-system/sw/bin:/usr/bin:/bin" HYPR_ROFI_LIB="$bin/hypr-rofi-lib" ROFI_ARGS="$tmp/rofi-args" ROFI_OUTPUT='Displays' NWG_DISPLAYS_ARGS="$tmp/nwg-displays-args" "$bin/hypr-devices-menu"
test -f "$tmp/nwg-displays-args"
for expected in '-e nmtui' '-e bluetui' '-e pulsemixer'; do
  case "$expected" in
    *nmtui) selection='WiFi' ;;
    *bluetui) selection='Bluetooth' ;;
    *) selection='Audio mixer' ;;
  esac
  HOME="$home" PATH="$test_bin:$bin:/run/current-system/sw/bin:/usr/bin:/bin" HYPR_ROFI_LIB="$bin/hypr-rofi-lib" ROFI_ARGS="$tmp/rofi-args" ROFI_OUTPUT="$selection" KITTY_ARGS="$tmp/kitty-args" "$bin/hypr-devices-menu"
  [[ "$(<"$tmp/kitty-args")" == "$expected" ]]
done
HOME="$home" PATH="$test_bin:$bin:/run/current-system/sw/bin:/usr/bin:/bin" HYPR_ROFI_LIB="$bin/hypr-rofi-lib" ROFI_ARGS="$tmp/rofi-args" ROFI_OUTPUT='Kitty' KITTY_ARGS="$tmp/kitty-args" "$bin/hypr-apps-menu"
[[ "$(<"$tmp/kitty-args")" == '' ]]
HOME="$home" PATH="$test_bin:$bin:/run/current-system/sw/bin:/usr/bin:/bin" HYPR_ROFI_LIB="$bin/hypr-rofi-lib" ROFI_ARGS="$tmp/rofi-args" ROFI_OUTPUT='Restart Waybar' WAYBAR_WATCH_ARGS="$tmp/waybar-watch-args" "$bin/hypr-system-menu"
[[ "$(<"$tmp/waybar-watch-args")" == "--restart $home/.config/waybar-hypr" ]]
HOME="$home" PATH="$test_bin:$bin:/run/current-system/sw/bin:/usr/bin:/bin" HYPR_ROFI_LIB="$bin/hypr-rofi-lib" ROFI_ARGS="$tmp/rofi-args" ROFI_OUTPUT='Reload nwg-dock' NWG_DOCK_RELOAD_ARGS="$tmp/nwg-dock-reload-args" "$bin/hypr-system-menu"
test -f "$tmp/nwg-dock-reload-args"

HOME="$home" PATH="$test_bin:$bin:/run/current-system/sw/bin:/usr/bin:/bin" HYPRLOCK_ARGS="$tmp/hyprlock-args" "$bin/hypr-lock"
[[ "$(<"$tmp/hyprlock-args")" == '--immediate-render --no-fade-in' ]]
HOME="$home" PATH="$test_bin:$bin:/run/current-system/sw/bin:/usr/bin:/bin" HYPRLAND_INSTANCE_SIGNATURE=test-instance HYPRCTL_ARGS="$tmp/hyprctl-args" LOGINCTL_ARGS="$tmp/loginctl-args" "$bin/hyprlock-unlock" 42
[[ "$(<"$tmp/hyprctl-args")" == '--instance test-instance eval hl.clear_crashed_lockscreen()' ]]
grep -Fxq 'unlock-session 42' "$tmp/loginctl-args"
grep -Fxq 'activate 42' "$tmp/loginctl-args"
HOME="$home" PATH="$test_bin:$bin:/run/current-system/sw/bin:/usr/bin:/bin" HYPRCTL_ARGS="$tmp/hyprctl-args" "$obsidian_helper"
[[ "$(<"$tmp/hyprctl-args")" == 'dispatch hl.dsp.focus({ window = "address:0xobsidian" })' ]]
printf '%s\n' 'hypr-core-helpers: ok'
