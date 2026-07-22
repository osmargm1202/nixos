#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/nixos/profiles/i3.nix"
CONFIG="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
RUNNER="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-run"
DOTFILES="$ROOT/nixos/common-dotfiles.nix"
ICONSET="$ROOT/dotfiles/config/profiles/i3/.config/bumblebee-status/themes/icons/i3-clean.json"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

grep -Fq 'environment.localBinInPath = true;' "$PROFILE" ||
  fail 'login session does not add ~/.local/bin to PATH'
grep -Fq 'bumblebeeI3 = ' "$PROFILE" || fail 'i3 Bumblebee package override missing'
grep -Fq 'i3-clean.json' "$PROFILE" || fail 'i3-clean iconset not embedded in Bumblebee package'
grep -Fq '"$out/${pkgs.python3.sitePackages}/themes/icons/i3-clean.json"' "$PROFILE" ||
  fail 'i3-clean iconset installed outside Bumblebee theme search path'
grep -Fq 'extraPackages = [ bumblebeeI3 ];' "$PROFILE" ||
  fail 'i3 does not use Bumblebee package with embedded iconset'
[[ -f "$ICONSET" ]] || fail 'i3-clean iconset source missing'

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

grep -Fq 'shortcut.cmds="$HOME/.local/bin/i3-caffeine-toggle"' "$CONFIG" ||
  fail 'Bumblebee caffeine command still depends on inherited i3 PATH'

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

printf 'PASS: i3 helpers and Bumblebee assets are independent of stale session PATH\n'
