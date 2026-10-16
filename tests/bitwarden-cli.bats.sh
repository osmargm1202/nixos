#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
mkdir -p "$TMP/bin" "$TMP/home"
export HOME="$TMP/home" XDG_CONFIG_HOME="$TMP/home/.config" BW_TEST_STATE="$TMP"
export PATH="$TMP/bin:$PATH"
unset BW_SESSION BW_CLIENTID BW_CLIENTSECRET BITWARDENCLI_APPDATA_DIR
# Never access real credentials/network. Implement only local status/config;
# any authentication or vault operation fails, even if accidentally introduced.
cat > "$TMP/bin/bw" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$BW_TEST_STATE/calls"
case "$*" in
  status)
    # Like the pinned CLI, even metadata queries create a fresh data.json.
    profile="${BITWARDENCLI_APPDATA_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/Bitwarden CLI}"
    mkdir -p "$profile"
    [[ -e $profile/data.json ]] || printf '{}\n' > "$profile/data.json"
    cat "$BW_TEST_STATE/status"
    ;;
  'config server') cat "$BW_TEST_STATE/server" ;;
  'config server https://vw.or-gm.com')
    [[ ! -e $BW_TEST_STATE/write-fails ]] || exit 27
    printf '%s\n' https://vw.or-gm.com > "$BW_TEST_STATE/server"
    ;;
  *) printf 'Unsafe/unexpected bw operation: %s\n' "$*" >&2; exit 99 ;;
esac
FAKE
chmod +x "$TMP/bin/bw"
wrapper="$ROOT/nixos/apps/bitwarden-cli.sh"
state() {
  rm -rf "$TMP/home/.config/Bitwarden CLI"
  printf '{"serverUrl":%s,"lastSync":null,"userEmail":null,"userId":null,"status":"%s"}\n' "$2" "$1" > "$TMP/status"
  printf '%s\n' "$3" > "$TMP/server"
  : > "$TMP/calls"
}
run() { bash "$wrapper" "$@" > "$TMP/out" 2> "$TMP/err"; }
expect_calls() { [[ $(cat "$TMP/calls") == "$1" ]] || fail "wrong calls: $(cat "$TMP/calls")"; }
state unauthenticated null ''
run init || fail 'fresh profile should initialize without logging in'
[[ $(cat "$TMP/server") == https://vw.or-gm.com ]] || fail 'fresh profile was not configured for Vaultwarden'
expect_calls $'status\nconfig server\nconfig server https://vw.or-gm.com'
printf 'PASS: fresh profile configures only the server\n'

for server in '' https://bitwarden.com https://bitwarden.com/ https://vault.bitwarden.com https://vault.bitwarden.com/; do
  state unauthenticated '"https://vault.bitwarden.com"' "$server"
  run init || fail 'unauthenticated default server should initialize'
  [[ $(cat "$TMP/server") == https://vw.or-gm.com ]] || fail 'default cloud not replaced'
done
# Pinned CLI can omit serverUrl entirely when env.getUrls().base is undefined.
state unauthenticated null https://bitwarden.com
printf '{"lastSync":null,"status":"unauthenticated"}\n' > "$TMP/status"
run init || fail 'fresh CLI status with absent serverUrl should initialize'
for status in unauthenticated locked unlocked; do
  state "$status" '"https://vw.or-gm.com"' https://vw.or-gm.com
  mkdir -p "$XDG_CONFIG_HOME/Bitwarden CLI"
  printf 'preserve custom split URLs and unsynced state\n' > "$XDG_CONFIG_HOME/Bitwarden CLI/data.json"
  run init || fail "correct $status profile rejected"
  expect_calls $'status\nconfig server'
  [[ $(cat "$TMP/server") == https://vw.or-gm.com ]] || fail 'correct endpoint changed'
done
printf 'PASS: default bootstrap and correct sessions preserve auth state\n'

for status in locked unlocked; do
  state "$status" '"https://vault.bitwarden.com"' https://vault.bitwarden.com
  if run init; then fail 'authenticated wrong server accepted'; fi
  expect_calls $'status\nconfig server'
done
state unauthenticated '"https://other.example"' https://other.example
if run init; then fail 'custom unauthenticated server overwritten'; fi
expect_calls $'status\nconfig server'
[[ $(cat "$TMP/server") == https://other.example ]] || fail 'custom server changed'
state unauthenticated '"https://vw.or-gm.com"' https://other.example
if run init; then fail 'inconsistent configured server accepted'; fi
expect_calls $'status\nconfig server'
printf 'PASS: wrong/custom endpoints refuse without mutation\n'

# Base-only CLI metadata hides split-service URL overrides. Existing logged-out
# profiles must never be reset just because their base URL looks like a default.
for location in xdg override; do
  state unauthenticated null https://bitwarden.com
  if [[ $location == override ]]; then
    export BITWARDENCLI_APPDATA_DIR="$TMP/override"
  fi
  profile="${BITWARDENCLI_APPDATA_DIR:-$XDG_CONFIG_HOME/Bitwarden CLI}"
  mkdir -p "$profile"
  printf 'existing opaque profile with split-service URLs\n' > "$profile/data.json"
  if run init; then fail 'existing default-base profile was reconfigured'; fi
  expect_calls $'status\nconfig server'
  [[ $(cat "$profile/data.json") == 'existing opaque profile with split-service URLs' ]] || fail 'existing state modified'
  unset BITWARDENCLI_APPDATA_DIR
done
printf 'PASS: existing default-base profiles cannot lose invisible service URLs\n'

for bad in '{}' 'not json' '{"serverUrl":null,"status":"unexpected"}'; do
  state unauthenticated null ''
  printf '%s\n' "$bad" > "$TMP/status"
  if run init; then fail 'invalid status did not fail closed'; fi
  expect_calls status
done
state unauthenticated null ''
touch "$TMP/write-fails"
if run init; then fail 'config failure swallowed'; fi
rm "$TMP/write-fails"
printf 'PASS: malformed status and failed configuration fail closed\n'

state unlocked '"https://vw.or-gm.com"' https://vw.or-gm.com
run status || fail 'status should be read-only'
expect_calls status
jq -e '. == {status:"unlocked",serverUrl:"https://vw.or-gm.com"}' "$TMP/out" >/dev/null || fail 'status output is not minimal metadata'
: > "$TMP/calls"
run --help || fail 'help failed'
expect_calls ''
for command in login logout list get; do
  if run "$command"; then fail 'wrapper should never perform authentication/vault operations'; fi
  expect_calls ''
done
printf 'PASS: status/help never retrieve vault contents or authenticate\n'

if [[ ${1:-} == --runtime-only ]]; then exit 0; fi
nix eval --json "path:$ROOT#nixosConfigurations" --apply '
  systems: let
    osmarg = systems.envy;
    selected = osmarg.extendModules { modules = [ ({lib, ...}: { orgm.user.programs = lib.mkForce [ "bitwarden-cli" ]; }) ]; };
    disabled = osmarg.extendModules { modules = [ ({lib, ...}: { orgm.user.programs = lib.mkForce []; }) ]; };
    packageNames = system: user: map (p: p.pname or p.name) (system.config.environment.systemPackages ++ system.config.home-manager.users.${user}.home.packages);
  in { selected = packageNames selected "osmarg"; disabled = packageNames disabled "osmarg"; jarq = packageNames systems.jarq "jarq"; }
' > "$TMP/packages.json"
jq -e '(.selected | index("bitwarden-cli") != null and index("bw-orgm") != null) and (.disabled | index("bitwarden-cli") == null and index("bw-orgm") == null) and (.jarq | index("bitwarden-cli") == null and index("bw-orgm") == null)' "$TMP/packages.json" >/dev/null || fail 'selected-only package integration failed'
printf 'PASS: user-selected Bitwarden packages isolated from disabled/Jarq users\n'
