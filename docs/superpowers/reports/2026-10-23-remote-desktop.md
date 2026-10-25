# Remmina / native remote desktop rollout

## Applied

Applied per-user, without system switch or compositor restart, on **OrgM (Hyprland)** and **Jarq (Sway)**. User authorized Jarq in the existing Tailscale network. Both have Remmina Flatpak1.4.43, private native WayVNC and session-owned systemd services. Canonical Nix defaults cover the fleet; other machines have not been activated.

- Open **Remmina → Mis equipos → Jarq — Tailscale / Orgm — Tailscale**.
- Alternatively **Win+Space → Conectar a equipo**, then select the peer.
- Tailscale and the target graphical session must remain running. No VNC password is required: dedicated SSH keys authenticate access.
- Closing the viewer leaves the target desktop and applications running. For unattended video use the target Control Center **Mantener despierto / Caffeine**, then disable it afterwards. No lock/idle policy was disabled globally. This controls the existing desktop; it is not an audio/video-streaming solution.
- Shared clipboard is deliberately unavailable in this backend; keyboard and pointer control remain enabled.

## Transport and identity

No VNC TCP ports or firewall holes. Server `server.sock` and forwarded `<peer>.sock` live in owner-only `/run/user/UID/orgm-remote-desktop` (0700, sockets0600). Remmina has a scoped read-only Flatpak runtime-directory override; no SSH private keys are shared with it.

Each host generated its own0600 Ed25519 key; only public material was exchanged through an already trusted channel. Peer SSH host keys are pinned separately. Authorized keys retain all preexisting entries and use exact source Tailscale IP, `restrict,port-forwarding,command=false`. **This denies shell/PTY/agent/X11 access, but forwarding authorization is not confined to the VNC socket:** the key can forward to other endpoints sshd can access as that account. This is a same-user, trusted-device design, not a sandbox for untrusted accounts.

The local machine is Tailscale **osmar.tailb870fa.ts.net**, not the separate tailnet device named `orgm`. Jarq is **jarq.tailb870fa.ts.net**. Avoid selecting similarly named devices.

`peers.json` is static per-device deployment configuration, not managed dotfiles. To change a peer host/user/UID, **disconnect/stop its tunnel first**, edit metadata and pinned host key, regenerate profiles, then start it again. The helper rejects stale identity reuse, but directly opened saved Remmina profiles bypass that check and could reach an old still-running tunnel if this sequence is ignored.

## Implementation / discoveries

- `remote.py`: strict peer validation, dedicated identities, private Unix endpoints, managed foreground SSH, marker-protected profile writes, themed connection launcher.
- `remote-desktop.nix`: session-owned server and per-peer tunnel template, scoped native backend, shared Remmina baseline, Flatpak access and profile activation. Future activation removes only precisely marked temporary rollout units that would otherwise shadow declarative units.
- Actual Remmina1.4.43 Flatpak ignored precommands after expanding them to empty strings. Real private GUI testing proved this; persistent systemd SSH units replace fragile profile hooks. Tunnel failure recovery was tested on both hosts.
- Existing clipboard selections plus rapid RFB disconnect/reconnect reproducibly kill upstream WayVNC0.10.0 with invalid `data_offer` object IDs, sometimes exiting status0. A scoped `wayvnc-private.nix` disables data-control initialization, not input or capture. No global WayVNC replacement or nixpkgs update. `Restart=always` additionally handles unexpected clean exits; session stop still stops the server.
- HM extended `lib.hm` must be selected inside the HM submodule. Tests now force activation data as well as systemd attributes, avoiding lazy evaluation masking this error.

## Verification

- **11 helper unit tests passed**, including malformed peers, strict SSH, profile preservation and live-master identity mismatch.
- **All six public host configurations passed** package/backend/activation projection; all three desktop manifests recognize the feature.
- Private headless Sway with disposable MP4/mpv: captured nonblank frames, keyboard pauses/resumes ONLY fixture video, seeded CLIPBOARD+PRIMARY and12rapid connections, viewer disconnect leaves video advancing, server and player alive.
- Real Remmina Flatpak GUI connected to that private Unix endpoint, with private Wayland/session bus/keyring and in-sandbox exported disposable XDG paths. No live input was injected.
- Live **both directions**: six framebuffer/disconnect/reconnect cycles passed, frame bytes discarded (no screenshots persisted), server/tunnel services active, sockets0600, no TCP5900–5999 listeners.
- Both dedicated forwarding keys explicitly rejected shell commands. Original system generations and compositor sessions stayed unchanged.
- Native X11 fallback is configured but not deployed or GUI-tested in this rollout.

## Backups / rollback

Only feature-owned files and services were added. Existing authorized keys and Flatpak overrides were backed up before scoped updates; `orgm-dot pull remote-desktop` created independent deployment backups. Per-user snapshots are under `~/.local/state/orgm-remote-desktop/backups/`; native dependencies have per-user GC roots. Clipboard-fix snapshots include the previous server unit. Stop/disable only `orgm-remote-desktop.service` and the appropriate `orgm-remote-tunnel@PEER.service` to withdraw this feature; restore exact feature snapshots rather than replacing entire source trees or unrelated authorization entries.

Jarq's current mutable Sway source is not the canonical Jarq i3 configuration. This rollout added only new helper/manifest paths there; it did **not** run `nh os switch .#jarq` or overwrite that source's existing modules. Future full rebuild must reconcile its source first. No commit/push was requested.

## Repository-wide suite

Initial broad run:207scripts,187passed,20nonzero. Six failures traced to the new activation's wrong `lib.hm` scope; all six passed explicit final reruns (`artcraft-defaults-nix`, `cadcraft-opening-nix`, `dotfile-disable-transition`, `dotfile-source`, `hypr-nautilus-default`, `i3-thunar-sort`); the new private session test lacked its explicit native test tools in the generic runner and passed separately with them (including real Flatpak GUI); a missing-tools run now reports SKIP with exit0. Remaining older assertions/fixture problems are not claimed fixed. See local ignored ledger for per-script results and targeted reruns. A fully green general suite is not claimed.

Remaining13nonzero scripts from that broad snapshot (not rerun/fixed as part of this feature): `hypr-device-support`, `i3-bar-caffeine`, `i3-cursor-size`, `i3-firefox-tabs`, `install-installer`, `nvim-x11-clipboard`, `orgm-status`, `qylock-session`, `runtime-generated-desktop-config`, `ryoku-profile`, `ryoku-provider-compat`, `ryoku-startup`, `sunshine-lenovo-autostart`. The six own activation regressions are not left unresolved.
