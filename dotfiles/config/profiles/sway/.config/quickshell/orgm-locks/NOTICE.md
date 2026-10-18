# Login/lock theme carousel provenance

Adapted from shadowofdominance/swaydots:
https://github.com/shadowofdominance/swaydots

Upstream revision: `4e61255e006de0f994ae21cfeab9bac5ccd58acc`.
Source paths: `.config/quickshell/menus/modules/WallpaperPicker.qml`,
`components/{MenuWindow,Surface}.qml`, `config/Style.qml`.

The upstream README grants permission as follows:

> Feel free to use, modify, and share. A star is appreciated. ⭐

No separate license file was present in that revision; no different license
is claimed here. Keep this attribution when redistributing these adaptations.

Local adaptations: dedicated qylock theme catalog, current-monitor selection,
profile palette, safe wheel input, Spanish labels, backend argument vectors,
and process exit after closing. Applying a theme hides/releases the overlay
while Polkit authenticates, then restores it on cancellation/error. No wallpaper
process-management scripts or unrelated menus are included.

Qylock themes and the session-lock/authentication adapter are GPL-3.0; see the
adjacent orgm-lock/NOTICE.md and the pinned Nix package's upstream source/LICENSE.
The qylock repository is not a runtime network dependency.
