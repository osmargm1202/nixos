#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DUNST="$ROOT/dotfiles/config/profiles/i3/.config/dunst/dunstrc"
CLIPBOARD="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-clipboard"
CLIPCAT_CONFIG="$ROOT/dotfiles/config/shared/.config/clipcat/clipcatd.toml"
CLIPCAT_MENU="$ROOT/dotfiles/config/shared/.config/clipcat/clipcat-menu.toml"
PROFILE="$ROOT/nixos/profiles/i3.nix"
CONFIG="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
MENU="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-main-menu"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

! grep -Fq 'i3-gh0stzk' "$DUNST" || fail 'Dunst keeps a removed Polybar rice dependency'
grep -Fq "exec --no-startup-id sh -lc 'dunstctl reload >/dev/null 2>&1 || exec dunst'" "$CONFIG" ||
  fail 'i3 must reload its profile-specific Dunst configuration or start Dunst'
grep -Fq 'clipcat' "$PROFILE" || fail 'Clipcat package/service missing'
grep -Fq 'systemd.user.services.i3-clipcat' "$PROFILE" || fail 'Clipcat user service missing'
grep -Fq -- '--no-daemon' "$PROFILE" || fail 'Clipcat must remain supervised by systemd'
grep -Fq -- '--grpc-socket-path %t/clipcat/grpc.sock' "$PROFILE" || fail 'Clipcat socket must use the current runtime directory'
! grep -Eq '/run/user/[0-9]+|/tmp/clipcatd-history' "$CLIPCAT_CONFIG" || fail 'Clipcat daemon keeps a fixed runtime path'
grep -Fq '@RUNTIME_SOCKET@' "$CLIPCAT_MENU" || fail 'Clipcat menu is not a runtime socket template'
grep -Fq 'XDG_RUNTIME_DIR' "$CLIPBOARD" || fail 'clipboard helper does not resolve the active runtime directory'
grep -Fq 'clipcat-menu --config' "$CLIPBOARD" || fail 'clipboard helper does not execute Clipcat'
grep -Fq 'i3-clipcat.service' "$CLIPBOARD" || fail 'clipboard helper does not start Clipcat when needed'
grep -Fq 'bindsym $mod+v exec --no-startup-id $run i3-clipboard' "$CONFIG" || fail 'Mod+V does not open Rofi clipboard'
grep -Fq 'Clipboard) exec i3-clipboard' "$MENU" || fail 'main menu does not open Rofi clipboard'
bash -n "$CLIPBOARD"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
cat >"$tmp/bin/dunstctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$DUNST_LOG"
exit "${DUNSTCTL_STATUS:-0}"
EOF
cat >"$tmp/bin/dunst" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' started >>"$DUNST_LOG"
EOF
chmod +x "$tmp/bin/dunstctl" "$tmp/bin/dunst"
DUNST_LOG="$tmp/log" DUNSTCTL_STATUS=0 PATH="$tmp/bin:$PATH" \
  sh -lc 'dunstctl reload >/dev/null 2>&1 || exec dunst'
grep -Fxq reload "$tmp/log" || fail 'Dunst startup must first reload the active Dunst instance'
[[ "$(wc -l <"$tmp/log")" == 1 ]] || fail 'Dunst must not start a second instance after a successful reload'
: >"$tmp/log"
DUNST_LOG="$tmp/log" DUNSTCTL_STATUS=1 PATH="$tmp/bin:$PATH" \
  sh -lc 'dunstctl reload >/dev/null 2>&1 || exec dunst'
grep -Fxq started "$tmp/log" || fail 'Dunst startup must launch Dunst when no active instance exists'

printf 'PASS: i3 starts or reloads Dunst and clipboard uses UID-independent Clipcat\n'
