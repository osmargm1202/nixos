#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/bin"
export PATH="$tmp/bin:$PATH" PODMAN_TEST_LOG="$tmp/calls"
export WINDOWS_VM_PROFILE_FILE="$tmp/profile" WINDOWS_COMPOSE_DIR="$tmp/compose"
mkdir "$WINDOWS_COMPOSE_DIR"
touch "$WINDOWS_COMPOSE_DIR/.env"
printf '%s\n' lenovo-vfio >"$WINDOWS_VM_PROFILE_FILE"
cat >"$tmp/bin/podman" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$PODMAN_TEST_LOG"
if [[ "$*" == "container exists ${PODMAN_FAIL_CONTAINER:-}" ]]; then
  exit 125
fi
case "$*" in
  'inspect --format {{.State.Running}} lenovo-windows')
    printf '%s\n' "$VM_RUNNING" ;;
  'container exists lenovo-windows') [[ "${VM_MISSING:-false}" != true ]] ;;
  'container exists windows') [[ "${OTHER_EXISTS:-false}" == true ]] ;;
  'inspect --format {{.State.Running}} windows') printf '%s\n' "$OTHER_RUNNING" ;;
  'start lenovo-windows'|'start windows'|'image exists localhost/local/dockurr-windows-spice:latest') ;;
  *) exit 99 ;;
esac
EOF
chmod +x "$tmp/bin/podman"
cat >"$tmp/bin/podman-compose" <<'EOF'
#!/usr/bin/env bash
printf 'compose %s\n' "$*" >>"$PODMAN_TEST_LOG"
EOF
chmod +x "$tmp/bin/podman-compose"
export VM_RUNNING=true
bash -euo pipefail "$ROOT/nixos/hosts/lenovo/windows-autostart.sh"
! grep -Eq '^(start |compose )' "$PODMAN_TEST_LOG"

: >"$PODMAN_TEST_LOG"
export VM_RUNNING=false
bash -euo pipefail "$ROOT/nixos/hosts/lenovo/windows-autostart.sh"
grep -Fxq 'start lenovo-windows' "$PODMAN_TEST_LOG"

: >"$PODMAN_TEST_LOG"
export OTHER_EXISTS=true OTHER_RUNNING=true
if bash -euo pipefail "$ROOT/nixos/hosts/lenovo/windows-autostart.sh" 2>/dev/null; then exit 1; fi
! grep -q '^start ' "$PODMAN_TEST_LOG"

: >"$PODMAN_TEST_LOG"
export OTHER_RUNNING=false
bash -euo pipefail "$ROOT/nixos/hosts/lenovo/windows-autostart.sh"
grep -Fxq 'start lenovo-windows' "$PODMAN_TEST_LOG"

: >"$PODMAN_TEST_LOG"
export VM_MISSING=true
if bash -euo pipefail "$ROOT/nixos/hosts/lenovo/windows-autostart.sh" 2>/dev/null; then exit 1; fi
! grep -q '^start ' "$PODMAN_TEST_LOG"

# Non-VFIO boots use the other runtime, without changing the active VFIO VM.
: >"$PODMAN_TEST_LOG"
printf '%s\n' lenovo-render-node >"$WINDOWS_VM_PROFILE_FILE"
export VM_MISSING=false VM_RUNNING=true OTHER_EXISTS=true OTHER_RUNNING=false
if bash -euo pipefail "$ROOT/nixos/hosts/lenovo/windows-autostart.sh" 2>/dev/null; then exit 1; fi
! grep -Eq '^(start |compose )' "$PODMAN_TEST_LOG"

: >"$PODMAN_TEST_LOG"
export VM_RUNNING=false
bash -euo pipefail "$ROOT/nixos/hosts/lenovo/windows-autostart.sh"
grep -Fxq 'start windows' "$PODMAN_TEST_LOG"

: >"$PODMAN_TEST_LOG"
export OTHER_RUNNING=true
bash -euo pipefail "$ROOT/nixos/hosts/lenovo/windows-autostart.sh"
! grep -Eq '^(start |compose )' "$PODMAN_TEST_LOG"

: >"$PODMAN_TEST_LOG"
export OTHER_EXISTS=false
bash -euo pipefail "$ROOT/nixos/hosts/lenovo/windows-autostart.sh"
grep -Eq '^compose .*up -d --no-build --no-recreate windows$' "$PODMAN_TEST_LOG"
! grep -Eq '(stop |rm |exec |force-recreate|--build)' "$PODMAN_TEST_LOG"

# Runtime failures are not missing containers and must never provision/start.
for profile in lenovo-vfio lenovo-render-node; do
  printf '%s\n' "$profile" >"$WINDOWS_VM_PROFILE_FILE"
  for failed_container in windows lenovo-windows; do
    : >"$PODMAN_TEST_LOG"
    export PODMAN_FAIL_CONTAINER="$failed_container" VM_MISSING=true OTHER_EXISTS=false
    result=0
    bash -euo pipefail "$ROOT/nixos/hosts/lenovo/windows-autostart.sh" 2>"$tmp/error" || result=$?
    [[ "$result" == 125 ]]
    grep -Fq "Cannot check Windows container $failed_container" "$tmp/error"
    ! grep -Eq '^(start |compose )' "$PODMAN_TEST_LOG"
  done
done
printf '%s\n' 'PASS: profile-aware autostart preserves active VMs and shared disks; first render-node boot only reuses the local image'
