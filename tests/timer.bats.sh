#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TIMER="$ROOT/dotfiles/config/shared/.local/bin/timer"
COMMON="$ROOT/nixos/common.nix"
DOTFILES="$ROOT/nixos/common-dotfiles.nix"

afail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"

cat >"$tmp/bin/termdown" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$TIMER_NOTIFICATION_BODY" >"$TIMER_NOTIFICATION_BODY_LOG"
printf '%s\0' "$@" >"$TERMDOWN_ARGS"
EOF
chmod +x "$tmp/bin/termdown"

TERMDOWN_ARGS="$tmp/args" TIMER_NOTIFICATION_BODY_LOG="$tmp/body" \
  PATH="$tmp/bin:$PATH" "$TIMER" 5

[[ "$(<"$tmp/body")" == '5 min' ]] || afail 'bare duration must be interpreted as minutes'
mapfile -d '' -t args <"$tmp/args"
expected=(
  '5m'
  '--blink'
  '--title'
  'Temporizador: 5 min'
  '--exec-cmd'
  'if [ "{0}" -eq 0 ]; then notify-send -u critical -a timer "Temporizador terminado" "$TIMER_NOTIFICATION_BODY"; fi'
)
[[ "${args[*]}" == "${expected[*]}" ]] || afail 'timer must launch termdown with its countdown and notification contract'

TERMDOWN_ARGS="$tmp/args" TIMER_NOTIFICATION_BODY_LOG="$tmp/body" \
  PATH="$tmp/bin:$PATH" "$TIMER" 45s
[[ "$(<"$tmp/body")" == '45s' ]] || afail 'explicit termdown duration must be preserved'

if PATH="$tmp/bin:$PATH" "$TIMER" >/dev/null 2>&1; then
  afail 'timer without a duration must fail'
fi

grep -Fq 'termdown' "$COMMON" || afail 'termdown must be installed for every profile'
grep -Fq '".local/bin/timer"' "$DOTFILES" || afail 'timer wrapper must be deployed for every profile'

printf '%s\n' 'PASS: global terminal timer uses termdown and notifies at completion'
