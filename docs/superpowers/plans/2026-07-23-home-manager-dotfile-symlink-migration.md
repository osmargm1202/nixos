# Home Manager Dotfile Symlink Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Recover Kitty and Yazi from cyclic links and make Home Manager safely migrate legacy directory-level links before deploying file-level links.

**Architecture:** A standalone shell helper owns safe, idempotent directory-link migration and is directly testable with temporary homes. `nixos/common-dotfiles.nix` packages that helper and runs it before existing Home Manager conflict cleanup. Local recovery uses the same helper, restores only corrupted tracked paths from `HEAD`, and preserves runtime-generated configuration.

**Tech Stack:** NixOS, Home Manager activation DAG, Bash, repository shell tests, Git.

## Global Constraints

- Never recursively delete a real directory.
- Never remove a symlink unless its immediate target matches `/nix/store/*-home-manager-files/<relative-path>`.
- Preserve runtime-owned Kitty and Yazi theme files.
- Leave unrelated working-tree changes untouched.
- Do not execute `nh os switch`; stop and ask the user to run it.

---

### Task 1: Add Tested Legacy Directory Migration

**Files:**

- Create: `nixos/scripts/migrate-home-manager-dotfile-dirs.sh`
- Create: `tests/home-manager-dotfile-dir-migration.bats.sh`
- Modify: `nixos/common-dotfiles.nix:8-45,698-738`

**Interfaces:**

- Consumes: `$HOME`; relative configuration paths as positional arguments.
- Produces: `migrate-home-manager-dotfile-dirs PATH...`, which replaces verified legacy Home Manager directory symlinks with real directories, preserves real directories, and exits nonzero without removing unexpected links.

- [ ] **Step 1: Write failing behavior and integration test**

Create `tests/home-manager-dotfile-dir-migration.bats.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/nixos/scripts/migrate-home-manager-dotfile-dirs.sh"
MODULE="$ROOT/nixos/common-dotfiles.nix"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[ -x "$SCRIPT" ] || fail 'migration helper must be executable'

export HOME="$TMP/home"
mkdir -p "$HOME/.config"
ln -s /nix/store/test-home-manager-files/.config/kitty "$HOME/.config/kitty"
ln -s /nix/store/test-home-manager-files/.config/yazi "$HOME/.config/yazi"
"$SCRIPT" .config/kitty .config/yazi
[ -d "$HOME/.config/kitty" ] && [ ! -L "$HOME/.config/kitty" ] ||
  fail 'legacy Kitty link must become a real directory'
[ -d "$HOME/.config/yazi" ] && [ ! -L "$HOME/.config/yazi" ] ||
  fail 'legacy Yazi link must become a real directory'

printf 'keep\n' >"$HOME/.config/kitty/runtime-theme.conf"
"$SCRIPT" .config/kitty
[ "$(cat "$HOME/.config/kitty/runtime-theme.conf")" = keep ] ||
  fail 'real directories and runtime files must be preserved'

ln -s "$TMP/user-managed" "$HOME/.config/unexpected"
if "$SCRIPT" .config/unexpected 2>"$TMP/error"; then
  fail 'unexpected links must be rejected'
fi
[ -L "$HOME/.config/unexpected" ] || fail 'unexpected link must remain untouched'
grep -Fq 'Refusing to remove unexpected symlink' "$TMP/error" ||
  fail 'unexpected link rejection must explain the problem'

grep -Fq 'home.activation.migrateLegacyDotfileDirectories' "$MODULE" ||
  fail 'Home Manager must register the migration activation'
grep -Fq 'lib.hm.dag.entryBefore [ "removeConflictingDotfiles" ]' "$MODULE" ||
  fail 'migration must run before existing link-target cleanup'
grep -Fq '.config/kitty .config/yazi' "$MODULE" ||
  fail 'activation must migrate Kitty and Yazi'

printf 'PASS: legacy Home Manager directory links migrate safely\n'
```

- [ ] **Step 2: Run test to verify failure**

Run:

```bash
bash tests/home-manager-dotfile-dir-migration.bats.sh
```

Expected: `FAIL: migration helper must be executable`.

- [ ] **Step 3: Implement minimal standalone migration helper**

Create executable `nixos/scripts/migrate-home-manager-dotfile-dirs.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

for relative_path in "$@"; do
  target="$HOME/$relative_path"

  if [ -L "$target" ]; then
    link_target="$(readlink "$target")"
    case "$link_target" in
      /nix/store/*-home-manager-files/"$relative_path")
        rm "$target"
        ;;
      *)
        printf 'Refusing to remove unexpected symlink: %s -> %s\n' \
          "$target" "$link_target" >&2
        exit 1
        ;;
    esac
  fi

  if [ ! -e "$target" ] && [ ! -L "$target" ]; then
    mkdir -p "$target"
  fi
done
```

Run:

```bash
chmod +x nixos/scripts/migrate-home-manager-dotfile-dirs.sh
```

- [ ] **Step 4: Package helper and order activation before conflict cleanup**

Add near other top-level helper packages in `nixos/common-dotfiles.nix`:

```nix
  migrateHomeManagerDotfileDirs = pkgs.writeShellApplication {
    name = "migrate-home-manager-dotfile-dirs";
    runtimeInputs = [ pkgs.coreutils ];
    text = builtins.readFile ./scripts/migrate-home-manager-dotfile-dirs.sh;
  };
```

Add before `home.activation.removeConflictingDotfiles`:

```nix
      home.activation.migrateLegacyDotfileDirectories =
        lib.hm.dag.entryBefore [ "removeConflictingDotfiles" ] ''
          $DRY_RUN_CMD ${migrateHomeManagerDotfileDirs}/bin/migrate-home-manager-dotfile-dirs \
            .config/kitty .config/yazi
        '';
```

- [ ] **Step 5: Run focused tests**

Run:

```bash
bash tests/home-manager-dotfile-dir-migration.bats.sh
bash tests/matugen-runtime-themes.bats.sh
```

Expected:

```text
PASS: legacy Home Manager directory links migrate safely
PASS: Kitty and Yazi load runtime-owned Matugen themes
```

- [ ] **Step 6: Run source diagnostics**

Run LSP diagnostics on `nixos/common-dotfiles.nix`, then:

```bash
nix-instantiate --parse nixos/common-dotfiles.nix >/dev/null
git diff --check
```

Expected: no parse errors or whitespace errors.

- [ ] **Step 7: Commit implementation**

```bash
git add nixos/scripts/migrate-home-manager-dotfile-dirs.sh \
  tests/home-manager-dotfile-dir-migration.bats.sh \
  nixos/common-dotfiles.nix
git commit -m "fix(home-manager): migrate legacy dotfile directory links"
```

### Task 2: Recover Current Kitty and Yazi State

**Files:**

- Restore from `HEAD`: `dotfiles/config/shared/.config/kitty/kitty.conf`
- Restore from `HEAD`: `dotfiles/config/shared/.config/yazi/flavors`
- Restore from `HEAD`: `dotfiles/config/shared/.config/yazi/keymap.toml`
- Restore from `HEAD`: `dotfiles/config/shared/.config/yazi/package.toml`
- Restore from `HEAD`: `dotfiles/config/shared/.config/yazi/yazi.toml`
- Preserve/move runtime state under: `~/.config/kitty`, `~/.config/yazi`

**Interfaces:**

- Consumes: migration helper from Task 1 and tracked contents from `HEAD`.
- Produces: real home configuration directories and regular tracked source files without symlink cycles.

- [ ] **Step 1: Preserve runtime-owned files outside source directories**

Create temporary backup and copy only existing runtime-owned files:

```bash
runtime_backup="$(mktemp -d)"
for relative in \
  .config/kitty/current-theme.conf \
  .config/kitty/skwd-theme.conf \
  .config/kitty/orgm-hypr-theme.conf \
  .config/yazi/theme.toml; do
  source_path="dotfiles/config/shared/$relative"
  if [ -f "$source_path" ]; then
    mkdir -p "$runtime_backup/$(dirname "$relative")"
    cp -a "$source_path" "$runtime_backup/$relative"
  fi
done
printf '%s\n' "$runtime_backup"
```

Expected: backup path printed; no tracked files changed.

- [ ] **Step 2: Migrate current parent links with tested helper**

```bash
nixos/scripts/migrate-home-manager-dotfile-dirs.sh .config/kitty .config/yazi
```

Expected: `~/.config/kitty` and `~/.config/yazi` become real directories.

- [ ] **Step 3: Restore runtime-owned files into real home directories**

Using the `runtime_backup` value from Step 1:

```bash
if [ -d "$runtime_backup/.config" ]; then
  cp -a "$runtime_backup/.config/." "$HOME/.config/"
fi
```

Expected: existing runtime theme files remain available under `$HOME/.config`.

- [ ] **Step 4: Replace cyclic source links with tracked contents only**

```bash
rm -f dotfiles/config/shared/.config/kitty/kitty.conf
git restore --source=HEAD --worktree -- \
  dotfiles/config/shared/.config/kitty/kitty.conf

rm -f \
  dotfiles/config/shared/.config/yazi/flavors \
  dotfiles/config/shared/.config/yazi/keymap.toml \
  dotfiles/config/shared/.config/yazi/package.toml \
  dotfiles/config/shared/.config/yazi/yazi.toml
git restore --source=HEAD --worktree -- \
  dotfiles/config/shared/.config/yazi/flavors \
  dotfiles/config/shared/.config/yazi/keymap.toml \
  dotfiles/config/shared/.config/yazi/package.toml \
  dotfiles/config/shared/.config/yazi/yazi.toml
```

Expected: paths match `HEAD`; unrelated paths remain untouched.

- [ ] **Step 5: Remove backup after comparison**

```bash
for relative in \
  .config/kitty/current-theme.conf \
  .config/kitty/skwd-theme.conf \
  .config/kitty/orgm-hypr-theme.conf \
  .config/yazi/theme.toml; do
  if [ -f "$runtime_backup/$relative" ]; then
    cmp "$runtime_backup/$relative" "$HOME/$relative"
  fi
done
rm -rf "$runtime_backup"
```

Expected: every backed-up runtime file matches its home destination.

### Task 3: Verify Pre-switch State and Hand Off

**Files:**

- Verify: `nixos/common-dotfiles.nix`
- Verify: `nixos/scripts/migrate-home-manager-dotfile-dirs.sh`
- Verify: Kitty/Yazi source and home paths

**Interfaces:**

- Consumes: completed implementation and recovered local state.
- Produces: evidence that repository and filesystem are ready for the user-run `nh os switch`.

- [ ] **Step 1: Run focused and regression tests**

```bash
bash tests/home-manager-dotfile-dir-migration.bats.sh
bash tests/matugen-runtime-themes.bats.sh
```

Expected: both print `PASS`.

- [ ] **Step 2: Verify link topology and tracked file types**

```bash
for path in \
  dotfiles/config/shared/.config/kitty/kitty.conf \
  dotfiles/config/shared/.config/yazi/keymap.toml \
  dotfiles/config/shared/.config/yazi/package.toml \
  dotfiles/config/shared/.config/yazi/yazi.toml; do
  [ -f "$path" ] && [ ! -L "$path" ] || exit 1
done
[ -d dotfiles/config/shared/.config/yazi/flavors ] &&
  [ ! -L dotfiles/config/shared/.config/yazi/flavors ]
[ -d "$HOME/.config/kitty" ] && [ ! -L "$HOME/.config/kitty" ]
[ -d "$HOME/.config/yazi" ] && [ ! -L "$HOME/.config/yazi" ]
realpath -e dotfiles/config/shared/.config/kitty/kitty.conf
realpath -e dotfiles/config/shared/.config/yazi/yazi.toml
```

Expected: all checks exit zero; `realpath` resolves directly into the repository.

- [ ] **Step 3: Check diagnostics and repository scope**

Run LSP diagnostics on changed source files, then:

```bash
nix-instantiate --parse nixos/common-dotfiles.nix >/dev/null
git diff --check
git status --short
```

Expected: no diagnostics, parse failures, or whitespace errors. Status may retain pre-existing icon and Herd changes but no Kitty/Yazi type changes.

- [ ] **Step 4: Stop before system activation**

Do not run `nh os switch`. Tell the user exactly:

```text
Implementación y recuperación listas. Ejecuta: nh os switch
```

After the user runs it, verify normal `kitty` startup and `yazi --debug` or equivalent configuration loading.
