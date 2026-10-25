# Shared remote desktop — approved design execution plan

**Goal:** Remmina Flatpak fleet baseline; existing-session VNC backend selected by compositor, deployed now only to OrgM and Jarq without switching/restarting either desktop.
**Architecture:** Native WayVNC for Sway/Hyprland, x0vncserver for X11; private per-user Unix sockets only. OpenSSH Unix-to-Unix forwarding over Tailscale, verified host keys and dedicated per-device restricted keys. Remmina saved profiles use foreground SSH tunnels supervised by per-peer systemd user services; no VNC passwords, public ports or SSH private keys inside Flatpak. Server lifetime belongs to the graphical session, never to a viewer connection.
**User approval:** User approved the prior full chat proposal and requested deployment on Jarq and here. Temporary OS credential is ephemeral only, never a VNC password or repository value. Jarq Tailscale enrollment was authorized by the user and is verified in the same tailnet.
**Constraints:** No desktop/session replacement or reboot. No typing/click injection into live sessions. Tests must use private compositor/client instances and disposable video files. No unrelated pending OSK/MIME/CAD edits overwritten. No commit/push requested. Work in new isolated-by-path feature files in the current checkout; no unsolicited branch/worktree changes.

## Tasks
- [x] TDD helper: compositor detection, Unix-only backend commands, private directories, validated peers, SSH identities/host checks, serialized tunnel reuse and safe profile generation.
- [x] Nix module common defaults, compositor-owned user service, Remmina shared Flatpak package; all-host evaluation and dedicated dotfile manifest.
- [x] Private Sway + real WayVNC/RFB handshake/capture/input fixture; media progress preserved after viewer disconnect; optional private X11 backend. Flatpak Remmina test in a private display, including Unix-socket visibility and a private session bus.
- [x] Fresh read-only independent review, fix important findings with RED→GREEN tests.
- [x] Backed-up targeted per-user deployment OrgM/Jarq, native store dependencies, restricted mutual SSH authorization, Tailscale endpoints, Remmina profiles and services; no system switch.
- [x] Verify bidirectional SSH/socket handshake and installed profile/backend readiness without live input injection. Confirm no TCP VNC listener and originals left running. Report connection instructions and exact test limits.

## Review focus
Host-key identity vs duplicate tailnet device names; same-user filesystem boundaries; unauthorized shell/key use; malformed peer/profile injection; stale SSH control sockets; client disconnect leaving remote playback intact; actual Remmina hook ordering, Flatpak runtime socket mapping, session ownership and X11-only fallback. Keep-awake must be explicit per host, not a global permanent disabling of locks.

## Validated adjustments
- Real Remmina Flatpak1.4.43 silently dropped precommands. Profiles therefore have no hooks; systemd supervises foreground SSH and the launcher checks tunnel readiness.
- Seeded CLIPBOARD/PRIMARY exposed WayVNC0.10.0 protocol failure after rapid reconnect. The narrowly scoped native backend omits clipboard bridging; keyboard/pointer/capture stay enabled. The session server restarts even after unexpected clean exits.
- Home Manager DAG construction belongs inside its submodule, not the enclosing NixOS lib; the all-host regression now forces activation contents.
- See deployment report for precise evidence, limits, backups and connection instructions.
