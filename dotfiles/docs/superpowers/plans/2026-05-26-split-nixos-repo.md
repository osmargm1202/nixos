# Split NixOS Repo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split NixOS system management and Go system executables into a new public `/home/osmarg/Hobby/nixos` repo, leaving `dotfiles` focused on user configuration, icons, desktop files, and scripts.

**Architecture:** The new `nixos` repo owns `flake.nix`, `flake.lock`, `nixos/**`, and the Go module that builds `orgm-hypr`/calendar logic and `orgm-dot`. The existing `dotfiles` repo keeps `config/**`, desktop assets, user scripts, and dotfile sync metadata. Migration must be done from a clean/staged baseline so unrelated dirty changes are not mixed into the repo split.

**Tech Stack:** Git, GitHub CLI (`gh`), Nix flakes, Go modules, Nix `buildGoModule`, `orgm-dot` via `distrobox-host-exec`.

---

## File Structure

### New repo: `/home/osmarg/Hobby/nixos`

- `flake.nix` — Nix flake outputs for NixOS configurations and packages.
- `flake.lock` — lock file for reproducible builds.
- `nixos/**` — host configs, profiles, gaming modules, package derivations, Plymouth assets.
- `cmd/orgm-hypr/**` — Go entrypoint for Hyprland/system helper CLI; includes calendar subcommands.
- `cmd/orgm-dot/**` — Go entrypoint for dotfile manager package installed by NixOS.
- `internal/**` — Go implementation packages used by the CLIs.
- `tests/**` — Go/Bats/shell tests for the CLIs and system helpers.
- `go.mod` — module path for the new repo.
- `go.sum` — only if dependency resolution creates it.
- `README.md` — short repo purpose and common commands.

### Existing repo: `/home/osmarg/Hobby/dotfiles`

- Keep: `config/**`, `webapp/**`, `sddm/**`, `scripts/**`, `packages/**` if they are user-level scripts/assets, `AGENTS.md`, dotfile docs.
- Remove after migration: `flake.nix`, `flake.lock`, `nixos/**`, `cmd/**`, `internal/**`, Go-specific tests that moved to NixOS repo, `go.mod`, `go.sum`.
- Keep dotfiles references to installed commands (`orgm-hypr`, `orgm-dot`) as command names only; do not vendor their source.

---

### Task 1: Freeze Current Dotfiles Work Before Split

**Files:**
- Inspect: `git status --short`
- Commit or stash: current dotfiles changes such as `AGENTS.md`, wrapper deletions, and unrelated fish/config changes.

- [ ] **Step 1: Inspect current dirty state**

Run:

```bash
cd /home/osmarg/Hobby/dotfiles
git status --short
```

Expected: shows current modified/deleted files. Do not proceed if unrelated user work is mixed with the migration.

- [ ] **Step 2: Commit the completed wrapper/AGENTS changes separately**

Run:

```bash
cd /home/osmarg/Hobby/dotfiles
git add AGENTS.md \
  config/hosts/orgm/.config/fuzzel/fuzzel.env \
  config/hosts/lenovo/.config/fuzzel/fuzzel.env \
  config/hosts/orgm/.config/rofi/hypr-menu.env \
  config/shared/.local/bin
git commit -m "chore(dotfiles): remove orgm-hypr wrappers"
```

Expected: commit contains only AGENTS/current workflow comments plus legacy wrapper deletion.

- [ ] **Step 3: Isolate unrelated dirty work**

If unrelated changes remain, run either:

```bash
git stash push -u -m "pre-nixos-split-unrelated-work"
```

or commit them separately with an accurate message.

Expected: `git status --short` is empty before repository split work starts.

---

### Task 2: Create Public GitHub Repo Skeleton

**Files:**
- Create repo directory: `/home/osmarg/Hobby/nixos`
- Create remote: `https://github.com/osmargm1202/nixos.git`

- [ ] **Step 1: Ensure target directory does not already exist**

Run:

```bash
test ! -e /home/osmarg/Hobby/nixos
```

Expected: exits `0`. If it fails, inspect the existing directory before continuing.

- [ ] **Step 2: Create the public GitHub repo and local clone**

Run:

```bash
cd /home/osmarg/Hobby
gh repo create osmargm1202/nixos --public --clone
```

Expected: `/home/osmarg/Hobby/nixos` exists and `git remote -v` points to `github.com/osmargm1202/nixos`.

- [ ] **Step 3: Add a minimal README**

Create `/home/osmarg/Hobby/nixos/README.md`:

```markdown
# nixos

NixOS system configuration and ORGM system executables.

This repository owns:

- NixOS flake outputs and host profiles.
- `orgm-hypr`, including calendar/system helper commands.
- `orgm-dot`, the Nix-installed dotfile manager.

User dotfiles, desktop files, icons, and small scripts live in the separate `dotfiles` repository.
```

- [ ] **Step 4: Commit skeleton**

Run:

```bash
cd /home/osmarg/Hobby/nixos
git add README.md
git commit -m "docs: add repo purpose"
git push -u origin HEAD
```

Expected: public repo exists with README.

---

### Task 3: Copy NixOS and Go Sources Into New Repo

**Files:**
- Copy from dotfiles: `flake.nix`, `flake.lock`, `nixos/`, `cmd/`, `internal/`, `tests/`, `go.mod`, `go.sum` if present.
- Modify in new repo: `go.mod`.

- [ ] **Step 1: Copy source trees**

Run:

```bash
cd /home/osmarg/Hobby/dotfiles
rsync -a flake.nix flake.lock nixos cmd internal tests go.mod /home/osmarg/Hobby/nixos/
test ! -f go.sum || cp go.sum /home/osmarg/Hobby/nixos/go.sum
```

Expected: new repo has flake, NixOS modules, Go CLIs, internals, and tests.

- [ ] **Step 2: Change Go module path in new repo**

Modify `/home/osmarg/Hobby/nixos/go.mod` from:

```go
module github.com/osmarg/dotfiles/orgm-hypr
```

to:

```go
module github.com/osmargm1202/nixos
```

- [ ] **Step 3: Update Go import paths**

Run:

```bash
cd /home/osmarg/Hobby/nixos
rg -l 'github.com/osmarg/dotfiles/orgm-hypr' cmd internal tests | xargs sed -i 's#github.com/osmarg/dotfiles/orgm-hypr#github.com/osmargm1202/nixos#g'
```

Expected: no old module imports remain in copied Go source.

- [ ] **Step 4: Verify old import path is gone**

Run:

```bash
cd /home/osmarg/Hobby/nixos
! rg 'github.com/osmarg/dotfiles/orgm-hypr' cmd internal tests go.mod
```

Expected: command exits `0` with no matches.

---

### Task 4: Verify New NixOS Repo Builds

**Files:**
- Test: `/home/osmarg/Hobby/nixos`.

- [ ] **Step 1: Run Go tests**

Run:

```bash
cd /home/osmarg/Hobby/nixos
go test ./...
```

Expected: all Go tests pass.

- [ ] **Step 2: Build Nix packages**

Run:

```bash
cd /home/osmarg/Hobby/nixos
nix build .#orgm-hypr
nix build .#orgm-dot
```

Expected: both packages build.

- [ ] **Step 3: Check representative NixOS configs**

Run:

```bash
cd /home/osmarg/Hobby/nixos
nix flake check
```

Expected: flake evaluation passes. If full check is slow, at minimum run:

```bash
nix eval .#nixosConfigurations.orgm-hyprland.config.networking.hostName
nix eval .#packages.x86_64-linux.orgm-hypr.name
nix eval .#packages.x86_64-linux.orgm-dot.name
```

Expected outputs include `"orgm"`, `orgm-hypr`, and `orgm-dot`.

- [ ] **Step 4: Commit migrated source**

Run:

```bash
cd /home/osmarg/Hobby/nixos
git add flake.nix flake.lock nixos cmd internal tests go.mod go.sum README.md
git commit -m "feat: migrate NixOS system config"
git push
```

Expected: new public repo contains working NixOS flake and system executables.

---

### Task 5: Remove NixOS-Owned Sources From Dotfiles

**Files:**
- Remove from dotfiles: `flake.nix`, `flake.lock`, `nixos/`, `cmd/`, `internal/`, Go tests moved to NixOS repo, `go.mod`, `go.sum`.
- Keep in dotfiles: `config/**`, desktop/icon assets, scripts, dotfile docs.

- [ ] **Step 1: Remove migrated source from dotfiles**

Run:

```bash
cd /home/osmarg/Hobby/dotfiles
git rm -r flake.nix flake.lock nixos cmd internal tests go.mod
test ! -f go.sum || git rm go.sum
```

Expected: dotfiles no longer owns NixOS flake or Go CLI implementation.

- [ ] **Step 2: Check for broken source references**

Run:

```bash
cd /home/osmarg/Hobby/dotfiles
rg -n 'cmd/orgm|internal/|nixos/packages|flake.nix|orgm-hypr-source|github.com/osmarg/dotfiles/orgm-hypr' . \
  --glob '!docs/superpowers/plans/**' \
  --glob '!openspec/**' \
  --glob '!sdd-orchestrator/**' || true
```

Expected: only historical docs/specs may reference old locations. Active config should call installed commands (`orgm-hypr`, `orgm-dot`) but not repo source paths.

- [ ] **Step 3: Update active documentation if needed**

If `AGENTS.md` or active dotfile docs mention NixOS source ownership in dotfiles, edit them to say:

```markdown
NixOS system configuration and Go system executables live in `/home/osmarg/Hobby/nixos`.
This dotfiles repo owns user configuration, icons, desktop files, and scripts.
```

Expected: active docs reflect the new repo split.

- [ ] **Step 4: Verify dotfiles manifest still parses**

Run:

```bash
cd /home/osmarg/Hobby/dotfiles
python3 -m json.tool config/dotfiles.json >/dev/null
distrobox-host-exec orgm-dot status
```

Expected: JSON parses and `orgm-dot status` reports repo/destination normally.

- [ ] **Step 5: Commit dotfiles cleanup**

Run:

```bash
cd /home/osmarg/Hobby/dotfiles
git add -A
git commit -m "chore: move NixOS sources to nixos repo"
git push origin HEAD
```

Expected: dotfiles repo is smaller and no longer contains NixOS flake or Go CLI source.

---

### Task 6: Final Integration Check

**Files:**
- New repo: `/home/osmarg/Hobby/nixos`
- Existing repo: `/home/osmarg/Hobby/dotfiles`
- Host-installed commands: `orgm-hypr`, `orgm-dot`.

- [ ] **Step 1: Confirm commands come from NixOS host profile**

Run:

```bash
distrobox-host-exec sh -lc 'command -v orgm-hypr; command -v orgm-dot; orgm-hypr version; orgm-dot status | sed -n "1,12p"'
```

Expected: commands resolve under `/run/current-system/sw/bin` and run successfully.

- [ ] **Step 2: Confirm dotfiles has no stale wrapper/bin ownership**

Run:

```bash
cd /home/osmarg/Hobby/dotfiles
python3 - <<'PY'
import json
from pathlib import Path
cfg=json.load(open('config/dotfiles.json'))
for p in cfg['shared']['paths']:
    if p.startswith('.local/bin'):
        print(p)
PY
```

Expected: only intentional user scripts remain, not `orgm-hypr` wrappers or `orgm-calendar` bin entries.

- [ ] **Step 3: Check both repos are clean**

Run:

```bash
git -C /home/osmarg/Hobby/nixos status --short
git -C /home/osmarg/Hobby/dotfiles status --short
```

Expected: both outputs are empty after commits and pushes.

---

## Self-Review

- Spec coverage: plan creates public repo, moves `nixos/` and flakes, moves `orgm-hypr`/calendar and `orgm-dot` source into NixOS repo, and leaves dotfiles focused on config/assets/scripts.
- Placeholder scan: no TBD/TODO placeholders remain.
- Type/path consistency: source paths and target paths are explicit; module path changes are consistent across `go.mod`, `cmd`, `internal`, and `tests`.
