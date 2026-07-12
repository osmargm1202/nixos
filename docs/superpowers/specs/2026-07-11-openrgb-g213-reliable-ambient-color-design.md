# OpenRGB G213 Reliable Ambient Color Design

## Goal

When a mapped application is focused, apply its solid color uniformly to all five lighting areas exposed by the Logitech G213. Preserve existing notification effects and base-profile restoration.

## Evidence and root cause

The running service is healthy and detects focus changes correctly. OpenRGB exposes the G213 as one keyboard zone containing five logical LEDs: Left, Middle, Right, Arrow/Home, and Numpad.

OpenRGB implements a device-wide color update for this keyboard as five sequential `SetDirect` HID transactions, one for each area. A controlled hardware test showed:

- one blue device-wide write illuminated only part of the keyboard;
- four red device-wide writes separated by 120 ms illuminated all five areas.

Therefore the failure is incomplete delivery or application of the sequential G213 direct-color transactions. It is not a focus-matching, application-color, or LED-count error.

## Scope

Change only steady ambient color application while a mapped application is focused.

Keep unchanged:

- notification palette and blink cadence;
- notification locking and dropped-notification behavior;
- application-to-color mappings;
- `.orp` base-profile restoration;
- OpenRGB connection and device selection;
- systemd service configuration.

## Design

Add two named constants:

- `AMBIENT_WRITE_ATTEMPTS = 4`
- `AMBIENT_WRITE_RETRY_SECONDS = 0.12`

Add a focused helper that applies a uniform ambient color reliably:

1. Force the G213 into Direct mode once before writing.
2. Build one frame containing the same color for every exposed LED area.
3. Send that frame four times.
4. Sleep 120 ms between attempts, with no unnecessary sleep after the final attempt.

`apply_ambient()` will call this helper only when `ambient_color` is not `None`. When `ambient_color` is `None`, it will continue to restore the saved OpenRGB profile exactly as before.

The existing blink path will continue using `_set()` directly, so notification behavior does not change.

## Data flow

For a mapped focused window:

`Hyprland activewindow event` → `on_focus()` → mapped `RGBColor` → `apply_ambient()` → reliable uniform helper → Direct mode → four full five-area frames.

For an unmapped focused window:

`Hyprland activewindow event` → `on_focus()` → `None` → `apply_ambient()` → `restore_base()` → load `orgm.orp`.

## Error handling

The existing `_set()` behavior remains responsible for detecting a lost SDK-server connection and reconnecting. If a write reconnects, remaining attempts still resend the full frame. Existing Direct-mode error logging remains unchanged.

This change does not add broad exception handling or alter process restart policy.

## Testing

Automated tests will isolate OpenRGB and timing with fakes or mocks and verify:

1. A mapped focus color forces Direct mode and sends four identical full-device frames.
2. Exactly three 120 ms waits occur between four attempts.
3. Every frame contains one identical color per exposed G213 LED area.
4. An unmapped focus restores the profile and performs no ambient retries.
5. The notification blink path retains its existing frame count, palette, and cadence.

Runtime verification will:

1. Run the automated tests.
2. Commit the dotfiles change.
3. Run `nh os switch` to apply the Home Manager configuration.
4. Restart `openrgb-notify.service` if the switch does not restart it automatically.
5. Focus Steam and confirm blue across all five areas.
6. Focus Vesktop/Discord or Dota and confirm red across all five areas.
7. Focus an unmapped application and confirm `orgm.orp` restoration.
8. Trigger a mapped notification and confirm blink behavior remains unchanged.

## Success criteria

- Steam focus produces uniform blue across all five G213 areas.
- Vesktop, Discord, or Dota focus produces uniform red across all five G213 areas.
- Leaving a mapped application restores the base profile.
- Notification behavior remains unchanged.
- No unrelated configuration or current working-tree changes are modified.
