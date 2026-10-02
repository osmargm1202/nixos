#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER="$ROOT/dotfiles/config/profiles/hyprland/.local/bin/hypr-nwg-dock"
PINS="$ROOT/dotfiles/config/profiles/hyprland/.config/nwg-dock-hyprland/pinned"
RELOAD="$ROOT/dotfiles/config/profiles/hyprland/.local/bin/hypr-nwg-dock-reload"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}



tmp="$(mktemp -d)"
launcher_pid=''
decoy_pid=''
fake_dock_pid=''
cleanup() {
  [[ -z "$launcher_pid" ]] || kill -TERM "$launcher_pid" 2>/dev/null || true
  [[ -z "$decoy_pid" ]] || kill -TERM "$decoy_pid" 2>/dev/null || true
  [[ -z "$fake_dock_pid" ]] || kill -TERM "$fake_dock_pid" 2>/dev/null || true
  rm -rf "$tmp"
}
trap cleanup EXIT
home="$tmp/home"
state="$tmp/state"
config="$tmp/config"
cache="$tmp/cache"
bin="$tmp/bin"
mkdir -p "$home" "$state" "$config/nwg-dock-hyprland" "$bin" \
  "$home/.local/state/nix/profiles/home-manager/home-path/share"
cp "$PINS" "$config/nwg-dock-hyprland/pinned"
cat >"$bin/nwg-dock-hyprland" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$DOCK_ARGS"
printf '%s\n' "$XDG_DATA_DIRS" >"$DOCK_XDG_DATA_DIRS"
if [[ "${DOCK_BLOCK:-0}" == 1 ]]; then
  trap 'exit 0' TERM INT
  while :; do sleep 1; done
fi
sleep 0.05
EOF
chmod +x "$bin/nwg-dock-hyprland"
export DOCK_ARGS="$tmp/dock-args"
export DOCK_XDG_DATA_DIRS="$tmp/xdg-data-dirs"

env HYPRLAND_INSTANCE_SIGNATURE=test-dock HOME="$home" XDG_STATE_HOME="$state" XDG_CONFIG_HOME="$config" XDG_CACHE_HOME="$cache" NWG_DOCK_BIN="$bin/nwg-dock-hyprland" PATH="$bin:$PATH" "$HELPER"
cmp "$PINS" "$cache/nwg-dock-pinned" ||
  fail 'dock must seed its pins when no user pin state exists'
[[ ! -e "$cache/nwg-dock-hyprland/nwg-dock-pinned" ]] ||
  fail 'dock must not initialize pins in the legacy nested cache path'
grep -Fxq -- "-x -p bottom -a center -mb 14 -c hypr-app-launcher -s style.css" "$DOCK_ARGS" ||
  fail 'dock must retain its floating bottom geometry and Rofi launcher'
[[ "$(<"$DOCK_XDG_DATA_DIRS")" == "$home/.local/state/nix/profiles/home-manager/home-path/share:"* ]] ||
  fail 'dock must search the active Home Manager desktop entries first'
printf 'custom\n' >"$cache/nwg-dock-pinned"
env HYPRLAND_INSTANCE_SIGNATURE=test-dock HOME="$home" XDG_STATE_HOME="$state" XDG_CONFIG_HOME="$config" XDG_CACHE_HOME="$cache" NWG_DOCK_BIN="$bin/nwg-dock-hyprland" PATH="$bin:$PATH" "$HELPER"
[[ "$(<"$cache/nwg-dock-pinned")" == "custom" ]] ||
  fail 'dock must preserve user-managed pins after initialization'
DOCK_BLOCK=1 env HYPRLAND_INSTANCE_SIGNATURE=test-dock HOME="$home" \
  XDG_STATE_HOME="$state" XDG_CONFIG_HOME="$config" XDG_CACHE_HOME="$cache" \
  NWG_DOCK_BIN="$bin/nwg-dock-hyprland" PATH="$bin:$PATH" "$HELPER" &
launcher_pid=$!
pid_file="$state/nwg-dock-hyprland/dock.pid"
for _ in {1..50}; do [[ -s "$pid_file" ]] && break; sleep 0.02; done
[[ -s "$pid_file" ]] || fail 'dock launcher did not publish owned PID state'
read -r dock_pid dock_starttime <"$pid_file"
kill -0 "$dock_pid" 2>/dev/null || fail 'published dock process is not alive'
HYPRLAND_INSTANCE_SIGNATURE=test-dock bash -c \
  'trap "exit 0" TERM INT; while :; do sleep 1; done' nwg-dock-hyprland &
decoy_pid=$!

cp "$(command -v bash)" "$bin/fake-nwg-dock-hyprland-helper"
HYPRLAND_INSTANCE_SIGNATURE=test-dock "$bin/fake-nwg-dock-hyprland-helper" -c \
  'trap "exit 0" TERM INT; while :; do sleep 1; done' &
fake_dock_pid=$!
env HYPRLAND_INSTANCE_SIGNATURE=test-dock HOME="$home" XDG_STATE_HOME="$state" \
  XDG_CONFIG_HOME="$config" XDG_CACHE_HOME="$cache" \
  NWG_DOCK_BIN="$bin/nwg-dock-hyprland" PATH="$bin:$(dirname "$HELPER"):$PATH" "$RELOAD"
for _ in {1..50}; do kill -0 "$dock_pid" 2>/dev/null || break; sleep 0.02; done
! kill -0 "$dock_pid" 2>/dev/null ||
  fail 'dock reload did not retire the exact PID-owned dock'
kill -0 "$decoy_pid" 2>/dev/null ||
  fail 'dock reload terminated an unrelated process containing the dock name'
kill -0 "$fake_dock_pid" 2>/dev/null ||
  fail 'dock reload terminated an unrelated executable containing the dock name'
wait "$launcher_pid" || true
launcher_pid=''
printf 'PASS: Hyprland autostarts and safely reloads a floating nwg-dock\n'
