# Waybar Display Selection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build local-only Waybar and nwg-dock display targeting for Hyprland hosts.

**Architecture:** Add a focused shell helper `hypr-display-targets` that reads Hyprland monitor JSON, stores local preferences in `~/.config/orgm-hypr/display-targets.json`, generates runtime Waybar config, and exposes a rofi menu. Update `waybar-watch`, `hypr-nwg-dock`, and `hypr-main-menu` to use the helper while keeping shared Waybar config output-free.

**Tech Stack:** Bash, jq, Hyprland `hyprctl -j monitors`, rofi helpers, existing dotfiles sync local-only config.

---

## File Map

- Create `config/shared/.local/bin/hypr-display-targets` — local display preference helper.
- Modify `config/shared/.local/bin/waybar-watch` — generate runtime config via helper before launching Waybar.
- Modify `config/shared/.local/bin/hypr-nwg-dock` — add `-o` output from helper when available.
- Modify `config/shared/.local/bin/hypr-main-menu` — add display targeting menu entry.
- Modify `config/dotfiles.json` — add `.config/orgm-hypr/display-targets.json` to local-only paths and `.local/bin/hypr-display-targets` to shared paths if needed.
- Test `tests/helpers/hypr-display-targets.bats.sh` — shell smoke/behavior tests.
- Modify `tests/helpers/hypr-shell-helpers.bats.sh` — include new helper in executable/syntax checks.

## Tasks

### Task 1: Helper tests

- [ ] Write `tests/helpers/hypr-display-targets.bats.sh` with fake monitor JSON and state file.
- [ ] Run it and confirm it fails because `hypr-display-targets` does not exist.

### Task 2: Helper implementation

- [ ] Create `config/shared/.local/bin/hypr-display-targets` with commands `ensure`, `status`, `waybar-config`, `dock-env`, and `menu`.
- [ ] Run helper tests and confirm pass.

### Task 3: Runtime integration

- [ ] Update `waybar-watch` to call `hypr-display-targets waybar-config` and launch generated config.
- [ ] Update `hypr-nwg-dock` to append dock output args from `hypr-display-targets dock-env`.
- [ ] Update `hypr-main-menu` to expose `Displays`.
- [ ] Update shell smoke tests to include `hypr-display-targets`.

### Task 4: Config registration and verification

- [ ] Add `.config/orgm-hypr/display-targets.json` to `local_only.paths`.
- [ ] Ensure `.local/bin/hypr-display-targets` is tracked in shared paths.
- [ ] Run JSON parse, shell syntax tests, helper tests, and `git diff --check`.
- [ ] Commit all changes with message `feat(hypr): persist waybar display targets`.
