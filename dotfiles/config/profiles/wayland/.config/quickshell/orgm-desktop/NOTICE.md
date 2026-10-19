# Ryoku desktop widgets

Adapted from https://github.com/aethctl/Ryoku-on-NixOS at
`28c5207586babb136aecf8568ce3ed873fa8f8fd`.

Sources: `ryoku/shell/quickshell/shell/modules/desktop/clock/{ClockDigital,DateInline}.qml`,
`clock/lib/clock.js`, `desktop/calendar/{CalendarGrid,CalendarDay,CalendarWidget}.qml`,
and `services/lib/calendar.js`. Retain upstream copyright and GPLv3 license
(`COPYING`). No upstream assets/fonts are copied.

Local adaptations: independent settings/theme/clock, standalone calendar host,
minimal per-monitor bottom-layer surfaces, shared Sway/Hyprland launcher,
local palette, bounded layout, no Ryoku shell/services, events, holidays, plugins,
wallpaper manager or network requests. Existing Ryoku files are never modified.
