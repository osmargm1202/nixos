# Hyprland Video Timer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `SUPER + SHIFT + TAB` timer flow that visits previous workspace, starts media, waits requested seconds, then returns; add `SUPER + mouse wheel` relative workspace navigation.

**Architecture:** One shared Bash helper is deployed through existing shared dotfiles paths to both Hyprland profiles. Stub-driven shell tests verify behavior without a live compositor. Each profile binds same command; existing Caelestia suspend binding on that exact shortcut is replaced.

**Tech Stack:** Bash, Rofi, Hyprland `hyprctl`, Playerctl/MPRIS, Lua Hyprland configuration, shell smoke tests.

## Global Constraints

- Input accepts decimal integer seconds greater than zero only.
- Use `workspace previous`; no fixed workspace number.
- Target first Playerctl-selected MPRIS player.
- New valid invocation replaces active timer.
- Playerctl failure must not prevent timed return.
- Remain independent of Caelestia IPC.
- Bind timer to `SUPER + SHIFT + TAB` in both profiles.
- Bind `SUPER + mouse wheel up` to `r-1` and `SUPER + mouse wheel down` to `r+1` in both profiles.
- Preserve existing Caelestia `SUPER + ALT + P` suspend binding.
- Change only `dotfiles/` plus plan documentation; preserve unrelated working-tree changes.
- Register new helper path in both Hyprland profile lists in `nixos/common-dotfiles.nix`, rebuild once, then reload Hyprland.

---

### Task 1: Timer helper behavior

**Files:**
- Create: `dotfiles/config/shared/.local/bin/hypr-video-timer`
- Create: `dotfiles/tests/helpers/hypr-video-timer.bats.sh`
- Modify: `nixos/common-dotfiles.nix`

**Interfaces:**
- Consumes: `rofi -dmenu`, `hyprctl dispatch workspace previous`, `playerctl play`, `sleep`, optional `notify-send`, `$XDG_RUNTIME_DIR`.
- Produces: executable command `hypr-video-timer` and runtime ownership files named under `$XDG_RUNTIME_DIR/hypr-video-timer-$UID`.

- [ ] **Step 1: Write failing stub-driven test**

Create test harness that places fake `rofi`, `hyprctl`, `playerctl`, `sleep`, `notify-send`, and `kill` behavior on `PATH`; record calls in `$CALLS`. Assert cancelled and invalid input cause no side effects; valid `5` produces exact semantic order `hyprctl`, `playerctl`, `sleep 5`, `hyprctl`; Playerctl failure still reaches final switch; replacing state prevents stale process return; and `nixos/common-dotfiles.nix` exports `.local/bin/hypr-video-timer` for both Hyprland profiles.

- [ ] **Step 2: Run test and verify red**

Run: `bash dotfiles/tests/helpers/hypr-video-timer.bats.sh`

Expected: nonzero because helper does not exist or export path is absent.

- [ ] **Step 3: Implement minimal helper**

Use strict Bash. Read input with:

```bash
seconds="$(printf '' | rofi -dmenu -p 'Segundos')" || exit 0
[[ "$seconds" =~ ^[1-9][0-9]*$ ]] || exit 0
```

Use a user runtime directory with mode `700`, an invocation token, PID/state ownership checks, signal trap, and cancellation of only a live process whose `/proc/$pid/cmdline` identifies `hypr-video-timer`. Dispatch first workspace switch, attempt `playerctl play`, notify on playback failure, sleep, verify token ownership, dispatch final switch, then clean owned state. Add helper path to both Hyprland profile lists in `nixos/common-dotfiles.nix`.

- [ ] **Step 4: Run focused tests**

Run: `bash dotfiles/tests/helpers/hypr-video-timer.bats.sh`

Expected: `hypr video timer tests passed` and exit 0.

- [ ] **Step 5: Commit helper**

```bash
git add dotfiles/config/shared/.local/bin/hypr-video-timer dotfiles/tests/helpers/hypr-video-timer.bats.sh nixos/common-dotfiles.nix
git commit -m "feat(hypr): add video workspace timer"
```

### Task 2: Bind both Hyprland profiles

**Files:**
- Modify: `dotfiles/config/profiles/hyprland/.config/hypr/lua/keybindings.lua`
- Modify: `dotfiles/config/profiles/hyprlandqs-caelestia/.config/hypr/lua/keybindings.lua`
- Create: `dotfiles/tests/helpers/hypr-video-timer-bindings.bats.sh`

**Interfaces:**
- Consumes: executable `hypr-video-timer` from Task 1.
- Produces: `SUPER + SHIFT + TAB` timer binding and `SUPER + mouse wheel up/down` workspace bindings in both profiles.

- [ ] **Step 1: Write failing binding test**

Assert each Lua file contains one `mainMod .. " + SHIFT + Tab"` binding executing `hypr-video-timer`. Assert each file binds `mainMod .. " + mouse:274"` to workspace `r-1` and `mainMod .. " + mouse:275"` to workspace `r+1`. Assert Caelestia still maps `SUPER + ALT + P` to `systemctl suspend`.

- [ ] **Step 2: Run test and verify red**

Run: `bash dotfiles/tests/helpers/hypr-video-timer-bindings.bats.sh`

Expected: nonzero because both profiles lack timer and workspace-wheel bindings.

- [ ] **Step 3: Add bindings**

Classic profile:

```lua
hl.bind(mainMod .. " + SHIFT + Tab", hl.dsp.exec_cmd("hypr-video-timer"))
hl.bind(mainMod .. " + mouse:274", hyprdeck.hyd.dsp.focus({ workspace = "r-1" }))
hl.bind(mainMod .. " + mouse:275", hyprdeck.hyd.dsp.focus({ workspace = "r+1" }))
```

Caelestia profile, preserving suspend binding:

```lua
hl.bind(mainMod .. " + SHIFT + Tab", hl.dsp.exec_cmd("hypr-video-timer"), { description = "Timed video workspace" })
hl.bind(mainMod .. " + mouse:274", hl.dsp.focus({ workspace = "r-1" }), { description = "Previous workspace" })
hl.bind(mainMod .. " + mouse:275", hl.dsp.focus({ workspace = "r+1" }), { description = "Next workspace" })
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

### Task 3: Verify and activate dotfiles

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

- [ ] **Step 3: Inspect tracked diff**

Run: `git diff --check` and inspect `git status --short`.

Expected: intended helper/export/binding changes only. Do not include unrelated log, session, lockfile, or `result` changes.

- [ ] **Step 4: Activate new helper symlink**

Run: `sudo nixos-rebuild switch --flake .#orgm`, then `hyprctl reload`.

Expected: Home Manager creates the new helper symlink and Hyprland reloads bindings.

- [ ] **Step 5: Final verification**

Verify `command -v hypr-video-timer`, executable bit, and active config contains timer and workspace-wheel bindings. Confirm Caelestia `SUPER + ALT + P` still suspends.
