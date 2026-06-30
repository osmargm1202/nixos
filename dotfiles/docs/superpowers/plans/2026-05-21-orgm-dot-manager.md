# orgm-dot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `dot.sh` with a faster compiled Go binary named `orgm-dot` while preserving existing commands and keeping `dot`/`dot.sh` as compatibility launchers.

**Architecture:** `orgm-dot` is separate from `orgm-hypr` because dotfile sync is cross-host and not Hyprland-specific. Code is split by responsibility so sync, diff, config, path handling, and manifest mutation do not share one large file. Phase 1 ships read-only/status/diff parity first; sync/add/remove come after test coverage proves behavior.

**Tech Stack:** Go 1.23+, standard library only where possible, Nix `buildGoModule`, JSON config compatible with `config/dotfiles.json`, compatibility shell wrappers for `dot` and `dot.sh` after parity.

---

## Current command surface to preserve

```bash
dot diff --host HOST [--no-color|--porcelain]
dot sync --host HOST [--dry-run]
dot daemon --host HOST
dot add PATH (--shared|--host HOST)
dot remove PATH (--shared|--host HOST)
dot install
dot status --host HOST
```

Legacy flags must continue:

```bash
dot --diff --host HOST
dot --sync --host HOST
dot --daemon --host HOST
dot --install
dot --status --host HOST
dot --add PATH --shared
dot --remove PATH --host HOST
```

`DOT_SH_CONFIG=/path/to/dotfiles.json` remains supported for compatibility.

---

## File structure

### Create

- `cmd/orgm-dot/main.go` — CLI entrypoint only.
- `internal/dotcli/parse.go` — command/flag parser compatible with `dot.sh`.
- `internal/dotcli/usage.go` — usage and error formatting.
- `internal/dotconfig/config.go` — load/validate `config/dotfiles.json`.
- `internal/dotpaths/paths.go` — `~`, relative path, repo root, destination/source resolution.
- `internal/dotmanifest/manifest.go` — shared/host/local_only path lists and mutation helpers.
- `internal/dotdiff/diff.go` — diff calculation and output formatting.
- `internal/dotsync/sync.go` — sync/copy/delete behavior.
- `internal/dotadd/add.go` — add command behavior.
- `internal/dotdaemon/daemon.go` — git-head polling sync daemon.
- `tests/orgm-dot.bats.sh` — end-to-end fixture tests.
- `nixos/packages/orgm-dot.nix` — Nix package.

### Modify

- `nixos/common.nix` or relevant profile — install `orgm-dot` globally when safe.
- `config/shared/.local/bin/dot` — compatibility wrapper after parity.
- `config/shared/.local/bin/dot.sh` — compatibility wrapper after parity.
- `dot.sh` — keep as fallback until Go parity is trusted.

---

## Phase 0: Skeleton and packaging

**Goal:** Build `orgm-dot version` and package it in Nix without changing current dot behavior.

- [ ] Create `cmd/orgm-dot/main.go` with `version` and usage.
- [ ] Create parser package with tests for current command forms.
- [ ] Add `tests/orgm-dot.bats.sh` building binary into temp dir.
- [ ] Add `nixos/packages/orgm-dot.nix` using filtered source for `cmd`, `internal`, and `go.mod`.
- [ ] Add package to Nix common/system packages only after `nix build` works on host.
- [ ] Commit: `feat(dot): add orgm-dot skeleton`.

Validation:

```bash
go test ./...
bash tests/orgm-dot.bats.sh
```

---

## Phase 1: Config/status parity

**Goal:** Implement safe read-only commands first.

Commands:

```bash
orgm-dot status --host lenovo
orgm-dot diff --host lenovo --porcelain
```

Files:

- `internal/dotconfig/config.go`
- `internal/dotpaths/paths.go`
- `internal/dotmanifest/manifest.go`

Status output must match current `dot.sh status` fields:

```text
repo:
config:
destination:
shared src:
host src:
state dir:
host:
managed shared:
managed host:
```

Tests:

- fake repo fixture with temp home
- `DOT_SH_CONFIG` override
- missing host errors
- `~` expansion

Commit: `feat(dot): read dot config in orgm-dot`.

---

## Phase 2: Diff parity

**Goal:** Make `orgm-dot diff` match `dot.sh diff` output and be faster.

Behavior to preserve:

- `M DEST/path` when file exists and differs.
- `A DEST/path` when source exists and destination missing.
- `R DEST/path` when destination file exists but no managed source exists.
- `L DEST/path local-only` when verbose mode and local_only applies.
- `--porcelain` removes header.
- `--no-color` accepted.

Important implementation rule:

- Do not shell out to `diff`, `find`, or `jq`.
- Walk directories in Go.
- Compare file metadata first; compare bytes only when size/mtime suggests possible diff.
- Respect `local_only.paths` for exact paths and nested paths.

Tests:

- shared file add/modify/remove
- host override file add/modify/remove
- nested directory path
- local_only skip
- porcelain output

Commit: `feat(dot): implement fast diff`.

---

## Phase 3: Dry-run sync parity

**Goal:** Implement `sync --dry-run` without changing files.

Behavior:

- Show planned copy/delete changes similar enough to current `rsync --itemize-changes` for human review.
- Preserve local_only exclusions.
- Respect shared then host ordering.

Tests:

- dry-run reports add/modify/delete
- local_only excluded
- host files override shared files where both manage paths

Commit: `feat(dot): add dry-run sync`.

---

## Phase 4: Real sync parity

**Goal:** Replace rsync dependency for normal sync.

Behavior:

- Copy files and dirs recursively.
- Delete destination files absent from source inside managed dirs, except local_only.
- Preserve permissions and symlinks where current dot behavior does.
- Create destination parent dirs.
- Shared sync runs first, host sync second.
- Lock file prevents concurrent sync.

Tests:

- directory sync with delete
- file sync
- symlink preservation
- local_only preservation
- concurrent lock behavior

Commit: `feat(dot): implement sync`.

---

## Phase 5: add/remove parity

**Goal:** Manage config manifest and copy/remove source paths.

Commands:

```bash
orgm-dot add ~/.config/example --shared
orgm-dot add ~/.config/example --host lenovo
orgm-dot remove ~/.config/example --shared
orgm-dot remove ~/.config/example --host lenovo
```

Behavior:

- `add`: copy local path into shared/host source, remove from local_only, add path to selected list, sort/unique list.
- `remove`: remove source path, remove from shared/host list, add to local_only, preserve local destination.

Tests:

- add file shared
- add dir host
- remove file shared
- remove dir host
- JSON remains pretty/valid

Commit: `feat(dot): implement add and remove`.

---

## Phase 6: daemon/install compatibility

**Goal:** Provide drop-in runtime replacement.

Commands:

```bash
orgm-dot daemon --host lenovo
orgm-dot install
```

Daemon:

- poll git HEAD every `poll_seconds`
- sync when HEAD changes
- write/read state under configured `state_dir`

Install:

- create `~/.local/bin/dot` and `~/.local/bin/dot.sh` symlinks/wrappers pointing to `orgm-dot` or current binary
- do not break current `dot.sh` until user approves switch

Commit: `feat(dot): add daemon and install`.

---

## Phase 7: Wrapper switch

**Goal:** Route `dot` and `dot.sh` to `orgm-dot` after host validation.

Options:

### Safe wrapper

```sh
#!/bin/sh
if command -v orgm-dot >/dev/null 2>&1; then
  exec orgm-dot "$@"
fi
exec "$HOME/Hobby/dotfiles/dot.sh" "$@"
```

### Final wrapper

```sh
#!/bin/sh
exec orgm-dot "$@"
```

Use safe wrapper first.

Validation:

```bash
dot diff --host lenovo
dot sync --host lenovo --dry-run
dot status --host lenovo
```

Commit: `refactor(dot): route dot through orgm-dot`.

---

## Nix integration

Create `nixos/packages/orgm-dot.nix`:

```nix
{ lib, buildGoModule }:

buildGoModule {
  pname = "orgm-dot";
  version = "0.1.0";

  src = builtins.path {
    path = ../..;
    name = "orgm-dot-source";
    filter = path: type:
      let
        root = toString ../..;
        rel = lib.removePrefix "${root}/" (toString path);
      in
      rel == "go.mod"
      || rel == "cmd"
      || rel == "internal"
      || lib.hasPrefix "cmd/" rel
      || lib.hasPrefix "internal/" rel;
  };

  subPackages = [ "cmd/orgm-dot" ];
  vendorHash = null;

  meta = {
    description = "ORGM dotfile manager";
    mainProgram = "orgm-dot";
  };
}
```

Install in common Nix package set only after host build succeeds.

---

## Guardrails

- Do not delete `dot.sh` until all commands have test parity.
- Do not switch wrappers until `orgm-dot diff/sync --dry-run` matches `dot.sh` on real `lenovo` and `orgm`.
- Keep `orgm-dot` separate from `orgm-hypr`.
- Keep each subsystem in its own package/file to prevent mixed functions.
- Commit by phase.

---

## Recommended first execution

Start with Phase 0 + Phase 1 only:

1. skeleton CLI
2. parser tests
3. config/status parity
4. Nix package file, but not wrapper switch

This gives safe binary availability without changing actual sync behavior.
