#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
export XDG_STATE_HOME="$work/state"
source "$ROOT/dotfiles/config/users/osmarg/programs/orgm/.local/bin/ssh-host-lib"

expect_hosts() {
  local expected=$1 actual
  actual=$(printf '%s\n' alpha bravo charlie alpha | ssh_order_hosts)
  [[ $actual == "$expected" ]] || {
    printf 'FAIL: host order\nExpected:\n%s\nActual:\n%s\n' "$expected" "$actual" >&2
    exit 1
  }
}

# Unused hosts retain input order, without duplicates or creating state.
expect_hosts $'alpha\nbravo\ncharlie'
[[ ! -e $XDG_STATE_HOME ]] || { echo 'FAIL: listing created state' >&2; exit 1; }
ssh_remember_host bravo
ssh_remember_host charlie
expect_hosts $'charlie\nbravo\nalpha'
# Selecting a previous host promotes it, including a manually entered SSH target.
ssh_remember_host bravo
expect_hosts $'bravo\ncharlie\nalpha'
ssh_remember_host 'osmar@nextcloud.or-gm.com'
expect_hosts $'osmar@nextcloud.or-gm.com\nbravo\ncharlie\nalpha'
# A remembered account replaces the bare host row and its previous account.
actual=$(printf '%s\n' nextcloud.or-gm.com | ssh_order_hosts)
[[ $actual == $'osmar@nextcloud.or-gm.com\nbravo\ncharlie' ]] || { echo 'FAIL: duplicate remembered host' >&2; exit 1; }
ssh_remember_host 'backup@nextcloud.or-gm.com'
actual=$(printf '%s\n' nextcloud.or-gm.com | ssh_order_hosts)
[[ $actual == $'backup@nextcloud.or-gm.com\nbravo\ncharlie' ]] || { echo 'FAIL: previous account remained in list' >&2; exit 1; }
ssh_remember_host 'osmar@nextcloud.or-gm.com'
# State persists across independent picker processes.
actual=$(bash -c 'source "$1"; printf "%s\n" alpha bravo charlie | ssh_order_hosts' _ "$ROOT/dotfiles/config/users/osmarg/programs/orgm/.local/bin/ssh-host-lib")
[[ $actual == $'osmar@nextcloud.or-gm.com\nbravo\ncharlie\nalpha' ]] || { echo 'FAIL: history did not persist' >&2; exit 1; }
ssh_forget_host 'nextcloud.or-gm.com'
ssh_forget_host bravo
expect_hosts $'charlie\nalpha\nbravo'
printf 'PASS: SSH recent-first order, promotion, custom targets, persistence and deletion\n'
