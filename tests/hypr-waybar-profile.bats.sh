#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

# Sources are copied by orgm-dot at runtime, never linked by Home Manager.
[[ -f dotfiles/apps/waybar.json ]]
jq -e '.paths | index(".config/waybar-hypr") != null' dotfiles/apps/waybar.json >/dev/null
grep -Fxq '@import "orgm-current.css";' \
  'dotfiles/config/profiles/hyprland/.config/waybar-hypr/style.css'


caffeine_helper='dotfiles/config/profiles/wayland/.local/bin/waybar-caffeine-state'
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/bin"
cat >"$tmp/bin/notify-send" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${CAFFEINE_NOTIFICATIONS:?}"
EOF
chmod +x "$tmp/bin/notify-send"
export CAFFEINE_NOTIFICATIONS="$tmp/caffeine-notifications"

XDG_STATE_HOME="$tmp/state" PATH="$tmp/bin:$PATH" "$caffeine_helper" toggle
[[ "$(XDG_STATE_HOME="$tmp/state" PATH="$tmp/bin:$PATH" "$caffeine_helper" status)" == activated ]]

XDG_STATE_HOME="$tmp/state" PATH="$tmp/bin:$PATH" "$caffeine_helper" toggle
[[ "$(XDG_STATE_HOME="$tmp/state" PATH="$tmp/bin:$PATH" "$caffeine_helper" status)" == deactivated ]]

# Persist Caffeine through stock Waybar's supported startup option, not an
# unhandled RT signal requiring a custom C++ build.
mkdir -p "$tmp/config/waybar-hypr" "$tmp/home"
printf '%s\n' '[{"name":"eDP-1","description":"Test panel","focused":true}]' > "$tmp/monitors.json"
printf '%s\n' '[{"idle_inhibitor":{"signal":8},"modules-left":["idle_inhibitor"]}]' > "$tmp/config/waybar-hypr/config"
generate_bar() {
  env HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/config" XDG_CACHE_HOME="$tmp/cache" \
    XDG_STATE_HOME="$tmp/state" HYPR_DISPLAY_TARGETS_MONITORS_JSON="$tmp/monitors.json" \
    DISPLAY= WAYLAND_DISPLAY= \
    "$repo_dir/dotfiles/config/profiles/hyprland/.local/bin/hypr-display-targets" \
    waybar-config "$tmp/config/waybar-hypr"
}
generated="$(generate_bar)"
jq -e '.[0].idle_inhibitor["start-activated"] == false and (.[0].idle_inhibitor | has("signal") | not)' "$generated" >/dev/null
XDG_STATE_HOME="$tmp/state" PATH="$tmp/bin:$PATH" "$caffeine_helper" toggle
generated="$(generate_bar)"
jq -e '.[0].idle_inhibitor["start-activated"] == true' "$generated" >/dev/null
# The Sway-based profile is one object, while historical profiles use arrays.
cp "$repo_dir/dotfiles/config/users/osmarg/profiles/hyprland/.config/waybar-hypr/config" "$tmp/config/waybar-hypr/config"
generated="$(generate_bar)"
jq -e 'length == 1 and .[0].idle_inhibitor["start-activated"] == true and (.[0] | has("output") | not)' "$generated" >/dev/null
printf '%s\n' '[{"name":"eDP-1","description":"Test panel","focused":true},{"name":"DP-2","description":"External panel"}]' > "$tmp/monitors.json"
state="$tmp/config/orgm-hypr/display-targets.json"
jq '.waybar = {mode:"selected", selected:["External panel"]}' "$state" > "$tmp/selected.json"
mv "$tmp/selected.json" "$state"
generated="$(generate_bar)"
jq -e 'length == 1 and .[0].output == "DP-2" and .[0].idle_inhibitor["start-activated"] == true' "$generated" >/dev/null
XDG_STATE_HOME="$tmp/state" PATH="$tmp/bin:$PATH" "$caffeine_helper" toggle
generated="$(generate_bar)"
jq -e '.[0].idle_inhibitor["start-activated"] == false' "$generated" >/dev/null
# Array sources remain supported with selected outputs too.
printf '%s\n' '[{"idle_inhibitor":{"signal":8},"modules-left":["idle_inhibitor"]}]' > "$tmp/config/waybar-hypr/config"
generated="$(generate_bar)"
jq -e 'length == 1 and .[0].output == "DP-2" and .[0].idle_inhibitor["start-activated"] == false' "$generated" >/dev/null
printf '%s\n' 'hypr-waybar-profile: ok'
