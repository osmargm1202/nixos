# Engram NixOS Install Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Install Engram CLI for user `osmarg` through existing NixOS/Home Manager config by wiring `nixos/home/engram.nix` into active NixOS hosts.

**Architecture:** Keep Engram user-scoped in Home Manager instead of adding a system package. Reuse the existing activation-time `go install github.com/Gentleman-Programming/engram/cmd/engram@latest` module until a pinned `buildGoModule` package is approved.

**Tech Stack:** NixOS flake, Home Manager NixOS module, Go toolchain from nixpkgs, host validation through `distrobox-host-exec`.

---

## Repo Pattern Notes

- `flake.nix` builds hosts through `mkHost` / `mkProfile`, always importing `./nixos/common.nix` for desktop hosts.
- `nixos/common.nix` owns Home Manager setup for `home-manager.users.osmarg`.
- `nixos/home/engram.nix` already defines Engram install behavior via Home Manager activation and `pkgs.go`.
- Do not implement `nixos/packages/engram.nix` in this task; `nixos/packages/engram-packaging-pending.md` says packaging needs trusted `src` hash and `vendorHash`.

## Exact Files

- Modify: `nixos/common.nix`
  - Responsibility: ensure `home-manager.users.osmarg.imports` includes `./home/engram.nix`.
- Inspect only: `nixos/home/engram.nix`
  - Responsibility: keep current activation install; no hash invention, no package rewrite.
- Inspect only: `flake.nix`
  - Responsibility: confirm target host output (`lenovo-labwc`, `lenovo-gnome`, `lenovo-hyprland`, or `lenovo-sway`) imports `nixos/common.nix` through `mkHost`.
- Do not touch: `nixos/server.nix`, `sddm/orgmos-sddm/Main.qml`, `nixos/packages/engram-packaging-pending.md` unless separate user approval exists.

## Tasks

### Task 1: Confirm current Engram module contract

**Files:**
- Inspect: `nixos/home/engram.nix`
- Inspect: `nixos/packages/engram-packaging-pending.md`

- [ ] Verify `nixos/home/engram.nix` contains:

```nix
{ lib, pkgs, ... }:

{
  home.packages = [ pkgs.go ];

  home.activation.installEngram = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "$HOME/.local/bin"
    if [ -z "''${DRY_RUN:-}" ]; then
      GOBIN="$HOME/.local/bin" GOPATH="$HOME/go" ${pkgs.go}/bin/go install github.com/Gentleman-Programming/engram/cmd/engram@latest
    fi
  '';
}
```

- [ ] If comments differ, leave comments alone unless they contradict this contract.
- [ ] If implementation differs, stop and ask whether to preserve current module or restore activation install.

### Task 2: Wire Engram into Home Manager user config

**Files:**
- Modify: `nixos/common.nix`

- [ ] Ensure this block exists exactly once in `nixos/common.nix`:

```nix
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.osmarg = {
    imports = [ ./home/engram.nix ];
    home.stateVersion = "25.11";
  };
```

- [ ] If `imports` already includes `./home/engram.nix`, make no code change.
- [ ] If `home-manager.users.osmarg` has other imports, preserve them and add `./home/engram.nix` once.

### Task 3: Validate Nix formatting and evaluation

**Files:**
- Validate: `nixos/common.nix`
- Validate: `nixos/home/engram.nix`
- Validate: `flake.nix`

- [ ] Format touched Nix files:

```bash
nix fmt nixos/common.nix nixos/home/engram.nix flake.nix
```

Expected: command exits `0`.

- [ ] Run pure flake validation from container if `nix` exists, else through host:

```bash
command -v nix >/dev/null && nix flake check --no-build -L || distrobox-host-exec bash -lc 'cd /home/osmarg/Hobby/nixos && nix flake check --no-build -L'
```

Expected: command exits `0`.

- [ ] Validate current host build without switching:

```bash
distrobox-host-exec bash -lc 'cd /home/osmarg/Hobby/nixos && sudo nixos-rebuild dry-build --flake .#lenovo-labwc -L'
```

Expected: command exits `0`; no system activation occurs.

### Task 4: Optional host switch and smoke test

**Files:**
- Runtime only; no source edits.

- [ ] Switch only after dry-build passes and user approves:

```bash
distrobox-host-exec bash -lc 'cd /home/osmarg/Hobby/nixos && sudo nixos-rebuild switch --flake .#lenovo-labwc -L'
```

Expected: command exits `0`.

- [ ] Open a new shell or source Home Manager profile, then verify Engram:

```bash
distrobox-host-exec bash -lc 'command -v engram && engram --help | head -n 20'
```

Expected: `command -v engram` prints a path, and help text prints without error.

### Task 5: Commit implementation

**Files:**
- Commit only implementation files changed by this task.

- [ ] Review changes:

```bash
git status --short
git diff -- nixos/common.nix nixos/home/engram.nix flake.nix
```

- [ ] Commit only Engram wiring:

```bash
git add nixos/common.nix nixos/home/engram.nix flake.nix
git commit -m "feat(nixos): install engram via home-manager"
```

- [ ] If only `nixos/common.nix` changed, stage only that file:

```bash
git add nixos/common.nix
git commit -m "feat(nixos): wire engram home module"
```

## Self-Review

- Spec coverage: plan wires existing `nixos/home/engram.nix` into current NixOS config; no package creation.
- Validation: includes `nix fmt`, `nix flake check --no-build`, `nixos-rebuild dry-build`, optional switch, and CLI smoke test.
- Commit plan: one focused implementation commit; unrelated current worktree changes stay untouched.
