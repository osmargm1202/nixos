#!/usr/bin/env bash
# Only local metadata and explicit server bootstrap; authentication stays in bw.
set -euo pipefail

usage() {
  printf '%s\n' \
    'Usage: bw-orgm {init|status|--help}' \
    'init: explicitly select https://vw.or-gm.com for a fresh logged-out profile.' \
    'status: show only vault lock status and server URL (no vault contents).' \
    'Use bw directly for interactive login, unlock, sync and vault commands.'
}

case "${1:---help}" in
  --help|-h) usage; exit 0 ;;
  init|status) [[ $# == 1 ]] || { usage >&2; exit 2; } ;;
  *) usage >&2; exit 2 ;;
esac

target='https://vw.or-gm.com'
# Check before bw status: even a read-only CLI query creates data.json. Never
# read this credential-containing file. CLI metadata exposes only the base URL,
# not split-service overrides that config server would otherwise erase.
profile="${BITWARDENCLI_APPDATA_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/Bitwarden CLI}"
existing_profile=false
if [[ -e $profile/data.json || -L $profile/data.json ]]; then
  existing_profile=true
fi
metadata="$(bw status)"
# Fail closed before consulting or writing configuration on unexpected CLI output.
if ! jq -e '
  type == "object" and
  (.status == "unauthenticated" or .status == "locked" or .status == "unlocked") and
  (.serverUrl == null or (.serverUrl | type == "string"))
' <<< "$metadata" >/dev/null 2>&1; then
  printf '%s\n' 'bw-orgm: could not validate local bw status; nothing changed.' >&2
  exit 1
fi

if [[ $1 == status ]]; then
  jq '{status, serverUrl}' <<< "$metadata"
  exit 0
fi

status="$(jq -r '.status' <<< "$metadata")"
status_server="$(jq -r '.serverUrl // ""' <<< "$metadata")"
configured_server="$(bw config server)"
# Only a trailing slash is equivalent; never rewrite an existing good session.
status_server="${status_server%/}"
configured_server="${configured_server%/}"
if [[ $status_server == "$target" && $configured_server == "$target" ]]; then
  printf '%s\n' 'bw-orgm: Vaultwarden already selected; existing session unchanged.'
  exit 0
fi
if [[ $status != unauthenticated ]]; then
  printf '%s\n' 'bw-orgm: authenticated profile is not consistently on Vaultwarden; nothing changed. Review manually; do not logout just to initialize.' >&2
  exit 1
fi
if [[ $existing_profile == true ]]; then
  printf '%s\n' 'bw-orgm: existing logged-out profile may contain custom service URLs; nothing changed. Review manually without deleting local state.' >&2
  exit 1
fi
for server in "$status_server" "$configured_server"; do
  case "$server" in
    ''|https://bitwarden.com|https://vault.bitwarden.com) ;;
    *)
      printf '%s\n' 'bw-orgm: existing custom/inconsistent server configuration; nothing changed. Review manually.' >&2
      exit 1
      ;;
  esac
done

bw config server "$target" >/dev/null
printf '%s\n' 'bw-orgm: Vaultwarden selected. Run bw login interactively if needed; no login performed.'
