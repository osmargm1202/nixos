# Remote desktop hotplug and Tailscale/SSH selector

## Restored Jarq external-only connection
After disabling eDP-1, HDMI-A-1 remained active at x1920. Tailscale/SSH and the tunnel were healthy; WayVNC composite `--desktop` capture aborted with `Composites must start at (x, y) = (0, 0)`. Restarting alone did not solve it because the same layout triggered it again.

Removed composite mode from the native command. WayVNC now shares **one available output at a time**, automatically switching when its selected output disappears. No physical display was repositioned, enabled/disabled or resized by the fix. No compositor, user applications or system restart. The scoped server also sets LimitCORE=0 to limit dumps of captured desktop buffers; existing OS crash records were not read or removed.

Applied helper and marked user-service update on OrgM and Jarq. Canonical Nix server definition carries the same core limit. Only each new VNC service was restarted; tunnels stayed intact.

## Approved selector extension
User replied “si” to showing Tailscale devices and selecting Desktop or Terminal SSH, with SSH authorization still required.

**Conectar a equipo** now:
1. Reads Tailscale device metadata and merges existing prepared VNC targets.
2. Excludes the current machine by stable ID and addresses, not ambiguous hostnames. Labels show name, full address and online/offline state.
3. Offers **Escritorio** only for devices whose private VNC peer is configured.
4. Offers **Terminal SSH** using a normal host terminal (Kitty/OpenSSH), asks remote username and leaves SSH authentication/host-key confirmation interactive.

Terminal-only machines need an SSH server and authorized user, not WayVNC, Remmina or a graphical session. Tailscale network membership alone never grants OS access. Offline peers and devices without SSH may appear, but the launcher does not pretend they accept logins. No arbitrary tailnet device was probed or logged into during deployment.

Native SSH **does not use the dedicated restricted VNC identity** and does not receive keys through Flatpak. Arguments are validated and passed without shell interpolation; login is a separate `-l` argument and StrictHostKeyChecking=ask is retained. No auto host-key trust, copied passwords or authorization changes. Username prompt handles account/realm spelling while excluding shell/option injection.

Updated selection policy (see `2026-10-23-tailnet-filter.md`) lists only verified online Linux peers; unavailable Tailscale metadata no longer falls back to configured targets. Cancellation performs no action. Named CLI `connect PEER`, profile/tunnel formats and dedicated VNC authentication remain compatible. The missing standalone `orgm-rofi` dependency was added selectively on Jarq, preserving native shared libraries/themes; actual installed theme parses in its live environment without opening a window.

## Verification
- Private two-output Sway hotplug: RED reproduced EOF with composite mode; GREEN external-only nonzero origin plus repeated alternating output removal/reconnect in the same server process.
- Real Jarq external-only framebuffer:5reconnections immediately after the fix and3after selector deployment passed. Frame bytes discarded, no screenshot persistence or live input. Actual service NRestarts0 after restart and no new errors observed.
- Existing private native video/input/clipboard-churn regression and actual Remmina Flatpak private GUI passed with the new single-output command. User video playback remains independent of viewer disconnect.
- **19unit tests passed** (8discovery/SSH/selector,11native VNC/transport). Independent reviewer ran the same19 and found no new important issues.
- Real themed Rofi device/protocol/username menus tested on a private Sway with actual virtual-key input; terminal argv and prepared-desktop dispatch observed through fixture-owned spies, never real host login.
- All6public-host Nix service/activation projections and3desktop manifest checks passed.
- Installed discovery on both hosts sees the prepared opposite peer and excludes Self. Actual Jarq Sway PATH contains ~/.local/bin; themed helper dump works. No general-suite all-green claim; older unrelated failures remain documented elsewhere.

## Backups and deployment
- Hotplug backups both hosts: `~/.local/state/orgm-remote-desktop/backups/hotplug-20261023T062405Z/`.
- Selector backups: OrgM `selector-20261023T063036Z`, Jarq `selector-20261023T063037Z` under that same backups directory. Index records installed/source files and presence.
- Added `connections.py` inside the existing owned helper directory; desktop-entry comment updated. `orgm-rofi` remains owned by rofi, not remote-desktop manifest; Jarq's rofi manifest gained only the missing path.
- Applied only selected feature files to actual active mutable sources/HOME; no wholesale canonical-to-Jarq source copy. Private device configuration and authorized_keys unchanged. Future declarative cleanup of original marked bootstrap VNC units remains as documented in the initial rollout report.
- No commit/push requested or performed.

## Files
- `remote.py` — stable output mode and interactive selector delegation
- `connections.py` — read-only discovery, selection, normal SSH
- `remote-desktop.nix` — scoped LimitCORE
- `orgm-remote-desktop.desktop` — desktop/SSH description
- `tests/remote-desktop-hotplug.test.py` — actual private output lifecycle
- `tests/remote-connections*.test.py` — unit and actual private UI regression
