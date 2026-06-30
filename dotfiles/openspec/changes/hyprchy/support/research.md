# Research: Omarchy Walker + Elephant for NixOS SDD

## Summary
Omarchy uses **Walker** as the visible launcher/menu UI and **Elephant** as its backend provider service. For NixOS, prefer upstream flakes/modules but pin Walker and Elephant together, because protocol/provider compatibility has broken across git revisions before. I did **not write files** because the task also said “No local edits,” which conflicts with the requested progress/artifact writes.

## Findings

1. **Upstream repos**
   - Walker: `https://github.com/abenz1267/walker` — Rust/GTK4 launcher frontend. [README](https://github.com/abenz1267/walker/blob/master/README.md)
   - Elephant: `https://github.com/abenz1267/elephant` — Go backend/provider service using Unix sockets + protobuf. [README](https://github.com/abenz1267/elephant/blob/master/README.md)
   - Omarchy: `https://github.com/basecamp/omarchy` — integrates Walker/Elephant as the Omarchy menu. [refresh script](https://github.com/basecamp/omarchy/blob/master/bin/omarchy-refresh-walker)

2. **Omarchy integration model**
   - `omarchy-refresh-walker` installs Walker autostart, systemd restart override, refreshes `walker/config.toml`, `elephant/calc.toml`, `elephant/desktopapplications.toml`, symlinks Elephant Lua menus into `~/.config/elephant/menus`, then restarts Walker. [Source](https://github.com/basecamp/omarchy/blob/master/bin/omarchy-refresh-walker)
   - Omarchy ships Elephant Lua menus such as `omarchy_themes.lua`; menu entries return `Text`, `Preview`, `PreviewType`, and `Actions`, e.g. running `omarchy-theme-set`. [Source](https://github.com/basecamp/omarchy/blob/master/default/elephant/omarchy_themes.lua)
   - Omarchy disables Walker layer animation through Hyprland `layerrule = no_anim on, match:namespace walker`. [Source](https://github.com/basecamp/omarchy/blob/master/default/hypr/apps/walker.conf)

3. **Build/runtime dependencies**
   - Walker build/runtime needs GTK4 4.6+, `gtk4-layer-shell`, protobuf compiler, cairo, poppler-glib, and Elephant running before Walker starts. [Walker README](https://github.com/abenz1267/walker/blob/master/README.md)
   - Walker’s Nix package uses Rust plus `glib`, `gtk4`, `gtk4-layer-shell`, `gdk-pixbuf`, `graphene`, `cairo`, `pango`, `poppler`, and GStreamer plugins. [package.nix](https://github.com/abenz1267/walker/blob/master/nix/package.nix)
   - Elephant’s flake builds the main Go binary and provider `.so` plugins; wrapper PATH includes `wl-clipboard`, `libqalculate`, `imagemagick`, and `bluez`. [Elephant flake](https://github.com/abenz1267/elephant/blob/master/flake.nix)

4. **Data/menu model**
   - Elephant provides data sources: desktop apps, files, bluetooth, clipboard, runner, symbols, calc/qalc, custom menus, provider list, websearch, packages, todos, bookmarks, windows, snippets, password providers, etc. [Elephant README](https://github.com/abenz1267/elephant/blob/master/README.md)
   - Elephant communicates over Unix sockets with protobuf; frontend clients query/activate provider items and can subscribe to menu updates. [Elephant README](https://github.com/abenz1267/elephant/blob/master/README.md)
   - Walker config maps providers and prefixes: default includes `desktopapplications`, `calc`, `websearch`; prefixes include `;` providerlist, `>` runner, `/` files, `=` calc, `@` websearch, `:` clipboard. [config.toml](https://github.com/abenz1267/walker/blob/master/resources/config.toml)

5. **Typical config paths**
   - Walker creates/uses `~/.config/walker/config.toml` and `~/.config/walker/themes/`. [Getting Started](https://walkerlauncher.com/docs/getting-started)
   - Elephant uses `~/.config/elephant/elephant.toml`, `.env`, provider TOMLs, `~/.config/elephant/providers/*.so`, and menus under `~/.config/elephant/menus`. [Elephant README](https://github.com/abenz1267/elephant/blob/master/README.md)
   - Elephant user systemd service is placed at `~/.config/systemd/user/elephant.service`. [Elephant README](https://github.com/abenz1267/elephant/blob/master/README.md)

6. **NixOS/Home Manager upstream support**
   - Walker flake exposes Home Manager and NixOS modules: `programs.walker.enable = true`; Home Manager supports `runAsService = true`. [Walker README](https://github.com/abenz1267/walker/blob/master/README.md)
   - Walker README recommends making `walker.inputs.elephant.follows = "elephant"` in Nix flakes. [Walker README](https://github.com/abenz1267/walker/blob/master/README.md)
   - Walker HM module imports Elephant HM module, enables Elephant automatically, writes `walker/config.toml`, themes, and can create `systemd.user.services.walker` requiring `elephant.service`. [HM module](https://github.com/abenz1267/walker/blob/master/nix/modules/home-manager.nix)
   - Elephant HM module writes provider `.so` symlinks, provider TOMLs, TOML menus, Lua menus, and an Elephant user service. [Elephant HM module](https://github.com/abenz1267/elephant/blob/master/nix/modules/home-manager.nix)

7. **Hyprland integration**
   - Recommended service startup: start Elephant, then `walker --gapplication-service`; bind launcher to either `walker` or faster socket call `nc -U /run/user/1000/walker/walker.sock`. [Advanced Usage](https://walkerlauncher.com/docs/advanced-usage)
   - Example Hyprland binding: `bind = SUPER, SPACE, exec, nc -U /run/user/1000/walker/walker.sock`. [Advanced Usage](https://walkerlauncher.com/docs/advanced-usage)
   - If socket launch is used, note it does not support command-line arguments. [Getting Started](https://walkerlauncher.com/docs/getting-started)

8. **Risks of using git versions**
   - Walker/Elephant compatibility matters: a Walker PR notes failures caused by incompatible Elephant/Walker versions when Elephant was not pinned. [PR #672](https://github.com/abenz1267/walker/pull/672)
   - Another PR documents a protocol header change where Walker 2.8.2 needed a newer Elephant revision; otherwise applications did not appear. [PR #591](https://github.com/abenz1267/walker/pull/591)
   - Omarchy users have hit `elephant` command-not-found/migration issues and broken launch behavior after upgrades. [Omarchy issue #2610](https://github.com/basecamp/omarchy/issues/2610)
   - `elephant-files` has reported high CPU/RAM and inotify-related issues in Omarchy. [Issue #2827](https://github.com/basecamp/omarchy/issues/2827), [Issue #3689](https://github.com/basecamp/omarchy/issues/3689)

## Recommendations for NixOS SDD

1. Use upstream flakes/modules, but **pin Walker and Elephant together**; set `walker.inputs.elephant.follows = "elephant"` or use Walker’s locked Elephant input.
2. Prefer Home Manager for user-session integration because Walker’s NixOS module notes `runAsService` is HM-only.
3. Start Elephant as a user service with the Wayland/session environment; do not use a system-level service.
4. Configure Hyprland:
   - `exec-once = systemctl --user start elephant.service`
   - `exec-once = walker --gapplication-service` or HM service
   - `bind = SUPER, SPACE, exec, walker` initially; switch to socket launch only after confirming service reliability.
5. For an Omarchy-like central menu, model custom actions as Elephant `menus` provider Lua/TOML entries under `~/.config/elephant/menus`.
6. Be conservative with providers on first NixOS implementation: start with `desktopapplications`, `providerlist`, `runner`, `calc`, `websearch`, maybe `menus`; add `files` only after checking CPU/inotify behavior.
7. Add a NixOS SDD acceptance test/checklist:
   - `elephant listproviders` works
   - `walker` opens
   - desktop apps appear
   - custom menu appears
   - `SUPER+SPACE` launches Walker
   - reboot preserves service startup
   - logs have no “Waiting for elephant” loop

## Sources

- Kept: Walker README — repo, dependencies, Nix flake/module guidance. https://github.com/abenz1267/walker/blob/master/README.md
- Kept: Walker default config — provider/prefix/action model. https://github.com/abenz1267/walker/blob/master/resources/config.toml
- Kept: Walker Nix package/module — exact Nix dependencies and HM service behavior. https://github.com/abenz1267/walker/blob/master/nix/package.nix
- Kept: Elephant README — backend model, providers, config paths, IPC. https://github.com/abenz1267/elephant/blob/master/README.md
- Kept: Elephant flake/HM module — providers packaging and Nix config model. https://github.com/abenz1267/elephant/blob/master/flake.nix
- Kept: Omarchy refresh script — concrete Omarchy Walker/Elephant setup. https://github.com/basecamp/omarchy/blob/master/bin/omarchy-refresh-walker
- Kept: Omarchy Lua menu — real menu structure. https://github.com/basecamp/omarchy/blob/master/default/elephant/omarchy_themes.lua
- Kept: Walker docs — Hyprland/service/socket integration. https://walkerlauncher.com/docs/advanced-usage
- Dropped: SEO/generated Walker pages — redundant with README/docs.
- Dropped: unrelated Omarchy issues — not directly relevant to Walker/Elephant integration.

## Gaps

- I did not inspect every Omarchy default config file, only the relevant Walker/Elephant/Hyprland integration paths.
- Engram save was requested, but no Engram callable tool is available in this subagent environment.
- Requested output files were not written because “No local edits” conflicts with artifact/progress writing.