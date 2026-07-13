# Hyprland Video Timer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `SUPER + ALT + P` timer flow that visits previous workspace, starts media, waits requested seconds, then returns.

**Architecture:** One shared Bash helper is deployed through existing shared dotfiles paths to both Hyprland profiles. Stub-driven shell tests verify behavior without a live compositor. Each profile binds same command; existing Caelestia suspend binding on that exact shortcut is replaced.

**Tech Stack:** Bash, Rofi, Hyprland `hyprctl`, Playerctl/MPRIS, Lua Hyprland configuration, shell smoke tests.

## Global Constraints

- Input accepts decimal integer seconds greater than zero only.
- Use `workspace previous`; no fixed workspace number.
- Target first Playerctl-selected MPRIS player.
- New valid invocation replaces active timer.
- Playerctl failure must not prevent timed return.
- Remain independent of Caelestia IPC.
- Change only `dotfiles/` plus plan documentation; preserve unrelated working-tree changes.
- Inspect with `orgm-diff`, then apply with `orgm-sync`.

---

### Task 1: Timer helper behavior

**Files:**
- Create: `dotfiles/config/shared/.local/bin/hypr-video-timer`
- Create: `dotfiles/tests/helpers/hypr-video-timer.bats.sh`
- Modify: `dotfiles/config/dotfiles.json`

**Interfaces:**
- Consumes: `rofi -dmenu`, `hyprctl dispatch workspace previous`, `playerctl play`, `sleep`, optional `notify-send`, `$XDG_RUNTIME_DIR`.
- Produces: executable command `hypr-video-timer` and runtime ownership files named under `$XDG_RUNTIME_DIR/hypr-video-timer-$UID`.

- [ ] **Step 1: Write failing stub-driven test**

Create test harness that places fake `rofi`, `hyprctl`, `playerctl`, `sleep`, `notify-send`, and `kill` behavior on `PATH`; record calls in `$CALLS`. Assert cancelled and invalid input cause no side effects; valid `5` produces exact semantic order `hyprctl`, `playerctl`, `sleep 5`, `hyprctl`; Playerctl failure still reaches final switch; replacing state prevents stale process return; and `dotfiles.json` exports `.local/bin/hypr-video-timer`.

- [ ] **Step 2: Run test and verify red**

Run: `bash dotfiles/tests/helpers/hypr-video-timer.bats.sh`

Expected: nonzero because helper does not exist or export path is absent.

- [ ] **Step 3: Implement minimal helper**

Use strict Bash. Read input with:

```bash
seconds="$(printf '' | rofi -dmenu -p 'Segundos')" || exit 0
[[ "$seconds" =~ ^[1-9][0-9]*$ ]] || exit 0
```

Use a user runtime directory with mode `700`, an invocation token, PID/state ownership checks, signal trap, and cancellation of only a live process whose `/proc/$pid/cmdline` identifies `hypr-video-timer`. Dispatch first workspace switch, attempt `playerctl play`, notify on playback failure, sleep, verify token ownership, dispatch final switch, then clean owned state. Add shared export path to `dotfiles/config/dotfiles.json`.

- [ ] **Step 4: Run focused tests**

Run: `bash dotfiles/tests/helpers/hypr-video-timer.bats.sh`

Expected: `hypr video timer tests passed` and exit 0.

- [ ] **Step 5: Commit helper**

```bash
git add dotfiles/config/shared/.local/bin/hypr-video-timer dotfiles/tests/helpers/hypr-video-timer.bats.sh dotfiles/config/dotfiles.json
git commit -m "feat(hypr): add video workspace timer"
```

### Task 2: Bind both Hyprland profiles

**Files:**
- Modify: `dotfiles/config/profiles/hyprland/.config/hypr/lua/keybindings.lua`
- Modify: `dotfiles/config/profiles/hyprlandqs-caelestia/.config/hypr/lua/keybindings.lua`
- Create: `dotfiles/tests/helpers/hypr-video-timer-bindings.bats.sh`

**Interfaces:**
- Consumes: executable `hypr-video-timer` from Task 1.
- Produces: `SUPER + ALT + P` binding in both profiles.

- [ ] **Step 1: Write failing binding test**

Assert each Lua file contains one `mainMod .. " + ALT + P"` binding executing `hypr-video-timer`. Assert Caelestia no longer maps that shortcut to `systemctl suspend`.

- [ ] **Step 2: Run test and verify red**

Run: `bash dotfiles/tests/helpers/hypr-video-timer-bindings.bats.sh`

Expected: nonzero because classic profile lacks binding and Caelestia maps shortcut to suspend.

- [ ] **Step 3: Add bindings**

Classic profile:

```lua
hl.bind(mainMod .. " + ALT + P", hl.dsp.exec_cmd("hypr-video-timer"))
```

Caelestia profile, replacing suspend line:

```lua
hl.bind(mainMod .. " + ALT + P", hl.dsp.exec_cmd("hypr-video-timer"), { description = "Timed video workspace" })
```

- [ ] **Step 4: Run binding and helper tests**

Run:

```bash
bash dotfiles/tests/helpers/hypr-video-timer-bindings.bats.sh
bash dotfiles/tests/helpers/hypr-video-timer.bats.sh
```

Expected: both exit 0.

- [ ] **Step 5: Commit bindings**

```bash
git add dotfiles/config/profiles/hyprland/.config/hypr/lua/keybindings.lua dotfiles/config/profiles/hyprlandqs-caelestia/.config/hypr/lua/keybindings.lua dotfiles/tests/helpers/hypr-video-timer-bindings.bats.sh
git commit -m "feat(hypr): bind video timer shortcut"
```

### Task 3: Verify and deploy dotfiles

**Files:**
- Verify all Task 1 and Task 2 files.

**Interfaces:**
- Consumes: completed helper, export manifest, bindings, tests.
- Produces: synchronized user configuration.

- [ ] **Step 1: Run feature tests**

```bash
bash dotfiles/tests/helpers/hypr-video-timer.bats.sh
bash dotfiles/tests/helpers/hypr-video-timer-bindings.bats.sh
```

Expected: both exit 0.

- [ ] **Step 2: Run repository-relevant test suite**

Run repository's established dotfiles test command if defined; otherwise execute all `dotfiles/tests/helpers/*.bats.sh` scripts and summarize failures without modifying unrelated code.

- [ ] **Step 3: Inspect deployment diff**

Run: `orgm-diff`

Expected: intended helper/export/binding changes only for synchronization. Do not accept unrelated log, session, lockfile, or `result` changes.

- [ ] **Step 4: Synchronize**

Run: `orgm-sync`

Expected: helper and Hyprland configuration copied to system locations successfully.

- [ ] **Step 5: Final verification**

Verify `command -v hypr-video-timer`, executable bit, and active config contains timer binding. Report shortcut conflict resolution: Caelestia `SUPER + ALT + P` now starts timer instead of suspending.
