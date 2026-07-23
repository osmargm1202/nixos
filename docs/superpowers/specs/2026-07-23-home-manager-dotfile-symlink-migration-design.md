# Home Manager Dotfile Symlink Migration Design

## Problem

Commit `4e67c5da` changed Kitty and Yazi from directory-level Home Manager links to links for selected files so runtime-owned theme files could remain writable. Existing machines still had `~/.config/kitty` and `~/.config/yazi` linked to an older Home Manager generation. During the next activation, Home Manager traversed those parent links and replaced files in the dotfiles repository, creating symbolic-link cycles.

Kitty now fails with `OSError: [Errno 40] Too many levels of symbolic links`. Yazi configuration and flavor links show the same corruption pattern.

## Goals

- Recover tracked Kitty and Yazi source files from Git.
- Preserve runtime-owned theme files and real directories.
- Remove legacy directory-level links safely.
- Prevent the same migration failure on machines upgrading from an older generation.
- Stop before running `nh os switch`; the user will run that command.

## Non-goals

- Redesign Kitty or Yazi configuration.
- Change theme generation behavior.
- Clean unrelated untracked files or repository changes.
- Revert to directory-level Home Manager links.

## Design

### Migration activation

Add a Home Manager activation step before link target checking and link generation. For each migrated path (`.config/kitty` and `.config/yazi`), it inspects the path under `$HOME`.

The step removes the path only when all conditions hold:

1. The path itself is a symbolic link.
2. Its immediate target is under `/nix/store/`.
3. The target belongs to a Home Manager files generation.

It then creates a real parent directory. Existing real directories are left untouched. Unexpected links produce an explicit error instead of being deleted.

This makes migration idempotent: once the real directory exists, later activations perform no destructive action.

### Source recovery

Restore only tracked files currently changed from regular files to symbolic links:

- `dotfiles/config/shared/.config/kitty/kitty.conf`
- `dotfiles/config/shared/.config/yazi/keymap.toml`
- `dotfiles/config/shared/.config/yazi/package.toml`
- `dotfiles/config/shared/.config/yazi/yazi.toml`

Recover their `HEAD` contents without resetting unrelated work. Runtime files such as Kitty `current-theme.conf`, Kitty `skwd-theme.conf`, Yazi `theme.toml`, and user-installed flavors remain untouched unless a generated cyclic link must be removed as part of local recovery.

### Local recovery before activation

Because current parent links point to an old Home Manager generation, remove only the two verified legacy parent links in `$HOME`, then create real directories. Afterward, source recovery can be reflected by Home Manager on the next switch without traversing stale parents.

### Failure handling

- Never recursively delete a real directory.
- Never remove a symlink whose immediate target is outside the Nix store or does not look Home Manager-managed.
- Abort migration with a useful message on an unexpected link.
- Leave unrelated working-tree changes untouched.

## Testing

Extend or add Bats coverage to prove:

1. The activation migration is ordered before Home Manager link checking/generation.
2. A legacy Home Manager directory symlink is removed and replaced with a real directory.
3. A real directory is preserved.
4. An unexpected user-managed symlink is rejected or preserved.
5. The selected Kitty/Yazi paths remain file-level links in `sharedPaths`.
6. Runtime-owned theme paths remain excluded from Home Manager ownership.

Before requesting the system switch:

- Run focused Bats tests.
- Run repository validation applicable to the changed Nix file.
- Confirm tracked Kitty/Yazi source files are regular files.
- Confirm no symlink cycles remain in the source tree.
- Run `kitty --config NONE` only as a binary/display control if needed; final normal Kitty verification occurs after the user runs `nh os switch`.

## Rollout

1. Commit this design document independently.
2. Add failing tests.
3. Implement migration activation.
4. Recover local source files and parent directories.
5. Run pre-switch verification.
6. Ask user to execute `nh os switch`.
7. After switch, verify Kitty and Yazi behavior and repository state.
