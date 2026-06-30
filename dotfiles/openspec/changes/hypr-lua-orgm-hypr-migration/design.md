# Design: Hyprland Lua and `orgm-hypr` migration

## Context and constraints

- Repo root: `/home/osmarg/Hobby/dotfiles`.
- Current environment: Arch/Hyprland session in podman virtualization, not tmux.
- Existing worktree note: unrelated modified file `config/shared/.config/nwg-dock-hyprland/style.css` must stay out of later migration slices.
- Strict TDD is active in `openspec/config.yaml`; implementation must write failing/characterization tests before Go behavior changes where practical.
- Dotfiles workflow uses tracked sources under `config/shared` / `config/hosts`, checked with `orgm-dot diff --host orgm` or current project wrapper `./dot.sh diff --host orgm`. No `orgm-dot sync` during design.

## Design goals

1. Put compositor-local behavior in Hyprland Lua modules: config, binds, dispatchers, rules, events, workspace/monitor/window behavior.
2. Put external orchestration in `orgm-hypr`: typed CLI, structured errors, testable state parsing, command runners behind interfaces.
3. Keep scripts only when they are safer as interactive/blocking wrappers, Unix glue, or compatibility entrypoints.
4. Migrate additively: old hyprlang/scripts stay until replacements and caller moves are validated.

## Proposed Lua module tree

Current repo already contains `config/shared/.config/hypr/hyprland.lua` and `config/shared/.config/hypr/lua/*.lua`. Future structure should make ownership clearer without changing behavior first:

```text
config/shared/.config/hypr/
  hyprland.lua                 # minimal entrypoint; ordered requires only
  lua/
    init.lua                   # optional module loader/version guards later
    core/
      programs.lua             # command strings and compatibility paths only
      environment.lua          # hl.env values
      permissions.lua          # permission declarations, guarded by version
      autostart.lua            # exec-once declarations; no blocking waits
    compositor/
      monitors.lua             # hl.monitor and monitor/workspace defaults
      input.lua                # input, gestures, keyboard layout config
      layout.lua               # dwindle/master/misc layout config
      look.lua                 # general/decoration/animations/curves
      windows.lua              # window rules, opacity, float/size/center rules
      workspaces.lua           # workspace binds/rules and special workspace helpers
      bindings.lua             # all hl.bind definitions, grouped by domain
      actions.lua              # reusable non-blocking dispatcher helpers
      events.lua               # future hl.on reactive logic only
    compat/
      legacy.lua               # optional feature flags and legacy caller notes
```

### Lua responsibilities

- `hyprland.lua`: require modules in deterministic order. No business logic.
- `core/programs.lua`: centralize external command names, preserving compatibility script paths like `~/.local/bin/hypr-main-menu` until cleanup.
- `core/autostart.lua`: declare startup commands only. Long-running/complex startup decisions should call `orgm-hypr session ...` rather than shell snippets once implemented.
- `compositor/bindings.lua`: own key/mouse bindings and direct compositor dispatches. It may execute external commands, but external command logic lives in scripts or `orgm-hypr`.
- `compositor/windows.lua`: own window rules and app matching.
- `compositor/workspaces.lua`: own workspace/scratchpad direct dispatchers and later workspace button parity helpers only if non-blocking.
- `compositor/actions.lua`: small helpers wrapping `hl.dsp.*`; no shell pipelines, fuzzel/rofi waits, network, disk scans, or package/build operations.
- `compositor/events.lua`: only fast event reactions. Any heavy response should fire-and-forget to `orgm-hypr`.

## Proposed `orgm-hypr` command shape

Existing command groups in `cmd/orgm-hypr/main.go` are `wallpaper` plus placeholders: `waybar`, `dock`, `zen`, `menu`, `updates`, `webapp`, `windows`, `notify`, `smart-run`. Keep this group model and fill it domain by domain.

```text
orgm-hypr
  version
  wallpaper
    restore | status | pick | next | change
    set-static PATH | set-video PATH
    carousel static|video
    data --mode MODE --manifest PATH --json PATH --current PATH
    clean-thumbs --root PATH
    warm-thumbs MODE [index]
    warm-page MODE [page] [page-size]
    picker-daemon | daemon
  session
    autostart                 # optional future orchestrator for complex startup snippets
    import-env                # systemd/dbus env import wrapper
    start-containers [names...] --engine auto|docker|podman
    start-discord             # start native/flatpak discord safely
  waybar
    watch [CONFIG_DIR]
    restart [CONFIG_DIR]
    swap-usage
    date --format date-es|day-month-es|time-ampm
    workspace status ID
    workspace click ID
  dock
    start [--reload]
    status
  windows
    list [--format tsv|json]
    focus ADDRESS
    kill-menu                 # may still invoke fuzzel/rofi; typed selection data in Go
  zen
    open-new-window
    focus
  menu
    main | system | tools | performance | wifi | bluetooth | keyboard | power
    keybindings [--category CATEGORY]
  smart-run
    run [QUERY...]
    parse QUERY              # pure/testable hint parser
  webapp
    create                   # may remain script if interactive flow too shell-heavy
    remove
    list [--format json|tsv]
  osd
    volume up|down|mute [--mic]
    brightness up|down
  notify
    focus-app APP            # if current script behavior verified
```

### CLI contracts

- Normal success exits 0; usage errors exit 2 through existing `cli.UsageError`; runtime failures exit non-zero with `orgm-hypr: ...` on stderr.
- Commands that mutate session/system state must be idempotent where possible (`dock start`, `waybar restart`, `wallpaper restore`).
- Host/runtime dependencies (`hyprctl`, `jq` replacement, `pamixer`, `brightnessctl`, `notify-send`, `rofi`, `fuzzel`, `systemctl`) must sit behind small interfaces so pure tests can cover parsing/decision logic.
- Interactive commands may call rofi/fuzzel, but should separate data generation from selection execution so tests can cover data/parsing without live GUI.

## Current-to-future classification matrix

Best-effort inventory from repo inspection. Exact implementation tasks should refresh this list before coding.

| Current path / category | Domain | Proposed owner | Rationale | Parity checks | Rollback | Slice |
|---|---|---|---|---|---|---|
| `.config/hypr/hyprland.lua` | Lua entrypoint | Hyprland Lua | Already additive Lua entrypoint | Hypr starts/reloads, modules load in order | Disable/revert entrypoint, use `hyprland.conf` | Lua foundation |
| `.config/hypr/hyprland.conf` and `00-90*.conf` | legacy config fallback | Retained script/config compatibility | Keep fallback until Lua parity proven | Source order, keybind/rule parity | Restore sources unchanged | Lua foundation/cleanup |
| `lua/monitors.lua`, `00-monitors.conf` | monitor config | Hyprland Lua | Pure compositor config | monitor scale/mode same | Keep old conf | Lua foundation |
| `lua/programs.lua`, `10-programs.conf` | command registry | Hyprland Lua + retained wrappers | Lua owns bind command strings; wrappers stay if interactive | all bound commands launch | restore conf/scripts | Lua foundation |
| `lua/autostart.lua`, `20-autostart.conf` | session startup | Lua for exec list; `orgm-hypr session` for complex decisions | startup is compositor event, but container/Discord/env logic deserves typed CLI | Waybar, dock, wallpaper, clipboard, apps start once | old exec-once lines | Session/CLI slice |
| `lua/environment.lua`, `30-environment.conf` | env vars | Hyprland Lua | Pure compositor/session config | env visible to apps | old conf | Lua foundation |
| `lua/permissions.lua`, `40-permissions.conf` | permissions | Hyprland Lua/deferred | Lua API/version sensitive; keep guarded | restart no permission errors | old conf | Lua foundation |
| `lua/look-and-feel.lua`, `50-look-and-feel.conf`, `55-layout.conf` | look/layout | Hyprland Lua | Pure compositor config | gaps, borders, animations, layout same | old conf | Lua foundation |
| `lua/input.lua`, `60-input.conf` | input/gestures | Hyprland Lua | Pure compositor config | keyboard layouts, gestures, numlock | old conf | Lua foundation |
| `lua/keybindings.lua`, `70-keybindings.conf` | binds | Hyprland Lua | Compositor-local bindings belong in Lua; external commands delegated | keybinding smoke checklist | old conf | Compositor slice |
| `lua/windows-workspaces.lua`, `80-windows-workspaces.conf` | rules/workspaces | Hyprland Lua | Window rules and special workspace logic are compositor-local | opacity/float/size/scratchpad | old conf | Compositor slice |
| `scheme/current.conf`, `90-noctalia-colors.conf` | theme variables/colors | Deferred/retained conf | Generated or external theme semantics unclear | theme colors unchanged | keep current files | Deferred |
| `.config/hypr/scripts/walker-window-switch.sh` | window switch menu | Retained script now; later `orgm-hypr windows list/focus` | Interactive dmenu wrapper; data parsing can move later | walker/rofi selection focuses window | keep script | Menu/windows slice |
| `.config/hypr/scripts/pi-walker-prompt.sh` | Pi prompt | Retained script | Interactive prompt + distrobox/kitty; blocking by nature | prompt opens pi with input | keep script | Retained |
| `hypr-fuzzel` | launcher scaling wrapper | Retained script or `orgm-hypr menu fuzzel-wrapper` deferred | Thin GUI wrapper with monitor probing; safe as script until typed need | fuzzel size on focused monitor | keep script | Retained/deferred |
| `hypr-main-menu`, `hypr-system-menu`, `hypr-tools-menu`, `hypr-performance-menu` | menus | Retained wrappers first; later `orgm-hypr menu ...` | Blocking rofi flows; Go can own menu data/actions after tests | every menu item launches same action | wrappers call old scripts or new CLI | Menu slice |
| `hypr-wifi-menu`, `hypr-bluetooth-menu`, `hypr-keyboard-menu`, `hypr-power-menu` | system menus | Retained wrappers first; later `orgm-hypr menu ...` | Interactive and may run systemctl/hyprctl; not Lua | GUI/TUI/system actions same | keep scripts | Menu slice |
| `hypr-keybindings-help` | help UI/data | `orgm-hypr menu keybindings` + compatibility wrapper | Static keybinding data should derive from typed table eventually; rofi wrapper may remain | categories and entries match binds | wrapper old/new switch | Menu/compositor slice |
| `hypr-smart-run` | search/URL/app launcher | `orgm-hypr smart-run` + wrapper | Parsing logic testable; rofi/browser launch external | hint parsing, URL/search/app launch | wrapper to old script | Smart-run slice |
| `fuzzel-open-file`, `fuzzel-open-file-dir`, `fuzzel-open-file-terminal`, `fuzzel-ssh-host`, `fuzzel-tmux-arch`, `fuzzel-calc` | fuzzel interactive tools | Retained scripts | File scans and prompts block; scripts are simple Unix glue | selection opens expected target | keep scripts | Retained |
| `fuzzel-hypr-window` | window switch | `orgm-hypr windows list/focus` + retained wrapper | hyprctl JSON parsing and focus command testable; fuzzel prompt can remain wrapper | list labels, focus address | wrapper old/new switch | Windows slice |
| `hypr-kill-windows` | process kill menu | `orgm-hypr windows kill-menu` + retained wrapper | Process filtering/labels testable; fuzzel prompt retained or in Go | excludes small/non-user processes, TERM target | keep script | Windows slice |
| `hypr-zen-new-window` | browser session action | `orgm-hypr zen open-new-window` + wrapper | hyprctl JSON parse/focus retry is typed/testable | opens/focuses Zen, handles missing install | wrapper old/new switch | Zen slice |
| `hypr-nwg-dock` | dock orchestration | `orgm-hypr dock start --reload` + wrapper | Idempotent process management and args are CLI-owned | start, reload, missing binary notify | keep script | Dock slice |
| `waybar-watch` | long-running watcher | `orgm-hypr waybar watch` | Process loop/restart/log path benefits from typed code | one watcher, restart behavior, log path | keep script | Waybar slice |
| `hypr-workspace-button` | Waybar workspace helper | `orgm-hypr waybar workspace ...` | JSON formatting and hyprctl parsing testable | Waybar JSON class/text/click focus | keep script | Waybar slice |
| `waybar-date-es`, `waybar-day-month-es`, `waybar-time-ampm`, `waybar-swap-usage` | Waybar text helpers | Retained scripts or `orgm-hypr waybar date/swap-usage` low priority | Tiny shell is adequate; move only if consolidating | output text exact | keep scripts | Retained/Waybar |
| `volume-osd`, `mic-volume-osd`, `brightness-osd` | media/OSD | `orgm-hypr osd ...` + wrappers | Args/state/notify testable; hardware calls mocked | volume/brightness changes and OSD hints | keep scripts | OSD slice |
| `hypr-current-wallpaper`, `hypr-random-wallpaper` | wallpaper compatibility | Compatibility wrappers to `orgm-hypr wallpaper` | Wallpaper already CLI-owned | old command paths still work | wrappers remain | Wallpaper cleanup |
| `hypr-webapp-maker`, `hypr-webapp-remover` | web app CRUD | Deferred or `orgm-hypr webapp` + wrappers | Complex interactive file/network behavior; needs characterization before move | desktop/icon/profile creation/removal | keep scripts | Webapp slice/deferred |
| `hypr-focus-notification-app` | notification focus | Deferred | Need inspect caller/side effects before migration | caller identified, focus behavior works | keep script | Deferred |
| non-Hypr analogs `sway-*`, `labwc-*`, `kbd-layout-next` | other desktop compatibility | Out of scope/retained | Not primary Hypr migration | unaffected | no changes | Out of scope |

## Compatibility and rollback approach

- Add replacements first, do not delete scripts/config in same slice.
- Preserve existing PATH entrypoints as wrappers until all callers are updated and parity is recorded.
- For Lua migration, keep old `hyprland.conf`/split conf files as fallback until `hyprland.lua` loading is validated on local Hyprland 0.55+.
- For `orgm-hypr` migration, wrappers can dispatch to new subcommands behind env flags, for example `ORGM_HYPR_USE_GO_WINDOWS=1`, before default switch.
- Rollback per slice: revert slice or change wrapper/caller back to old script; do not touch unrelated dotfiles.
- Cleanup happens only after: replacement added, tests pass, callers updated, manual parity checked, `orgm-dot diff --host orgm` reviewed.

## Validation approach

Required later validation evidence by affected slice:

```sh
nix fmt
nix flake check
nix build .#nixosConfigurations.orgm-hyprland.config.system.build.toplevel --no-link
# preferred project standard says orgm-dot; config currently also documents ./dot.sh
orgm-dot diff --host orgm
./dot.sh diff --host orgm
```

Focused Go validation:

```sh
go test ./...
go test ./internal/<domain> ./cmd/orgm-hypr
nix build .#packages.x86_64-linux.orgm-hypr --no-link
```

Manual Hyprland parity checklist per slice:

- Hyprland starts/reloads without Lua errors.
- Keybindings affected by slice still perform same user-visible action.
- Waybar/dock/wallpaper autostart still appears once.
- Window switch/focus/kill actions still act on selected window.
- OSD commands show notification and preserve volume/brightness semantics.
- Menu cancellation exits 0 and does not run action.
- Missing dependency messages remain safe and understandable.

### Strict TDD implications

- Before moving shell logic into Go, add characterization tests from current script behavior: inputs, parsed hyprctl JSON, generated menu rows, selected action, error paths.
- For commands with external dependencies, design interfaces first and use fake runners/filesystems/clocks in tests.
- For Lua, pure TDD is limited by compositor runtime. Later tasks should still add static/structural checks where possible and manual RED evidence for missing/failed Lua load before fixing.
- No cleanup task may be marked complete until parity tests/manual checks exist for that domain.

## Review slice forecast

This migration will exceed 400 changed lines if implemented fully. Use chained review slices:

1. **Inventory + test harness**: refresh inventory, add Go command parser/test scaffolding, no behavior changes.
2. **Lua foundation**: normalize module tree/loader, keep hyprlang fallback.
3. **Compositor parity**: bindings, window rules, workspaces; no script deletion.
4. **Session/Waybar/Dock CLI**: `orgm-hypr session`, `waybar`, `dock`; wrappers retained.
5. **Windows/Zen/OSD CLI**: typed `windows`, `zen`, `osd`; wrappers retained.
6. **Menu/smart-run/webapp**: only if characterization is complete; otherwise defer.
7. **Cleanup/docs**: remove or shrink wrappers only after caller/parity evidence.

Each slice must stay reviewable, independently runnable, and rollbackable.

## Risks, unknowns, decisions needed

- Hyprland Lua API/version details may differ locally; destructive Lua replacement blocked until runtime load is proven.
- Existing repo already has Lua modules, so later tasks must decide whether to reorganize paths or preserve current names to reduce churn.
- `scheme/current.conf` and Noctalia/color generation ownership is unclear; defer until generator/caller is known.
- Interactive menu migration to Go may add complexity without much value; decide per domain whether wrappers are enough.
- Webapp maker/remover perform network, file writes, generated launchers, and profile deletion; needs careful tests and maybe should remain scripts.
- `hypr-focus-notification-app` was not inspected in detail; keep deferred until caller and behavior are known.
- Need choose canonical diff command in docs: user requested `orgm-dot diff --host orgm`, while `openspec/config.yaml` lists `./dot.sh diff --host orgm`; later verification can run both if available.
- No Engram tool is available in this phase, so discoveries are persisted only in this design artifact.
