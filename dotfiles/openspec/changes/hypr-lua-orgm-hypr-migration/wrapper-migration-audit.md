# Slice 8 wrapper migration audit

Scope: command surface normalization and safest compatibility-wrapper migration only. Hyprland Lua remains compositor-local config owner. Shell wrappers may remain only when already thin or deferred because live/destructive/interactive behavior is not fully tested in Slice 8.

| Wrapper / caller | Current caller(s) | Canonical command | Slice 8 disposition | Parity / safety check | Rollback |
|---|---|---|---|---|---|
| `waybar-date-es` | Waybar date modules | `orgm-hypr waybar date --format date-es` | Converted to thin exec wrapper | CLI test covers format with fixed time; old output was `date +%d/%m/%Y` | Restore previous 2-line shell body |
| `waybar-day-month-es` | Waybar day/month modules | `orgm-hypr waybar date --format day-month-es` | Converted to thin exec wrapper | CLI test covers Spanish weekday/month | Restore previous shell case body |
| `waybar-time-ampm` | Waybar time modules | `orgm-hypr waybar date --format time-ampm` | Converted to thin exec wrapper | `internal/waybar` formats `3:04 PM`, matching `LC_TIME=C date '+%-I:%M %p'` shape | Restore previous `date` shell body |
| `waybar-swap-usage` | Waybar swap modules | `orgm-hypr waybar swap-usage` | Converted to thin exec wrapper | CLI test covers `/proc/meminfo` override and rounded percent | Restore previous awk body |
| `hypr-workspace-button` | `waybar-hypr/config` status/click entries | `orgm-hypr waybar workspace status|click WORKSPACE_ID` | Converted to thin exec wrapper | New CLI tests cover status JSON from Hypr JSON files and click `hyprctl dispatch` print path | Restore previous bash/JQ body |
| `hypr-nwg-dock` | Hypr autostart, menu reload actions | `orgm-hypr dock start [reload|restart|--reload]` | Converted to thin exec wrapper | CLI test covers compatibility args; new test covers old positional `reload` alias | Restore previous bash body |
| `hypr-zen-new-window` | Hypr Lua/conf bind `SUPER+W`, keybinding help | `orgm-hypr zen open-new-window` | Converted to thin exec wrapper | New CLI print test covers already-running install plan; live path uses tested `zen.OpenCommand` and existing `zen focus` | Restore previous bash body |
| `hypr-current-wallpaper` | `hyprlock.conf` reads `$XDG_RUNTIME_DIR/hypr-current-wallpaper`; compatibility entrypoint may be run before lock | `orgm-hypr wallpaper current` | Converted to thin exec wrapper | New CLI test creates current-file symlink and prints compatibility lock path | Restore previous shell body |
| `hypr-random-wallpaper` | Wallpaper compatibility callers | `orgm-hypr wallpaper ...` | Already thin exec wrapper; unchanged | Existing wallpaper tests retained | Restore old wrapper if needed |
| `volume-osd` | Hypr media binds and keybinding help | `orgm-hypr osd volume ACTION` | Deferred to Slice 9/10 | Go command remains print-only; live hardware/query/notify path not safe enough for wrapper switch | Keep current script |
| `mic-volume-osd` | Hypr mic binds and keybinding help | `orgm-hypr osd mic ACTION` | Deferred to Slice 9/10 | Go command remains print-only; live hardware/query/notify path not safe enough for wrapper switch | Keep current script |
| `brightness-osd` | Hypr brightness binds and keybinding help | `orgm-hypr osd brightness ACTION` | Deferred to Slice 9/10 | Go command remains print-only; live hardware/query/notify path not safe enough for wrapper switch | Keep current script |
| `fuzzel-hypr-window` | Window switch launcher | `orgm-hypr windows list/focus` or future interactive mode | Deferred | Prompt/cancel path still wrapper-owned; no Slice 8 interactive menu forcing | Keep current script |
| `hypr-kill-windows` | Kill menu | `orgm-hypr windows kill-menu` future | Deferred | Destructive kill/cancel path not fully moved/tested | Keep current script |
| `walker-window-switch.sh` | Walker window switch | `orgm-hypr windows list/focus` or future interactive mode | Deferred | Interactive Walker prompt not forced in Slice 8 | Keep current script |
| `hypr-main-menu` | Keybindings / dock launcher | `orgm-hypr menu main` | Converted in Slice 9 | Menu model/action tests cover labels, selected actions, cancel/no-op, and destructive power gates | Restore previous rofi shell body |
| `hypr-system-menu` | Main menu | `orgm-hypr menu system` | Converted in Slice 9 | Print/selection path covered through shared menu model; live rofi execution owned by `orgm-hypr menu` | Restore previous rofi shell body |
| `hypr-tools-menu` | Main menu | `orgm-hypr menu tools` | Converted in Slice 9 | Menu model/action planning covers submenu dispatch/action commands | Restore previous rofi shell body |
| `hypr-performance-menu` | Main menu | `orgm-hypr menu performance` | Converted in Slice 9 | Menu command exists; dynamic availability filtering is no longer shell-owned and is deferred for parity smoke in Slice 10 | Restore previous shell body |
| `hypr-wifi-menu` | Main menu | `orgm-hypr menu wifi` | Converted in Slice 9 | Menu model/action planning covers NetworkManager/nmtui actions | Restore previous shell body |
| `hypr-bluetooth-menu` | Main menu | `orgm-hypr menu bluetooth` | Converted in Slice 9 | Menu model/action planning covers GUI/bluetui actions | Restore previous shell body |
| `hypr-keyboard-menu` | Main menu | `orgm-hypr menu keyboard` | Converted in Slice 9 | Focused test covers explicit Latam action; model includes toggle/US/cancel | Restore previous shell body |
| `hypr-power-menu` | Main menu / keybinding | `orgm-hypr menu power` | Converted in Slice 9 | Focused tests require confirmation for destructive live actions; `--print` remains safe | Restore previous shell body |
| `hypr-keybindings-help` | Main menu / keybinding | `orgm-hypr menu keybindings` | Converted in Slice 9 | Keybinding category data has focused tests; interactive copy UI is not retained in wrapper and needs Slice 10 manual parity note | Restore previous shell body |
| `hypr-smart-run` | Main menu/search binding | `orgm-hypr smart-run run` | Converted in Slice 9 | Execution planner tests cover browser, desktop copy/launch, and command actions; `--print` and `--print-exec` stay safe | Restore previous shell body |
| `hypr-webapp-maker`, `hypr-webapp-remover` | Main menu / user commands | `orgm-hypr webapp create|remove` | Deferred wrappers | Go dry-run/list/create/remove surfaces exist with fake filesystem tests, but existing no-arg interactive maker/remover prompt parity is not implemented; keep scripts until Slice 10 or further interactive flags | Keep current scripts |

## Slice 10 final status

| Path / caller | Final status | Canonical command / exception | Evidence / blocker | Rollback |
|---|---|---|---|---|
| Hypr Lua `programs.control_center` and fallback `$control_center` | Migrated | `orgm-hypr menu main` | Static grep: no repo-owned Hypr caller uses `hypr-main-menu`; menu tests pass | Restore previous program value |
| Hypr Lua `programs.smart_run` and fallback smart-run bind | Migrated | `orgm-hypr smart-run run` | Smart-run CLI/planner tests pass | Restore wrapper caller |
| Hypr Lua/fallback Zen bind | Migrated | `orgm-hypr zen open-new-window` | Existing Zen tests plus full `go test ./...` pass | Restore wrapper caller |
| Hypr Lua/fallback keybinding help/menu/power callers | Migrated | `orgm-hypr menu keybindings`, `orgm-hypr menu power` | Menu tests pass; wrappers kept only for compatibility | Restore wrapper caller |
| Hypr Lua/fallback OSD media binds | Migrated | `orgm-hypr osd volume|mic|brightness ACTION` | New live OSD fake-bin test proves action → query → notify flow; wrappers converted thin | Restore wrapper bodies/callers |
| Hypr Lua/fallback window switch/kill binds | Migrated | `orgm-hypr windows switch --launcher fuzzel`, `orgm-hypr windows kill-menu` | New CLI tests cover selected focus and selected kill print paths; wrappers converted thin | Restore wrapper bodies/callers |
| `walker-window-switch.sh` | Converted thin | `orgm-hypr windows switch --launcher walker` | Static wrapper grep confirms direct exec | Restore previous Walker script |
| Hypr Lua/fallback autostart env import | Migrated | `orgm-hypr session import-env` | Existing import-env tests pass | Restore systemctl/dbus lines |
| Hypr Lua/fallback autostart containers/Discord | Migrated | `orgm-hypr session start-containers arch windows`; `orgm-hypr session start-discord` | New print tests cover docker and Flatpak plans; live command uses existing session planners | Restore shell snippets |
| Hypr Lua/fallback Waybar watch | Migrated | `orgm-hypr waybar watch ~/.config/waybar-hypr` | New watch `--print` test; `waybar-watch` converted thin | Restore old watcher script/caller |
| Waybar date/swap/workspace/menu callers | Migrated | `orgm-hypr waybar ...`, `orgm-hypr menu ...` | Static config replacement plus existing Waybar tests | Restore wrapper caller strings |
| `hypr-webapp-maker`, `hypr-webapp-remover` | Deferred behavior-owning wrappers | Exception: no-arg rofi prompt flow still not implemented in `orgm-hypr webapp create/remove`; Go owns non-interactive create/remove/list and destructive gates | Exact blocker: converting now would remove current interactive maker/remover UX. Command surface still needed: `orgm-hypr webapp create/remove --interactive` or prompt flags for name/url/browser/overwrite/icon/remove choice | Keep scripts; do not delete |
| `hypr-fuzzel` | Deferred retained script | Exception: generic fuzzel scaling/launcher wrapper, not migrated to `orgm-hypr` in this change | Command surface still needed if goal becomes total consolidation: `orgm-hypr launcher apps` or `orgm-hypr menu apps`; current caller `$menu` still uses this compatibility helper | Keep script |
| `hypr-lock` | Out of scope retained script | Exception: lock wrapper/session lock behavior was not part of approved slices | Needs separate command surface if desired: `orgm-hypr session lock` | Keep script |
| `hypr-focus-notification-app` | Out of scope retained script | Exception: SwayNC action outside Slice 10 caller migration; caller remains `swaync/config.json` | Needs separate `orgm-hypr notify focus-app` implementation before conversion | Keep script |
| `fuzzel-open-file*`, `fuzzel-ssh-host`, `fuzzel-tmux-arch`, `fuzzel-calc`, `pi-walker-prompt.sh` | Out of scope retained scripts | Exception: standalone fuzzel/file/tmux/calc/Pi prompt utilities lack approved `orgm-hypr` command surfaces | Needs follow-up command design if user wants complete non-Hypr launcher consolidation | Keep scripts |
| `sway/config` `waybar-watch` caller | Out of scope | Non-Hypr desktop config outside `hypr-lua-orgm-hypr-migration` Slice 10 | Avoided cross-desktop behavior change | Keep caller |

## Caller notes

- Repo-owned Hypr Lua/hyprlang fallback callers now use canonical `orgm-hypr <function>` or `orgm-hypr <function> <subfunction>` command names for migrated domains.
- Thin wrappers remain for external compatibility and muscle memory. Converted wrappers contain only `exec orgm-hypr ... "$@"`.
- Behavior-owning wrappers still present are explicit exceptions above, mostly no-arg webapp interactive prompts and out-of-scope generic fuzzel/lock/notification utilities.

## Final exception closure: Slices 11-13

Naming decision: generic app launcher uses `orgm-hypr launcher apps`; `orgm-hypr fuzzel apps` is accepted as alias route through same handler. Sway caller uses `orgm-hypr waybar watch ~/.config/waybar`.

| Former exception | Final command surface | Final wrapper/caller status | Test / verification evidence | Rollback |
|---|---|---|---|---|
| `hypr-webapp-maker` | `orgm-hypr webapp create --interactive` | Thin wrapper | CLI cancel test: `webapp create --interactive --cancel`; existing dry-run/list tests retained | Restore prior shell body from git |
| `hypr-webapp-remover` | `orgm-hypr webapp remove --interactive` | Thin wrapper | CLI interactive cancel surface added; existing remove dry-run/profile confirmation tests retained | Restore prior shell body from git |
| `hypr-fuzzel` | `orgm-hypr launcher apps` | Thin wrapper | CLI `launcher apps --print` verifies scaled fuzzel args | Restore prior shell body from git |
| `hypr-lock` | `orgm-hypr session lock --force` wrapper, safe plan via `session lock --print` | Thin wrapper | CLI lock `--print`; live lock gated by `--force` | Restore prior shell body from git |
| `hypr-focus-notification-app` | `orgm-hypr notify focus-app` | Thin wrapper | CLI `notify focus-app --print --pid` verifies focus plan | Restore prior shell body from git |
| `fuzzel-open-file` | `orgm-hypr file open --launcher fuzzel` | Thin wrapper | CLI file open-terminal print test covers path arg handling; command supports open/open-dir/open-terminal | Restore prior shell body from git |
| `fuzzel-open-file-dir` | `orgm-hypr file open-dir --launcher fuzzel` | Thin wrapper | Static wrapper audit plus shared file command test | Restore prior shell body from git |
| `fuzzel-open-file-terminal` | `orgm-hypr file open-terminal --launcher fuzzel` | Thin wrapper | CLI print test: `kitty --directory <dir>` | Restore prior shell body from git |
| `fuzzel-ssh-host` | `orgm-hypr ssh host --launcher fuzzel` | Thin wrapper | CLI SSH host discovery/print test | Restore prior shell body from git |
| `fuzzel-tmux-arch` | `orgm-hypr tmux arch --launcher fuzzel` | Thin wrapper | CLI selected tmux row print test | Restore prior shell body from git |
| `fuzzel-calc` | `orgm-hypr calc fuzzel` | Thin wrapper | CLI calc print test verifies qalc/wl-copy plan | Restore prior shell body from git |
| `pi-walker-prompt.sh` | `orgm-hypr pi prompt --launcher walker` | Thin wrapper | CLI Pi prompt print test | Restore prior shell body from git |
| Sway `waybar-watch` caller | `orgm-hypr waybar watch ~/.config/waybar` | Caller migrated; `waybar-watch` compatibility wrapper retained | Static grep confirms Sway caller no longer invokes `waybar-watch` | Restore previous Sway config line |

Remaining blockers: no behavior-owning listed final exception remains. Manual smoke and Nix/dot validators remain blocked by current executor/runtime.
