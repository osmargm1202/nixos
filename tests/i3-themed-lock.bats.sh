#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
POWER="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-powermenu"
LOCK="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-lock"
DOTFILES="$ROOT/nixos/common-dotfiles.nix"
PROFILE="$ROOT/nixos/profiles/i3.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[ -x "$LOCK" ] || fail 'i3-lock helper missing or not executable'
grep -Fq '".local/bin/i3-lock"' "$DOTFILES" || fail 'i3-lock not deployed'
grep -Fq '(i3lock-fancy.override {' "$PROFILE" || fail 'stock i3lock-fancy package missing'
grep -Fq 'screenshotCommand = "${scrot}/bin/scrot -z";' "$PROFILE" || fail 'fast scrot screenshot command missing'
grep -Fq 'name = "i3lock-color-fallback";' "$PROFILE" || fail 'collision-safe color fallback wrapper missing'
grep -Eq '^[[:space:]]+i3lockColorFallback[[:space:]]*$' "$PROFILE" || fail 'color fallback wrapper not installed'
if grep -Eq '^[[:space:]]+i3lock-color[[:space:]]*$' "$PROFILE"; then
  fail 'standalone i3lock-color conflicts with i3lock-fancy bin/i3lock'
fi
grep -Fq "i3lock-fancy -t 'Ingrese su contraseña'" "$LOCK" || fail 'lock helper does not launch i3lock-fancy with Spanish prompt'
grep -Fq 'exec i3lock-color-fallback --color=2e3440ff --ignore-empty-password' "$LOCK" || fail 'fancy preprocessing failure has no secure lock fallback'
if grep -Eq 'magick|--clock|--inside-color|--image=' "$LOCK"; then
  fail 'legacy custom lock implementation remains active'
fi

grep -Fq 'xss-lock --transfer-sleep-lock -- i3-lock --nofork' "$CONFIG" || fail 'idle lock bypasses themed helper'
grep -Fq 'bindsym $mod+Mod1+l exec --no-startup-id i3-lock' "$CONFIG" || fail 'Mod+Alt+L bypasses themed helper'
grep -Fq 'bindsym $mod+Shift+l exec --no-startup-id i3-lock' "$CONFIG" || fail 'legacy lock shortcut bypasses helper'
grep -Fq 'Lock) exec i3-lock' "$POWER" || fail 'power menu bypasses themed helper'

bash -n "$LOCK"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
cat >"$tmp/bin/i3lock-fancy" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$LOCK_CALLS"
[[ "${FANCY_FAIL:-0}" == 0 ]]
STUB
cat >"$tmp/bin/i3lock-color-fallback" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$FALLBACK_CALLS"
STUB
chmod +x "$tmp/bin/i3lock-fancy" "$tmp/bin/i3lock-color-fallback"
export LOCK_CALLS="$tmp/calls" FALLBACK_CALLS="$tmp/fallback-calls"
PATH="$tmp/bin:$PATH" "$LOCK" --nofork

grep -Fxq -- '-t' "$tmp/calls" || fail 'text option not passed to i3lock-fancy'
grep -Fxq -- 'Ingrese su contraseña' "$tmp/calls" || fail 'Spanish unlock prompt not passed'
grep -Fxq -- '--nofork' "$tmp/calls" || fail 'xss-lock foreground argument not preserved'
[[ ! -e "$tmp/fallback-calls" ]] || fail 'fallback ran after successful fancy lock'

FANCY_FAIL=1 PATH="$tmp/bin:$PATH" "$LOCK" --nofork
grep -Fxq -- '--color=2e3440ff' "$tmp/fallback-calls" || fail 'fallback color missing'
grep -Fxq -- '--ignore-empty-password' "$tmp/fallback-calls" || fail 'fallback does not ignore empty passwords'
grep -Fxq -- '--nofork' "$tmp/fallback-calls" || fail 'fallback did not remain foregrounded for xss-lock'

printf 'PASS: every lock path uses packaged i3lock-fancy with required dependencies\n'
