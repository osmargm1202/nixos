#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_BIN_DIR="$(mktemp -d)"
TMP_ROOT="$(mktemp -d)"
BIN="$TMP_BIN_DIR/orgm-dot"

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

assert_file() {
	local file="$1" want="$2" name="$3"
	grep -qF -- "$want" "$file" || {
		echo "--- $file ---" >&2
		cat "$file" >&2 2>/dev/null || true
		fail "$name expected: $want"
	}
}

run_dot() {
	local repo="$1" home="$2"
	shift 2
	HOME="$home" ORGM_DOT_CONFIG="$repo/config/dotfiles.json" "$BIN" "$@"
}

make_fixture() {
	local name="$1"
	local repo="$TMP_ROOT/$name/repo"
	local home="$TMP_ROOT/$name/home"
	local default_host
	default_host="$(hostname)"
	mkdir -p "$repo/config/shared/.config/fish" "$repo/config/hosts/lenovo/.config/fish" "$repo/config/hosts/$default_host/.config/fish" "$home/.config/fish" "$repo/config/shared/.config/app" "$home/.config/app"
	printf 'shared fish\n' >"$repo/config/shared/.config/fish/config.fish"
	printf 'host age\n' >"$repo/config/hosts/lenovo/.config/fish/age-host.fish"
	printf 'default host age\n' >"$repo/config/hosts/$default_host/.config/fish/age-host.fish"
	printf 'tmux\n' >"$repo/config/shared/.tmux.conf"
	printf 'same\n' >"$repo/config/shared/.config/app/same.txt"
	printf 'same\n' >"$home/.config/app/same.txt"

	local hosts_json
	if [ "$default_host" = "lenovo" ]; then
		hosts_json='"lenovo": { "paths": [".config/fish/age-host.fish"] }'
	else
		hosts_json='"lenovo": { "paths": [".config/fish/age-host.fish"] }, "'"$default_host"'": { "paths": [".config/fish/age-host.fish"] }'
	fi

	cat >"$repo/config/dotfiles.json" <<JSON
{
  "settings": {
    "repo": "$repo",
    "destination": "~",
    "source_shared": "config/shared",
    "source_hosts": "config/hosts",
    "state_dir": "~/.local/state/orgm-dot",
    "poll_seconds": 5
  },
  "shared": { "paths": [".config/fish", ".config/app", ".tmux.conf"] },
  "hosts": { $hosts_json },
  "local_only": { "paths": [".config/fish/fish_variables"] },
  "diff": { "scan_roots": [] }
}
JSON
	printf '%s\t%s\n' "$repo" "$home"
}

trap 'rm -rf "$TMP_BIN_DIR" "$TMP_ROOT"' EXIT

go build -o "$BIN" "$REPO_DIR/cmd/orgm-dot"

version="$($BIN version)"
[ "$version" = "orgm-dot dev" ] || fail "unexpected version output: $version"

fixture="$(make_fixture status)"
repo="${fixture%%$'\t'*}"
home="${fixture##*$'\t'}"
status="$(run_dot "$repo" "$home" status --host lenovo)"
case "$status" in *"repo:        $repo"*) ;; *)
	echo "$status" >&2
	fail "status missing repo"
	;;
esac
case "$status" in *"config:      $repo/config/dotfiles.json"*) ;; *)
	echo "$status" >&2
	fail "status missing config"
	;;
esac
case "$status" in *"destination: $home"*) ;; *)
	echo "$status" >&2
	fail "status missing destination"
	;;
esac
case "$status" in *"shared src:  $repo/config/shared"*) ;; *)
	echo "$status" >&2
	fail "status missing shared source"
	;;
esac
case "$status" in *"host src:    $repo/config/hosts/lenovo"*) ;; *)
	echo "$status" >&2
	fail "status missing host source"
	;;
esac

default_status="$(run_dot "$repo" "$home" status)"
case "$default_status" in *"host:        $(hostname)"*) ;; *)
	echo "$default_status" >&2
	fail "status without --host should default to hostname"
	;;
esac
case "$default_status" in *"host src:    $repo/config/hosts/$(hostname)"*) ;; *)
	echo "$default_status" >&2
	fail "status without --host should use hostname source"
	;;
esac

fixture="$(make_fixture diff)"
repo="${fixture%%$'\t'*}"
home="${fixture##*$'\t'}"
printf 'old fish\n' >"$home/.config/fish/config.fish"
printf 'local\n' >"$home/.config/fish/fish_variables"
printf 'remove me\n' >"$home/.config/fish/removed.fish"
diff_out="$TMP_ROOT/diff.out"
run_dot "$repo" "$home" diff --host lenovo --porcelain >"$diff_out"
assert_file "$diff_out" $'M\t'"$home/.config/fish/config.fish" "diff reports modified shared file"
assert_file "$diff_out" $'A\t'"$home/.config/fish/age-host.fish" "diff reports missing host file"
assert_file "$diff_out" $'A\t'"$home/.tmux.conf" "diff reports missing file"
assert_file "$diff_out" $'R\t'"$home/.config/fish/removed.fish" "diff reports removed file"
if grep -q 'fish_variables' "$diff_out"; then
	cat "$diff_out" >&2
	fail "diff should skip local_only"
fi
human_diff_out="$TMP_ROOT/diff-human.out"
run_dot "$repo" "$home" diff --host lenovo >"$human_diff_out"
assert_file "$human_diff_out" "orgm-dot diff --host lenovo" "human diff prints orgm-dot command"
if grep -q 'dot\.sh' "$human_diff_out"; then
	cat "$human_diff_out" >&2
	fail "human diff must not mention dot.sh"
fi

fixture="$(make_fixture syncdry)"
repo="${fixture%%$'\t'*}"
home="${fixture##*$'\t'}"
printf 'old fish\n' >"$home/.config/fish/config.fish"
dry_out="$TMP_ROOT/dry.out"
run_dot "$repo" "$home" sync --host lenovo --dry-run >"$dry_out"
assert_file "$dry_out" "M  $home/.config/fish/config.fish" "dry-run reports modify"
assert_file "$dry_out" "A  $home/.config/fish/age-host.fish" "dry-run reports add"
[ ! -e "$home/.config/fish/age-host.fish" ] || fail "dry-run should not copy files"

fixture="$(make_fixture sync)"
repo="${fixture%%$'\t'*}"
home="${fixture##*$'\t'}"
printf 'secret\n' >"$home/.config/fish/fish_variables"
printf 'remove me\n' >"$home/.config/fish/removed.fish"
mkdir -p "$home/.local/state/orgm-dot"
printf 'stale lock from orgm-dot\n' >"$home/.local/state/orgm-dot/sync.lock"
run_dot "$repo" "$home" sync --host lenovo
assert_file "$home/.config/fish/config.fish" "shared fish" "sync copies shared file"
assert_file "$home/.config/fish/age-host.fish" "host age" "sync copies host file"
assert_file "$home/.config/fish/fish_variables" "secret" "sync preserves local_only"
[ ! -e "$home/.config/fish/removed.fish" ] || fail "sync deletes stale managed file"

fixture="$(make_fixture addremove)"
repo="${fixture%%$'\t'*}"
home="${fixture##*$'\t'}"
mkdir -p "$home/.config/newapp"
printf 'new\n' >"$home/.config/newapp/config"
run_dot "$repo" "$home" add "$home/.config/newapp" --host lenovo >"$TMP_ROOT/add.out"
assert_file "$repo/config/hosts/lenovo/.config/newapp/config" "new" "add copies local dir to host source"
assert_file "$repo/config/dotfiles.json" '".config/newapp"' "add updates manifest"
run_dot "$repo" "$home" remove "$home/.config/newapp" --host lenovo >"$TMP_ROOT/remove.out"
[ ! -e "$repo/config/hosts/lenovo/.config/newapp" ] || fail "remove deletes source path"
assert_file "$repo/config/dotfiles.json" '"local_only"' "remove preserves local_only block"
assert_file "$repo/config/dotfiles.json" '".config/newapp"' "remove adds local_only path"
[ -e "$home/.config/newapp/config" ] || fail "remove preserves local destination"

install_home="$TMP_ROOT/install-home"
mkdir -p "$install_home"
HOME="$install_home" "$BIN" install >"$TMP_ROOT/install.out"
[ -L "$install_home/.local/bin/dot" ] || fail "install creates dot symlink"
[ ! -e "$install_home/.local/bin/dot.sh" ] || fail "install must not create dot.sh compatibility symlink"
assert_file "$TMP_ROOT/install.out" "launch example: orgm-dot daemon --host orgm" "install prints launch example"

echo "orgm-dot smoke tests passed"
