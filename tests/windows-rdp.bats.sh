#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPTS=(
  "$REPO_DIR/dotfiles/config/shared/.local/bin/windows-rdp"
)

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

make_stub() {
	local dir="$1" name="$2" body="$3"
	printf '#!/bin/bash\n%s\n' "$body" >"$dir/$name"
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
	local password_file="$tmp/osmar-password"
	if [[ $# -eq 4 ]]; then
		printf '%s' "$4" | \
			PATH="$tmp" \
			CALLS="$tmp/calls" \
			HOME="$tmp/home" \
			XDG_CURRENT_DESKTOP= \
			WINDOWS_VM_PROFILE_FILE="$tmp/profile" \
			WINDOWS_RDP_OSMAR_WINDOWS_USER=osmarg \
			WINDOWS_RDP_OSMAR_WINDOWS_PASSWORD_FILE="$password_file" \
			SWAYSOCK= \
			WAYLAND_DISPLAY= \
			DISPLAY="${WINDOWS_RDP_TEST_DISPLAY:-}" \
			/bin/bash "$script" "$command" >"$tmp/out" 2>"$tmp/err"
	else
		PATH="$tmp" \
			CALLS="$tmp/calls" \
			HOME="$tmp/home" \
			XDG_CURRENT_DESKTOP= \
			WINDOWS_VM_PROFILE_FILE="$tmp/profile" \
			WINDOWS_RDP_OSMAR_WINDOWS_USER=osmarg \
			WINDOWS_RDP_OSMAR_WINDOWS_PASSWORD_FILE="$password_file" \
			SWAYSOCK= \
			WAYLAND_DISPLAY= \
			DISPLAY="${WINDOWS_RDP_TEST_DISPLAY:-}" \
			/bin/bash "$script" "$command" >"$tmp/out" 2>"$tmp/err"
	fi
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
	printf '%s\n' osmar-password >"$tmp/osmar-password"
	make_default_stubs "$tmp"
	printf '%s\n' render-node >"$tmp/profile"
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
    run_script "$script" run "$tmp"
    assert_calls_contains "$tmp" "prime-run xfreerdp3" "uses prime-run with host xfreerdp3"
  ' bash "$script"

	with_tmp bash -c '
    script="$1"; tmp="$2"
    make_stub "$tmp" xfreerdp "echo xfreerdp \"\$@\" >>\"\$CALLS\"; exit 0"
    make_stub "$tmp" distrobox-enter "echo distrobox-enter \"\$@\" >>\"\$CALLS\""
    run_script "$script" run "$tmp"
    assert_calls_contains "$tmp" "xfreerdp /v:localhost:3389" "uses host xfreerdp"
  ' bash "$script"
	with_tmp bash -c '
    script="$1"; tmp="$2"
    make_stub "$tmp" distrobox-enter "echo distrobox-enter \"\$@\" >>\"\$CALLS\"; exit 0"
    if run_script "$script" run "$tmp"; then
      dump_case "$tmp"
      fail "connection without a FreeRDP client should fail"
    fi
    grep -Fq "Error: FreeRDP client not found." "$tmp/err" ||
      fail "missing FreeRDP client is reported"
  ' bash "$script"
}

test_saved_password_uses_nla() {
	local script="$1"
	with_tmp bash -c '
    script="$1"; tmp="$2"
    make_stub "$tmp" xfreerdp3 "echo xfreerdp3 \"\$@\" >>\"\$CALLS\"; exit 0"
    run_script "$script" run "$tmp"
    assert_calls_contains "$tmp" "xfreerdp3 .* /u:osmarg /p:[^[:space:]]+ .* /sec:nla( |$)" "saved password uses NLA"
    assert_calls_not_contains "$tmp" "/sec:nla:off" "saved password does not disable NLA"
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
    make_stub "$tmp" docker "if [[ \"\$1\" == inspect ]]; then echo true; else echo docker \"\$@\" >>\"\$CALLS\"; fi"
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
    assert_stdout_empty "$tmp" "a disconnected client does not trigger helper output"
  ' bash "$script"
}

test_remote_selector_rdp() {
	local script="$1"
	with_tmp bash -c '
    script="$1"; tmp="$2"
    make_stub "$tmp" tailscale "echo tailscale \"\$@\" >>\"\$CALLS\"; printf \"%s\\n\" \"\$TAILSCALE_STATUS\""
    make_stub "$tmp" jq "printf \"%s\\n\" \"\$JQ_OUTPUT\""
    make_stub "$tmp" xfreerdp3 "echo xfreerdp3 \"\$@\" >>\"\$CALLS\""
    export TAILSCALE_STATUS="{}"
    export JQ_OUTPUT=$'"'"'alpha-linux\t100.64.0.3\tonline\nbeta-windows\t100.64.0.4\toffline\nhp-windows\tsin-ip\toffline\nlenovo\t100.64.0.7\toffline\norgm\t100.64.0.6\tonline\norgm-windows\t100.64.0.5\tonline'"'"'
    selection_input="$(printf "%s\n" invalid 9 5)"
    run_script "$script" connect "$tmp" "$selection_input"
    assert_stdout_empty "$tmp" "numeric selector does not add connection chatter"
    assert_calls_contains "$tmp" "tailscale status --json" "selector queries Tailscale once"
    assert_calls_contains "$tmp" "xfreerdp3 /v:100.64.0.6:3389 .* /p:osmar-password" "orgm uses osmar-windows credentials"
    assert_calls_not_contains "$tmp" "docker" "remote RDP never touches containers"
    grep -Fq "1) Local | osmar-windows | RDP" "$tmp/err" ||
      fail "local Windows is selector row zero"
    grep -Fq "Tailscale | beta-windows | RDP | offline" "$tmp/err" ||
      fail "offline Windows peer remains selectable"
    grep -Fq "Tailscale | orgm-windows | RDP | online" "$tmp/err" ||
      fail "online Windows peer remains selectable"
    grep -Fq "Tailscale | orgm | RDP | online" "$tmp/err" ||
      fail "orgm offers RDP to its Windows VM"
    grep -Fq "Tailscale | lenovo | RDP | offline" "$tmp/err" ||
      fail "lenovo offers RDP to its Windows VM"
    grep -Fq "Tailscale | orgm | Moonlight | online" "$tmp/err" ||
      fail "orgm offers Moonlight"
    grep -Fq "Tailscale | lenovo | Moonlight | offline" "$tmp/err" ||
      fail "lenovo offers Moonlight"
    ! grep -Fq "alpha-linux" "$tmp/err" ||
      fail "unrelated Tailscale peers are omitted"
    grep -Fq "hp-windows" "$tmp/err" && grep -Fq "no usable Tailscale IP" "$tmp/err" || {
      dump_case "$tmp"
      fail "Windows peers without an IP are reported and skipped"
    }
    grep -Fq "Selecciona un número válido." "$tmp/err" ||
      fail "numeric selector rejects invalid and out-of-range input"
    : >"$tmp/calls"
    printf "%s\n" lenovo-password >"$tmp/lenovo-password"
    export WINDOWS_RDP_LENOVO_WINDOWS_USER=osmarg
    export WINDOWS_RDP_LENOVO_WINDOWS_PASSWORD_FILE="$tmp/lenovo-password"
    run_script "$script" connect "$tmp" 4
    assert_calls_contains "$tmp" "xfreerdp3 /v:100.64.0.7:3389 .* /p:lenovo-password" "lenovo uses lenovo-windows credentials"
  ' bash "$script"
}

test_graphical_selector_and_moonlight() {
	local script="$1"
	with_tmp bash -c '
    script="$1"; tmp="$2"
    make_stub "$tmp" tailscale "printf \"%s\\n\" \"\$TAILSCALE_STATUS\""
    make_stub "$tmp" jq "printf \"%s\\n\" \"\$JQ_OUTPUT\""
    make_stub "$tmp" rofi "echo rofi \"\$@\" >>\"\$CALLS\"; printf \"%s\\n\" \"\$ROFI_INDEX\""
    make_stub "$tmp" xfreerdp3 "echo xfreerdp3 \"\$@\" >>\"\$CALLS\""
    export TAILSCALE_STATUS="{}"
    printf "%s\n" tony-password >"$tmp/tony-password"
    export WINDOWS_RDP_TONY_WINDOWS_USER=osmarg
    export WINDOWS_RDP_TONY_WINDOWS_PASSWORD_FILE="$tmp/tony-password"
    export JQ_OUTPUT=$'"'"'tony-windows\t100.64.0.4\toffline\norgm\t100.64.0.6\tonline'"'"'
    export ROFI_INDEX=2 WINDOWS_RDP_TEST_DISPLAY=:1
    run_script "$script" connect "$tmp"
    assert_calls_contains "$tmp" "rofi -dmenu -i -no-custom -only-match -format i -p Conectar remoto" "desktop selector uses Rofi indexes"
    assert_calls_contains "$tmp" "xfreerdp3 /v:100.64.0.4:3389" "Rofi index dispatches remote RDP"
    assert_calls_not_contains "$tmp" "docker" "graphical remote RDP leaves the local VM untouched"
  ' bash "$script"

	with_tmp bash -c '
    script="$1"; tmp="$2"
    make_stub "$tmp" tailscale "printf \"%s\\n\" \"\$TAILSCALE_STATUS\""
    make_stub "$tmp" jq "printf \"%s\\n\" \"\$JQ_OUTPUT\""
    make_stub "$tmp" rofi "printf \"%s\\n\" 3"
    make_stub "$tmp" flatpak "echo flatpak \"\$@\" >>\"\$CALLS\"; if [[ \"\$1\" == info ]]; then exit 0; fi; if [[ \"\$3\" == list ]]; then [[ \"\${FLATPAK_LIST_MODE:-desktop}\" == desktop ]] && { echo Desktop; exit 0; }; exit 1; fi; exit 0"
    export TAILSCALE_STATUS="{}"
    export JQ_OUTPUT=$'"'"'orgm\t100.64.0.6\tonline'"'"'
    export WINDOWS_RDP_TEST_DISPLAY=:1
    run_script "$script" connect "$tmp"
    assert_calls_contains "$tmp" "flatpak run com.moonlight_stream.Moonlight stream 100.64.0.6 Desktop" "Moonlight streams the exact Desktop app"
    : >"$tmp/calls"
    export FLATPAK_LIST_MODE=failed
    run_script "$script" connect "$tmp"
    assert_calls_not_contains "$tmp" "stream 100.64.0.6 Desktop" "Moonlight does not stream an unavailable Desktop app"
    assert_calls_contains "$tmp" "flatpak run com.moonlight_stream.Moonlight$" "Moonlight opens its GUI when listing fails"
  ' bash "$script"
}

test_gum_cancellation() {
	local script="$1"
	with_tmp bash -c '
    script="$1"; tmp="$2"
    make_stub "$tmp" gum "echo gum \"\$@\" >>\"\$CALLS\"; exit 1"
    PATH="$tmp" \
      CALLS="$tmp/calls" \
      HOME="$tmp/home" \
      WINDOWS_VM_PROFILE_FILE="$tmp/profile" \
      WINDOWS_RDP_OSMAR_WINDOWS_USER=osmarg \
      WINDOWS_RDP_OSMAR_WINDOWS_PASSWORD_FILE="$tmp/osmar-password" \
      /run/current-system/sw/bin/script -qec "/bin/bash \"$script\" connect" /dev/null >/dev/null
    grep -Fq -- "--cursor.foreground" "$tmp/calls" && grep -Fq -- "--selected.foreground" "$tmp/calls" ||
      fail "terminal selector configures Gum"
    assert_calls_not_contains "$tmp" "docker|freerdp" "Gum cancellation does not connect"
  ' bash "$script"
}

test_selector_local_starts_container() {
	local script="$1"
	with_tmp bash -c '
    script="$1"; tmp="$2"
    make_stub "$tmp" nc "if [[ \"\$(<\"\$CALLS\")\" == *nc-seen* ]]; then exit 0; fi; echo nc-seen >>\"\$CALLS\"; exit 1"
    make_stub "$tmp" docker "if [[ \"\$1\" == inspect ]]; then echo true; else echo docker \"\$@\" >>\"\$CALLS\"; fi"
    make_stub "$tmp" xfreerdp3 "echo xfreerdp3 \"\$@\" >>\"\$CALLS\"; exit 0"
    run_script "$script" connect "$tmp" 1
    assert_calls_contains "$tmp" "docker start windows" "selector local row starts the local container"
    assert_calls_contains "$tmp" "xfreerdp3 /v:localhost:3389" "selector local row connects to localhost"
  ' bash "$script"
}

test_custom_rdp_connection() {
	local script="$1"
	with_tmp bash -c '
    script="$1"; tmp="$2"
    make_stub "$tmp" xfreerdp3 "echo xfreerdp3 \"\$@\" >>\"\$CALLS\"; exit 0"
    custom_input="$(printf "%s\n" 2 192.0.2.44 custom-user custom-password)"
    run_script "$script" connect "$tmp" "$custom_input"
    grep -Fq "2) Custom | RDP" "$tmp/err" ||
      fail "custom RDP is selector row one"
    assert_calls_contains "$tmp" "xfreerdp3 /v:192.0.2.44:3389 /u:custom-user /p:custom-password" "custom RDP uses supplied connection details"
    assert_calls_not_contains "$tmp" "docker" "custom RDP never touches containers"
  ' bash "$script"

	with_tmp bash -c '
    script="$1"; tmp="$2"
    make_stub "$tmp" xfreerdp3 "echo xfreerdp3 \"\$@\" >>\"\$CALLS\"; exit 0"
    make_stub "$tmp" rofi "count=0; [[ -r \"\$ROFI_STATE\" ]] && read -r count <\"\$ROFI_STATE\"; count=\$((count + 1)); printf \"%s\\n\" \"\$count\" >\"\$ROFI_STATE\"; echo rofi \"\$@\" >>\"\$CALLS\"; case \"\$count\" in 1) echo 1 ;; 2) echo 192.0.2.45 ;; 3) echo rofi-user ;; 4) echo rofi-password ;; esac"
    export ROFI_STATE="$tmp/rofi-state" WINDOWS_RDP_TEST_DISPLAY=:1
    run_script "$script" connect "$tmp"
    assert_calls_contains "$tmp" "xfreerdp3 /v:192.0.2.45:3389 /u:rofi-user /p:rofi-password" "Rofi custom RDP uses supplied connection details"
    assert_calls_contains "$tmp" "rofi -dmenu -password -p Clave RDP" "Rofi masks the custom password prompt"
  ' bash "$script"
}

for script in "${SCRIPTS[@]}"; do
	test_command_selection "$script"
	test_direct_connection_is_silent_and_immediate "$script"
	test_saved_password_uses_nla "$script"
	test_container_start_waits_before_connecting "$script"
	test_direct_connection_reports_failure_without_retry_waits "$script"
	test_remote_selector_rdp "$script"
	test_graphical_selector_and_moonlight "$script"
	test_gum_cancellation "$script"
	test_selector_local_starts_container "$script"
	test_custom_rdp_connection "$script"
done

echo "windows-rdp tests passed"
