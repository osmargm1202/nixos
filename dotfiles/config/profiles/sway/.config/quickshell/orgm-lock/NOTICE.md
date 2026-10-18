# qylock session lock

Compatible with Darkkal44/qylock (GPL-3.0), pinned by
`nixos/sddm/sddm-qylock.nix`. The full source, original license and all theme
assets are kept in the Nix closure; no network fetch runs at lock time.
https://github.com/Darkkal44/qylock

The local lock/Auth/fallback code implements the qylock SDDM-compatible
interface using Quickshell's WlSessionLock and PAM. It is GPL-3.0-only; see
LICENSE. It does not run SDDM inside the desktop, import Ryoku singletons,
kill existing lockers, expose an IPC unlock method or use an X11 fullscreen
window as a substitute for a real session lock.

The runtime uses Quickshell 0.3.0 (LGPL-3.0), built with only the required
Wayland/IO/PAM/widgets features. A small local patch destroys removed native
lock windows before Qt 6.11 migrates them to the primary output, preventing a
fatal ext-session-lock buffer-size protocol violation on mixed-size hotplug.
Its complete upstream source and the patch are linked/copied in the Nix package
as `quickshell-source` and `quickshell-session-lock-hotplug.patch`.

The theme carousel in the adjacent orgm-locks directory adapts the wallpaper
carousel's UI; its upstream attribution is retained there.
