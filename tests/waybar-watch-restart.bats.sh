#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
watcher="$repo_dir/dotfiles/config/profiles/hyprland/.local/bin/waybar-watch"
tmp="$(mktemp -d)"
watcher_pid=""
restart_pid=""

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
config="$tmp/waybar-hypr"
bin="$tmp/bin"
pids="$tmp/waybar-pids"
mkdir -p "$home/.local/bin" "$state" "$config" "$bin"
: >"$pids"
touch "$config/config" "$config/style.css"
ln -s "$repo_dir/dotfiles/config/profiles/hyprland/.local/bin/waybar-caffeine-state" "$home/.local/bin/waybar-caffeine-state"

cat >"$home/.local/bin/waybar" <<'EOF'
#!/bin/sh
printf '%s\n' "$$" >>"$WAYBAR_PIDS"
trap 'exit 0' INT TERM
while :; do
  sleep 1
done
EOF
chmod +x "$home/.local/bin/waybar"

HOME="$home" XDG_STATE_HOME="$state" PATH="$bin:/run/current-system/sw/bin:/usr/bin:/bin" WAYBAR_PIDS="$pids" \
  "$watcher" "$config" &
watcher_pid="$!"

wait_for_starts() {
  expected="$1"
  for _ in $(seq 1 50); do
    [ "$(wc -l <"$pids")" -ge "$expected" ] && return 0
    sleep 0.1
  done
  return 1
}

wait_for_starts 1
HOME="$home" XDG_STATE_HOME="$state" PATH="$bin:/run/current-system/sw/bin:/usr/bin:/bin" WAYBAR_PIDS="$pids" \
  "$watcher" --restart "$config" &
restart_pid="$!"
wait_for_starts 2
wait "$watcher_pid" || true

active_watcher="$(cat "$state/waybar/waybar-hypr.watch.pid")"
[[ "$active_watcher" == "$restart_pid" ]]
kill -0 "$active_watcher"
watcher_pid="$restart_pid"
printf '%s\n' 'waybar-watch-restart: ok'
