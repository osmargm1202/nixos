#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPTS=(
	"$REPO_DIR/config/shared/.local/bin/windows-rdp"
	"$REPO_DIR/scripts/windows-rdp.sh"
)

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

make_stub() {
	local dir="$1" name="$2" body="$3"
	printf '#!/usr/bin/bash\n%s\n' "$body" >"$dir/$name"
	chmod +x "$dir/$name"
}

make_default_stubs() {
	local tmp="$1"
	make_stub "$tmp" nc 'exit 0'
	make_stub "$tmp" docker 'echo docker "$@" >>"$CALLS"; exit 0'
	make_stub "$tmp" podman 'exit 127'
	make_stub "$tmp" sleep 'echo sleep "$@" >>"$CALLS"; exit 0'
	make_stub "$tmp" seq 'if [[ "$1" == "1" && "$2" == "60" ]]; then echo 1; else /usr/bin/seq "$@"; fi'
}

run_script() {
	local script="$1" command="$2" tmp="$3"
	PATH="$tmp" \
		CALLS="$tmp/calls" \
		HOME="$tmp/home" \
		XDG_CURRENT_DESKTOP= \
		SWAYSOCK= \
		WAYLAND_DISPLAY= \
		DISPLAY= \
		/usr/bin/bash "$script" "$command" >"$tmp/out" 2>"$tmp/err"
}

assert_calls_contains() {
	local tmp="$1" pattern="$2" name="$3"
	grep -qE "$pattern" "$tmp/calls" 2>/dev/null || {
		dump_case "$tmp"
		fail "$name expected calls to match: $pattern"
	}
}

assert_calls_not_contains() {
	local tmp="$1" pattern="$2" name="$3"
	if grep -qE "$pattern" "$tmp/calls" 2>/dev/null; then
		dump_case "$tmp"
		fail "$name expected calls not to match: $pattern"
	fi
}

assert_stdout_contains() {
	local tmp="$1" pattern="$2" name="$3"
	grep -qE "$pattern" "$tmp/out" || {
		dump_case "$tmp"
		fail "$name expected stdout to match: $pattern"
	}
}

assert_stdout_not_contains() {
	local tmp="$1" pattern="$2" name="$3"
	if grep -qE "$pattern" "$tmp/out"; then
		dump_case "$tmp"
		fail "$name expected stdout not to match: $pattern"
	fi
}

assert_stdout_empty() {
	local tmp="$1" name="$2"
	if [[ -s "$tmp/out" ]]; then
		dump_case "$tmp"
		fail "$name expected stdout to be empty"
	fi
}

dump_case() {
	local tmp="$1"
	echo "--- calls ---" >&2
	cat "$tmp/calls" >&2 2>/dev/null || true
	echo "--- stdout ---" >&2
	cat "$tmp/out" >&2 2>/dev/null || true
	echo "--- stderr ---" >&2
	cat "$tmp/err" >&2 2>/dev/null || true
}

with_tmp() {
	local tmp rc
	tmp="$(mktemp -d)"
	: >"$tmp/calls"
	mkdir -p "$tmp/home"
	make_default_stubs "$tmp"
	"$@" "$tmp"
	rc=$?
	rm -rf "$tmp"
	return "$rc"
}

export -f fail make_stub make_default_stubs run_script \
	assert_calls_contains assert_calls_not_contains \
	assert_stdout_contains assert_stdout_not_contains assert_stdout_empty \
	dump_case

test_command_selection() {
	local script="$1"

	with_tmp bash -c '
    script="$1"; tmp="$2"
    make_stub "$tmp" xfreerdp3 "echo xfreerdp3 \"\$@\" >>\"\$CALLS\"; exit 0"
    make_stub "$tmp" prime-run "echo prime-run \"\$@\" >>\"\$CALLS\"; exec \"\$@\""
    make_stub "$tmp" distrobox-enter "echo distrobox-enter \"\$@\" >>\"\$CALLS\""
    run_script "$script" connect "$tmp"
    assert_calls_contains "$tmp" "prime-run xfreerdp3" "uses prime-run with host xfreerdp3"
  ' bash "$script"

	with_tmp bash -c '
    script="$1"; tmp="$2"
    make_stub "$tmp" xfreerdp "echo xfreerdp \"\$@\" >>\"\$CALLS\"; exit 0"
    make_stub "$tmp" distrobox-enter "echo distrobox-enter \"\$@\" >>\"\$CALLS\""
    run_script "$script" connect "$tmp"
    assert_calls_contains "$tmp" "xfreerdp /v:localhost:3389" "uses host xfreerdp"
  ' bash "$script"

	with_tmp bash -c '
    script="$1"; tmp="$2"
    make_stub "$tmp" distrobox-enter "echo distrobox-enter \"\$@\" >>\"\$CALLS\"; exit 0"
    run_script "$script" connect "$tmp"
    assert_calls_contains "$tmp" "distrobox-enter arch -- xfreerdp3" "falls back to distrobox"
  ' bash "$script"
}

test_direct_connection_is_silent_and_immediate() {
	local script="$1"
	with_tmp bash -c '
    script="$1"; tmp="$2"
    make_stub "$tmp" xfreerdp3 "echo xfreerdp3 \"\$@\" >>\"\$CALLS\"; exit 0"
    run_script "$script" run "$tmp"
    assert_calls_contains "$tmp" "xfreerdp3 /v:localhost:3389" "direct connection uses RDP"
    assert_calls_not_contains "$tmp" "docker start" "direct connection does not start container"
    assert_calls_not_contains "$tmp" "sleep" "direct connection does not wait"
    assert_stdout_empty "$tmp" "direct connection is silent"
  ' bash "$script"
}

test_container_start_waits_before_connecting() {
	local script="$1"
	with_tmp bash -c '
    script="$1"; tmp="$2"
    make_stub "$tmp" nc "if [[ \"\$(<\"\$CALLS\")\" == *nc-seen* ]]; then exit 0; fi; echo nc-seen >>\"\$CALLS\"; exit 1"
    make_stub "$tmp" xfreerdp3 "echo xfreerdp3 \"\$@\" >>\"\$CALLS\"; exit 0"
    run_script "$script" run "$tmp"
    assert_calls_contains "$tmp" "docker start windows" "container path starts docker"
    assert_calls_contains "$tmp" "sleep 10" "container path waits boot delay"
    assert_stdout_contains "$tmp" "Windows iniciando|Starting container|RDP is not available" "container path announces startup"
  ' bash "$script"
}

test_direct_connection_reports_failure_without_retry_waits() {
	local script="$1"
	with_tmp bash -c '
    script="$1"; tmp="$2"
    make_stub "$tmp" xfreerdp3 "echo xfreerdp3 \"\$@\" >>\"\$CALLS\"; exit 9"
    if run_script "$script" run "$tmp"; then
      dump_case "$tmp"
      fail "direct failure should return non-zero"
    fi
    assert_calls_not_contains "$tmp" "docker start" "direct failure does not start container"
    assert_calls_not_contains "$tmp" "sleep" "direct failure does not retry with waits"
    assert_stdout_not_contains "$tmp" "RDP connection attempt|Retrying" "direct failure suppresses retry chatter"
    assert_stdout_contains "$tmp" "Error: RDP connection failed \(exit code 9\)" "direct failure reports error"
  ' bash "$script"
}

for script in "${SCRIPTS[@]}"; do
	test_command_selection "$script"
	test_direct_connection_is_silent_and_immediate "$script"
	test_container_start_waits_before_connecting "$script"
	test_direct_connection_reports_failure_without_retry_waits "$script"
done

echo "windows-rdp tests passed"
