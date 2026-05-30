# ORGM helper packaging staging note

This NixOS branch consumes focused ORGM Go helpers from the separate dotfiles repo through the `dotfiles-orgm-source` flake input.

During this staged migration, the dotfiles helper branch is local/unpublished, so `flake.lock` is intentionally not updated here. Locking now would either:

- pin current `github:osmargm1202/dotfiles` main, which does not contain `cmd/orgm-wallpaper`, `cmd/orgm-calendar`, and `cmd/orgm-dot`; or
- pin a local worktree path, which is not portable.

Use an override while testing this branch:

```bash
distrobox-host-exec nix build .#orgm-wallpaper --override-input dotfiles-orgm-source path:/home/osmarg/Hobby/dotfiles/.worktrees/orgm-helper-restore --no-link
distrobox-host-exec nix build .#orgm-calendar --override-input dotfiles-orgm-source path:/home/osmarg/Hobby/dotfiles/.worktrees/orgm-helper-restore --no-link
distrobox-host-exec nix build .#orgm-dot --override-input dotfiles-orgm-source path:/home/osmarg/Hobby/dotfiles/.worktrees/orgm-helper-restore --no-link
```

After the dotfiles helper branch is merged or pushed to a stable ref, update `flake.lock` so `dotfiles-orgm-source` points to a revision containing the focused Go helpers.
