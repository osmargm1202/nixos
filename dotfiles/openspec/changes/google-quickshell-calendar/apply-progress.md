# Apply Progress: google-quickshell-calendar

## Slice / PR boundary

Correction slice applied on 2026-05-24 within the existing calendar review boundary: replace the standalone `orgm-calendar` helper with `orgm-hypr calendar <function>` in the existing Go binary, preserve runtime `orgm-calendar` cache/state paths for compatibility, and preserve host-local launchers.

Previously implemented Slices 1-3 after user-approved sliced delivery:

1. Backend/cache/reminders/tests/docs scaffold.
2. Nix/package additions, Hyprland `exec-once`, Waybar date/time click, and `Win+Shift+C` activation.
3. Quickshell calendar UI/cache reader and fixture/static validation.

No systemd user services or timers were added. `gcalcli` remains the calendar data backend. Command entrypoints are now integrated into the existing `orgm-hypr calendar` command group; no standalone `orgm-calendar` binary remains tracked.

## Completed tasks

### Correction slice — `orgm-hypr calendar`

- Removed tracked standalone `config/shared/.local/bin/orgm-calendar`.
- Added Go implementation under `internal/calendar` and wired `cmd/orgm-hypr/main.go` with the `calendar` command group.
- Updated Hyprland autostart, keybinding, Waybar clicks, and Quickshell actions to call `orgm-hypr calendar ...`.
- Removed `.local/bin/orgm-calendar` from `config/dotfiles.json`.
- Preserved compatible runtime cache/state paths under `orgm-calendar`.
- Documented Python/Nix fact: `gcalcli` is a Python application and may pull Python through Nix; `python3Minimal` was pre-existing, and the Go helper adds no extra Python packages.
- Preserved authoritative local host launchers `config/hosts/orgm/.local/share/applications/dota.desktop` and `config/hosts/orgm/.local/share/applications/silksong.desktop`.

### Slice 1 — backend/cache/reminders

- Replaced the earlier Python helper/tests with focused Go tests under `internal/calendar/` and CLI tests under `cmd/orgm-hypr/`.
- Added `orgm-hypr calendar` backend/action command group using `gcalcli` as the data backend.
- Added cache/status/reminder state under XDG cache/state paths only.
- Added schema version 1 JSON cache generation with atomic temp-file + rename writes.
- Added dependency/auth/network/parse classification and preservation of previous cache on refresh failure.
- Added duplicate-safe `notify-send` reminder bookkeeping for 1440/720/240/60 minute horizons.
- Added `open-web`, `open-event`, `add`, `status`, `sync`, `daemon`, `toggle-ui` commands.
- Added TSV parsing for default `gcalcli --nocolor --tsv agenda --details calendar --details url` output.
- Added slice documentation at `openspec/changes/google-quickshell-calendar/support/gcalcli-calendar.md`.

### Slice 2 — packages/startup/activation

- Added `gcalcli` and `libnotify` to `nixos/profiles/hyprland.nix`.
- Added Hyprland Lua autostart entry for `orgm-hypr calendar daemon` using `exec-once` semantics.
- Added `Win+Shift+C` keybinding in the Hyprland keybinding source to call `orgm-hypr calendar toggle-ui`.
- Added Waybar time/date/day click handlers in `config/shared/.config/waybar-hypr/config`, all calling `orgm-hypr calendar toggle-ui`.
- `toggle-ui` writes `${XDG_STATE_HOME:-$HOME/.local/state}/orgm-calendar/ui-request.json` and starts `quickshell -c calendar` only when the calendar UI is not already running.

### Slice 3 — Quickshell UI

- Added `config/shared/.config/quickshell/calendar/shell.qml`.
- The UI reads `${XDG_CACHE_HOME:-$HOME/.cache}/orgm-calendar/events.json` via `FileView` and does not call `gcalcli` directly.
- The UI watches `${XDG_STATE_HOME:-$HOME/.local/state}/orgm-calendar/ui-request.json` for toggle/show/hide requests.
- The UI action runner launches `orgm-hypr calendar` actions only.
- Added Caelestia-inspired month grid, today/selected day styling, event counts/dots, selected-day agenda, empty/stale/error states, and action buttons.
- Added fixture caches and static/fixture validation under `openspec/changes/google-quickshell-calendar/support/fixtures/`.

## Files changed

- `internal/calendar/calendar.go`
- `internal/calendar/calendar_test.go`
- `cmd/orgm-hypr/main.go`
- `cmd/orgm-hypr/main_test.go`
- removed `config/shared/.local/bin/orgm-calendar`
- `config/dotfiles.json`
- `config/shared/.config/hypr/lua/autostart.lua`
- `config/shared/.config/hypr/lua/keybindings.lua`
- `config/shared/.config/waybar-hypr/config`
- `config/shared/.config/quickshell/calendar/shell.qml`
- `nixos/profiles/hyprland.nix`
- removed `tests/orgm_calendar/`
- removed `tests/fixtures/gcalcli/`
- `openspec/changes/google-quickshell-calendar/support/gcalcli-calendar.md`
- `openspec/changes/google-quickshell-calendar/support/fixtures/validate_calendar_ui.py`
- `openspec/changes/google-quickshell-calendar/proposal.md`
- `openspec/changes/google-quickshell-calendar/spec.md`
- `openspec/changes/google-quickshell-calendar/design.md`
- `openspec/changes/google-quickshell-calendar/tasks.md`
- `openspec/changes/google-quickshell-calendar/apply-progress.md`

## Test commands run

| Command | Result | Notes |
| --- | --- | --- |
| `go test ./internal/calendar -run TestRunSyncParsesDefaultGcalcliTSVAndWritesCache` | RED failed, then PASS after fix | RED caught uppercase `Source.Backend`/`Source.Command` JSON keys; GREEN added JSON tags for lower-case schema keys. |
| `go test ./cmd/orgm-hypr ./internal/calendar` | PASS | Focused Go tests for `orgm-hypr calendar` CLI and calendar package. |
| `python openspec/changes/google-quickshell-calendar/support/fixtures/validate_calendar_ui.py` | PASS | Static QML/fixture validation updated for `orgm-hypr calendar`. |
| `git grep` standalone command check | PASS | No `orgm-calendar <subcommand>` or `["orgm-calendar"]` command refs in config/openspec/cmd/internal. Runtime cache/state paths intentionally remain. |
| JSON/JSONC/Lua parse checks | PASS | `config/dotfiles.json`, Waybar JSONC-stripped parse, Hyprland autostart/keybinding Lua syntax. |
| `orgm-dot diff --host orgm` | PASS with expected diff | Shows expected managed changes for Hyprland, Waybar, and Quickshell after removing standalone bin manifest. |
| `nix flake check` | NOT RUN: command unavailable | `nix: command not found` in this session. |

## TDD Cycle Evidence

| Task | Test File | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
|------|-----------|-------|------------|-----|-------|-------------|----------|
| Go calendar command group | `cmd/orgm-hypr/main_test.go` | CLI | ✅ Existing focused Go package tests run | ✅ `calendar status` failed before CLI wiring | ✅ `go test ./cmd/orgm-hypr ./internal/calendar` passed | ✅ Missing-usage and status path cases | ✅ Calendar logic delegated to `internal/calendar` |
| Cache contract / TSV sync | `internal/calendar/calendar_test.go` | Unit/CLI | N/A (new Go package) | ✅ `Run`/`Cache` were undefined | ✅ Passed after Go implementation | ✅ Timed event, all-day event, lower-case source schema keys | ✅ Parser/schema helpers in package |
| Preserve cache on failure | `internal/calendar/calendar_test.go` | Unit/CLI | N/A (new Go package) | ✅ Test failed before sync implementation | ✅ Passed | ✅ Parse failure with prior valid cache preserved and stale status | ✅ Error classification/failure path extracted |
| Toggle UI command | `internal/calendar/calendar_test.go` | Unit/CLI | N/A (new Go package) | ✅ Test failed before toggle implementation | ✅ Passed | ✅ Starts Quickshell when absent, does not restart when running | ✅ UI request/start helpers separated |
| Open/status actions | `internal/calendar/calendar_test.go` | Unit/CLI | N/A (new Go package) | ✅ Test failed before action implementation | ✅ Passed | ✅ Open cached event link and print status/cache path | ✅ URL/open/status helpers separated |
| Dotfile/static command migration | `validate_calendar_ui.py`, `git grep` checks | Static | ✅ Existing config files parsed after change | ✅ Static expectations updated for `orgm-hypr calendar` | ✅ Validator and grep checks passed | ✅ Ensures no standalone command refs while preserving cache paths | ✅ Manifest removed standalone bin path |

## Deviations / notes

- Runtime cache/state paths remain under `orgm-calendar` for compatibility: cache, status, reminders, and UI request JSON.
- The command surface is `orgm-hypr calendar <function>` only; the standalone managed bin was removed.
- `gcalcli` remains the data/OAuth backend. `orgm-hypr` is command glue and local cache/reminder orchestration.
- `nixos/profiles/hyprland.nix` explicitly adds `gcalcli` and `libnotify` for this feature. `python3Minimal` was pre-existing; Nix may pull Python because `gcalcli` is a Python app, but the Go helper adds no extra Python packages.
- Real `gcalcli` output should still be smoke-tested after OAuth/bootstrap on the target desktop.

## Remaining tasks

- Manual desktop smoke test after sync:
  - configure/authenticate `gcalcli`;
  - run `orgm-hypr calendar sync`;
  - run `orgm-hypr calendar toggle-ui`;
  - click Waybar date/time/day;
  - press `Win+Shift+C`;
  - verify reminders with a controlled near-future event.
- Full Nix validation once `nix` is available: `nix flake check` and focused `orgm-hyprland` build if desired.
- Decide whether to apply dotfiles with `orgm-dot sync --host orgm` after reviewing `orgm-dot diff --host orgm`.

## Risks

- `nix flake check` could not run because `nix` is unavailable in this container/session.
- Quickshell executable is not available in this session, so QML was validated statically/with fixtures but not launched live.
