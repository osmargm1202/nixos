# Skwd-wall Migration Implementation Plan

<!-- markdownlint-disable MD013 -->

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Waytrogen and the classic Hyprland legacy wallpaper flow with declaratively installed `skwd-wall` and `skwd-daemon`.

**Architecture:** The classic Hyprland NixOS profile imports the Skwd module and exposes its selector, CLI, renderer, and user service. `graphical-session.target` starts the daemon declaratively; no compositor bootstrap helper remains. Skwd restores the previous wallpaper itself, while Waybar and Hyprland keybindings invoke the selector directly. Hyprlock keeps a narrow read-only bridge to Skwd's generated `current.jpg` and never applies a desktop wallpaper.

**Tech Stack:** Nix flakes, NixOS modules, Home Manager out-of-store symlinks, Bash, Hyprland Lua configuration, Waybar JSONC, Bats-style shell tests, systemd user services, `skwd` CLI.

## Global Constraints

- Apply only to the classic `hyprland` profile; do not modify `hyprlandqs-caelestia`.
- Use `github:osmargm1202/skwd-wall` and its `skwd-daemon` dependency.
- `skwd-daemon` is the only component allowed to restore or apply desktop wallpapers.
- Do not start automatic rotation at login.
- `Win+Alt+W` runs `skwd wall toggle`; `Win+Shift+W` runs `chromium`.
- Waybar has no legacy wallpaper-picker right-click action.
- Hyprlock prefers `${XDG_CACHE_HOME:-$HOME/.cache}/skwd-wall/wallpaper/current.jpg` and retains the existing fallback.
- Preserve unrelated working-tree modifications, especially `hyprlandqs-caelestia` wallpaper-picker files and Herdr runtime files.
- Do not delete user wallpapers or Skwd runtime data.
- Source edits under `dotfiles/` are live through Home Manager out-of-store symlinks.
- Run `nh os switch` after changing flake and NixOS module wiring.

## Revision: declarative daemon ownership

This revision supersedes the historical Task 2 bootstrap implementation below. Remove `hypr-skwd-wall-start`, its dotfile registration, and its Hyprland autostart entry. Add `skwd-daemon.service` to `graphical-session.target` from `nixos/profiles/hyprland.nix`. Skwd owns restore behavior; automatic 1800-second rotation no longer resumes at login. Keep `hypr-current-wallpaper` because it is a read-only Hyprlock bridge, not a wallpaper controller.

## Revision: Mesa Wayland video rendering

The `osmargm1202/skwd-wall` fork must lock `osmargm1202/skwd-daemon`. The daemon fork selects window-only Wayland EGL configs and uses `EGL_KHR_surfaceless_context` for its offscreen FBO, replacing the unsupported combined `WINDOW_BIT | PBUFFER_BIT` requirement. Verify the Rust paper tests, workspace check, Nix daemon/wall/system builds, and runtime rendering of both a video and a shader transition before updating this repository's `flake.lock`.

---

### Task 1: Install Skwd through the classic Hyprland profile

**Files:**

- Create: `tests/skwd-wall-profile.bats.sh`
- Modify: `flake.nix:43-55`
- Modify: `flake.lock`
- Modify: `nixos/profiles/hyprland.nix:19-40`

**Interfaces:**

- Consumes: upstream flake `github:osmargm1202/skwd-wall` with `nixosModules.default`.
- Produces: `inputs.skwd-wall`, `programs.skwd-wall.enable = true`, and the `skwd`, `skwd-wall`, `skwd-daemon`, and `skwd-daemon.service` runtime artifacts.

- [ ] **Step 1: Write the failing profile contract test**

Create `tests/skwd-wall-profile.bats.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLAKE="$ROOT/flake.nix"
PROFILE="$ROOT/nixos/profiles/hyprland.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

grep -Fq 'skwd-wall = {' "$FLAKE" || fail "missing skwd-wall flake input"
grep -Fq 'url = "github:osmargm1202/skwd-wall";' "$FLAKE" || fail "skwd-wall input must use Osmar fork"
grep -Fq 'inputs.skwd-wall.nixosModules.default' "$PROFILE" || fail "Hyprland profile must import Skwd module"
grep -Fq 'programs.skwd-wall.enable = true;' "$PROFILE" || fail "Hyprland profile must enable Skwd"
if grep -Eq '^[[:space:]]+waytrogen([[:space:]]|$)' "$PROFILE"; then
  fail "Hyprland profile must not install Waytrogen"
fi

printf 'PASS: Skwd profile contract\n'
```

Make it executable:

```bash
chmod +x tests/skwd-wall-profile.bats.sh
```

- [ ] **Step 2: Run the contract test and confirm RED**

Run:

```bash
bash tests/skwd-wall-profile.bats.sh
```

Expected: FAIL with `missing skwd-wall flake input`.

- [ ] **Step 3: Add the Skwd flake input**

Add beside `caelestia-shell` in `flake.nix`:

```nix
    skwd-wall = {
      # Osmar fork of the standalone selector; it carries the matching
      # skwd-daemon package and user service.
      url = "github:osmargm1202/skwd-wall";
    };
```

Do not add `inputs.nixpkgs.follows = "nixpkgs"`; the Skwd flake pins the nixpkgs and Quickshell revisions it tests against.

- [ ] **Step 4: Import and enable Skwd, then remove Waytrogen**

Change the import block in `nixos/profiles/hyprland.nix` to:

```nix
  imports = [
    ./common_hyprland.nix
    inputs.skwd-wall.nixosModules.default
  ];

  programs.skwd-wall.enable = true;
```

Remove this package entry from `environment.systemPackages`:

```nix
    waytrogen
```

Keep every unrelated package unchanged.

- [ ] **Step 5: Lock the new dependency**

Run:

```bash
nix flake lock --update-input skwd-wall
```

Expected: `flake.lock` gains `skwd-wall`, `skwd-daemon`, and their pinned inputs; existing unrelated inputs remain pinned.

- [ ] **Step 6: Run the profile test and Nix evaluation**

Run:

```bash
bash tests/skwd-wall-profile.bats.sh
nix eval .#nixosConfigurations.hyprland.config.programs.skwd-wall.enable
nix eval --raw .#nixosConfigurations.hyprland.config.system.build.toplevel.drvPath >/dev/null
```

Expected:

```text
PASS: Skwd profile contract
true
```

The derivation-path evaluation exits 0.

- [ ] **Step 7: Commit the package integration**

```bash
git add flake.nix flake.lock nixos/profiles/hyprland.nix tests/skwd-wall-profile.bats.sh
git commit -m "feat(hypr): install Skwd wallpaper stack"
```

---

### Task 2: Start Skwd and static rotation safely

**Files:**

- Create: `dotfiles/config/profiles/hyprland/.local/bin/hypr-skwd-wall-start`
- Create: `dotfiles/tests/helpers/hypr-skwd-wall-start.bats.sh`
- Modify: `dotfiles/config/profiles/hyprland/.config/hypr/lua/autostart.lua:1-12`
- Modify: `dotfiles/tests/helpers/hypr-autostart.bats.sh`
- Modify: `dotfiles/tests/helpers/hypr-shell-helpers.bats.sh`
- Modify: `nixos/common-dotfiles.nix:245-260`

**Interfaces:**

- Consumes: `skwd-daemon.service`; `skwd wall list`; `skwd wall random_start JSON`.
- Produces: executable `hypr-skwd-wall-start` with injectable `SYSTEMCTL_BIN`, `SKWD_BIN`, `SLEEP_BIN`, and `SKWD_START_ATTEMPTS`; returns nonzero on service/readiness/rotation failure so autostart can log and continue.

- [ ] **Step 1: Write the failing bootstrap behavior test**

Create `dotfiles/tests/helpers/hypr-skwd-wall-start.bats.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/config/profiles/hyprland/.local/bin/hypr-skwd-wall-start"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/state"
CALLS="$TMP/calls"
export CALLS

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

cat >"$TMP/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
printf 'systemctl %s\n' "$*" >>"$CALLS"
[ "${SYSTEMCTL_FAIL:-0}" != 1 ]
EOF

cat >"$TMP/bin/skwd" <<'EOF'
#!/usr/bin/env bash
printf 'skwd' >>"$CALLS"
printf ' <%s>' "$@" >>"$CALLS"
printf '\n' >>"$CALLS"
if [ "$1 $2" = "wall list" ]; then
  count_file="${SKWD_TEST_STATE}/list-count"
  count="$(cat "$count_file" 2>/dev/null || printf 0)"
  count=$((count + 1))
  printf '%s\n' "$count" >"$count_file"
  if [ "${SKWD_LIST_ALWAYS_EMPTY:-0}" = 1 ] || [ "$count" -lt 2 ]; then
    printf '{"count":0,"wallpapers":[]}\n'
  else
    printf '{"count":2,"wallpapers":[{"type":"static"},{"type":"video"}]}\n'
  fi
fi
EOF

cat >"$TMP/bin/sleep" <<'EOF'
#!/usr/bin/env bash
printf 'sleep %s\n' "$*" >>"$CALLS"
EOF

chmod +x "$TMP/bin/systemctl" "$TMP/bin/skwd" "$TMP/bin/sleep"

[ -x "$SCRIPT" ] || fail "missing executable hypr-skwd-wall-start"

export SKWD_TEST_STATE="$TMP/state"
SYSTEMCTL_BIN="$TMP/bin/systemctl" \
SKWD_BIN="$TMP/bin/skwd" \
SLEEP_BIN="$TMP/bin/sleep" \
SKWD_START_ATTEMPTS=3 \
  "$SCRIPT"

grep -Fxq 'systemctl --user start skwd-daemon.service' "$CALLS" || fail "must start user daemon service"
[ "$(grep -c '^skwd <wall> <list>$' "$CALLS")" -eq 2 ] || fail "must wait until collection is populated"
grep -Fxq 'sleep 1' "$CALLS" || fail "must sleep between readiness attempts"
grep -Fxq 'skwd <wall> <random_start> <{"interval":1800,"types":["static"]}>' "$CALLS" || fail "must start static 1800-second rotation"

: >"$CALLS"
rm -f "$TMP/state/list-count"
if SKWD_LIST_ALWAYS_EMPTY=1 \
  SYSTEMCTL_BIN="$TMP/bin/systemctl" \
  SKWD_BIN="$TMP/bin/skwd" \
  SLEEP_BIN="$TMP/bin/sleep" \
  SKWD_START_ATTEMPTS=2 \
  "$SCRIPT" 2>"$TMP/not-ready.err"; then
  fail "empty collection must return nonzero"
fi
! grep -q '<random_start>' "$CALLS" || fail "must not rotate an empty collection"
grep -Fq 'static wallpaper collection not ready after 2 attempts' "$TMP/not-ready.err" || fail "must explain readiness timeout"

: >"$CALLS"
if SYSTEMCTL_FAIL=1 \
  SYSTEMCTL_BIN="$TMP/bin/systemctl" \
  SKWD_BIN="$TMP/bin/skwd" \
  SLEEP_BIN="$TMP/bin/sleep" \
  "$SCRIPT" 2>"$TMP/service.err"; then
  fail "service start failure must return nonzero"
fi
! grep -q '^skwd ' "$CALLS" || fail "must not call Skwd after service failure"
grep -Fq 'failed to start skwd-daemon.service' "$TMP/service.err" || fail "must explain service failure"

printf 'PASS: Skwd session bootstrap\n'
```

Make it executable:

```bash
chmod +x dotfiles/tests/helpers/hypr-skwd-wall-start.bats.sh
```

- [ ] **Step 2: Update source-contract tests before implementation**

In `dotfiles/tests/helpers/hypr-autostart.bats.sh`, replace the old wallpaper-daemon assertion with:

```bash
grep -Fq 'hypr-skwd-wall-start >>/tmp/hypr-skwd-wall-start.log 2>&1 || true' "$AUTOSTART" ||
  fail "Hyprland autostart must launch the bounded Skwd bootstrap"

if grep -Eq 'waytrogen|hypr-random-wallpaper|hypr-current-wallpaper' "$AUTOSTART"; then
  fail "Hyprland autostart must not launch a legacy wallpaper controller"
fi
```

In `dotfiles/tests/helpers/hypr-shell-helpers.bats.sh`, change:

```bash
BIN="$ROOT/config/shared/.local/bin"
```

to:

```bash
BIN="$ROOT/config/profiles/hyprland/.local/bin"
```

Replace `hypr-random-wallpaper` in its helper list with:

```bash
  hypr-skwd-wall-start \
```

- [ ] **Step 3: Run tests and confirm RED**

Run:

```bash
bash dotfiles/tests/helpers/hypr-skwd-wall-start.bats.sh
bash dotfiles/tests/helpers/hypr-autostart.bats.sh
bash dotfiles/tests/helpers/hypr-shell-helpers.bats.sh
```

Expected failures:

```text
FAIL: missing executable hypr-skwd-wall-start
FAIL: Hyprland autostart must launch the bounded Skwd bootstrap
```

The shell-helper test also fails because the new helper does not exist.

- [ ] **Step 4: Implement the bounded bootstrap helper**

Create `dotfiles/config/profiles/hyprland/.local/bin/hypr-skwd-wall-start`:

```bash
#!/usr/bin/env bash
set -u

systemctl_bin="${SYSTEMCTL_BIN:-systemctl}"
skwd_bin="${SKWD_BIN:-skwd}"
sleep_bin="${SLEEP_BIN:-sleep}"
attempts="${SKWD_START_ATTEMPTS:-120}"
rotation='{"interval":1800,"types":["static"]}'

if ! "$systemctl_bin" --user start skwd-daemon.service; then
  printf 'hypr-skwd-wall-start: failed to start skwd-daemon.service\n' >&2
  exit 1
fi

for ((attempt = 1; attempt <= attempts; attempt++)); do
  payload="$("$skwd_bin" wall list 2>/dev/null || true)"
  if printf '%s\n' "$payload" | grep -Eq '"type"[[:space:]]*:[[:space:]]*"static"'; then
    if "$skwd_bin" wall random_start "$rotation"; then
      exit 0
    fi
    printf 'hypr-skwd-wall-start: failed to start static wallpaper rotation\n' >&2
    exit 1
  fi
  if [ "$attempt" -lt "$attempts" ]; then
    "$sleep_bin" 1
  fi
done

printf 'hypr-skwd-wall-start: static wallpaper collection not ready after %s attempts\n' "$attempts" >&2
exit 1
```

Make it executable:

```bash
chmod +x dotfiles/config/profiles/hyprland/.local/bin/hypr-skwd-wall-start
```

- [ ] **Step 5: Register the helper and replace autostart commands**

In the classic `hyprland` list in `nixos/common-dotfiles.nix`, replace:

```nix
      ".local/bin/hypr-random-wallpaper"
```

with:

```nix
      ".local/bin/hypr-skwd-wall-start"
```

In `dotfiles/config/profiles/hyprland/.config/hypr/lua/autostart.lua`, replace the three legacy wallpaper entries:

```lua
  "sh -lc 'hypr-random-wallpaper restore >>/tmp/hypr-random-wallpaper.log 2>&1 || true'",
  "hypr-current-wallpaper",
  "sh -lc 'hypr-random-wallpaper daemon >>/tmp/hypr-random-wallpaper.log 2>&1 &'",
```

with one entry:

```lua
  "sh -lc 'hypr-skwd-wall-start >>/tmp/hypr-skwd-wall-start.log 2>&1 || true'",
```

- [ ] **Step 6: Run focused startup tests**

Run:

```bash
bash dotfiles/tests/helpers/hypr-skwd-wall-start.bats.sh
bash dotfiles/tests/helpers/hypr-autostart.bats.sh
bash dotfiles/tests/helpers/hypr-shell-helpers.bats.sh
bash -n dotfiles/config/profiles/hyprland/.local/bin/hypr-skwd-wall-start
```

Expected:

```text
PASS: Skwd session bootstrap
hypr autostart checks passed
hypr shell helper smoke tests passed
```

All commands exit 0.

- [ ] **Step 7: Commit the startup migration**

```bash
git add \
  nixos/common-dotfiles.nix \
  dotfiles/config/profiles/hyprland/.config/hypr/lua/autostart.lua \
  dotfiles/config/profiles/hyprland/.local/bin/hypr-skwd-wall-start \
  dotfiles/tests/helpers/hypr-skwd-wall-start.bats.sh \
  dotfiles/tests/helpers/hypr-autostart.bats.sh \
  dotfiles/tests/helpers/hypr-shell-helpers.bats.sh
git commit -m "feat(hypr): start Skwd wallpaper rotation"
```

---

### Task 3: Route wallpaper UI to Skwd and remove classic legacy picker

**Files:**

- Modify: `dotfiles/config/profiles/hyprland/.config/waybar-hypr/config:148-154,572-578`
- Modify: `dotfiles/config/profiles/hyprland/.config/hypr/lua/keybindings.lua:15-22`
- Modify: `dotfiles/config/profiles/hyprland/.local/bin/hypr-tweaks-menu`
- Modify: `dotfiles/config/profiles/hyprland/.local/bin/hypr-keybindings-help:120-135`
- Modify: `dotfiles/config/profiles/hyprland/.config/hypr/lua/README.md:24-32`
- Modify: `dotfiles/tests/helpers/waybar-hypr-custom-icons.bats.sh`
- Modify: `dotfiles/tests/helpers/hypr-menu-categories.bats.sh`
- Modify: `nixos/common-dotfiles.nix:165-185`
- Delete: `dotfiles/config/profiles/hyprland/.local/bin/hypr-random-wallpaper`
- Delete: `dotfiles/config/profiles/hyprland/.local/bin/hypr-wallpaper-picker`
- Delete: `dotfiles/config/profiles/hyprland/.local/bin/hypr-wallpaper-picker-dark`
- Delete: `dotfiles/config/profiles/hyprland/.local/bin/hypr-wallpaper-picker-light`
- Delete: `dotfiles/config/profiles/hyprland/.config/hypr/wallpaper-picker/README.md`
- Delete: `dotfiles/config/profiles/hyprland/.config/hypr/wallpaper-picker/wallpaper_picker.py`
- Delete: `dotfiles/config/profiles/hyprland/.config/quickshell/wallpaper-picker/shell.qml`
- Delete: `dotfiles/tests/helpers/hypr-random-wallpaper.bats.sh`
- Delete: `dotfiles/tests/helpers/hypr-wallpaper-picker-python.bats.sh`

**Interfaces:**

- Consumes: `skwd wall toggle`; Chromium executable from `nixos/common.nix`.
- Produces: Waybar and `Win+Alt+W` selector entry points; `Win+Shift+W` Chromium entry point; no classic-profile legacy picker/controller files.

- [ ] **Step 1: Change Waybar assertions to the Skwd contract**

In `dotfiles/tests/helpers/waybar-hypr-custom-icons.bats.sh`, replace the existing Waytrogen/right-click assertions with:

```bash
config="$root/config/profiles/hyprland/.config/waybar-hypr/config"
[ "$(grep -Fc '"on-click": "skwd wall toggle"' "$config")" -eq 2 ] || fail "both wallpaper modules should toggle Skwd"
[ "$(grep -Fc '"tooltip-format": "Selector de wallpapers"' "$config")" -eq 2 ] || fail "both wallpaper tooltips should describe the selector"
if grep -Eq 'waytrogen|hypr-wallpaper-picker' "$config"; then
  fail "Waybar wallpaper modules must not expose a legacy picker action"
fi
```

Keep unrelated Waybar assertions unchanged.

- [ ] **Step 2: Update menu/keybinding source assertions**

In `dotfiles/tests/helpers/hypr-menu-categories.bats.sh`, change:

```bash
BIN="$ROOT/config/shared/.local/bin"
```

to:

```bash
BIN="$ROOT/config/profiles/hyprland/.local/bin"
KEYS="$ROOT/config/profiles/hyprland/.config/hypr/lua/keybindings.lua"
```

Replace the two legacy wallpaper assertions with:

```bash
assert_contains "$TWEAKS" 'skwd wall toggle'
assert_not_contains "$TWEAKS" 'hypr-random-wallpaper'
assert_not_contains "$TWEAKS" 'hypr-wallpaper-picker'
assert_contains "$KEYS" 'mainMod .. " + ALT + W", hl.dsp.exec_cmd("skwd wall toggle")'
assert_contains "$KEYS" 'mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("chromium")'
assert_not_contains "$KEYS" 'hypr-wallpaper-picker'
```

Replace the obsolete dotfiles-manager assertions at the bottom with:

```bash
DOTFILES_NIX="$ROOT/../nixos/common-dotfiles.nix"
assert_contains "$DOTFILES_NIX" '".local/bin/hypr-tweaks-menu"'
assert_contains "$DOTFILES_NIX" '".local/bin/hypr-devices-menu"'
assert_contains "$DOTFILES_NIX" '".local/bin/hypr-help-menu"'

for legacy in \
  "$BIN/hypr-random-wallpaper" \
  "$BIN/hypr-wallpaper-picker" \
  "$BIN/hypr-wallpaper-picker-dark" \
  "$BIN/hypr-wallpaper-picker-light" \
  "$ROOT/config/profiles/hyprland/.config/hypr/wallpaper-picker/README.md" \
  "$ROOT/config/profiles/hyprland/.config/hypr/wallpaper-picker/wallpaper_picker.py" \
  "$ROOT/config/profiles/hyprland/.config/quickshell/wallpaper-picker/shell.qml"; do
  [ ! -e "$legacy" ] || fail "legacy wallpaper file remains: $legacy"
done

classic_paths="$(awk '/^    hyprland = \[/,/^    \];/' "$DOTFILES_NIX")"
if printf '%s\n' "$classic_paths" | rg -q 'waytrogen|hypr-random-wallpaper|hypr-wallpaper-picker'; then
  fail "classic Hyprland dotfile registrations still contain legacy wallpaper paths"
fi
```

- [ ] **Step 3: Run UI tests and confirm RED**

Run:

```bash
bash dotfiles/tests/helpers/waybar-hypr-custom-icons.bats.sh
bash dotfiles/tests/helpers/hypr-menu-categories.bats.sh
```

Expected: failures mention missing `skwd wall toggle` and legacy picker references.

- [ ] **Step 4: Update both Waybar wallpaper definitions**

Replace both duplicate `custom/wallpaper` objects with:

```json
    "custom/wallpaper": {
      "format": "",
      "tooltip": true,
      "tooltip-format": "Selector de wallpapers",
      "on-click": "skwd wall toggle"
    },
```

Do not add `on-click-right`.

- [ ] **Step 5: Update Hyprland keybindings and visible help**

In `dotfiles/config/profiles/hyprland/.config/hypr/lua/keybindings.lua`, replace the old wallpaper binding with:

```lua
  hl.bind(mainMod .. " + ALT + W", hl.dsp.exec_cmd("skwd wall toggle"))
  hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("chromium"))
```

In the `system)` section of `dotfiles/config/profiles/hyprland/.local/bin/hypr-keybindings-help`, replace the old wallpaper entry with:

```bash
      entry 'Win+Alt+W' 'Selector de wallpapers' 'skwd wall toggle'
      entry 'Win+Shift+W' 'Chromium' 'chromium'
```

In `dotfiles/config/profiles/hyprland/.config/hypr/lua/README.md`, replace the legacy helper examples with:

```markdown
- High-cost startup helpers should call focused shell scripts directly (for
  example, `hypr-skwd-wall-start` and `orgm-dot`).
```

- [ ] **Step 6: Collapse the Tweaks menu to one Skwd action**

Replace the two wallpaper choices in `dotfiles/config/profiles/hyprland/.local/bin/hypr-tweaks-menu` with:

```bash
  '󰸉 Wallpaper selector' \
```

Replace the two corresponding `case` branches with:

```bash
  *'Wallpaper selector') exec skwd wall toggle ;;
```

Keep transitions, keyboard, memory, config-editor, and cancel actions unchanged.

- [ ] **Step 7: Remove classic-profile legacy files and registrations**

Delete only classic-profile files:

```bash
rm -f \
  dotfiles/config/profiles/hyprland/.local/bin/hypr-random-wallpaper \
  dotfiles/config/profiles/hyprland/.local/bin/hypr-wallpaper-picker \
  dotfiles/config/profiles/hyprland/.local/bin/hypr-wallpaper-picker-dark \
  dotfiles/config/profiles/hyprland/.local/bin/hypr-wallpaper-picker-light \
  dotfiles/config/profiles/hyprland/.config/hypr/wallpaper-picker/README.md \
  dotfiles/config/profiles/hyprland/.config/hypr/wallpaper-picker/wallpaper_picker.py \
  dotfiles/config/profiles/hyprland/.config/quickshell/wallpaper-picker/shell.qml \
  dotfiles/tests/helpers/hypr-random-wallpaper.bats.sh \
  dotfiles/tests/helpers/hypr-wallpaper-picker-python.bats.sh
```

Remove these two entries from the classic `hyprland` list in `nixos/common-dotfiles.nix`:

```nix
      ".config/hypr/wallpaper-picker/README.md"
      ".config/hypr/wallpaper-picker/wallpaper_picker.py"
```

Do not remove similarly named files or registrations under `hyprlandqs-caelestia`.

- [ ] **Step 8: Run UI/menu tests and scan classic profile for legacy ownership**

Run:

```bash
bash dotfiles/tests/helpers/waybar-hypr-custom-icons.bats.sh
bash dotfiles/tests/helpers/hypr-menu-categories.bats.sh
bash -n \
  dotfiles/config/profiles/hyprland/.local/bin/hypr-tweaks-menu \
  dotfiles/config/profiles/hyprland/.local/bin/hypr-keybindings-help
if rg -n 'waytrogen|hypr-random-wallpaper|hypr-wallpaper-picker' \
  nixos/profiles/hyprland.nix \
  dotfiles/config/profiles/hyprland; then
  printf 'legacy wallpaper ownership remains in classic Hyprland files\n' >&2
  exit 1
fi
if awk '/^    hyprland = \[/,/^    \];/' nixos/common-dotfiles.nix |
  rg -n 'waytrogen|hypr-random-wallpaper|hypr-wallpaper-picker'; then
  printf 'legacy wallpaper registration remains in classic Hyprland paths\n' >&2
  exit 1
fi
```

Expected:

```text
PASS: Waybar-Hypr custom icons configured
hypr menu categories test passed
```

Both legacy scans emit no matches. The `awk` range deliberately excludes Caelestia registrations.

- [ ] **Step 9: Commit the UI migration and legacy cleanup**

```bash
git add -A -- \
  nixos/common-dotfiles.nix \
  dotfiles/config/profiles/hyprland \
  dotfiles/tests/helpers/waybar-hypr-custom-icons.bats.sh \
  dotfiles/tests/helpers/hypr-menu-categories.bats.sh \
  dotfiles/tests/helpers/hypr-random-wallpaper.bats.sh \
  dotfiles/tests/helpers/hypr-wallpaper-picker-python.bats.sh
git commit -m "refactor(hypr): replace legacy wallpaper UI with Skwd"
```

---

### Task 4: Point Hyprlock at Skwd's generated image

**Files:**

- Create: `dotfiles/tests/helpers/hypr-current-wallpaper.bats.sh`
- Modify: `dotfiles/config/profiles/hyprland/.local/bin/hypr-current-wallpaper`
- Verify: `dotfiles/config/profiles/hyprland/.local/bin/hypr-lock`
- Verify: `dotfiles/config/profiles/hyprland/.config/hypr/hyprlock.conf`

**Interfaces:**

- Consumes: `${XDG_CACHE_HOME:-$HOME/.cache}/skwd-wall/wallpaper/current.jpg` maintained by `skwd-daemon`.
- Produces: `$XDG_RUNTIME_DIR/hypr-current-wallpaper` symlink targeting Skwd `current.jpg` or `$HOME/.config/wallpapers/xnm1-background.png` fallback; prints the symlink path.

- [ ] **Step 1: Write the failing lockscreen bridge test**

Create `dotfiles/tests/helpers/hypr-current-wallpaper.bats.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/config/profiles/hyprland/.local/bin/hypr-current-wallpaper"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p \
  "$TMP/home/.config/wallpapers" \
  "$TMP/cache/skwd-wall/wallpaper" \
  "$TMP/runtime"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

fallback="$TMP/home/.config/wallpapers/xnm1-background.png"
current="$TMP/cache/skwd-wall/wallpaper/current.jpg"
printf 'fallback\n' >"$fallback"
printf 'skwd\n' >"$current"

output="$(HOME="$TMP/home" XDG_CACHE_HOME="$TMP/cache" XDG_RUNTIME_DIR="$TMP/runtime" "$SCRIPT")"
[ "$output" = "$TMP/runtime/hypr-current-wallpaper" ] || fail "helper must print runtime link"
[ "$(readlink "$output")" = "$current" ] || fail "lockscreen must prefer Skwd current.jpg"

rm -f "$current"
HOME="$TMP/home" XDG_CACHE_HOME="$TMP/cache" XDG_RUNTIME_DIR="$TMP/runtime" "$SCRIPT" >/dev/null
[ "$(readlink "$TMP/runtime/hypr-current-wallpaper")" = "$fallback" ] || fail "lockscreen must preserve fallback"

if rg -q 'waytrogen|hypr-random-wallpaper' "$SCRIPT"; then
  fail "lockscreen bridge must not read legacy wallpaper state"
fi

printf 'PASS: Hyprlock follows Skwd current image\n'
```

Make it executable:

```bash
chmod +x dotfiles/tests/helpers/hypr-current-wallpaper.bats.sh
```

- [ ] **Step 2: Run the bridge test and confirm RED**

Run:

```bash
bash dotfiles/tests/helpers/hypr-current-wallpaper.bats.sh
```

Expected: FAIL because the existing helper still queries Waytrogen and legacy state.

- [ ] **Step 3: Replace the helper with the minimal Skwd bridge**

Replace `dotfiles/config/profiles/hyprland/.local/bin/hypr-current-wallpaper` with:

```sh
#!/bin/sh
set -eu

runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}"
current="${cache_dir}/skwd-wall/wallpaper/current.jpg"
fallback="${HOME}/.config/wallpapers/xnm1-background.png"
out="${runtime_dir}/hypr-current-wallpaper"

wallpaper="$fallback"
if [ -f "$current" ]; then
  wallpaper="$current"
fi

ln -sfn "$wallpaper" "$out"
printf '%s\n' "$out"
```

Keep it executable:

```bash
chmod +x dotfiles/config/profiles/hyprland/.local/bin/hypr-current-wallpaper
```

- [ ] **Step 4: Run lockscreen tests and source checks**

Run:

```bash
bash dotfiles/tests/helpers/hypr-current-wallpaper.bats.sh
bash -n \
  dotfiles/config/profiles/hyprland/.local/bin/hypr-current-wallpaper \
  dotfiles/config/profiles/hyprland/.local/bin/hypr-lock
grep -Fq 'hypr-current-wallpaper' dotfiles/config/profiles/hyprland/.local/bin/hypr-lock
grep -Fq 'path = $XDG_RUNTIME_DIR/hypr-current-wallpaper' dotfiles/config/profiles/hyprland/.config/hypr/hyprlock.conf
```

Expected:

```text
PASS: Hyprlock follows Skwd current image
```

All remaining checks exit 0.

- [ ] **Step 5: Commit the lockscreen bridge**

```bash
git add \
  dotfiles/config/profiles/hyprland/.local/bin/hypr-current-wallpaper \
  dotfiles/tests/helpers/hypr-current-wallpaper.bats.sh
git commit -m "fix(hypr): sync lockscreen with Skwd wallpaper"
```

---

### Task 5: Verify and deploy the migration

**Files:**

- Verify: all files changed in Tasks 1-4
- Preserve: current unrelated `hyprlandqs-caelestia` and Herdr working-tree files

**Interfaces:**

- Consumes: completed Skwd profile, bootstrap, UI, and lockscreen integration.
- Produces: evaluated and deployed NixOS configuration with live `skwd-daemon.service`, 1800-second static rotation, Skwd selector entry points, and synchronized Hyprlock background.

- [ ] **Step 1: Run the complete focused regression set**

Run:

```bash
bash tests/skwd-wall-profile.bats.sh
bash dotfiles/tests/helpers/hypr-skwd-wall-start.bats.sh
bash dotfiles/tests/helpers/hypr-autostart.bats.sh
bash dotfiles/tests/helpers/hypr-shell-helpers.bats.sh
bash dotfiles/tests/helpers/waybar-hypr-custom-icons.bats.sh
bash dotfiles/tests/helpers/hypr-menu-categories.bats.sh
bash dotfiles/tests/helpers/hypr-current-wallpaper.bats.sh
```

Expected: every script exits 0 and prints its PASS message.

- [ ] **Step 2: Run syntax, formatting, and diagnostics checks**

Run:

```bash
bash -n \
  dotfiles/config/profiles/hyprland/.local/bin/hypr-skwd-wall-start \
  dotfiles/config/profiles/hyprland/.local/bin/hypr-current-wallpaper \
  dotfiles/config/profiles/hyprland/.local/bin/hypr-lock \
  dotfiles/config/profiles/hyprland/.local/bin/hypr-tweaks-menu \
  dotfiles/config/profiles/hyprland/.local/bin/hypr-keybindings-help
nixfmt --check flake.nix nixos/profiles/hyprland.nix nixos/common-dotfiles.nix
git diff --check
git status --short
```

Expected: syntax, Nix formatting, and whitespace checks exit 0. `git status --short` shows only intentionally changed implementation files plus the pre-existing unrelated Caelestia/Herdr files.

Run Pi diagnostics on all changed source files before builds:

```text
lsp_diagnostics(paths=[changed Nix, Lua, shell, and test files])
lens_diagnostics(mode="all")
```

Expected: no blocking errors.

- [ ] **Step 3: Evaluate the flake**

Run:

```bash
nix eval .#nixosConfigurations.hyprland.config.programs.skwd-wall.enable
nix eval --raw .#nixosConfigurations.orgm-hyprland.config.system.build.toplevel.drvPath >/dev/null
nix flake check
```

Expected: first command prints `true`; remaining commands exit 0.

- [ ] **Step 4: Review final ownership and diff boundaries**

Run:

```bash
git diff --stat HEAD~4..HEAD
git diff --check HEAD~4..HEAD
git status --short
rg -n 'waytrogen|hypr-random-wallpaper|hypr-wallpaper-picker' \
  nixos/profiles/hyprland.nix \
  dotfiles/config/profiles/hyprland || true
git diff -- \
  dotfiles/config/profiles/hyprlandqs-caelestia \
  dotfiles/config/shared/.config/herdr
```

Expected:

- No legacy wallpaper-owner matches in the classic Hyprland profile.
- No task-generated diff in Caelestia or Herdr files; any displayed changes match the pre-existing user modifications.
- No whitespace errors.

- [ ] **Step 5: Deploy the NixOS and Home Manager changes**

Run:

```bash
nh os switch
```

Expected: switch completes successfully, installs the Skwd package and user unit, removes Waytrogen from the active classic Hyprland closure, and refreshes Home Manager symlinks.

- [ ] **Step 6: Start and inspect the runtime flow**

Run inside the active Hyprland session:

```bash
hypr-skwd-wall-start
systemctl --user status skwd-daemon.service --no-pager
skwd wall random_status
readlink "$XDG_RUNTIME_DIR/hypr-current-wallpaper" || true
```

Expected:

- `hypr-skwd-wall-start` exits 0 when at least one static wallpaper exists.
- Service status is `active (running)`.
- `skwd wall random_status` reports `running: true`, `interval: 1800`, and `types: ["static"]`.
- After running `hypr-lock` once or `hypr-current-wallpaper` directly, runtime link targets `${XDG_CACHE_HOME:-$HOME/.cache}/skwd-wall/wallpaper/current.jpg` when available.

- [ ] **Step 7: Perform manual UI smoke checks**

Verify:

1. Click Waybar wallpaper icon: Skwd selector toggles.
2. Press `Win+Alt+W`: same selector toggles.
3. Press `Win+Shift+W`: Chromium launches.
4. Select a static wallpaper, then run `hypr-lock`: lockscreen shows Skwd's generated current image.
5. Confirm no Waytrogen, old GTK picker, or old random-wallpaper daemon opens.

Expected: all five checks pass.
