# Quickshell Fixed Theme Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Quickshell help and wallpaper picker use stable dark/light theme files instead of dynamically generated palette colors.

**Architecture:** Add fixed JSON theme files under `config/shared/.config/quickshell/theme/`. Change QML to read `current.json`. Change `orgm-themes` renderer to write fixed contents to `current.json` and compatibility `theme.json` when known fixed files exist.

**Tech Stack:** Go `internal/orgmtheme`, Quickshell QML, JSON fixtures, shell smoke tests.

---

### Task 1: Fixed theme fixtures and QML read path

**Files:**
- Create: `config/shared/.config/quickshell/theme/orgm-dark.json`
- Create: `config/shared/.config/quickshell/theme/orgm-light.json`
- Create: `config/shared/.config/quickshell/theme/current.json`
- Modify: `config/shared/.config/quickshell/modules/keyhelper/shell.qml`
- Modify: `config/shared/.config/quickshell/wallpaper-picker/shell.qml`

- [ ] Add fixed dark JSON using current known-good dark colors.
- [ ] Add fixed light JSON using existing light palette colors.
- [ ] Copy dark JSON to `current.json` as repo default.
- [ ] Change both QML files from `/quickshell/theme/theme.json` to `/quickshell/theme/current.json`.
- [ ] Run `git diff -- config/shared/.config/quickshell` and confirm only intended paths changed.

### Task 2: Renderer fixed selection

**Files:**
- Modify: `internal/orgmtheme/render.go`
- Modify: `internal/orgmtheme/render_test.go`
- Modify: `internal/orgmtheme/apply_test.go`

- [ ] Update `BuildWrites` to include `current.json` and compatibility `theme.json`.
- [ ] Implement fixed dark/light content helpers.
- [ ] Keep fallback `renderQuickshell(theme)` for non-`orgm-dark`/`orgm-light` names.
- [ ] Update render tests to assert Quickshell paths use fixed colors.
- [ ] Add apply test asserting `current.json` and `theme.json` are written.
- [ ] Run `go test ./internal/orgmtheme` and expect PASS.

### Task 3: Smoke tests and host sync

**Files:**
- Test only, then sync dotfiles through `orgm-dot` after merge or direct copy if needed.

- [ ] Run `bash tests/helpers/orgm-theme-wallpaper.bats.sh` and expect PASS.
- [ ] Run `bash tests/helpers/orgm-theme-light-contrast.bats.sh` and expect PASS.
- [ ] Run `git diff --check` and expect no whitespace errors.
- [ ] If user wants live apply now, copy changed Quickshell/theme files to host and run `distrobox-host-exec orgm-dot diff` before sync.
