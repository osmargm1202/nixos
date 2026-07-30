#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/nixos/profiles/i3.nix"
CONFIG="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
LAUNCHER="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-start-discord-background"
DOTFILES="$ROOT/nixos/common-dotfiles.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[ -x "$LAUNCHER" ] || fail 'Discord background launcher is missing or not executable'
grep -Fq 'exec --no-startup-id $run i3-start-discord-background' "$CONFIG" ||
  fail 'i3 does not start Discord through its background launcher'
grep -Fq 'xdotool' "$PROFILE" || fail 'i3 profile does not provide xdotool for Discord launcher'
grep -Fq 'discord >/dev/null 2>&1 &' "$LAUNCHER" || fail 'Discord is not launched asynchronously'
grep -Fq "read -r window_id < <(xdotool search --onlyvisible --class '^Discord$' 2>/dev/null)" "$LAUNCHER" ||
  fail 'launcher does not capture the initial Discord window ID'
grep -Fq 'i3-msg "[id=${window_id}] move scratchpad"' "$LAUNCHER" ||
  fail 'launcher does not move only the initial Discord window to scratchpad'
grep -Fq 'i3-start-discord-background' "$DOTFILES" || fail 'Discord background launcher is not deployed'
! grep -Fq 'for_window' "$LAUNCHER" || fail 'launcher must not hide future Discord windows'
bash -n "$LAUNCHER"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
cat >"$tmp/bin/discord" <<'STUB'
#!/usr/bin/env bash
printf 'discord\n' >>"$CALLS"
STUB
cat >"$tmp/bin/xdotool" <<'STUB'
#!/usr/bin/env bash
printf 'xdotool %s\n' "$*" >>"$CALLS"
printf '42\n'
STUB
cat >"$tmp/bin/i3-msg" <<'STUB'
#!/usr/bin/env bash
printf 'i3-msg %s\n' "$*" >>"$CALLS"
STUB
cat >"$tmp/bin/sleep" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
chmod +x "$tmp/bin/discord" "$tmp/bin/xdotool" "$tmp/bin/i3-msg" "$tmp/bin/sleep"

CALLS="$tmp/calls" PATH="$tmp/bin:$PATH" "$LAUNCHER"
grep -Fxq 'discord' "$tmp/calls" || fail 'launcher did not start Discord'
grep -Fxq 'i3-msg [id=42] move scratchpad' "$tmp/calls" ||
  fail 'launcher did not hide the initial Discord window'
[[ "$(grep -Fc 'i3-msg ' "$tmp/calls")" -eq 1 ]] || fail 'launcher must hide Discord only once'

printf 'PASS: i3 starts only its initial Discord window in the background\n'
