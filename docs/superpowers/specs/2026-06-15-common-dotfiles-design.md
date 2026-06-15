# Common Dotfiles Nix Design

## Goal

Replace `orgm-dot` as the dotfile synchronization mechanism. NixOS will keep the dotfiles repository present and updated at `/home/osmarg/Hobby/dotfiles`, and Home Manager will expose the managed paths as live out-of-store symlinks.

## Current State

- Dotfiles source of truth lives in `https://github.com/osmargm1202/dotfiles.git` on branch `master`.
- Existing path inventory lives in `/home/osmarg/Hobby/dotfiles/config/dotfiles.json`.
- NixOS currently packages and installs `orgm-dot` from `inputs.dotfiles-orgm-source`.
- `orgm-dot` should no longer be required for synchronizing dotfiles.

## Architecture

Create `nixos/common-dotfiles.nix` and import it from `nixos/common.nix` so all hosts receive the same dotfiles behavior.

The module owns four concerns:

1. Keep `/home/osmarg/Hobby/dotfiles` cloned from GitHub master.
2. Keep the clone updated with fast-forward-only pulls.
3. Declare every shared and host-specific path from `dotfiles.json` in Nix.
4. Create Home Manager out-of-store symlinks from the live repo into the user's home directory.

## Repository Management

A NixOS oneshot service named `orgm-dotfiles-repo.service` will:

- create `/home/osmarg/Hobby` if needed;
- clone `https://github.com/osmargm1202/dotfiles.git` into `/home/osmarg/Hobby/dotfiles` if missing;
- fetch and `git pull --ff-only origin master` if the repo already exists;
- set ownership to the configured user;
- run before Home Manager activation when possible.

The service must never merge, rebase, or overwrite local changes. If a fast-forward pull fails, the service should fail visibly instead of destroying work.

## Dotfile Symlinks

Home Manager will create symlinks for:

- all entries in `shared.paths` from `dotfiles.json`;
- host-specific entries in `hosts.<hostname>.paths` when the current hostname has a matching set.

Each link maps:

- `~/<path>` -> `/home/osmarg/Hobby/dotfiles/config/shared/<path>` for shared paths;
- `~/<path>` -> `/home/osmarg/Hobby/dotfiles/config/hosts/<hostname>/<path>` for host paths.

Host-specific links override shared links for the same destination by using `lib.mkForce`.

Directory paths use recursive linking. File paths link directly. This keeps edits live: changing files in the dotfiles repo updates the active config without running `nh os switch`.

## Local-Only Handling

`local_only.paths`, `local_only.patterns`, and `local_only.types` from `dotfiles.json` are represented in Nix as excluded/documented values only. Nix must not link or modify local-only paths.

This protects secrets, generated state, caches, theme state, app runtime state, and machine-local files.

`local_defaults.paths` are not managed in this implementation.

## orgm-dot Removal Scope

The synchronization role of `orgm-dot` is removed. The package file can remain temporarily if other tooling still references it, but `environment.systemPackages` should stop installing `orgmDot` for dotfile synchronization.

Hyprland menu entries or scripts that call `orgm-dot` are out of scope for this change and should be handled by a separate cleanup task if they remain useful.

## Testing

Implementation must verify:

1. `nixos/common-dotfiles.nix` evaluates.
2. `nixos/common.nix` imports the module for all hosts.
3. Every path from `dotfiles.json` shared and hosts sections exists in the Nix module.
4. `local_only` entries are not linked.
5. `orgm-dot` is no longer installed as the sync mechanism.

Suggested commands:

```bash
cd /home/osmarg/Hobby/nixos
nix eval .#nixosConfigurations.orgm.config.system.build.toplevel.drvPath
```

A comparison script should parse `/home/osmarg/Hobby/dotfiles/config/dotfiles.json` and `nixos/common-dotfiles.nix` to detect missing shared or host paths.

## Deployment

Because this changes NixOS configuration, after implementation run:

```bash
orgm-diff
```

If the diff looks correct, run:

```bash
orgm-sync
```

The NixOS repo flake input for dotfiles must be kept aligned with the dotfiles repository head when lockfile updates are made.
