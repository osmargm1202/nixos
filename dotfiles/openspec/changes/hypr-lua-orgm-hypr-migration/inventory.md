# Hyprland Lua / orgm-hypr migration inventory

Generated/refreshed during apply Slice 1. No live behavior changed by this artifact.

Discovery command:

```sh
find config/shared/.config/hypr config/shared/.local/bin cmd/orgm-hypr internal nixos/packages -maxdepth 3 \
  \( -path 'config/shared/.local/bin/hypr-*' -o -path 'config/shared/.local/bin/fuzzel-*' \
     -o -path 'config/shared/.local/bin/*-osd' -o -path 'config/shared/.local/bin/waybar-*' \
     -o -path 'config/shared/.config/hypr/*' -o -path 'cmd/orgm-hypr/*' \
     -o -path 'internal/*' -o -path 'nixos/packages/orgm-hypr.nix' \) -print | sort
```

## Classification table

| Path / entrypoint | Domain | Owner target | Rationale | Parity check | Rollback | Slice |
|---|---|---|---|---|---|---|
| `config/shared/.config/hypr/hyprland.lua` | Lua entrypoint | Hyprland Lua | Existing additive Lua startup entrypoint | Module order loads; Hyprland reload has no Lua error | Revert entrypoint or use `hyprland.conf` fallback | 2 |
| `config/shared/.config/hypr/hyprland.conf` | legacy source order | Retained config | Fallback until Lua parity validated | Source order unchanged | Restore split-conf source list | 2/7 |
| `config/shared/.config/hypr/00-monitors.conf` | monitors | Retained fallback then Lua | Pure compositor config; keep fallback | monitor scale/mode match | restore conf/disable Lua monitors | 2/3 |
| `config/shared/.config/hypr/10-programs.conf` | command registry | Retained fallback + Lua | Lua may centralize command strings; wrappers stay | bound commands still launch | restore conf/script paths | 2/3 |
| `config/shared/.config/hypr/20-autostart.conf` | autostart | Retained fallback + future `orgm-hypr session` | Startup side effects need typed validation before move | apps/processes start once | restore exec-once lines | 2/4 |
| `config/shared/.config/hypr/30-environment.conf` | environment | Hyprland Lua | Pure env declarations | env visible to apps | restore conf | 2 |
| `config/shared/.config/hypr/40-permissions.conf` | permissions | Hyprland Lua/deferred | Version-sensitive Lua permissions API | no permission load errors | restore conf | 2 |
| `config/shared/.config/hypr/50-look-and-feel.conf` | look | Hyprland Lua | Pure compositor config | gaps/borders/animations match | restore conf | 2/3 |
| `config/shared/.config/hypr/55-layout.conf` | layout | Hyprland Lua | Pure compositor config | dwindle/master behavior match | restore conf | 2/3 |
| `config/shared/.config/hypr/60-input.conf` | input | Hyprland Lua | Pure compositor config | layouts/gestures/numlock match | restore conf | 2/3 |
| `config/shared/.config/hypr/70-keybindings.conf` | binds | Hyprland Lua | Compositor-local bindings; external actions remain wrappers | keybinding smoke checklist | restore conf or disable Lua binds | 3 |
| `config/shared/.config/hypr/80-windows-workspaces.conf` | windows/workspaces | Hyprland Lua | Rules and workspace dispatch are compositor-local | rules/scratchpad/workspaces match | restore conf or disable module | 3 |
| `config/shared/.config/hypr/90-noctalia-colors.conf` | theme colors | Deferred/retained config | Generated/theme ownership unclear | colors unchanged | keep generated conf | deferred |
| `config/shared/.config/hypr/hypridle.conf` | idle/lock | Retained config | Adjacent but not migration target yet | idle lock behavior unchanged | restore file | retained |
| `config/shared/.config/hypr/hyprlock.conf` | lock screen | Retained config | Adjacent but not migration target yet | lock UI works | restore file | retained |
| `config/shared/.config/hypr/noctalia/noctalia-colors.conf` | theme colors | Deferred/retained config | External Noctalia semantics unclear | theme colors unchanged | keep file | deferred |
| `config/shared/.config/hypr/scheme/current.conf` | theme scheme | Deferred/retained config | Generated/current color source unclear | theme colors unchanged | keep file | deferred |
| `config/shared/.config/hypr/lua/monitors.lua` | monitors | Hyprland Lua | Existing Lua pure compositor config | monitor parity | disable module/use conf | 2/3 |
| `config/shared/.config/hypr/lua/programs.lua` | programs | Hyprland Lua + wrappers | Central command names, no command behavior | commands resolve | restore old variable source | 2 |
| `config/shared/.config/hypr/lua/autostart.lua` | autostart | Lua + future `orgm-hypr session` | Lua can declare exec list; complex decisions typed later | autostart parity | restore conf exec-once | 2/4 |
| `config/shared/.config/hypr/lua/environment.lua` | env | Hyprland Lua | Pure declarations | env parity | disable module | 2 |
| `config/shared/.config/hypr/lua/permissions.lua` | permissions | Hyprland Lua/deferred | Keep guarded for version risk | no reload errors | disable module/use conf | 2 |
| `config/shared/.config/hypr/lua/look-and-feel.lua` | look | Hyprland Lua | Pure declarations | visual parity | disable module/use conf | 2/3 |
| `config/shared/.config/hypr/lua/layout.lua` | layout | Hyprland Lua | Pure declarations | layout parity | disable module/use conf | 2/3 |
| `config/shared/.config/hypr/lua/input.lua` | input | Hyprland Lua | Pure declarations | input parity | disable module/use conf | 2/3 |
| `config/shared/.config/hypr/lua/keybindings.lua` | keybindings | Hyprland Lua | Binds belong to compositor; wrappers retained | keybinding smoke checklist | disable module/use conf | 3 |
| `config/shared/.config/hypr/lua/windows-workspaces.lua` | rules/workspaces | Hyprland Lua | Rules/workspace logic are compositor-local | rule/workspace parity | disable module/use conf | 3 |
| `config/shared/.config/hypr/scripts/pi-walker-prompt.sh` | Pi prompt | Retained script | Interactive prompt and terminal/distrobox flow can block | prompt opens Pi with input | keep script | retained |
| `config/shared/.config/hypr/scripts/walker-window-switch.sh` | window switch menu | Retained then `orgm-hypr windows` candidate | Interactive menu; parsing can move later | selected window focuses | keep script | 5 |
| `config/shared/.local/bin/hypr-fuzzel` | launcher wrapper | Retained/deferred | GUI wrapper with monitor probing; script is safe | fuzzel scale/position works | keep script | retained |
| `config/shared/.local/bin/hypr-main-menu` | menu | Retained then optional `orgm-hypr menu` | Blocking rofi/menu flow | all menu items/cancel path | keep wrapper | 6 |
| `config/shared/.local/bin/hypr-system-menu` | menu | Retained then optional `orgm-hypr menu` | Blocking system actions | item parity | keep wrapper | 6 |
| `config/shared/.local/bin/hypr-tools-menu` | menu | Retained then optional `orgm-hypr menu` | Blocking interactive actions | item parity | keep wrapper | 6 |
| `config/shared/.local/bin/hypr-performance-menu` | menu | Retained then optional `orgm-hypr menu` | Blocking system/perf actions | item parity | keep wrapper | 6 |
| `config/shared/.local/bin/hypr-wifi-menu` | system menu | Retained script | Interactive/network/systemctl risk | wifi menu actions | keep wrapper | 6 |
| `config/shared/.local/bin/hypr-bluetooth-menu` | system menu | Retained script | Interactive/system side effects | bluetooth actions | keep wrapper | 6 |
| `config/shared/.local/bin/hypr-keyboard-menu` | system menu | Retained script | Input layout action; interactive | layout switch parity | keep wrapper | 6 |
| `config/shared/.local/bin/hypr-power-menu` | power menu | Retained script | Destructive/session actions need manual parity | logout/reboot/etc prompt | keep wrapper | 6 |
| `config/shared/.local/bin/hypr-keybindings-help` | help/menu | `orgm-hypr menu keybindings` candidate + wrapper | Static data can become typed; UI wrapper remains | categories/entries match | keep wrapper | 6 |
| `config/shared/.local/bin/hypr-smart-run` | launcher parser | `orgm-hypr smart-run` candidate + wrapper | URL/search/app parsing is testable | parse and launch parity | wrapper calls old body | 6 |
| `config/shared/.local/bin/fuzzel-open-file` | file menu | Retained script | File scan + prompt is Unix glue | selected file opens | keep script | retained |
| `config/shared/.local/bin/fuzzel-open-file-dir` | file menu | Retained script | File scan + prompt | selected dir opens | keep script | retained |
| `config/shared/.local/bin/fuzzel-open-file-terminal` | file menu | Retained script | File scan + terminal action | selected dir opens terminal | keep script | retained |
| `config/shared/.local/bin/fuzzel-ssh-host` | ssh menu | Retained script | Interactive SSH prompt | selected host connects | keep script | retained |
| `config/shared/.local/bin/fuzzel-tmux-arch` | tmux menu | Retained script | Interactive container/tmux flow | session opens | keep script | retained |
| `config/shared/.local/bin/fuzzel-calc` | calculator menu | Retained script | Small interactive tool | calc result behavior | keep script | retained |
| `config/shared/.local/bin/fuzzel-hypr-window` | window switch | `orgm-hypr windows` candidate + wrapper | hyprctl parsing/focus testable; prompt can remain | labels and focus address | keep wrapper | 5 |
| `config/shared/.local/bin/hypr-kill-windows` | kill menu | `orgm-hypr windows kill-menu` candidate + wrapper | process filtering testable; destructive action guarded | filtering/cancel/TERM parity | keep wrapper | 5 |
| `config/shared/.local/bin/hypr-zen-new-window` | browser action | `orgm-hypr zen` candidate + wrapper | focus retry/hyprctl parsing testable | opens/focuses Zen | keep wrapper | 5 |
| `config/shared/.local/bin/hypr-nwg-dock` | dock orchestration | `orgm-hypr dock` candidate + wrapper | idempotent process management testable | start/reload/missing binary | restore old script body | 4 |
| `config/shared/.local/bin/waybar-watch` | watcher | `orgm-hypr waybar watch` candidate | loop/restart/log handling typed | one watcher/restart log | keep script | 4 |
| `config/shared/.local/bin/hypr-workspace-button` | Waybar workspace | `orgm-hypr waybar workspace` candidate | JSON/hyprctl parsing testable | status/click JSON parity | keep script | 4 |
| `config/shared/.local/bin/waybar-date-es` | date helper | Retained or low-priority waybar CLI | Tiny shell adequate | exact output text | keep script | retained/4 |
| `config/shared/.local/bin/waybar-day-month-es` | date helper | Retained or low-priority waybar CLI | Tiny shell adequate | exact output text | keep script | retained/4 |
| `config/shared/.local/bin/waybar-time-ampm` | date helper | Retained or low-priority waybar CLI | Tiny shell adequate | exact output text | keep script | retained/4 |
| `config/shared/.local/bin/waybar-swap-usage` | Waybar metric | Retained or low-priority waybar CLI | Tiny shell adequate | exact output text | keep script | retained/4 |
| `config/shared/.local/bin/volume-osd` | OSD | `orgm-hypr osd` candidate + wrapper | state/notify/error handling testable; hardware mocked | volume change/notify hints | keep wrapper | 5 |
| `config/shared/.local/bin/mic-volume-osd` | OSD | `orgm-hypr osd` candidate + wrapper | mic state/notify testable | mute/volume notify parity | keep wrapper | 5 |
| `config/shared/.local/bin/brightness-osd` | OSD | `orgm-hypr osd` candidate + wrapper | brightness step/notify testable | brightness/notify parity | keep wrapper | 5 |
| `config/shared/.local/bin/hypr-current-wallpaper` | wallpaper compat | Compatibility wrapper to `orgm-hypr wallpaper` | Wallpaper already CLI-owned | path/CLI output parity | keep wrapper | 7 |
| `config/shared/.local/bin/hypr-random-wallpaper` | wallpaper compat | Compatibility wrapper to `orgm-hypr wallpaper` | Wallpaper already CLI-owned | random/pick parity | keep wrapper | 7 |
| `config/shared/.local/bin/hypr-webapp-maker` | webapp | Deferred by default | Interactive file/network writes need characterization | desktop/icon/profile creation | keep script | 6/deferred |
| `config/shared/.local/bin/hypr-webapp-remover` | webapp | Deferred by default | Destructive deletion prompts need safety tests | removal/cancel parity | keep script | 6/deferred |
| `config/shared/.local/bin/hypr-focus-notification-app` | notification focus | Deferred | Caller/side effects not yet verified | caller identified and focus works | keep script | deferred |
| `config/shared/.local/bin/hypr-lock` | lock wrapper | Retained script | Session security/lock action; not migration target | lock starts | keep script | retained |
| `cmd/orgm-hypr/main.go` | CLI router | `orgm-hypr` | Command groups and placeholders are test harness target | CLI usage/placeholder/version tests | revert testable router refactor | 1/4/5/6 |
| `cmd/orgm-hypr/main_test.go` | CLI tests | `orgm-hypr` | Characterizes existing CLI behavior before changes | `go test ./cmd/orgm-hypr` | delete test file | 1 |
| `internal/cli/cli.go` | CLI errors | `orgm-hypr` | Shared exit/usage contract | usage exit code 2 | revert callers | 1+ |
| `internal/wallpaper/*` | wallpaper CLI internals | `orgm-hypr` | Existing implemented behavior; not changed in slice 1 | existing wallpaper tests | revert changes | existing |
| `internal/dot*`, `internal/paths`, `internal/run` | dotfile sync internals | Out of scope/retained | Not Hypr migration behavior | existing tests unaffected | no changes | out of scope |
| `nixos/packages/orgm-hypr.nix` | package build | `orgm-hypr` packaging | Build/package must include CLI changes | nix package build/flake check | revert package changes | verify |
| `config/dotfiles.json` | managed paths | Retained manifest | `.config/hypr` and `.local/bin` already tracked; no manifest change in Slice 1 | dotfile diff only expected changes | no manifest edit | verify |

## Discovery notes

- Uncertain or interactive entries stay retained/deferred until side effects are characterized.
- Cleanup/removal remains blocked until replacement, caller migration, and parity evidence exist.
- `config/shared/.config/nwg-dock-hyprland/style.css` was not edited; dock slice must keep it untouched.
