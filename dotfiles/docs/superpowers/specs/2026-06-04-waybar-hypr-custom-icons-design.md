# Waybar-Hypr Custom Icon Bar Design

## Goal

Test a cleaner Waybar-Hypr top/right visual style: no texture, a very dark transparent blue bar surface, fine border lines, and image icons for each custom button in the top-right module group.

## Scope

Only `config/shared/.config/waybar-hypr` is in scope. Regular Waybar remains unchanged.

## Visual Direction

- Remove futuristic texture backgrounds.
- Use a very dark translucent blue panel color: `rgba(2, 10, 24, 0.78)`.
- Use fine horizontal edge lines instead of rectangular full borders, avoiding fake square corners.
- Remove internal divider lines.
- Keep top and bottom bars visually consistent.
- Replace glyph text on top-right custom buttons with SVG image icons.
- SVG style: transparent background, cyan/blue line icon, simple futuristic geometry.

## Custom Buttons

The top-right custom buttons get individual icons:

- `custom/theme_toggle`
- `custom/wallpaper`
- `custom/usb_devices`
- `custom/nixclean`
- `custom/hardware_fetch`
- `custom/pi_status`
- `custom/headset_reconnect`
- `custom/logout_menu`

Tooltips and click behavior stay unchanged.

## Verification

- `tests/helpers/waybar-hypr-custom-icons.bats.sh` passes.
- `go test ./internal/orgmtheme ./cmd/orgm-themes -count=1` passes.
- Live Waybar-Hypr restarts and logs `Bar configured`.
