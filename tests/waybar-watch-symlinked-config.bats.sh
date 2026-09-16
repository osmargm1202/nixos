#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
watcher="$repo_dir/dotfiles/config/profiles/hyprland/.local/bin/waybar-watch"
tmp="$(mktemp -d)"
watcher_pid=""

cleanup() {
  if [ -n "$watcher_pid" ] && kill -0 "$watcher_pid" 2>/dev/null; then
    kill "$watcher_pid" 2>/dev/null || true
    wait "$watcher_pid" 2>/dev/null || true
  fi
  rm -rf "$tmp"
}
trap cleanup EXIT

home="$tmp/home"
state="$tmp/state"
checkout="$tmp/checkout"
store="$tmp/store"
config="$tmp/waybar-hypr"
bin="$tmp/bin"
pids="$tmp/waybar-pids"
mkdir -p "$home/.local/bin" "$state" "$checkout" "$store" "$config" "$bin"
: >"$pids"

# Mirror how the live config is wired: Home Manager links ~/.config entries to
# the store, and the store links on to the mutable checkout that gets edited.
printf '%s\n' '[]' >"$checkout/config"
printf '%s\n' '/* base */' >"$checkout/style.css"
for name in config style.css; do
  ln -s "$checkout/$name" "$store/$name"
  ln -s "$store/$name" "$config/$name"
done

ln -s "$repo_dir/dotfiles/config/profiles/hyprland/.local/bin/waybar-caffeine-state" \
  "$home/.local/bin/waybar-caffeine-state"

cat >"$home/.local/bin/waybar" <<'INNER'
#!/bin/sh
printf '%s\n' "$$" >>"$WAYBAR_PIDS"
trap 'exit 0' INT TERM
while :; do
  sleep 1
done
INNER
chmod +x "$home/.local/bin/waybar"

HOME="$home" XDG_STATE_HOME="$state" PATH="$bin:/run/current-system/sw/bin:/usr/bin:/bin" WAYBAR_PIDS="$pids" \
  "$watcher" "$config" &
watcher_pid="$!"

wait_for_starts() {
  expected="$1"
  for _ in $(seq 1 80); do
    [ "$(wc -l <"$pids")" -ge "$expected" ] && return 0
    sleep 0.1
  done
  return 1
}

wait_for_starts 1 || {
  printf 'FAIL: %s\n' 'watcher did not start Waybar' >&2
  exit 1
}

printf '%s\n' '/* edited through the checkout */' >>"$checkout/style.css"

wait_for_starts 2 || {
  printf 'FAIL: %s\n' 'watcher ignored an edit made through the symlinked config' >&2
  exit 1
}

printf '%s\n' 'waybar-watch-symlinked-config: ok'
