#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
DOTFILES="$ROOT/nixos/common-dotfiles.nix"
MP4="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-record-screen-mp4"
GIF="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-record-screen-gif"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

for binding in \
  'bindsym $mod+Print exec --no-startup-id i3-record-screen-mp4' \
  'bindsym $mod+Shift+Print exec --no-startup-id i3-record-screen-gif'; do
  grep -Fq "$binding" "$CONFIG" || fail "missing i3 binding: $binding"
done
for helper in i3-record-screen-mp4 i3-record-screen-gif; do
  grep -Fq ".local/bin/$helper" "$DOTFILES" || fail "helper is not deployed: $helper"
done

mkdir -p "$tmp/bin" "$tmp/runtime"
cat >"$tmp/bin/dunstify" <<'EOF'
#!/usr/bin/env bash
EOF
cat >"$tmp/bin/xclip" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null
EOF
cat >"$tmp/bin/ffcast" <<'EOF'
#!/usr/bin/env bash
for output; do :; done
trap 'printf video >"$output"; exit 0' TERM
while :; do read -r -t 0.05 _ || :; done
EOF
cat >"$tmp/bin/ffmpeg" <<'EOF'
#!/usr/bin/env bash
for output; do :; done
printf gif >"$output"
EOF
chmod +x "$tmp/bin"/*

wait_for_pid() {
  local pid_file=$1
  for _ in $(seq 1 50); do
    [[ -s "$pid_file" ]] && return 0
    sleep 0.05
  done
  fail "recorder did not create $pid_file"
}

run_toggle() {
  local script=$1 output_dir=$2 pid_file=$3
  HOME="$tmp/home" XDG_RUNTIME_DIR="$tmp/runtime" PATH="$tmp/bin:$PATH" "$script" &
  local launcher=$!
  wait_for_pid "$pid_file"
  HOME="$tmp/home" XDG_RUNTIME_DIR="$tmp/runtime" PATH="$tmp/bin:$PATH" "$script"
  wait "$launcher"
  compgen -G "$output_dir/*" >/dev/null || fail "recorder did not create output"
}

mkdir -p "$tmp/home"
run_toggle "$MP4" "$tmp/home/Videos/Records" "$tmp/runtime/i3-screen-recording/mp4.pid"
run_toggle "$GIF" "$tmp/home/Pictures/Records" "$tmp/runtime/i3-screen-recording/gif.pid"

printf 'PASS: i3 recording shortcuts toggle isolated X11 MP4 and GIF captures\n'
