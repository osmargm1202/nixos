# Hyprland Resize and SteamCMD Image Downloader Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add easy keyboard resizing to both Hyprland profiles and a tested helper that downloads one Wallpaper Engine Workshop item and copies its image into `~/Pictures/Wallpapers/Steam`.

**Architecture:** Lua keybindings remain profile-local and invoke Hyprland's `resizeactive` dispatcher. A compositor-neutral Bash helper owns Workshop ID parsing, SteamCMD execution, image extraction, sanitization, and atomic copy; the existing wallpaper manager only watches the destination directory. Nix installs SteamCMD for both Hyprland profiles and Home Manager exposes the shared helper.

**Tech Stack:** Hyprland Lua configuration, Bash, SteamCMD, jq, NixOS modules, fixture-based shell tests.

## Global Constraints

- Keep existing resize bindings and mouse resize.
- Add `Super+Alt+Arrow` bindings to both Hyprland profiles with 40-pixel steps.
- Accept only a numeric Workshop ID or URL containing `id=<number>`.
- Use Wallpaper Engine app ID `431960`.
- Copy images to `${STEAM_WALLPAPER_DEST:-$HOME/Pictures/Wallpapers/Steam}`.
- Do not search Workshop, apply wallpapers, start Skwd, alter Skwd configuration, or store credentials/API keys.
- Use `${STEAMCMD_USER:-anonymous}`; SteamCMD owns authentication state.
- Preserve unrelated Herdr state files.

---

### Task 1: Add discoverable resize bindings to both profiles

**Files:**

- Create: `dotfiles/tests/helpers/hypr-resize-bindings.bats.sh`
- Modify: `dotfiles/config/profiles/hyprland/.config/hypr/lua/keybindings.lua`
- Modify: `dotfiles/config/profiles/hyprlandqs-caelestia/.config/hypr/lua/keybindings.lua`
- Modify: `dotfiles/config/profiles/hyprland/.local/bin/hypr-keybindings-help`

**Interfaces:**

- Produces four `Super+Alt+Arrow` bindings in each profile.

- [ ] **Step 1: Write failing structural test**

Create a strict Bash test that loops over both Lua files and requires these exact command fragments:

```text
ALT + left     resizeactive -40 0
ALT + right    resizeactive 40 0
ALT + up       resizeactive 0 -40
ALT + down     resizeactive 0 40
```

Also require `hypr-keybindings-help` to contain `Win+Alt+flechas` and retain existing minus/equal resize documentation.

- [ ] **Step 2: Run RED test**

Run: `bash dotfiles/tests/helpers/hypr-resize-bindings.bats.sh`

Expected: fail because `SUPER + ALT + left` is missing.

- [ ] **Step 3: Add bindings**

In both `M.setup` functions, after existing resize bindings, add:

```lua
hl.bind(mainMod .. " + ALT + left",  hl.dsp.exec_cmd("hyprctl dispatch resizeactive -40 0"), { repeating = true, description = "Resize: shrink width" })
hl.bind(mainMod .. " + ALT + right", hl.dsp.exec_cmd("hyprctl dispatch resizeactive 40 0"),  { repeating = true, description = "Resize: grow width" })
hl.bind(mainMod .. " + ALT + up",    hl.dsp.exec_cmd("hyprctl dispatch resizeactive 0 -40"), { repeating = true, description = "Resize: shrink height" })
hl.bind(mainMod .. " + ALT + down",  hl.dsp.exec_cmd("hyprctl dispatch resizeactive 0 40"),  { repeating = true, description = "Resize: grow height" })
```

The classic profile may use its local `dispatch()` helper instead of `hl.dsp.exec_cmd`, but resulting dispatcher arguments must match exactly.

Update help with one entry describing `Win+Alt+flechas`, and correct old entries to distinguish `Win+Ctrl+-/=` for width and `Win+Shift+-/=` for height.

- [ ] **Step 4: Run GREEN test and Lua syntax checks**

```bash
bash dotfiles/tests/helpers/hypr-resize-bindings.bats.sh
luac -p dotfiles/config/profiles/hyprland/.config/hypr/lua/keybindings.lua
luac -p dotfiles/config/profiles/hyprlandqs-caelestia/.config/hypr/lua/keybindings.lua
```

Expected: all exit zero.

- [ ] **Step 5: Commit resize bindings**

```bash
git add dotfiles/tests/helpers/hypr-resize-bindings.bats.sh \
  dotfiles/config/profiles/hyprland/.config/hypr/lua/keybindings.lua \
  dotfiles/config/profiles/hyprlandqs-caelestia/.config/hypr/lua/keybindings.lua \
  dotfiles/config/profiles/hyprland/.local/bin/hypr-keybindings-help
git commit -m "feat: add Hyprland arrow resize bindings"
```

---

### Task 2: Implement SteamCMD image downloader with fixtures

**Files:**

- Create: `dotfiles/config/shared/.local/bin/steam-workshop-image`
- Create: `dotfiles/tests/helpers/steam-workshop-image.bats.sh`

**Interfaces:**

- `steam-workshop-image URL_OR_ID` prints final copied image path.
- Environment: `STEAMCMD_USER`, `STEAM_ROOT`, `STEAM_WORKSHOP_ROOT`, `STEAM_WALLPAPER_DEST`.

- [ ] **Step 1: Write failing helper tests**

Create fake `steamcmd` in a temporary `PATH` that appends arguments to `$CALLS`. Add independent cases:

1. Invalid input exits nonzero and does not call SteamCMD.
2. Raw ID invokes `+workshop_download_item 431960 ID validate`.
3. URL input extracts the same ID.
4. Image-valued `project.json.file` is preferred over preview.
5. Scene/video project falls back to `project.json.preview`.
6. Title is sanitized into `<ID>-<title>.<ext>`.
7. No image exits nonzero and creates no destination.

Use `STEAM_ROOT="$TMP/steam"`, `STEAM_WORKSHOP_ROOT="$TMP/workshop"`, and `STEAM_WALLPAPER_DEST="$TMP/dest"` so tests never touch real Steam or wallpaper state.

- [ ] **Step 2: Run RED test**

Run: `bash dotfiles/tests/helpers/steam-workshop-image.bats.sh`

Expected: fail because helper is missing.

- [ ] **Step 3: Implement helper**

Use strict Bash mode. Normalize input with:

```bash
if [[ "$input" =~ ^[0-9]+$ ]]; then
  id="$input"
elif [[ "$input" =~ [\?\&]id=([0-9]+) ]]; then
  id="${BASH_REMATCH[1]}"
else
  fail "invalid Workshop ID or URL"
fi
```

Run:

```bash
steamcmd \
  +force_install_dir "$steam_root" \
  +login "$steam_user" \
  +workshop_download_item 431960 "$id" validate \
  +quit
```

Resolve item directory from `${STEAM_WORKSHOP_ROOT:-$steam_root/steamapps/workshop/content/431960}/$id`. Parse `project.json` using jq. Candidate selection order:

1. `.file` only when extension is jpg/jpeg/png/webp/gif.
2. `.preview` with the same extensions.
3. `preview.jpg`, `preview.jpeg`, `preview.png`, `preview.webp`, `preview.gif`.
4. First compatible image recursively, sorted.

Reject absolute paths and paths containing `..`; use `realpath -e` and require resolved candidate to remain under item directory. Sanitize title using lowercase-independent ASCII-safe replacement of non-alphanumeric runs with `-`, trim edge dashes, and fall back to ID only.

Create destination and copy atomically through a temporary file in the destination directory. Print final absolute path.

- [ ] **Step 4: Run GREEN tests and ShellCheck**

```bash
chmod +x dotfiles/config/shared/.local/bin/steam-workshop-image
bash dotfiles/tests/helpers/steam-workshop-image.bats.sh
nix shell nixpkgs#shellcheck -c shellcheck \
  dotfiles/config/shared/.local/bin/steam-workshop-image \
  dotfiles/tests/helpers/steam-workshop-image.bats.sh
```

Expected: tests print PASS and ShellCheck exits zero.

- [ ] **Step 5: Commit helper**

```bash
git add dotfiles/config/shared/.local/bin/steam-workshop-image \
  dotfiles/tests/helpers/steam-workshop-image.bats.sh
git commit -m "feat: download Steam Workshop images"
```

---

### Task 3: Install and deploy SteamCMD helper in Hyprland profiles

**Files:**

- Create: `tests/steamcmd-hypr-profile.bats.sh`
- Modify: `nixos/profiles/common_hyprland.nix`
- Modify: `nixos/common-dotfiles.nix`

**Interfaces:**

- Consumes helper from Task 2.
- Produces `steamcmd` in both Hyprland system closures and helper symlink for users.

- [ ] **Step 1: Write failing profile test**

Test structurally that `common_hyprland.nix` includes `steamcmd` and `sharedPaths` includes `.local/bin/steam-workshop-image`. Evaluate both orgm profiles and assert one system package store path matches `steamcmd`:

```bash
nix eval .#nixosConfigurations.orgm-hyprland.config.environment.systemPackages --json
nix eval .#nixosConfigurations.orgm-hyprlandqs-caelestia.config.environment.systemPackages --json
```

- [ ] **Step 2: Run RED test**

Run: `bash tests/steamcmd-hypr-profile.bats.sh`

Expected: fail because `steamcmd` is absent.

- [ ] **Step 3: Add Nix wiring**

Add `steamcmd` near other Hyprland media/tool packages in `common_hyprland.nix`. Add `.local/bin/steam-workshop-image` to `sharedPaths` near other shared user helpers in `common-dotfiles.nix`.

- [ ] **Step 4: Run GREEN test and LSP diagnostics**

Run profile test and Nix diagnostics for both changed modules. Expected: test passes and diagnostics are clean.

- [ ] **Step 5: Commit Nix wiring**

```bash
git add tests/steamcmd-hypr-profile.bats.sh \
  nixos/profiles/common_hyprland.nix nixos/common-dotfiles.nix
git commit -m "feat: install SteamCMD for Hyprland"
```

---

### Task 4: Validate both profiles and publish

**Files:**

- Modify only if verification exposes a defect in Task 1-3 files.

- [ ] **Step 1: Run focused tests**

```bash
bash dotfiles/tests/helpers/hypr-resize-bindings.bats.sh
bash dotfiles/tests/helpers/steam-workshop-image.bats.sh
bash tests/steamcmd-hypr-profile.bats.sh
```

- [ ] **Step 2: Run syntax/static checks**

```bash
luac -p dotfiles/config/profiles/hyprland/.config/hypr/lua/keybindings.lua
luac -p dotfiles/config/profiles/hyprlandqs-caelestia/.config/hypr/lua/keybindings.lua
nix shell nixpkgs#shellcheck -c shellcheck \
  dotfiles/config/shared/.local/bin/steam-workshop-image \
  dotfiles/tests/helpers/steam-workshop-image.bats.sh
```

- [ ] **Step 3: Build both orgm Hyprland profiles**

```bash
nix build .#nixosConfigurations.orgm-hyprland.config.system.build.toplevel --no-link
nix build .#nixosConfigurations.orgm-hyprlandqs-caelestia.config.system.build.toplevel --no-link
```

- [ ] **Step 4: Inspect and publish**

```bash
git diff --check
git status --short
git log --oneline -8
git push origin master
```

Expected: only pre-existing Herdr state remains dirty and master push succeeds.
