#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/config/shared/.local/bin/hypr-rofi-ssh-host"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/home/.ssh" "$TMP/bin" "$TMP/state"
printf 'server-a ssh-ed25519 AAAA\nserver-b ssh-ed25519 BBBB\n' >"$TMP/home/.ssh/known_hosts"

cat >"$TMP/lib.sh" <<'SH'
#!/usr/bin/env bash
hypr_rofi_dmenu() {
  local prompt="$1"
  local choice
  IFS= read -r choice <"$ROFI_RESPONSES"
  tail -n +2 "$ROFI_RESPONSES" >"$ROFI_RESPONSES.tmp"
  mv "$ROFI_RESPONSES.tmp" "$ROFI_RESPONSES"
  printf '%s\n' "$prompt" >>"$ROFI_PROMPTS"
  cat >/dev/null
  printf '%s\n' "$choice"
}
HYPR_ROFI_WIDTH=600px
SH

cat >"$TMP/bin/kitty" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$KITTY_ARGS"
SH
chmod +x "$TMP/bin/kitty"

cat >"$TMP/bin/ssh-keygen" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$SSH_KEYGEN_ARGS"
exit 0
SH
chmod +x "$TMP/bin/ssh-keygen"

run_menu() {
  HOME="$TMP/home" \
  XDG_STATE_HOME="$TMP/state" \
  PATH="$TMP/bin:$PATH" \
  HYPR_ROFI_LIB="$TMP/lib.sh" \
  ROFI_RESPONSES="$TMP/responses" \
  ROFI_PROMPTS="$TMP/prompts" \
  KITTY_ARGS="$TMP/kitty.args" \
  SSH_KEYGEN_ARGS="$TMP/ssh-keygen.args" \
  "$SCRIPT"
}

printf 'server-a\n➕ Agregar usuario\ndeploy\n' >"$TMP/responses"
: >"$TMP/prompts"
run_menu

grep -Fxq 'server-a	deploy' "$TMP/state/hypr-rofi-ssh-host/users.tsv" || {
  echo "FAIL: new user was not saved for selected host" >&2
  cat "$TMP/state/hypr-rofi-ssh-host/users.tsv" >&2 || true
  exit 1
}
grep -Fxq -- '-e ssh deploy@server-a' "$TMP/kitty.args" || {
  echo "FAIL: ssh target should include selected user and host" >&2
  cat "$TMP/kitty.args" >&2
  exit 1
}

printf 'server-a\ndeploy\n' >"$TMP/responses"
: >"$TMP/prompts"
run_menu
grep -Fxq -- '-e ssh deploy@server-a' "$TMP/kitty.args" || {
  echo "FAIL: saved user should be selectable for same host" >&2
  cat "$TMP/kitty.args" >&2
  exit 1
}

if grep -Fxq 'server-b	deploy' "$TMP/state/hypr-rofi-ssh-host/users.tsv"; then
  echo "FAIL: users must be saved per known host" >&2
  cat "$TMP/state/hypr-rofi-ssh-host/users.tsv" >&2
  exit 1
fi

printf 'server-a	admin\nserver-b	root\n' >>"$TMP/state/hypr-rofi-ssh-host/users.tsv"
printf '🗑 Eliminar usuarios de known host\nserver-a\nadmin\n' >"$TMP/responses"
: >"$TMP/prompts"
run_menu
if grep -Fxq 'server-a	admin' "$TMP/state/hypr-rofi-ssh-host/users.tsv"; then
  echo "FAIL: selected saved user should be removed for host" >&2
  cat "$TMP/state/hypr-rofi-ssh-host/users.tsv" >&2
  exit 1
fi
grep -Fxq 'server-a	deploy' "$TMP/state/hypr-rofi-ssh-host/users.tsv" || {
  echo "FAIL: removing one user should keep other users for same host" >&2
  cat "$TMP/state/hypr-rofi-ssh-host/users.tsv" >&2
  exit 1
}

printf '🗑 Eliminar known host\nserver-b\nSí, eliminar server-b\n' >"$TMP/responses"
: >"$TMP/prompts"
run_menu
grep -Fxq -- '-R server-b' "$TMP/ssh-keygen.args" || {
  echo "FAIL: deleting known host should call ssh-keygen -R host" >&2
  cat "$TMP/ssh-keygen.args" >&2 || true
  exit 1
}
if grep -Fxq 'server-b	root' "$TMP/state/hypr-rofi-ssh-host/users.tsv"; then
  echo "FAIL: deleting known host should delete saved users for that host" >&2
  cat "$TMP/state/hypr-rofi-ssh-host/users.tsv" >&2
  exit 1
fi

echo "hypr rofi ssh host user menu test passed"
