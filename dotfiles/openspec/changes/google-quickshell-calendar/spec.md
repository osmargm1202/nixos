# Spec Delta: Google Quickshell Calendar

## ADDED Requirements

### Requirement: gcalcli-backed calendar data source

The calendar runtime SHALL use `gcalcli` as the primary backend for Google Calendar authentication and calendar data access. The implementation SHALL expose the command surface through the existing Go binary as `orgm-hypr calendar <function>`, but SHALL NOT make `orgm-hypr` the primary Google Calendar data backend.

#### Scenario: calendar data comes from gcalcli

- Given Google OAuth has been configured for `gcalcli`
- When the calendar helper refreshes calendar data
- Then it invokes `gcalcli` or consumes data produced by `gcalcli`
- And the generated local cache reflects Google Calendar events returned by `gcalcli`
- And `orgm-hypr calendar` acts as command glue around `gcalcli`, not as an independent calendar data provider

#### Scenario: missing gcalcli is reported clearly

- Given `gcalcli` is not installed or is not executable
- When the calendar helper starts or refreshes
- Then it SHALL fail gracefully without crashing Quickshell
- And it SHALL expose a user-visible or log-visible message explaining that `gcalcli` is required
- And it SHALL preserve any existing valid cache instead of replacing it with invalid data

### Requirement: Google OAuth and configuration bootstrap

The change SHALL document that Google OAuth credentials and tokens are configured through normal `gcalcli` setup. The runtime SHALL NOT store Google account secrets outside `gcalcli`'s normal credential/token handling. The implementation SHOULD provide clear bootstrap and troubleshooting guidance for first-run OAuth, expired tokens, missing calendars, and network failures.

#### Scenario: OAuth is configured externally through gcalcli

- Given the user has not completed `gcalcli` OAuth setup
- When the helper attempts to sync
- Then the helper SHALL report that `gcalcli` OAuth/bootstrap is required
- And it SHALL NOT prompt for or persist Google credentials itself

#### Scenario: token or authorization failure is visible

- Given `gcalcli` returns an authorization, token, or permission error
- When the helper records the refresh result
- Then the error SHALL be observable through logs, status JSON, or an equivalent troubleshooting surface
- And the Quickshell widget SHALL show a non-destructive failure state rather than stale data as if it were fresh

### Requirement: local JSON cache contract

The calendar helper SHALL maintain a local JSON cache that Quickshell can read without directly invoking Google APIs. The cache SHALL include enough structured data to render the visible month grid, selected-day event list, event titles, event start/end times, all-day status where available, event identifiers where available, event links where available, and refresh/error metadata. Cache files SHOULD live under `$XDG_CACHE_HOME` or `$XDG_STATE_HOME` and SHOULD avoid repository-tracked paths.

#### Scenario: widget renders from local cache

- Given the helper has completed a successful refresh
- When Quickshell opens the calendar widget
- Then Quickshell SHALL read event data from the local JSON cache
- And it SHALL render month/day information without directly invoking `gcalcli` for every UI render

#### Scenario: cache write is safe for readers

- Given Quickshell may read the cache while the helper refreshes it
- When the helper writes new cache data
- Then the write SHALL avoid exposing partially written JSON to the widget
- And the previous valid cache SHALL remain usable if refresh or serialization fails

#### Scenario: cache metadata identifies freshness

- Given a cache file exists
- When Quickshell reads it
- Then the cache SHALL expose last successful refresh time and current error state, if any
- And the widget SHALL be able to distinguish fresh data, stale data, empty data, and refresh failure

### Requirement: sync cadence and offline behavior

The calendar helper SHALL refresh calendar data on startup and SHOULD refresh periodically while the Hyprland session is active. The helper SHALL tolerate temporary network failures, empty calendars, and `gcalcli` errors without disrupting unrelated desktop behavior. When offline or failing, the widget MAY display stale cached events, but it SHALL indicate that the cache is stale or refresh failed when that status is known.

#### Scenario: startup refresh populates cache

- Given Hyprland starts the helper through `exec-once`
- When the helper starts
- Then it SHALL attempt an initial calendar refresh
- And it SHALL produce or update the local JSON cache when `gcalcli` succeeds

#### Scenario: network failure preserves last known data

- Given a previous valid cache exists
- And the network is unavailable during refresh
- When the helper refreshes
- Then it SHALL keep the previous valid cache data available
- And it SHALL record an observable refresh failure or stale-cache status

### Requirement: Hyprland exec-once startup

The calendar helper SHALL be started by Hyprland `exec-once` in the initial implementation. The change SHALL NOT introduce a systemd user service or timer as the startup mechanism for this slice. Startup configuration SHALL be managed through the dotfiles source paths and manifest rules used by this repository.

#### Scenario: Hyprland starts helper once per session

- Given the dotfiles are synced to the `orgm` host
- When the user starts a Hyprland session
- Then Hyprland SHALL start the calendar helper from an `exec-once` entry
- And the startup path SHALL NOT require enabling a systemd user unit

#### Scenario: startup can be disabled for rollback

- Given the calendar helper causes startup or runtime problems
- When the user removes or disables the Hyprland `exec-once` entry
- Then the helper SHALL stop starting automatically
- And existing `gcalcli` OAuth credentials SHALL remain untouched

### Requirement: Quickshell calendar widget UX

The Quickshell widget SHALL provide a simple, pleasant, Caelestia-inspired calendar surface that remains consistent with the repository's existing Quickshell style. The UI SHALL include a month grid, selected-day state, selected-day event list, and basic action buttons. The UI SHOULD be readable, compact, keyboard/mouse friendly where practical, and visually calm rather than a full calendar application.

#### Scenario: user views month and selected day events

- Given the cache contains events for the visible month
- When the user opens the calendar widget
- Then the widget SHALL show a month grid
- And the current or selected day SHALL be visually distinguishable
- And selecting a day SHALL show that day's events in a details or agenda area

#### Scenario: empty day is handled gracefully

- Given the selected day has no events in the cache
- When the selected-day event list is displayed
- Then the widget SHALL show an empty-state message or equivalent calm placeholder
- And it SHALL NOT render an error solely because the day has no events

#### Scenario: stale or failed data is visible without blocking use

- Given the cache is stale or the last refresh failed
- When the widget is displayed
- Then it SHALL still render any usable cached calendar data
- And it SHALL show an observable stale/error indicator with enough context for troubleshooting

### Requirement: desktop activation triggers

The calendar UI SHALL be reachable from the desktop clock/date entry points. Clicking the Waybar time/date/day module SHALL open or toggle the same Quickshell calendar UI as the keyboard shortcut. Pressing `Win+Shift+C` SHALL also open or toggle the calendar. Both triggers SHALL use the same underlying calendar surface and SHALL NOT create separate inconsistent calendar implementations.

#### Scenario: Waybar clock/date click opens calendar

- Given the user is in a Hyprland session with the Waybar time/date/day module visible
- When the user clicks the time, date, or day module
- Then the Quickshell calendar UI SHALL open or toggle
- And the selected day SHOULD default to today unless the UI already has an active selected day

#### Scenario: keyboard shortcut opens calendar

- Given the user is in a Hyprland session
- When the user presses `Win+Shift+C`
- Then the Quickshell calendar UI SHALL open or toggle
- And it SHALL show the same cache-backed calendar surface used by the Waybar click action

#### Scenario: activation does not start duplicate backends

- Given the calendar helper is already running from Hyprland startup
- When the user activates the calendar repeatedly through Waybar click or `Win+Shift+C`
- Then activation SHALL NOT start duplicate `gcalcli` helper daemons
- And it SHALL only toggle or focus the UI surface

### Requirement: calendar actions

The widget SHALL provide actions to add an event, view or open an event/day, and open Google Calendar on the web. Add-event behavior MAY use `gcalcli` or open Google Calendar web, but it SHALL NOT require a full in-widget event editor in the initial slice. Event-opening behavior SHOULD use event links from the cache when available and SHOULD fall back to the Google Calendar web view when direct links are unavailable.

#### Scenario: add event action is available

- Given the widget is open
- When the user chooses the add-event action
- Then the implementation SHALL start the documented add-event flow through `gcalcli` or Google Calendar web
- And the widget SHALL NOT require a full custom editor to satisfy this action

#### Scenario: view event or day action opens calendar context

- Given the selected day has an event with an available link
- When the user chooses view/open for that event
- Then the implementation SHOULD open that event or an equivalent Google Calendar context in the browser

#### Scenario: open web action opens Google Calendar

- Given a browser opener is available
- When the user chooses the open-web action
- Then Google Calendar SHALL open in the browser
- And failure to open the browser SHALL be reported without breaking the widget

### Requirement: notify-send reminders

The calendar runtime SHALL emit desktop reminders using `notify-send` for event horizons of 24 hours, 12 hours, 4 hours, and 1 hour before an event starts. Reminder notifications SHALL include enough information to identify the event and its start time. Reminder behavior SHALL be duplicate-safe across refreshes and helper restarts by storing notification bookkeeping in local state.

#### Scenario: reminders fire at configured horizons

- Given an event starts in the future
- And the helper is running with event data in the cache
- When the event crosses the 24h, 12h, 4h, or 1h reminder horizon
- Then the helper SHALL send a `notify-send` reminder for that horizon
- And the notification SHALL identify the event and timing in a user-understandable way

#### Scenario: reminder de-duplication prevents spam

- Given a reminder for an event and horizon has already been sent
- When the helper refreshes data, restarts, or re-evaluates reminders
- Then it SHALL NOT send the same event/horizon reminder again unless local reminder state is intentionally cleared or the event identity materially changes

#### Scenario: notification failure does not corrupt cache

- Given `notify-send` fails or no notification daemon accepts the notification
- When the helper attempts to send a reminder
- Then the failure SHALL be observable for troubleshooting
- And event cache data SHALL remain intact
- And reminder state SHALL NOT falsely mark an unsent reminder as successfully delivered unless the design explicitly documents best-effort semantics

### Requirement: failure states and user feedback

The implementation SHALL define observable failure states for missing dependencies, OAuth/configuration failure, network failure, invalid or stale cache, malformed cache JSON, notification failure, and browser-open failure. Failure states SHALL avoid notification spam and SHALL avoid breaking unrelated Hyprland, Quickshell, or dotfile behavior.

#### Scenario: malformed cache does not crash the shell

- Given the local JSON cache is malformed or unreadable
- When Quickshell loads the widget
- Then the widget SHALL show an error or empty-state surface
- And it SHALL NOT crash the entire shell session

#### Scenario: unrelated desktop behavior is preserved

- Given the calendar helper or widget fails
- When the user continues using Hyprland and Quickshell
- Then unrelated keybindings, widgets, launchers, and desktop startup behavior SHALL continue to work

### Requirement: managed dotfile compatibility

Runtime implementation files SHALL be added under tracked dotfile source paths such as `config/shared` or `config/hosts/<host>` according to repository conventions. New managed paths SHALL be reflected in `config/dotfiles.json` when required. Implementation validation SHALL include a dotfile diff for host `orgm` before applying or claiming sync readiness.

#### Scenario: new dotfiles are tracked by manifest

- Given implementation adds a new managed Quickshell, Hyprland, helper, or documentation path
- When dotfile management is reviewed
- Then the path SHALL live under the appropriate tracked source tree
- And `config/dotfiles.json` SHALL include the path when the dotfile manager requires manifest registration

#### Scenario: orgm dotfile diff is part of validation

- Given implementation changes tracked dotfiles for this feature
- When the implementation is verified
- Then the verifier SHALL run an `orgm` dotfile diff command according to current project standards
- And unexpected unrelated dotfile changes SHALL be investigated before sync or completion

### Requirement: extensibility boundaries

The initial slice SHALL keep future notification center, email summary, app-alert routing, multi-calendar filters, and deeper event editing as extension points rather than required runtime behavior. The design SHOULD avoid data shapes and UI coupling that would prevent those later integrations, but the initial acceptance SHALL NOT depend on implementing them.

#### Scenario: future integrations are not required for acceptance

- Given the widget, cache, `gcalcli` sync, Hyprland startup, and `notify-send` reminders satisfy this spec
- When acceptance is evaluated
- Then the absence of email delivery, persistent notification center integration, mobile/app push alerts, or a full in-widget editor SHALL NOT block acceptance

#### Scenario: data model leaves room for future routing

- Given reminder state and event cache schemas are designed
- When future notification center or app-alert routing is considered
- Then event identifiers, reminder horizons, timestamps, and status metadata SHOULD be represented clearly enough to support extension without replacing the whole cache contract

## Acceptance Criteria

- `gcalcli` is the documented and actual backend for Google Calendar OAuth and event data access.
- Hyprland startup uses `exec-once`; no systemd user service or timer is introduced for the initial slice.
- A local JSON cache exists and supports rendering a month grid, selected-day events, freshness status, and failure status.
- The Quickshell widget displays a pleasant month calendar, supports day selection, and lists selected-day events.
- The widget opens/toggles from both the Waybar time/date/day click target and the `Win+Shift+C` keybinding.
- The widget exposes actions to add an event, view/open an event or day, and open Google Calendar web.
- `notify-send` reminders support 24h, 12h, 4h, and 1h horizons with duplicate protection across refreshes and restarts.
- Missing dependencies, OAuth problems, network failures, malformed cache, notification failures, and browser-open failures are observable and non-destructive.
- Runtime state remains local under XDG cache/state locations and repository-tracked source paths are used only for managed configuration/code.
- New managed dotfile paths are reflected in `config/dotfiles.json` when required.
- Implementation-phase validation includes an `orgm` dotfile diff and any broader project checks relevant to changed files.

## Compatibility and Non-goals

- This change SHALL NOT replace Google Calendar with CalDAV or a multi-provider calendar stack.
- This change SHALL NOT make `orgm-hypr calendar` the primary backend.
- This change SHALL NOT require systemd user services for startup in the initial implementation.
- This change SHALL NOT implement a full offline calendar editor or conflict-resolution engine.
- This change SHALL NOT store Google account secrets beyond normal `gcalcli` credential/token handling.
- This change SHALL preserve unrelated Hyprland, Quickshell, and dotfile behavior.
