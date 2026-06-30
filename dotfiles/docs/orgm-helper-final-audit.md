# ORGM helper final audit

Date: 2026-05-30

## Follow-up blocker fix

Diff review found a blocker: restored helper names existed, but many helper bodies were still thin wrappers around broad `orgm-hypr` commands. This follow-up restored real shell implementations directly from historical per-file commits, leaving the intentionally rewritten `config/shared/.local/bin/hypr-random-wallpaper` untouched.

Post-fix helper audit:

```bash
rg -n 'orgm-hypr' config/shared/.local/bin || true
```

Result: 0 matches in executable helper scripts.

Worktrees audited:

- Dotfiles: `/home/osmarg/Hobby/dotfiles/.worktrees/orgm-helper-restore`
- NixOS packaging: `/home/osmarg/Hobby/nixos/.worktrees/orgm-helper-packaging`

## Worktree safety

Both repositories were audited from linked worktrees, not master checkouts:

- Dotfiles branch: `orgm-helper-restore`
- NixOS branch: `orgm-helper-packaging`

No live `orgm-dot sync` was run. See [Sync readiness](#sync-readiness).

## `orgm-hypr` reference audit

Commands:

```bash
cd /home/osmarg/Hobby/dotfiles/.worktrees/orgm-helper-restore
rg -n 'orgm-hypr' config/shared docs tests || true

cd /home/osmarg/Hobby/nixos/.worktrees/orgm-helper-packaging
rg -n 'orgm-hypr' flake.nix nixos tests cmd internal docs || true
```

### Dotfiles result

Current active dotfiles paths are clean:

- `config/shared`: 0 matches
- `tests`: 0 matches
- `docs`: remaining matches are historical plans/specs and migration audit files

Classification:

| Class | Paths | Status |
| --- | --- | --- |
| Docs/history | `docs/superpowers/**`, `docs/orgm-hypr-callers-before-shell-restore.txt`, `docs/orgm-hypr-callers-deferred-after-shell-restore.txt` | Intentional documentation. Some caller-audit files are historical snapshots and do not reflect current active config. |
| Active config | `config/shared/**` | No remaining `orgm-hypr` refs found. |
| Tests | `tests/**` | No remaining `orgm-hypr` refs found. |
| Action needed | none in dotfiles active config | No live dotfile caller blocks sync readiness. |

### NixOS packaging result

Remaining `orgm-hypr` references are expected while the old package still exists in the NixOS companion worktree.

Classification:

| Class | Paths | Status |
| --- | --- | --- |
| Deferred old package | `cmd/orgm-hypr/**`, `internal/**`, `tests/orgm-hypr.bats.sh`, `nixos/packages/orgm-hypr.nix`, `flake.nix` | Intentional until broad package removal is handled in later NixOS cleanup. |
| Compatibility/data defaults | `internal/wallpaper/**`, `internal/calendar/**`, `internal/menu/**`, `internal/dock/**`, `internal/helper/**` | Old package internals and tests still name `orgm-hypr`; not active dotfiles callers. |
| Theme state/file names | `internal/theme/**` | Deferred theme namespace from old package; not part of Task 8 change. |
| Docs/history | `docs/superpowers/**` | Historical plans/specs. |
| Action needed | NixOS cleanup only | Remove/deprecate old `orgm-hypr` package after focused packages fully replace it. |

## Dotfiles verification

Command group:

```bash
bash tests/helpers/hypr-shell-helpers.bats.sh
bash tests/helpers/hypr-random-wallpaper.bats.sh
go test ./...
luac -p config/shared/.config/hypr/lua/*.lua
python -m json.tool config/shared/.config/swaync/config.json >/dev/null
distrobox-host-exec orgm-dot diff
```

Outcomes:

- `rg -n 'orgm-hypr' config/shared/.local/bin || true`: PASS, 0 matches after restoring real shell helpers.
- `bash -n` over shell helpers in `config/shared/.local/bin`: PASS.
- `bash tests/helpers/hypr-shell-helpers.bats.sh`: PASS (`hypr shell helper smoke tests passed`)
- `bash tests/helpers/hypr-random-wallpaper.bats.sh`: PASS (`hypr random wallpaper smoke test passed`)
- `go test ./...`: PASS
- `luac -p config/shared/.config/hypr/lua/*.lua`: PASS
- `python -m json.tool config/shared/.config/swaync/config.json >/dev/null`: PASS
- `distrobox-host-exec orgm-dot diff`: PASS, but sync deferred

## Sync readiness

`orgm-dot diff` output:

```text
orgm-dot diff --host lenovo
R  /home/osmarg/.local/bin/engram
R  /home/osmarg/.local/bin/orgmai
R  /home/osmarg/.local/bin/orgmos
R  /home/osmarg/.local/bin/orgmweb
```

Decision: `distrobox-host-exec orgm-dot sync` was skipped.

Reasons:

- This is a feature worktree that has not been merged.
- Diff is small, but removal-only entries for `engram`, `orgmai`, `orgmos`, and `orgmweb` were not part of Task 8 intent.
- Live sync should happen after branch integration or after a separate review confirms these removals are intended.

## NixOS package verification

Commands were run with the dotfiles worktree override:

```bash
distrobox-host-exec nix build .#orgm-wallpaper --override-input dotfiles-orgm-source path:/home/osmarg/Hobby/dotfiles/.worktrees/orgm-helper-restore --no-link
distrobox-host-exec nix build .#orgm-calendar --override-input dotfiles-orgm-source path:/home/osmarg/Hobby/dotfiles/.worktrees/orgm-helper-restore --no-link
distrobox-host-exec nix build .#orgm-dot --override-input dotfiles-orgm-source path:/home/osmarg/Hobby/dotfiles/.worktrees/orgm-helper-restore --no-link
```

Outcomes:

- `.#orgm-wallpaper`: PASS
- `.#orgm-calendar`: PASS
- `.#orgm-dot`: PASS

Nix printed expected lock-file warnings because `--override-input` used a local path and `--no-link` avoided result links. No lock file was written.

## Manual smoke checks

Status: NOT RUN in this SDD execution; requires interactive Hyprland session after branch integration/sync/rebuild.

Deferred checklist:

- [ ] Hypr main menu opens.
- [ ] Power menu opens.
- [ ] Waybar date/time render.
- [ ] Waybar swap renders.
- [ ] Workspace buttons render and click.
- [ ] Volume/mic/brightness OSD shows notifications.
- [ ] Wallpaper picker opens and thumbnails load quickly.
- [ ] `hypr-random-wallpaper next` changes wallpaper.
- [ ] `hypr-random-wallpaper daemon` keeps one daemon and uses 30-minute default interval.
- [ ] Calendar daemon starts and does not duplicate notifications.
- [ ] `orgm-dot diff` and `orgm-dot sync` work from host.

## Final concerns

- Live sync remains deferred for safety.
- Dotfiles active config and helper scripts have no `orgm-hypr` refs.
- NixOS worktree still contains the deferred broad `orgm-hypr` package and compatibility internals; cleanup belongs to later NixOS package removal work.
