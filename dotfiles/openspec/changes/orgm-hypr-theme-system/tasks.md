# Tasks: orgm-hypr-theme-system

## Status

planned

## Gate 0: approval

- [ ] User approves proposal/spec/design before implementation.
- [ ] Confirm whether artifact name should be `themes.json` or Spanish `temas.json` in user-facing docs. Recommended: file `themes.json`, UI label `Temas`.
- [ ] Confirm first implementation slice despite full Phase 1 goal; recommend schema + core engine first to keep review sane.

## Slice 1: schema and neutral theme

- [ ] RED: add tests for theme registry loader and validation.
- [ ] Add `internal/theme` package with registry structs.
- [ ] Add `orgm-hypr theme list|validate|status` command stubs.
- [ ] Create `config/shared/.config/orgm-hypr/themes.json` with `neutral` dark/light data from current config.
- [ ] Update `config/dotfiles.json` if `.config/orgm-hypr` is new.
- [ ] GREEN: tests pass for validation/list/status.

## Slice 2: plan, dry-run, atomic writer

- [ ] RED: tests for apply plan and dry-run output.
- [ ] Implement palette resolver for dark/light/auto fallback.
- [ ] Implement target plan model.
- [ ] Implement atomic writer with generated-file guard.
- [ ] Implement `theme preview` and `theme apply --dry-run`.
- [ ] GREEN: dry-run never writes; invalid target fails clearly.

## Slice 3: core desktop targets

- [ ] RED: renderer tests for Hyprland, Waybar, nwg-dock, GTK, Qt.
- [ ] Implement Hyprland generated palette output compatible with current Lua/hyprlang setup.
- [ ] Implement Waybar theme CSS output.
- [ ] Implement nwg-dock CSS output.
- [ ] Implement GTK 3/4 settings/CSS output.
- [ ] Implement Qt 5/6 color/config output.
- [ ] Add reload hooks and warnings.
- [ ] GREEN: representative rendered files match snapshots.

## Slice 4: app targets

- [ ] RED: renderer tests for Fuzzel/Rofi, Kitty, Yazi, Helix, Kvantum/KDE.
- [ ] Implement launcher colors.
- [ ] Implement Kitty theme include.
- [ ] Implement Yazi/Helix theme outputs or safe pointers.
- [ ] Implement Kvantum/KDE best-effort outputs where current config exists.
- [ ] GREEN: target plans include warnings for absent configs.

## Slice 5: browser export targets

- [x] RED: Chromium manifest generation test.
- [x] Implement Chromium theme export directory with manifest and optional wallpaper asset.
- [x] Implement Zen Browser best-effort export notes/files, no profile mutation by default.
- [x] Add docs for manual load/restart and profile safety.
- [x] GREEN: browser exporters never mutate profiles unless configured.

## Slice 6: verification and docs

- [ ] Update docs with theme workflow and HyDE adaptation notes.
- [ ] Run `go test ./...`.
- [ ] Run `tests/orgm-hypr.bats.sh`.
- [ ] Run `nix flake check` if practical.
- [ ] Run `orgm-dot diff --host orgm` after managed dotfile changes.
- [ ] Create verify report before any commit/PR.

## Phase 2 placeholder: Quickshell selector

- [ ] Design UI after CLI engine stabilizes.
- [ ] Read registry/status JSON.
- [ ] Trigger `orgm-hypr theme apply` only; no duplicated apply logic.
