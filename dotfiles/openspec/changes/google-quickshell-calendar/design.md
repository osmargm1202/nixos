# Design: Google Quickshell Calendar

## Context and decisions

This design keeps Google Calendar access behind `gcalcli` and exposes only a local JSON contract to Quickshell. Quickshell renders the calendar and launches small commands; it does not own Google OAuth, Google API calls, token storage, or long-running sync logic.

Repository discoveries for this change:

- Managed dotfiles are declared in `config/dotfiles.json`; `.config/quickshell` and `.config/hypr` are already shared managed paths, and `.config/DankMaterialShell` is host-specific for `orgm`.
- The expected `config/shared/.config/hypr/20-autostart.conf` is not present in this checkout. The active shared Hyprland startup path found is `config/shared/.config/hypr/lua/autostart.lua`, imported by `config/shared/.config/hypr/hyprland.lua`.
- Existing shared Quickshell config exists at `config/shared/.config/quickshell/wallpaper-picker/shell.qml` and already uses `FileView`, `Process`, timers, JSON parsing, and overlay/panel patterns suitable for this calendar widget.
- `nixos/profiles/hyprland.nix` already installs `quickshell`, `swaynotificationcenter`, `dunst`, and `xdg-utils`; implementation should add `gcalcli` and ensure `notify-send` is available via the appropriate package, commonly `libnotify`.

Primary architecture decisions:

1. `gcalcli` is the backend of record for OAuth and event access.
2. Hyprland `exec-once` starts the helper and Quickshell; no systemd user service/timer in MVP.
3. The runtime contract is a cache file, e.g. `$XDG_CACHE_HOME/orgm-calendar/events.json`, plus local state for reminder de-duplication.
4. Quickshell reads JSON and executes small scripts for add/sync/open actions.
5. Notifications use `notify-send` and support 24h, 12h, 4h, and 1h horizons.
6. The calendar UI is toggled from the desktop clock/date entry points: Waybar time/date/day click and `Win+Shift+C`.
7. UI follows the existing repo-native Quickshell style with Caelestia-inspired calm panels, rounded cards, accent borders, month/day layout, and compact actions.

## Components

### 1. Calendar helper / daemon script

Proposed managed source path:

- `internal/calendar` package, wired into existing `cmd/orgm-hypr` as `orgm-hypr calendar`

Responsibilities:

- Run once in foreground as a session helper started by Hyprland.
- Create cache/state directories under XDG locations.
- Verify dependencies: `gcalcli`, `notify-send`, `xdg-open` or configured browser opener.
- Perform startup sync, then periodic refresh while the session is active.
- Invoke `gcalcli` to fetch event data for a bounded range around the current month.
- Normalize `gcalcli` output into cache JSON.
- Atomically write cache files.
- Evaluate reminders and call `notify-send`.
- Persist reminder bookkeeping under `$XDG_STATE_HOME/orgm-calendar/reminders.json`.
- Preserve the last valid cache when refresh fails.

Implementation language may be Python or shell plus `jq`; Python is preferred if `gcalcli` output parsing needs robust datetime/timezone handling. If Python is used, keep it stdlib-only unless the Nix/profile slice explicitly packages dependencies.

### 2. Action command wrapper

Existing binary command group:

- `orgm-hypr calendar` implemented by `internal/calendar` and wired through `cmd/orgm-hypr/main.go`

Small command surface used by Quickshell and manual troubleshooting:

```text
orgm-hypr calendar sync              # trigger/cache a refresh, or ask helper to refresh if later IPC is added
orgm-hypr calendar daemon            # long-running helper loop in the existing orgm-hypr binary
orgm-hypr calendar open-web [date]   # open Google Calendar web, optionally focused to selected day
orgm-hypr calendar open-event <id>   # open event htmlLink when known, fallback to web date
orgm-hypr calendar add [date]        # open Google Calendar create URL or documented gcalcli add flow
orgm-hypr calendar status            # print cache metadata and last error for troubleshooting
```

The wrapper may be the same file as the helper if kept simple, but the contract should remain stable for Quickshell: Quickshell calls commands, not Google APIs.

### 3. Local cache/state files

Recommended runtime paths:

- Cache: `${XDG_CACHE_HOME:-$HOME/.cache}/orgm-calendar/events.json`
- Temporary cache: same directory, `events.json.tmp.<pid>`
- Helper log/status optional: `${XDG_STATE_HOME:-$HOME/.local/state}/orgm-calendar/status.json`
- Reminder state: `${XDG_STATE_HOME:-$HOME/.local/state}/orgm-calendar/reminders.json`

Cache and state are not tracked by dotfiles.

### 4. Quickshell widget

Proposed managed source paths:

- `config/shared/.config/quickshell/calendar/shell.qml`
- Optional component files under `config/shared/.config/quickshell/calendar/components/`

Responsibilities:

- Read `events.json` using `FileView` with `watchChanges: true`.
- Maintain selected month and selected day state locally in QML.
- Render:
  - header with month title and prev/next controls;
  - 7-column weekday row;
  - month grid with today, selected day, outside-month days, and event dots/counts;
  - selected-day agenda list;
  - status strip for fresh/stale/error/empty states;
  - actions: sync, add, open selected day/web, open event.
- Expose a stable toggle/open action that can be invoked by Waybar click commands and the Hyprland `Win+Shift+C` keybinding.
- Execute commands via `Process`/`Quickshell.execDetached`, following the pattern already used by the wallpaper picker and DankMaterialShell plugins.
- Never call `gcalcli` directly for render.
- Tolerate missing/malformed cache by rendering an error/empty state without crashing the shell.

### 5. Activation triggers

The calendar must open from two desktop entry points:

- Waybar time/date/day module click.
- Hyprland keybinding: `Win+Shift+C`.

Both triggers should call the same Quickshell IPC/toggle command or the same small wrapper, for example:

```text
orgm-hypr calendar toggle-ui
# or a repo-native quickshell IPC command once the calendar shell command is chosen
```

The trigger command should only open/toggle/focus the UI. It must not start another long-running sync/reminder daemon. If Quickshell is not running, the command may start the calendar shell entrypoint as a recovery path, but it should avoid duplicate shell instances where Quickshell IPC supports toggling an existing panel.

Implementation should inspect the current Waybar module that renders time/date/day and wire its `on-click` to the chosen toggle command. The Hyprland binding should be added to the repo-native keybinding source so `Win+Shift+C` invokes the same toggle command.

Rollback is removing the Waybar `on-click` command and the `Win+Shift+C` binding; backend cache/reminder behavior can remain untouched.

### 6. Hyprland startup

MVP startup uses `exec-once` semantics through the existing Lua autostart mechanism.

Implementation should update `config/shared/.config/hypr/lua/autostart.lua` with entries equivalent to:

```lua
"sh -lc 'orgm-hypr calendar daemon >>${XDG_STATE_HOME:-$HOME/.local/state}/orgm-calendar/helper.log 2>&1'",
"quickshell -c calendar",
```

If the implementation discovers an active generated `exec-once` config before apply, use the repo-native source of truth, but do not add systemd user units/timers for MVP.

Rollback is a one-line removal/comment of the calendar helper startup and Quickshell calendar startup entries; local cache/state and `gcalcli` credentials can remain untouched.

## Data flow

```text
Hyprland session starts
  -> lua/autostart.lua exec-once starts orgm-hypr calendar daemon
  -> daemon checks dependencies and XDG dirs
  -> daemon runs startup sync via gcalcli
  -> daemon normalizes events and atomically writes events.json
  -> Quickshell calendar reads events.json via FileView
  -> Waybar time/date click or Win+Shift+C toggles the same calendar UI
  -> user selects day / opens actions in Quickshell
  -> Quickshell executes orgm-hypr calendar add/open/sync commands
  -> daemon periodically refreshes cache and evaluates reminders
  -> notify-send emits due reminders; reminders.json prevents duplicates
```

Failure flow:

```text
gcalcli/network/OAuth failure
  -> daemon keeps previous valid events.json
  -> daemon writes observable error metadata/status
  -> Quickshell keeps rendering usable stale data with warning
```

## Cache schema sketch

Versioned schema, optimized for UI reads and future extension:

```json
{
  "schemaVersion": 1,
  "generatedAt": "2026-05-23T23:31:00Z",
  "lastSuccessAt": "2026-05-23T23:30:45Z",
  "timezone": "America/Santo_Domingo",
  "source": {
    "backend": "gcalcli",
    "command": "gcalcli --calendar ... agenda ...",
    "rangeStart": "2026-05-01T00:00:00-04:00",
    "rangeEnd": "2026-06-15T23:59:59-04:00"
  },
  "status": {
    "state": "ok",
    "stale": false,
    "message": "",
    "lastErrorAt": null,
    "lastErrorKind": null,
    "lastError": null
  },
  "events": [
    {
      "id": "provider-or-derived-id",
      "stableKey": "calendarId:eventId:start",
      "calendarId": "primary",
      "calendarName": "Personal",
      "title": "Project review",
      "description": "",
      "location": "",
      "start": "2026-05-24T10:00:00-04:00",
      "end": "2026-05-24T11:00:00-04:00",
      "startDate": "2026-05-24",
      "endDate": "2026-05-24",
      "allDay": false,
      "htmlLink": "https://calendar.google.com/...",
      "status": "confirmed",
      "attendeesCount": 0,
      "reminderEligible": true
    }
  ]
}
```

Notes:

- `schemaVersion` allows future notification-center/email/app-alert routing without replacing the cache.
- `stableKey` is required for reminder de-duplication; prefer Google event id when `gcalcli` exposes it, otherwise derive from calendar/title/start/end and document collision risk.
- `startDate`/`endDate` are denormalized to keep QML date filtering simple.
- `status.state` values: `ok`, `empty`, `stale`, `dependency_error`, `auth_error`, `network_error`, `parse_error`, `unknown_error`.
- Atomic write sequence: write temp file, fsync/close where practical, then rename over `events.json`. Do not truncate existing cache before successful serialization.

## Reminder state schema sketch

```json
{
  "schemaVersion": 1,
  "updatedAt": "2026-05-23T23:31:00Z",
  "horizonsMinutes": [1440, 720, 240, 60],
  "sent": {
    "stableKey|1440|2026-05-24T10:00:00-04:00": {
      "eventStableKey": "stableKey",
      "horizonMinutes": 1440,
      "eventStart": "2026-05-24T10:00:00-04:00",
      "sentAt": "2026-05-23T10:00:05-04:00",
      "notifyExitCode": 0
    }
  }
}
```

Reminder semantics:

- Evaluate after each successful sync and at a short periodic tick, e.g. every 60 seconds.
- Send a horizon notification when `0 <= eventStart - now <= horizon` and that horizon key was not already sent.
- To avoid late flood after long offline periods, implementation may cap late notifications to a grace window, e.g. only send if within `horizon + 10 minutes`; document the chosen behavior in tasks/apply.
- Mark a reminder as sent only after `notify-send` exits successfully. If best-effort semantics are chosen later, document that explicitly.
- Periodically prune reminder state for events older than a retention window, e.g. 30 days.

Notification content:

```text
Title: Calendar: Project review
Body: Starts in 1 hour at 10:00 AM
Urgency: normal for 24h/12h/4h, critical or normal+icon for 1h based on existing notification style
```

## Sync cadence

Recommended MVP defaults:

- Initial refresh immediately on daemon start.
- Periodic refresh every 5-15 minutes; start with 10 minutes unless implementation testing shows `gcalcli` is too slow/noisy.
- Fetch a useful range around the visible UI: previous month start through next month end, or now through 45-60 days plus current month padding. The cache schema records the actual range.
- Optional manual `orgm-hypr calendar sync` command refreshes immediately.

Do not block Hyprland startup on a slow sync. The autostart command should run in background through `exec-once`; the helper handles dependency errors internally.

## Quickshell UI structure

Suggested QML structure:

```text
calendar/shell.qml
  ShellRoot
    FileView cacheFile
    Process actionProcess
    Timer cacheReloadDebounce
    PanelWindow / PopupWindow
      Rectangle overlay/card
        Header: title, prev/next, sync/open buttons
        Month grid: weekday labels + day cells
        Agenda: selected date, event cards, empty state
        Footer/status: last refresh, stale/error text, key hints including Win+Shift+C
```

Interaction details:

- Default selected day: today.
- Prev/next month buttons update only UI state; cache refresh remains helper-owned.
- Day cells show compact event count/dots.
- Selecting a day updates the agenda list.
- Calendar UI activation comes from Waybar clock/date/day click and `Win+Shift+C`; both should call the same toggle/open path.
- Event card click or action button calls `orgm-hypr calendar open-event <id>` when `htmlLink` exists; otherwise `orgm-hypr calendar open-web <date>`.
- Add button calls `orgm-hypr calendar add <selected-date>`.
- Sync button calls `orgm-hypr calendar sync` and relies on cache file update to refresh UI.
- Keyboard support should at least include Esc to close when panel mode exists, arrow navigation if reasonable, Enter to open selected event/day, and PageUp/PageDown for months.

Styling guidance:

- Reuse repo conventions observed in `wallpaper-picker/shell.qml`: transparent overlay, rounded dark card, Catppuccin-like colors (`#cad3f5`, `#8aadf4`, `#494d64`, muted text), subtle borders, short opacity/scale animations.
- Visual inspiration from Caelestia should be translated into compact cards and calm spacing, not a wholesale external theme import.

## Auth and secrets handling

- The helper never asks for, stores, or parses Google account secrets.
- OAuth bootstrap is through normal `gcalcli` setup. Documentation should tell the user to run a manual `gcalcli` command in a terminal to complete first-run OAuth before expecting the widget to sync.
- `gcalcli` credential/token files remain wherever `gcalcli` normally stores them, outside this feature's cache/state contract.
- Auth/token failures are captured as status/error metadata and visible in helper logs/status; existing cache is preserved.

## Error handling matrix

| Failure | Helper behavior | Quickshell behavior |
| --- | --- | --- |
| Missing `gcalcli` | Record dependency error, do not overwrite valid cache | Show setup-required status if visible in cache/status; otherwise empty error state |
| Missing `notify-send` | Record notification dependency error; continue cache sync | Calendar remains usable; reminders disabled warning optional |
| OAuth/token failure | Preserve cache, record `auth_error` | Render stale data with auth warning |
| Network failure | Preserve cache, record `network_error` | Render stale data with stale warning |
| `gcalcli` parse failure | Preserve cache, record `parse_error` | Render previous cache if valid; show warning |
| Malformed cache | No direct helper action unless detected at startup | Catch JSON exception and show non-crashing error state |
| Browser open failure | Command exits non-zero and logs error | Action may show status/log-visible failure; widget stays open |
| Notification failure | Log non-zero exit; do not corrupt event cache | UI unaffected |

## File changes expected in implementation

Likely managed files:

- `internal/calendar` and `cmd/orgm-hypr/main.go` for the `orgm-hypr calendar` command group
- `config/shared/.config/quickshell/calendar/shell.qml`
- Optional QML components under `config/shared/.config/quickshell/calendar/`
- `config/shared/.config/hypr/lua/autostart.lua`
- the repo-native Hyprland keybinding source for `Win+Shift+C`
- the repo-native Waybar time/date/day module source for click activation
- `nixos/profiles/hyprland.nix` to add `gcalcli` and `libnotify`/notification CLI if missing
- Documentation under `openspec/changes/google-quickshell-calendar/support/` or a tracked repo doc if desired

Manifest impact:

- `.config/quickshell` and `.config/hypr` are already shared paths, so files below those roots should not require new `config/dotfiles.json` entries.
- No new `.local/bin` helper path is required because `orgm-hypr` is already built/managed as the existing Go binary; `config/dotfiles.json` must not list `.local/bin/orgm-calendar`.

## Testing and verification plan

Implementation phases should follow strict TDD where practical.

Suggested RED tests/checks before implementation:

- Helper unit tests with sample `gcalcli` outputs for timed events, all-day events, empty calendars, OAuth failure text, network failure text, and malformed output.
- Cache writer test proving temp-file-and-rename behavior preserves the previous valid cache on serialization/fetch failure.
- Reminder tests for 24h, 12h, 4h, 1h horizons and duplicate prevention across restart/state reload.
- Command wrapper tests for open-web/open-event URL selection and non-zero opener handling.

Manual/desktop verification after implementation:

1. `orgm-hypr calendar status` reports dependency/OAuth state clearly.
2. With `gcalcli` configured, `orgm-hypr calendar sync` writes valid JSON under `$XDG_CACHE_HOME/orgm-calendar/events.json`.
3. Quickshell calendar renders from the cache with network disabled.
4. Malformed cache does not crash Quickshell; widget shows an error/empty state.
5. Reminder dry-run or controlled fixture sends at most one notification per event/horizon.
6. Hyprland startup entry appears in managed source and starts the helper once per session.
7. Waybar time/date/day click and `Win+Shift+C` both open/toggle the same calendar UI without spawning duplicate helper daemons.
7. Dotfile validation: `orgm-dot diff --host orgm` per project standard. `openspec/config.yaml` also mentions `./dot.sh diff --host orgm`; prefer current injected standard, and note any command mismatch during verify.
8. Nix validation after package/profile changes: `nix flake check`; consider focused build for `orgm-hyprland` if profile behavior changes.
9. Formatting: `nix fmt` if Nix files change.

## Rollout and rollback

Rollout steps:

1. Add package dependencies (`gcalcli`, `notify-send` provider) in Nix profile.
2. Add helper/action script and tests/fixtures.
3. Add Hyprland `exec-once` autostart entry through `lua/autostart.lua`.
4. Add Quickshell widget reading the cache.
5. Document OAuth bootstrap and troubleshooting.
6. Run dotfile/Nix verification before syncing.

Rollback steps:

1. Remove/comment the calendar helper and calendar Quickshell startup entries in Hyprland autostart.
2. Remove or ignore the Quickshell calendar entrypoint/import.
3. Optionally delete `$XDG_CACHE_HOME/orgm-calendar` and `$XDG_STATE_HOME/orgm-calendar`.
4. Leave `gcalcli` OAuth credentials untouched unless the user explicitly wants revocation.
5. Re-run `orgm-dot diff --host orgm` to confirm rollback diff.

## Future extension points

- `orgm-hypr calendar` provides command glue/supervision/status while `gcalcli` remains primary calendar access.
- Multi-calendar filters can be added via `calendarId`, `calendarName`, and future `color` fields.
- Notification center integration can consume the same event/reminder state without replacing `notify-send` MVP.
- Email summaries or app-alert routing can use `stableKey`, `horizonsMinutes`, and status metadata.
- Rich event editing can be added behind `orgm-hypr calendar add/edit` commands without embedding Google API logic in QML.

## Risks and open questions

- `gcalcli` output format and availability of event IDs/html links must be verified during implementation; schema may need adapters or derived IDs.
- Timezone and all-day event normalization are the highest correctness risks.
- The active Quickshell shell composition may differ between shared `.config/quickshell` and host-specific `DankMaterialShell`; implementation must choose an integration point without breaking existing shell startup.
- `openspec/config.yaml` still references a different current change (`hyprchy`) and uses `./dot.sh diff`; user-provided project standards prefer `orgm-dot diff --host orgm`.
- No web-browsing tool is available in this phase, so external references should be inspected by the implementation/explore phase if not already captured elsewhere.
