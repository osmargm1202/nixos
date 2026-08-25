#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"
HELPER="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-focus-last"
DOTFILES="$ROOT/nixos/common-dotfiles.nix"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

grep -Fq 'bindsym Mod1+Escape exec --no-startup-id i3-focus-last' "$CONFIG" ||
  fail 'Alt+Escape does not invoke the focus-history helper'
grep -Fq 'exec_always --no-startup-id i3-focus-last --watch' "$CONFIG" ||
  fail 'i3 does not start the focus-history watcher'
grep -Fq '".local/bin/i3-focus-last"' "$DOTFILES" ||
  fail 'focus-history helper is not deployed'

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
mkdir -p "$tmp_dir/bin" "$tmp_dir/runtime/i3-focus-last"

cat >"$tmp_dir/bin/i3-msg" <<'EOF'
#!/usr/bin/env bash
if [[ "$#" -eq 2 && "$1" == '-t' && "$2" == 'get_tree' ]]; then
  if [[ -n "${I3_GET_TREE_COUNTER:-}" ]]; then
    count=0
    [[ -f "$I3_GET_TREE_COUNTER" ]] && read -r count <"$I3_GET_TREE_COUNTER"
    count=$((count + 1))
    printf '%s\n' "$count" >"$I3_GET_TREE_COUNTER"
    if [[ "$count" -eq 1 ]]; then
      printf '%s\n' "$I3_TREE_INITIAL"
    elif [[ "$count" -eq 2 ]]; then
      printf '%s\n' "$I3_TREE_SECOND"
    else
      printf '%s\n' "$I3_TREE"
    fi
  else
    printf '%s\n' "$I3_TREE"
  fi
elif [[ "$#" -ge 3 && "$1" == '-m' && "$2" == '-t' && "$3" == 'subscribe' ]]; then
  printf '%s\n' "$I3_EVENT"
else
  printf '%s\n' "$*" >>"$I3_MSG_CALLS"
fi
EOF
chmod +x "$tmp_dir/bin/i3-msg"

export PATH="$tmp_dir/bin:$PATH"
export XDG_RUNTIME_DIR="$tmp_dir/runtime"
export I3_MSG_CALLS="$tmp_dir/i3-msg.calls"
printf '101 202\n' >"$XDG_RUNTIME_DIR/i3-focus-last/history"

export I3_TREE='{"id":101,"window":1}'
"$HELPER"
grep -Fxq '[con_id=101] focus' "$I3_MSG_CALLS" ||
  fail 'helper did not focus the previously focused live window'

: >"$I3_MSG_CALLS"
export I3_TREE='{"id":202,"window":1}'
"$HELPER"
[[ ! -s "$I3_MSG_CALLS" ]] ||
  fail 'helper attempted to focus a closed window'

rm "$XDG_RUNTIME_DIR/i3-focus-last/history"
export I3_TREE_INITIAL='{"id":202,"window":1,"focused":true}'
export I3_TREE_SECOND='{"id":404,"window":1,"focused":true}'
export I3_TREE='{"id":505,"window":1,"focused":true}'
export I3_EVENT=$'{"change":"focus","container":{"id":303}}\n{"change":"focus","container":{"id":304}}'
export I3_GET_TREE_COUNTER="$tmp_dir/get-tree-count"
watch_status=0
timeout 2 "$HELPER" --watch || watch_status=$?
[[ "$watch_status" -eq 124 ]] || fail 'focus-history watcher exited unexpectedly'

read -r previous_id current_id <"$XDG_RUNTIME_DIR/i3-focus-last/history"
[[ "$previous_id $current_id" == '404 505' ]] ||
  fail 'watcher did not retain the immediately previous focused window'

unset I3_GET_TREE_COUNTER I3_TREE_INITIAL I3_TREE_SECOND I3_EVENT
: >"$I3_MSG_CALLS"
export I3_TREE='{"id":404,"window":1}'
"$HELPER"
grep -Fxq '[con_id=404] focus' "$I3_MSG_CALLS" ||
  fail 'helper did not restore the immediately previous focused window'

printf '%s\n' 'PASS: Alt+Escape restores the previously focused live i3 window'
