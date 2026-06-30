# orgm-dot Shared Without Host and Arch Installer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `orgm-dot` sync shared paths even on hosts without host-specific config, and add a repeatable Arch distrobox bootstrap script.

**Architecture:** Host resolution should return the detected/explicit host name without requiring it to exist in `config.hosts`; host-specific loops already no-op for unknown hosts through `HostPaths`. The Arch installer lives with `packages/arch` and reuses `packages.lst`, `aur-packages.lst`, and `install.sh`.

**Tech Stack:** Go tests and implementation for `orgm-dot`; Bash for Arch distrobox bootstrap; pacman/paru/npm/pnpm.

---

### Task 1: Allow unknown hosts for shared sync/diff/status

**Files:**
- Modify: `internal/dotconfig/host.go`
- Test: `internal/dotconfig/host_test.go`

- [ ] Write failing test that `ResolveHost` accepts an unknown hostname and `HostPaths` returns no host paths.
- [ ] Run `go test ./internal/dotconfig` and verify failure mentions unknown host rejection.
- [ ] Remove the config-host existence error from `ResolveHost` while keeping empty-host validation.
- [ ] Run `go test ./internal/dotconfig ./internal/dotsync ./internal/dotdiff`.

### Task 2: Add Arch distrobox bootstrap script and update package lists

**Files:**
- Create: `packages/arch/distrobox.sh`
- Modify: `packages/arch/packages.lst`
- Modify: `packages/arch/aur-packages.lst`

- [ ] Add current explicit native Arch packages missing from `packages.lst`.
- [ ] Add current foreign/AUR packages missing from `aur-packages.lst`.
- [ ] Create `distrobox.sh` with subcommands: `create`, `enter`, `bootstrap`, `all`.
- [ ] Make `bootstrap` clone/update dotfiles repo, run `packages/arch/install.sh`, install `pnpm`, install `@earendil-works/pi-coding-agent` and `orgmrnc` globally with npm.
- [ ] Run `bash -n packages/arch/install.sh packages/arch/distrobox.sh`.

### Task 3: Verify, commit, push, and update NixOS lock if needed

**Files:**
- Dotfiles repo.
- Optional: `/home/osmarg/Hobby/nixos/flake.lock` if it references dotfiles.

- [ ] Run `go test ./...`.
- [ ] Run `bash -n packages/arch/install.sh packages/arch/distrobox.sh`.
- [ ] Commit dotfiles changes and push branch/master per integration path.
- [ ] If NixOS flake references dotfiles, update lock, commit, and push NixOS.
