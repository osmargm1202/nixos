#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

launcher_drv="$({
  cd "$REPO_DIR"
  nix eval --json --impure --expr '
    let
      flake = builtins.getFlake (toString ./.);
      command = builtins.head flake.nixosConfigurations.lenovo-hyprland.config.home-manager.users.osmarg.systemd.user.services.deskflow.Service.ExecStart;
    in
    builtins.getContext command
  '
} | jq -er 'keys[0]')"
launcher="$(nix-store --realise "$launcher_drv")"

[[ -x "$launcher" ]] || fail "realized Deskflow launcher must be executable"

runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
[[ -S "$runtime_dir/bus" ]] \
  || fail "test requires the current systemd user bus at $runtime_dir/bus"

stub_dir="$(mktemp -d)"
capture_file="$stub_dir/flatpak-environment"
trap 'rm -rf "$stub_dir"' EXIT

cat >"$stub_dir/systemctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

[[ "${1:-}" == "--user" && "${2:-}" == "show-environment" ]] || exit 64
[[ -n "${XDG_RUNTIME_DIR:-}" ]] || exit 72

printf 'WAYLAND_DISPLAY=wayland-test\n'
printf 'DISPLAY=:99\n'
printf 'XDG_RUNTIME_DIR=%s\n' "$DESKFLOW_TEST_RUNTIME"
EOF

cat >"$stub_dir/flatpak" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

[[ "$*" == "run org.deskflow.deskflow" ]] || exit 65
{
  printf 'WAYLAND_DISPLAY=%s\n' "${WAYLAND_DISPLAY:-}"
  printf 'DISPLAY=%s\n' "${DISPLAY:-}"
  printf 'XDG_RUNTIME_DIR=%s\n' "${XDG_RUNTIME_DIR:-}"
} >"$DESKFLOW_CAPTURE"
EOF

cat >"$stub_dir/sleep" <<'EOF'
#!/usr/bin/env bash
exit 73
EOF

chmod +x "$stub_dir/systemctl" "$stub_dir/flatpak" "$stub_dir/sleep"
export DESKFLOW_TEST_RUNTIME="$runtime_dir"
export DESKFLOW_CAPTURE="$capture_file"

set +e
PATH="$stub_dir:$PATH" \
  XDG_RUNTIME_DIR="$runtime_dir" \
  WAYLAND_DISPLAY="wayland-original" \
  DISPLAY=":0" \
  "$launcher"
status=$?
set -e

[[ "$status" -eq 0 ]] \
  || fail "launcher did not reach Flatpak after querying the user manager (status $status)"
[[ -f "$capture_file" ]] || fail "Flatpak stub was not called"
grep -Fxq 'WAYLAND_DISPLAY=wayland-test' "$capture_file" \
  || fail "Wayland display was not exported"
grep -Fxq 'DISPLAY=:99' "$capture_file" \
  || fail "X11 display was not exported"
grep -Fxq "XDG_RUNTIME_DIR=$runtime_dir" "$capture_file" \
  || fail "runtime directory was not exported"

echo "PASS: Deskflow launcher preserves bus access and exports graphics environment"
