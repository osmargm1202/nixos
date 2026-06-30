# Proposal: google-quickshell-calendar

## Status

proposed

## Problem

The Hyprland desktop does not yet have a pleasant, local-first Google Calendar surface that fits the current Quickshell direction. Calendar access currently requires opening a browser or external app, and reminder/agenda behavior is not integrated with the desktop notification flow.

The desired workflow is a small Quickshell calendar inspired by Caelestia-style shell polish: a simple month grid, selectable days, day-event details, quick actions, and reliable reminders backed by `gcalcli` with Google OAuth.

## Goals

- Add a Google Calendar desktop widget for the Hyprland/Quickshell environment.
- Use `gcalcli` as the primary backend for Google Calendar OAuth and calendar data access.
- Keep runtime state local through a JSON cache that Quickshell can consume.
- Start the calendar sync/reminder helper through Hyprland `exec-once`, not a systemd user service.
- Provide a simple, pleasant UI: month grid, selected-day event list, and actions to add an event, view an event, or open Google Calendar in the browser.
- Activate/toggle the calendar from the desktop clock/date surface: clicking the Waybar time/date/day module and pressing `Win+Shift+C` SHALL open the same calendar UI.
- Support reminder/alert horizons of 24h, 12h, 4h, and 1h through `notify-send`.
- Keep the proposal/design open for future notification-center, email, or app-alert integration without committing to those in the first runtime slice.

## Non-goals

- Do not make `orgm-hypr calendar` the primary Google Calendar data backend; it is the required command surface around `gcalcli`.
- Do not replace Google Calendar with a new calendar provider or CalDAV stack.
- Do not introduce a systemd user service for startup in the initial implementation.
- Do not implement a full calendar editor inside Quickshell.
- Do not build email delivery, persistent notification center integration, or mobile/app push alerts in the first slice.
- Do not implement runtime code in this proposal phase.

## Proposed scope

### In scope

- A tracked Quickshell calendar widget under the existing dotfiles-managed Quickshell configuration.
- `gcalcli` installation/configuration expectations and documentation for Google OAuth setup.
- A local JSON cache contract for month/day events and reminder state.
- A lightweight sync/reminder launcher or helper that can be started by Hyprland `exec-once`.
- `notify-send` reminders for 24h, 12h, 4h, and 1h event horizons, with duplicate-notification protection in local state.
- UI controls for:
  - changing visible month;
  - selecting a day;
  - viewing events for the selected day;
  - adding an event through `gcalcli` or Google Calendar web;
  - viewing/opening an event or Google Calendar in the browser.
- Documentation for manual OAuth/bootstrap and troubleshooting.

### Out of scope

- Primary Google Calendar provider/backend logic in `orgm-hypr`; it only wraps/supervises `gcalcli`.
- Systemd unit/timer setup.
- Multi-provider calendar abstraction.
- Full offline event creation/editing conflict resolution.
- Account-secret storage beyond `gcalcli`'s normal OAuth/token handling.
- Automatic migration from other calendar widgets.

## Affected areas

- `config/shared/.config/quickshell` or host-specific Quickshell paths, depending on where the current shell config is managed.
- Hyprland startup configuration for an `exec-once` entry.
- Dotfile manifest (`config/dotfiles.json`) if new managed paths are added.
- Local runtime/cache paths, likely under `$XDG_CACHE_HOME` or `$XDG_STATE_HOME`, for generated calendar JSON and notification bookkeeping.
- Package/config documentation for `gcalcli`, `notify-send`, browser opening, and OAuth setup.

## References

The implementation design should inspect and cite these references before code work starts:

- xeins-custom ML4W Google Calendar Quickshell widget.
- ML4W discussion #1573.
- `insanum/gcalcli` for Google Calendar CLI behavior and OAuth expectations.
- `caelestia-dots/shell` for visual direction and interaction feel.
- `faiyt-quickshell`, `quickdash`, and `HyprQuick` for Quickshell patterns and shell composition ideas.

## Phased delivery

1. **Discovery/design artifact**
   - Confirm current Quickshell layout, Hyprland startup files, and managed dotfile paths.
   - Define the JSON cache schema, sync cadence, and reminder-state format.
   - Decide exact UI integration point and styling vocabulary.

2. **Backend/cache slice**
   - Configure `gcalcli` expectations and create a helper that exports upcoming/month/day events to local JSON.
   - Add duplicate-safe reminder state and `notify-send` alarm emission.
   - Wire startup through Hyprland `exec-once`.

3. **Quickshell UI slice**
   - Render month grid and selected-day agenda from the JSON cache.
   - Add basic navigation and action buttons.
   - Apply Caelestia-inspired but repo-native styling.

4. **Polish/verification slice**
   - Add docs, troubleshooting, and focused verification.
   - Validate dotfile sync diff and Nix checks where applicable.
   - Record limitations and future notification-center/email/app-alert direction.

## Acceptance criteria

- `gcalcli` is documented and used as the calendar data backend.
- Hyprland starts the calendar helper via `exec-once`.
- A local JSON cache exists with enough data for the Quickshell widget to render a month grid and selected-day events.
- Quickshell shows a month calendar, allows selecting a day, and lists that day's events.
- The same calendar UI opens/toggles when clicking the Waybar time/date/day module and when pressing `Win+Shift+C`.
- UI provides actions to add an event, view/open an event, and open Google Calendar web.
- `notify-send` reminders can fire at 24h, 12h, 4h, and 1h before events without repeatedly spamming the same reminder.
- Managed dotfile changes are made under tracked source paths and reflected in `config/dotfiles.json` if new paths are added.
- Validation for an implementation phase includes `orgm-dot diff --host orgm`; broader checks may include `nix flake check`, focused NixOS builds, and `nix fmt` as relevant.

## Dependencies

- `gcalcli` with working Google OAuth credentials.
- Network access for sync operations.
- Quickshell and the current Hyprland session.
- `notify-send`/desktop notification daemon support.
- A browser opener for Google Calendar links.
- Existing dotfile management through `orgm-dot`.

## Risks

- Google OAuth setup may be the highest-friction user step and may need clear manual instructions.
- `gcalcli` output shape and timezone handling must be validated before locking the cache schema.
- Reminder de-duplication needs careful local state to avoid notification spam after restarts.
- Quickshell examples may not match the repo's current shell structure and could require adaptation.
- Startup via Hyprland `exec-once` is simple, but long-running helpers need safe restart/failure behavior.
- Missing exploration context for the exact current Quickshell structure remains a risk until the design phase inspects the repo.

## Rollback / escape hatch

- Remove or disable the Hyprland `exec-once` calendar helper entry.
- Remove the Quickshell calendar widget import/entrypoint from the shell config.
- Keep `gcalcli` credentials untouched unless the user explicitly wants to revoke OAuth access.
- Delete local generated cache/reminder state if it becomes stale or noisy.
- Fall back to opening Google Calendar in the browser while the widget is disabled.

## Optional future direction

`orgm-hypr calendar` now provides glue commands, daemon supervision, and status JSON around calendar behavior in the existing Go binary. It is not the primary Google Calendar backend; `gcalcli` remains the source of calendar access.

Future enhancements may include a notification center, email summaries, richer app-alert routing, multi-calendar filters, and deeper event creation/editing.

## Review workload estimate

Expected implementation is medium-sized and should be reviewed in slices:

1. Cache/reminder helper plus docs for `gcalcli` setup.
2. Hyprland startup and dotfile manifest updates.
3. Quickshell UI and styling.
4. Final verification and troubleshooting docs.

Estimated review size: moderate, likely 300-700 changed lines depending on existing Quickshell structure and helper implementation language.
