#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/nixos/profiles/i3.nix"
CONFIG="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
RUNNER="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-run"
DOTFILES="$ROOT/nixos/common-dotfiles.nix"
BLOCKS="$ROOT/dotfiles/config/profiles/i3/.config/i3blocks/config"
STATUS_HELPER="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3blocks-status"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

grep -Fq 'environment.localBinInPath = true;' "$PROFILE" ||
  fail 'login session does not add ~/.local/bin to PATH'
grep -Fq 'extraPackages = [ pkgs.i3blocks ];' "$PROFILE" || fail 'i3blocks package missing'
grep -Fq 'status_command /run/current-system/sw/bin/i3blocks' "$CONFIG" ||
  fail 'i3blocks launch still depends on inherited i3 PATH'
grep -Fq 'command=$HOME/.local/bin/i3blocks-status "$BLOCK_NAME"' "$BLOCKS" ||
  fail 'i3blocks commands do not resolve the absolute user helper'
[[ -x "$STATUS_HELPER" ]] || fail 'i3blocks dispatcher missing'
grep -Fq '".local/bin/i3blocks-status"' "$DOTFILES" || fail 'i3blocks dispatcher not deployed'

[[ -x "$RUNNER" ]] || fail 'i3 PATH runner missing or not executable'
grep -Fq 'export PATH="$HOME/.local/bin:$PATH"' "$RUNNER" ||
  fail 'i3 runner does not prepend user helper directory'
grep -Fq '".local/bin/i3-run"' "$DOTFILES" || fail 'i3 runner not deployed'
grep -Fq 'set $run $HOME/.local/bin/i3-run' "$CONFIG" || fail 'i3 runner variable missing'

for command in \
  'bindsym $mod+space exec --no-startup-id $run i3-rofi --drun' \
  'bindsym $mod+Escape exec --no-startup-id $run i3-expo-toggle' \
  'bindsym Mod1+Tab exec --no-startup-id $run i3-rofi --window' \
  'bindsym $mod+c exec --no-startup-id $run i3-calc' \
  'bindsym $mod+w exec --no-startup-id $run i3-zen-new-window' \
  'bindsym $mod+o exec --no-startup-id $run i3-obsidian-open-or-focus' \
  'bindsym $mod+Shift+p exec --no-startup-id $run i3-pi-prompt'; do
  grep -Fq "$command" "$CONFIG" || fail "custom helper bypasses i3 PATH runner: $command"
done

grep -Fq '[caffeine]' "$BLOCKS" || fail 'i3blocks caffeine block missing'
grep -Fq 'i3-caffeine-toggle toggle' "$STATUS_HELPER" ||
  fail 'i3blocks caffeine action does not resolve through localBinInPath'

bash -n "$RUNNER"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/home/.local/bin" "$tmp/system"
cat >"$tmp/home/.local/bin/i3-test-command" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$PATH" >"$RUNNER_PATH"
printf '%s\n' "$@" >"$RUNNER_ARGS"
STUB
chmod +x "$tmp/home/.local/bin/i3-test-command"
test_path="$tmp/system:$(dirname "$(type -P bash)")"
HOME="$tmp/home" PATH="$test_path" RUNNER_PATH="$tmp/path" RUNNER_ARGS="$tmp/args" \
  "$RUNNER" i3-test-command one 'two words'
grep -Fq "$tmp/home/.local/bin:$test_path" "$tmp/path" || fail 'runner PATH incorrect'
[[ "$(sed -n '1p' "$tmp/args")" == one ]] || fail 'runner lost first argument'
[[ "$(sed -n '2p' "$tmp/args")" == 'two words' ]] || fail 'runner lost quoted argument'

printf 'PASS: i3 helpers and i3blocks are independent of stale session PATH\n'
