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

The theme carousel in the adjacent orgm-locks directory adapts the wallpaper
carousel's UI; its upstream attribution is retained there.
