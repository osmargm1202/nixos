# Minimal i3 Profile Implementation Plan

**Goal:** Replace the current Polybar/Picom/Conky i3 desktop with portable i3bar+i3status, persistent Feh wallpaper selection, Nautilus integration, and Dunst N1-N3 notifications.

**Constraint:** Do not run full Nix builds or broad CPU-intensive evaluations. The user performs final build and boot validation.

---

## Task 1: Contract the minimal profile

**Files:**

- Modify `tests/i3-profile.bats.sh`
- Modify `dotfiles/tests/helpers/i3-shell-helpers.bats.sh`
- Modify `nixos/profiles/i3.nix`
- Modify `nixos/common-dotfiles.nix`
- Modify `dotfiles/config/dotfiles.json`
- Modify `dotfiles/config/profiles/i3/.config/i3/config`
- Delete i3 Picom, Polybar, and Conky paths and obsolete helpers

1. Add static failing assertions rejecting Picom, Polybar, Conky, Waybar, and `hypr-*` references.
2. Require a native `bar`, `status_command i3status`, `tray_output primary`, and the selected three applets.
3. Require removed helper and dotfile paths to be absent.
4. Observe RED.
5. Remove packages, startup commands, deployment entries, files, and obsolete helper tests.
6. Add the native bar and observe GREEN with static checks.

## Task 2: Persistent wallpaper and Nautilus action

**Files:**

- Create `dotfiles/config/profiles/i3/.local/bin/i3-wallpaper`
- Delete `dotfiles/config/profiles/i3/.local/bin/i3-wallpaper-random`
- Create `dotfiles/config/profiles/i3/.local/share/nautilus/scripts/Set as Wallpaper`
- Modify i3 config, common-dotfiles deployment, and helper tests

1. Write failing fixture tests for `--set`, `--restore`, random fallback, invalid files, and Nautilus delegation.
2. Implement one helper owning validation, Feh application, and state persistence.
3. Change i3 startup to `i3-wallpaper --restore`.
4. Add executable Nautilus script that accepts exactly one local path and calls `i3-wallpaper --set`.
5. Run fixture tests and shell syntax checks.

## Task 3: Dunst controls and shared OSD

**Files:**

- Modify `dotfiles/config/profiles/i3/.config/dunst/dunstrc`
- Move `volume-osd` and `mic-volume-osd` from Hyprland profile to shared dotfiles
- Modify i3 keybindings and common-dotfiles deployment
- Modify helper tests

1. Add failing assertions for portable Dunst commands, no `/home/osmar`, enabled progress bar, history/DND bindings, and shared OSD paths.
2. Correct Dunst configuration.
3. Bind audio keys to shared OSD helpers.
4. Bind `Mod+N` to `dunstctl history-pop` and `Mod+Shift+N` to DND toggle.
5. Move OSD helpers to shared ownership while preserving current live links until deployment.
6. Run static and shell checks.

## Task 4: Exclude G213 on Lenovo

**Files:**

- Modify `nixos/common-dotfiles.nix`
- Add or extend a static contract

1. Add failing assertion requiring `openrgb-notify` to be disabled when `hostName == "lenovo"`.
2. Guard the user service with `lib.mkIf (hostName != "lenovo")`.
3. Keep service behavior unchanged on other hosts.
4. Run static contract and Nix LSP diagnostics.

## Task 5: Final review and publication

1. Run focused static contracts, shell syntax, JSON/TOML validation, LSP, and `git diff --check`.
2. Confirm unrelated dirty files and build result symlink remain untouched.
3. Review `master...HEAD` against the approved design.
4. Commit and push source changes.
5. User runs `nh os build/boot -H lenovo-i3`, reboots, and validates i3bar, i3status, tray, wallpaper restore, Nautilus action, Dunst controls, and OSD.
