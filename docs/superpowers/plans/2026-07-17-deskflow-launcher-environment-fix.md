# Deskflow Launcher Environment Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the shared Deskflow user service start the stable Flatpak reliably on both `lenovo` and `orgm` instead of restarting every 40 seconds.

**Architecture:** Keep the existing generated Bash launcher and systemd user unit. Capture the systemd user-manager environment before resetting parsed variables, then validate and export the recovered display/runtime values before replacing the launcher with the Deskflow Flatpak process.

**Tech Stack:** NixOS modules, Home Manager systemd user services, Bash, Flatpak, shell regression tests.

## Global Constraints

- Modify only the shared launcher in `nixos/deskflow.nix` plus focused regression coverage.
- Apply identical behavior to the `lenovo` and `orgm` hosts.
- Preserve Flatpak ID `org.deskflow.deskflow`, 30 retries, one-second waits, `Restart=on-failure`, and current host selection.
- Keep Deskflow on stable version 1.26.0; do not select beta or continuous builds.
- Preserve unrelated working-tree changes.
- Use `orgm-diff` before `orgm-sync`; do not substitute a different system-application command if either tool is unavailable.

---

### Task 1: Reproduce and fix launcher environment propagation

**Files:**

- Create: `tests/deskflow-launcher.bats.sh`
- Modify: `nixos/deskflow.nix:5-40`
- Test: `tests/deskflow-launcher.bats.sh`

**Interfaces:**

- Consumes: `nixosConfigurations.lenovo-hyprland.config.home-manager.users.osmarg.systemd.user.services.deskflow.Service.ExecStart`, whose first list item is the generated launcher path.
- Produces: a launcher that queries the user manager while inherited `XDG_RUNTIME_DIR` is intact and exports `WAYLAND_DISPLAY`, `DISPLAY`, and `XDG_RUNTIME_DIR` to `flatpak`.

- [ ] **Step 1: Write the failing executable regression test**

Create `tests/deskflow-launcher.bats.sh`:

```bash
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
```

- [ ] **Step 2: Run the test and verify the current launcher fails for the confirmed reason**

Run:

```bash
chmod +x tests/deskflow-launcher.bats.sh
./tests/deskflow-launcher.bats.sh
```

Expected: exit non-zero with:

```text
FAIL: launcher did not reach Flatpak after querying the user manager (status 73)
```

This proves the launcher clears inherited `XDG_RUNTIME_DIR`, the `systemctl` stub rejects the bus query, and retry reaches the fail-fast `sleep` stub.

- [ ] **Step 3: Implement the minimal launcher fix**

In `nixos/deskflow.nix`, replace the body of the retry loop with:

```nix
      until [ "$i" -ge 30 ]; do
        # Query the user manager while its inherited runtime directory is intact.
        manager_environment="$(systemctl --user show-environment 2>/dev/null || true)"

        WAYLAND_DISPLAY=""
        DISPLAY=""
        XDG_RUNTIME_DIR=""

        while IFS= read -r line; do
          case "$line" in
            WAYLAND_DISPLAY=*) WAYLAND_DISPLAY="$(printf '%s' "$line" | sed 's/^WAYLAND_DISPLAY=//')" ;;
            DISPLAY=*) DISPLAY="$(printf '%s' "$line" | sed 's/^DISPLAY=//')" ;;
            XDG_RUNTIME_DIR=*) XDG_RUNTIME_DIR="$(printf '%s' "$line" | sed 's/^XDG_RUNTIME_DIR=//')" ;;
          esac
        done <<EOF
$manager_environment
EOF

        if [ -n "$WAYLAND_DISPLAY" ] || [ -n "$DISPLAY" ]; then
          if [ -n "$XDG_RUNTIME_DIR" ] && [ -S "$XDG_RUNTIME_DIR/bus" ]; then
            export WAYLAND_DISPLAY DISPLAY XDG_RUNTIME_DIR
            return 0
          fi
        fi

        sleep 1
        i=$((i + 1))
      done
```

Do not change the final `return 1`, `exec flatpak run`, package declaration, or systemd unit.

- [ ] **Step 4: Format the Nix module**

Run:

```bash
nix fmt nixos/deskflow.nix
```

Expected: exit 0; only formatting necessary for `nixos/deskflow.nix` changes.

- [ ] **Step 5: Run the focused test and verify it passes**

Run:

```bash
./tests/deskflow-launcher.bats.sh
```

Expected:

```text
PASS: Deskflow launcher preserves bus access and exports graphics environment
```

- [ ] **Step 6: Commit the regression test and fix**

```bash
git add tests/deskflow-launcher.bats.sh nixos/deskflow.nix
git diff --cached --check
git commit -m "fix(deskflow): preserve user bus environment"
```

Expected: one commit containing only the test and shared module.

---

### Task 2: Verify both host configurations

**Files:**

- Verify: `nixos/deskflow.nix`
- Verify: `nixos/hosts/lenovo/p14s-gen2i.nix`
- Verify: `nixos/hosts/orgm/ms-7d43.nix`

**Interfaces:**

- Consumes: the fixed shared Deskflow module from Task 1.
- Produces: evidence that both host outputs include the stable Flatpak and generated launcher.

- [ ] **Step 1: Evaluate the Deskflow package on both hosts**

Run:

```bash
for host in lenovo-hyprland orgm-hyprland; do
  nix eval --json ".#nixosConfigurations.$host.config.services.flatpak.packages" \
    | jq -e 'index("org.deskflow.deskflow") != null'
done
```

Expected: `true` twice and exit 0.

- [ ] **Step 2: Evaluate the generated service launcher on both hosts**

Run:

```bash
for host in lenovo-hyprland orgm-hyprland; do
  nix eval --json ".#nixosConfigurations.$host.config.home-manager.users.osmarg.systemd.user.services.deskflow.Service.ExecStart" \
    | jq -e 'length == 1 and (.[0] | endswith("-deskflow-launcher"))'
done
```

Expected: `true` twice and exit 0.

- [ ] **Step 3: Verify repository hygiene**

Run:

```bash
git diff --check HEAD~1..HEAD
git show --stat --oneline HEAD
git status --short
```

Expected: no whitespace errors; the fix commit contains only `nixos/deskflow.nix` and `tests/deskflow-launcher.bats.sh`; pre-existing generated/runtime files remain uncommitted.

---

### Task 3: Apply and verify the corrected service

**Files:**

- Apply: current NixOS configuration through project commands.
- Verify: generated user unit `deskflow.service`.

**Interfaces:**

- Consumes: verified `lenovo-hyprland` configuration from Task 2.
- Produces: running Deskflow Flatpak under a stable systemd user service.

- [ ] **Step 1: Confirm required project application tools exist**

Run:

```bash
type -P orgm-diff
type -P orgm-sync
```

Expected: both commands print executable paths. If either command is unavailable, stop this task and report the blocker; do not substitute `nixos-rebuild`, `nh`, or direct Home Manager commands.

- [ ] **Step 2: Review system changes**

Run:

```bash
orgm-diff
```

Expected: output includes the Deskflow launcher/user-unit change and no unintended repository or system changes. Stop before syncing if unrelated destructive changes appear.

- [ ] **Step 3: Apply approved system changes**

Run:

```bash
orgm-sync
```

Expected: exit 0 after copying/applying the declarative configuration.

- [ ] **Step 4: Reload and restart the user service**

Run:

```bash
systemctl --user daemon-reload
systemctl --user reset-failed deskflow.service
systemctl --user restart deskflow.service
sleep 5
```

Expected: exit 0.

- [ ] **Step 5: Confirm Deskflow stays running without another restart**

Run:

```bash
before="$(systemctl --user show deskflow.service -p NRestarts --value)"
sleep 45
after="$(systemctl --user show deskflow.service -p NRestarts --value)"
systemctl --user is-active deskflow.service
flatpak ps | grep -F org.deskflow.deskflow
test "$before" = "$after"
```

Expected: `active`, one Deskflow Flatpak process, and unchanged restart count across a window longer than the previous 40-second failure cycle.
