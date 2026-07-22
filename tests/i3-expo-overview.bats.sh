#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE="$ROOT/nixos/packages/i3expo-ng.nix"
PROFILE="$ROOT/nixos/profiles/i3.nix"
CONFIG="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
THEME="$ROOT/dotfiles/config/profiles/i3/.config/rofi/i3-menu.rasi"
EXPO_CONFIG="$ROOT/dotfiles/config/profiles/i3/.config/i3expo/config"
BIN="$ROOT/dotfiles/config/profiles/i3/.local/bin"
DOTFILES="$ROOT/nixos/common-dotfiles.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[ -f "$PACKAGE" ] || fail 'i3expo-ng Nix package missing'
grep -Fq 'rev = "2c273b0ec8d9d0b75dca80744574bffeb9330a28";' "$PACKAGE" || fail 'i3expo-ng source is not pinned'
grep -Fq 'hash = "sha256-I8bQWIv0zbRJmwZytYapU7mIet4ugULCla7kK4Y5ErA=";' "$PACKAGE" || fail 'i3expo-ng source hash missing'
grep -Fq 'pyproject = true;' "$PACKAGE" || fail 'i3expo-ng must use setuptools PEP-517 hooks'
grep -Fq 'rm -f "$out/bin/i3expod"' "$PACKAGE" || fail 'broken upstream console entry point remains installed'
grep -Fq 'mainProgram = "i3expod.py";' "$PACKAGE" || fail 'working upstream script is not the main program'
grep -Fq 'patches = [ ./i3expo-ng-ready.patch ];' "$PACKAGE" || fail 'SIGUSR1 readiness patch missing'
PATCH="$ROOT/nixos/packages/i3expo-ng-ready.patch"
thread_line="$(grep -n 'i3_thread.start()' "$PATCH" | head -n1 | cut -d: -f1)"
ready_line="$(grep -n 'I3EXPO_READY_FILE' "$PATCH" | head -n1 | cut -d: -f1)"
[[ -n "$thread_line" && -n "$ready_line" && "$ready_line" -gt "$thread_line" ]] ||
  fail 'readiness marker is published before Expo runtime initialization'
for dependency in pygame i3ipc pillow xdg pyxdg; do
  grep -Eq "^[[:space:]]+${dependency}[[:space:]]*$" "$PACKAGE" || fail "i3expo-ng Python dependency missing: $dependency"
done
grep -Fq 'i3expo = pkgs.callPackage ../packages/i3expo-ng.nix { };' "$PROFILE" || fail 'i3 profile does not construct i3expo-ng'
grep -Eq '^[[:space:]]+i3expo[[:space:]]*$' "$PROFILE" || fail 'i3expo-ng not installed'

for helper in i3-expo-daemon i3-expo-toggle; do
  [ -x "$BIN/$helper" ] || fail "$helper missing or not executable"
  grep -Fq "\".local/bin/$helper\"" "$DOTFILES" || fail "$helper not deployed"
  bash -n "$BIN/$helper"
done
grep -Fq 'flock -n 9' "$BIN/i3-expo-daemon" || fail 'i3expo daemon lacks single-instance lock'
grep -Fq '/proc/$candidate/stat' "$BIN/i3-expo-toggle" || fail 'i3expo toggle does not validate PID start time'
grep -Fq 'exec i3expod.py' "$BIN/i3-expo-daemon" || fail 'daemon uses broken upstream console entry point'
grep -Fq 'I3EXPO_READY_FILE' "$BIN/i3-expo-daemon" || fail 'daemon does not request readiness handshake'
grep -Fq 'is_ready' "$BIN/i3-expo-toggle" || fail 'toggle can signal before Expo installs SIGUSR1 handler'
[ -f "$EXPO_CONFIG" ] || fail 'i3expo runtime configuration missing'
grep -Fq '".config/i3expo"' "$DOTFILES" || fail 'i3expo config not deployed'

grep -Fq 'exec --no-startup-id i3-expo-daemon' "$CONFIG" || fail 'i3expo screenshot daemon not started'
grep -Fq 'bindsym $mod+Escape exec --no-startup-id i3-expo-toggle' "$CONFIG" || fail 'Win+Escape does not open i3expo'
grep -Fq 'bindsym Mod1+Tab exec --no-startup-id i3-rofi --window' "$CONFIG" || fail 'Alt+Tab must remain Rofi window selector'
grep -Fq 'bindsym $mod+Tab workspace back_and_forth' "$CONFIG" || fail 'Win+Tab must switch to previous workspace'

grep -Fq 'border: 0px;' "$THEME" || fail 'Rofi outer border remains visible'
if grep -Eq '^[[:space:]]*border:[[:space:]]*[1-9]' "$THEME"; then fail 'Rofi has a nonzero border line'; fi

tmp="$(mktemp -d)"
cleanup() {
  if [[ -f "$tmp/runtime/i3expod.pid" ]]; then
    read -r pid _ <"$tmp/runtime/i3expod.pid"
    kill "$pid" 2>/dev/null || true
  fi
  rm -rf "$tmp"
}
trap cleanup EXIT
mkdir -p "$tmp/bin" "$tmp/runtime"
cat >"$tmp/bin/i3expod.py" <<'STUB'
#!/usr/bin/env bash
trap 'printf signal\\n >>"$EXPO_SIGNAL"' USR1
sleep 0.3
printf '%s\n' "$$" >"$I3EXPO_READY_FILE"
while :; do sleep 0.1; done
STUB
cat >"$tmp/bin/notify-send" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
chmod +x "$tmp/bin/i3expod.py" "$tmp/bin/notify-send"
printf '%s %s\n' "$$" 0 >"$tmp/runtime/i3expod.pid"
printf '%s\n' "$$" >"$tmp/runtime/i3expod.ready"
EXPO_SIGNAL="$tmp/signal" XDG_RUNTIME_DIR="$tmp/runtime" PATH="$tmp/bin:$BIN:$PATH" "$BIN/i3-expo-toggle"
for _ in {1..20}; do [[ -f "$tmp/signal" ]] && break; sleep 0.1; done
[[ -f "$tmp/signal" ]] || fail 'toggle did not signal running wrapped-style Expo daemon'

read -r first_pid _ <"$tmp/runtime/i3expod.pid"
kill "$first_pid" 2>/dev/null || true
for _ in {1..20}; do kill -0 "$first_pid" 2>/dev/null || break; sleep 0.1; done
rm -f "$tmp/runtime/i3expod.pid" "$tmp/runtime/i3expod.ready" "$tmp/runtime/i3expod.lock" "$tmp/signal"
EXPO_SIGNAL="$tmp/signal" XDG_RUNTIME_DIR="$tmp/runtime" PATH="$tmp/bin:$BIN:$PATH" "$BIN/i3-expo-daemon" &
for _ in {1..20}; do [[ -f "$tmp/runtime/i3expod.pid" ]] && break; sleep 0.01; done
[[ ! -f "$tmp/runtime/i3expod.ready" ]] || fail 'delayed readiness fixture became ready too early'
EXPO_SIGNAL="$tmp/signal" XDG_RUNTIME_DIR="$tmp/runtime" PATH="$tmp/bin:$BIN:$PATH" "$BIN/i3-expo-toggle"
for _ in {1..20}; do [[ -f "$tmp/signal" ]] && break; sleep 0.1; done
EXPO_SIGNAL="$tmp/signal" XDG_RUNTIME_DIR="$tmp/runtime" PATH="$tmp/bin:$BIN:$PATH" "$BIN/i3-expo-toggle"
for _ in {1..20}; do
  [[ -f "$tmp/signal" ]] && [[ "$(grep -c '^signal$' "$tmp/signal")" -ge 2 ]] && break
  sleep 0.1
done
[[ -f "$tmp/runtime/i3expod.pid" ]] || fail 'toggle discarded live daemon PID while waiting for readiness'
[[ "$(grep -c '^signal$' "$tmp/signal")" -eq 2 ]] || fail 'repeated toggles did not signal the same initialized daemon'

printf 'PASS: Win+Escape opens i3expo, Alt+Tab stays Rofi and Win+Tab switches workspace\n'
