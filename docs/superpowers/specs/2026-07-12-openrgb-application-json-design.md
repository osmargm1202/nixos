# OpenRGB Application JSON Configuration Design

## Goal

Move Logitech G213 application color rules out of Python dictionaries and into an editable JSON file. Users can add focused-window and notification mappings without modifying service code.

The first new mapping is the Chromium Crunchyroll web application. Focusing its window illuminates the complete keyboard uniformly in warm orange (`#F28C28`).

## Scope

The JSON configuration controls:

- focused-window class matching;
- desktop-notification application-name matching;
- one uniform RGB color per application.

It does not control device selection, effect timing, retry behavior, profile restoration, or per-zone colors. Those remain implementation constants in `main.py`.

## Files

- `dotfiles/config/shared/.config/openrgb/lg213/apps.json`: application rules.
- `dotfiles/config/shared/.config/openrgb/lg213/main.py`: configuration loading, validation, matching, and existing effects.
- `tests/openrgb/test_lg213.py`: configuration and behavior tests.

## JSON Schema

The root object contains an `applications` array. Each application entry has this form:

```json
{
  "name": "Crunchyroll",
  "windowClasses": ["crunchyroll"],
  "notificationNames": ["crunchyroll"],
  "color": "#F28C28"
}
```

Fields:

- `name`: non-empty descriptive string used in diagnostics.
- `windowClasses`: array of non-empty strings matched against focused-window classes.
- `notificationNames`: array of non-empty strings matched against notification application names.
- `color`: RGB color encoded strictly as `#RRGGBB`.

At least one matching list must contain a value. A missing matching list is treated as empty.

Existing Discord, Vesktop, Dota, and Steam rules migrate from Python dictionaries into this file without changing their current colors or behavior.

## Loading and Validation

`main.py` loads `apps.json` from its own directory when the service starts. It validates the root structure and each application independently, then converts valid hexadecimal colors into `RGBColor` values.

Failure behavior:

- A missing file, malformed JSON, or invalid root logs a clear error and yields an empty rule set.
- An invalid application entry logs an error containing its name or array position and is skipped.
- Valid entries remain active when another entry is invalid.
- An empty rule set keeps the service running but maps no focus or notification events.

Configuration changes take effect after restarting `openrgb-notify.service`. Runtime hot reload is outside scope.

## Matching and Focus Flow

Matching remains case-insensitive substring matching. A configured pattern such as `crunchyroll` therefore matches Chromium class `chrome-www.crunchyroll.com__-Default`.

Focus flow:

1. Hyprland emits an `activewindow` event.
2. The service compares the window class with every configured `windowClasses` pattern.
3. First matching application supplies its color.
4. The existing reliable ambient writer sends a uniform frame to all five G213 areas.
5. If no application matches, the service reloads the saved `.orp` base profile.

Application order in the JSON array defines precedence when multiple rules match.

## Notification Flow

1. `dbus-monitor` provides the notification application name.
2. The service compares it with configured `notificationNames` patterns.
3. First matching application supplies its color.
4. Existing notification palette and blink timing derive from that base color.
5. After blinking, current ambient focus state is restored.

A notification without a matching rule is ignored.

## Safety and Compatibility

The existing OpenRGB connection, G213 selection, Direct mode enforcement, ambient retries, notification locking, and `.orp` restoration behavior remain unchanged.

Invalid configuration must not terminate the listener or leave a stale application color active. Focusing an unmapped application always restores the base profile.

## Testing

Automated tests cover:

- loading valid application rules;
- strict `#RRGGBB` conversion, including Crunchyroll `#F28C28`;
- case-insensitive substring matching;
- matching `crunchyroll` against `chrome-www.crunchyroll.com__-Default`;
- uniform Crunchyroll color across all five keyboard areas;
- missing and malformed JSON producing an empty rule set without crashing;
- invalid entries being skipped while valid entries survive;
- migration of existing Discord, Vesktop, Dota, and Steam behavior;
- unchanged ambient retries, notification blinking, and base-profile restoration.

## Deployment

Changes are made in the dotfiles source tree. After tests pass, commit the changes and run `nh os switch` to deploy the Home Manager configuration. Restart `openrgb-notify.service` if the switch does not restart it automatically, so it reloads `apps.json`.
