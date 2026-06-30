# gcalcli calendar helper — slice 1

This slice adds only the backend/cache/reminder command surface. It does not wire Quickshell UI, Waybar clicks, Hyprland keybindings, autostart, Nix packages, or systemd units.

## Command surface

Managed helper: existing Go binary `orgm-hypr` with implementation in `internal/calendar` and command group `cmd/orgm-hypr calendar`. No standalone `orgm-calendar` binary is tracked or used.

Subcommands:

- `orgm-hypr calendar sync` refreshes the local cache from `gcalcli` and evaluates reminders.
- `orgm-hypr calendar daemon` runs `sync` immediately and then every 10 minutes by default (`ORGM_CALENDAR_SYNC_SECONDS` overrides).
- `orgm-hypr calendar status` prints status metadata from local state.
- `orgm-hypr calendar open-web [date]` opens Google Calendar, optionally on `YYYY-MM-DD`.
- `orgm-hypr calendar open-event <id>` opens a cached event `htmlLink`, falling back to the event day.
- `orgm-hypr calendar add [date]` opens Google Calendar's create-event URL, optionally for the date.
- `orgm-hypr calendar toggle-ui` is a safe stub for later UI wiring and does not start a backend daemon.

## Runtime files

- Cache: `${XDG_CACHE_HOME:-$HOME/.cache}/orgm-calendar/events.json`
- Status: `${XDG_STATE_HOME:-$HOME/.local/state}/orgm-calendar/status.json`
- Reminder state: `${XDG_STATE_HOME:-$HOME/.local/state}/orgm-calendar/reminders.json`

The cache uses schema version `1` and includes `generatedAt`, `lastSuccessAt`, `timezone`, `source`, `status`, and normalized `events[]` with stable keys, dates/times, all-day flags, and event links when available. Writes use temp-file + rename so readers do not see partial JSON. Failed refreshes preserve the last valid cache and update status metadata instead.

## OAuth/bootstrap assumptions

`gcalcli` remains the backend of record. The helper does not prompt for, store, or parse Google credentials. Complete OAuth using normal `gcalcli` setup in a terminal before expecting `sync` to succeed, for example by running a simple `gcalcli agenda` command and following its browser/token flow.

Python 3.13 / Python packaging note: `nixos/profiles/hyprland.nix` explicitly adds only `gcalcli` and `libnotify` for this feature. The existing `python3Minimal` entry was pre-existing. Because `gcalcli` is a Python application, Nix may pull Python as part of `gcalcli`; the Go calendar helper does not add or require extra Python packages.

Troubleshooting states are recorded as `dependency_error`, `auth_error`, `network_error`, `parse_error`, or `unknown_error`. Missing `notify-send` is reported as a notification dependency problem while cache sync remains usable.

## Reminder semantics

Reminder horizons are `1440`, `720`, `240`, and `60` minutes. A reminder is sent only when the event is within a small crossing window for that horizon; the default grace window is 10 minutes (`ORGM_CALENDAR_REMINDER_GRACE_MINUTES`). This avoids flooding old 12h/4h reminders after a long offline period. A reminder is marked sent only after `notify-send` exits successfully. Clearing `reminders.json` resets duplicate protection.

## Test hooks

The test suite uses environment overrides:

- `ORGM_CALENDAR_GCALCLI_CMD` injects fixture event output.
- `ORGM_CALENDAR_NOTIFY_CMD` records or fails notification attempts.
- `ORGM_CALENDAR_OPEN_CMD` records browser-open URLs.
- `ORGM_CALENDAR_NOW` fixes time for deterministic cache/reminder tests.
