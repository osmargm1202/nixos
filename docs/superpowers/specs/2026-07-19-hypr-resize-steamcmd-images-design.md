# Hyprland resize bindings and SteamCMD image downloader

## Goal

Add discoverable keyboard resizing to both Hyprland profiles and provide a focused SteamCMD helper that downloads a Wallpaper Engine Workshop item, extracts an image, and copies it into the wallpaper directory already managed by Skwd.

## Scope

- Add `Super+Alt+Arrow` resize bindings to `hyprland` and `hyprlandqs-caelestia`.
- Keep existing resize bindings and mouse resize behavior.
- Install `steamcmd` for both Hyprland profiles through `common_hyprland.nix`.
- Create a compositor-neutral helper named `steam-workshop-image`.
- Accept a numeric Workshop item ID or a Steam Workshop URL containing `id=<number>`.
- Copy one compatible image to `~/Pictures/Wallpapers/Steam`.
- Let the existing wallpaper manager detect and manage the copied image.

## Resize bindings

Both Lua keybinding files will define:

| Binding | Action |
| --- | --- |
| `Super+Alt+Left` | Reduce active window width by 40 pixels |
| `Super+Alt+Right` | Increase active window width by 40 pixels |
| `Super+Alt+Up` | Reduce active window height by 40 pixels |
| `Super+Alt+Down` | Increase active window height by 40 pixels |

Existing `Super+Ctrl+-/=`, `Super+Shift+-/=` and `Super+right mouse` bindings remain available. The classic Hyprland keybinding helper will document both keyboard schemes.

## SteamCMD downloader

Command:

```bash
steam-workshop-image URL_OR_ID
```

Examples:

```bash
steam-workshop-image 1234567890
steam-workshop-image 'https://steamcommunity.com/sharedfiles/filedetails/?id=1234567890'
```

The helper will:

1. Validate and normalize the numeric Workshop ID.
2. Require `steamcmd`, `jq`, `find`, and standard core utilities.
3. Use Wallpaper Engine app ID `431960`.
4. Use `${STEAMCMD_USER:-anonymous}` for SteamCMD login.
5. Run `workshop_download_item 431960 <ID>`.
6. Locate the item under a configurable Workshop root, defaulting to `~/.local/share/Steam/steamapps/workshop/content/431960`.
7. Read `project.json` when present.
8. Prefer the project `file` when its extension is an image (`jpg`, `jpeg`, `png`, `webp`, `gif`); otherwise use the `preview` image.
9. Fall back to common preview names and then the first compatible image inside the item directory.
10. Copy the image to `${STEAM_WALLPAPER_DEST:-$HOME/Pictures/Wallpapers/Steam}`.
11. Name it `<WORKSHOP_ID>-<sanitized-title>.<ext>` when a title exists, otherwise `<WORKSHOP_ID>.<ext>`.
12. Print the final absolute path for callers and logs.

The script does not apply the wallpaper, start Skwd, alter Skwd configuration, or store Steam/API credentials.

## Authentication and API key

A Steam Web API key is not needed when the helper already receives a URL or Workshop ID. SteamCMD authentication is separate. Wallpaper Engine Workshop downloads may require an account that owns Wallpaper Engine:

```bash
steamcmd +login YOUR_STEAM_USERNAME +quit
export STEAMCMD_USER=YOUR_STEAM_USERNAME
```

SteamCMD owns its cached login/session. The helper never accepts, prints, or stores a password, Steam Guard code, or API key.

## Failure behavior

The helper exits nonzero with a concise message when:

- input contains no valid Workshop ID;
- SteamCMD is missing;
- SteamCMD reports download failure;
- downloaded item directory cannot be found;
- no compatible image exists;
- destination cannot be created or written.

An existing destination file for the same ID/title is replaced atomically.

## Deployment

- Store helper at `dotfiles/config/shared/.local/bin/steam-workshop-image`.
- Register it in `sharedPaths` in `nixos/common-dotfiles.nix`.
- Add `steamcmd` to `environment.systemPackages` in `nixos/profiles/common_hyprland.nix`.

## Tests

Automated shell tests will verify:

- raw ID and URL parsing;
- rejection of invalid input;
- exact SteamCMD app/item arguments;
- project image preference;
- preview fallback;
- sanitized destination naming;
- no compatible image failure;
- both Hyprland profiles contain all four resize bindings;
- the classic helper documents the new keys.

Nix evaluation/build checks will verify `steamcmd` is present in both Hyprland host profiles.

## Out of scope

- Searching Steam Workshop by text.
- Storing or configuring Steam Web API keys.
- Rendering Wallpaper Engine scene packages.
- Applying wallpapers directly.
- Changing Skwd wallpaper-manager settings.
