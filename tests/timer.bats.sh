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
printf '%s\0' "$@" >"$TERMDOWN_ARGS"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --outfile)
      [ ! -e "$2" ] || exit 9
      printf 'DONE\n%s\n' "${TERMDOWN_STATUS:-0}" >"$2"
      shift 2
      ;;
    *) shift ;;
  esac
done
EOF
cat >"$tmp/bin/notify-send" <<'EOF'
#!/usr/bin/env bash
printf '%s\0' "$@" >"$NOTIFY_ARGS"
EOF
chmod +x "$tmp/bin/termdown" "$tmp/bin/notify-send"

TERMDOWN_ARGS="$tmp/args" NOTIFY_ARGS="$tmp/notify" \
  PATH="$tmp/bin:$PATH" "$TIMER" 5

mapfile -d '' -t args <"$tmp/args"
expected=(
  '5m'
  '--blink'
  '--quit-after'
  '1'
  '--outfile'
)
[[ "${args[*]:0:5}" == "${expected[*]}" ]] || afail 'timer must launch termdown with a finite blinking countdown'
[[ -n "${args[5]}" && ! -e "${args[5]}" ]] || afail 'timer must remove its completion status file'
[[ "${args[6]}" == '--title' && "${args[7]}" == 'Temporizador: 5 min' ]] ||
  afail 'bare duration must be interpreted as minutes'
mapfile -d '' -t notification <"$tmp/notify"
[[ "${notification[*]}" == '-u critical -a timer Temporizador terminado 5 min' ]] ||
  afail 'completed timer must send one desktop notification'

rm -f "$tmp/notify"
TERMDOWN_STATUS=12 TERMDOWN_ARGS="$tmp/args" NOTIFY_ARGS="$tmp/notify" \
  PATH="$tmp/bin:$PATH" "$TIMER" 45s
mapfile -d '' -t args <"$tmp/args"
[[ "${args[0]}" == '45s' ]] || afail 'explicit termdown duration must be preserved'
[[ ! -e "$tmp/notify" ]] || afail 'early timer exit must not notify'

if PATH="$tmp/bin:$PATH" "$TIMER" >/dev/null 2>&1; then
  afail 'timer without a duration must fail'
fi

grep -Fq 'termdown' "$COMMON" || afail 'termdown must be installed for every profile'
grep -Fq '".local/bin/timer"' "$DOTFILES" || afail 'timer wrapper must be deployed for every profile'

printf '%s\n' 'PASS: global terminal timer uses termdown and notifies at completion'
