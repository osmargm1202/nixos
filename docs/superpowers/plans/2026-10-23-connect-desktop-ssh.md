# Conectar a equipo: escritorio y SSH — Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans inline, task by task.

**Goal:** User-approved selector discovers Tailscale peers and opens either prepared graphical desktop or ordinary SSH terminal.
**Architecture:** Keep existing private VNC authentication/tunnels intact. A separate connections.py provides read-only tailnet discovery, native themed selection and ordinary OpenSSH in Kitty. No remote installation, password/key copying, or GUI on terminal-only servers. Show desktop only for configured VNC peers.
**Tech Stack:** Python stdlib, Tailscale JSON, orgm-rofi, Kitty/OpenSSH, existing Remmina Flatpak.
**Approval/spec:** User replied “si” to showing Tailscale devices and choosing Desktop/SSH, explicitly informed SSH requires authorization and no desktop. Defaults/constraints communicated in follow-up message: preserve normal SSH authentication, never reuse restricted VNC key, available graphical targets only.

## Constraints
- Preserve private peers.json schema and existing connect NAME/tunnel commands.
- Exclude Self by stable ID/addresses, not name (another tailnet device is named orgm).
- Validate addresses/users and use argv only. Keep host-key verification/normal authentication.
- Cancel is a no-op. Only online Linux peers in current Tailscale metadata qualify (latest user instruction); unavailable metadata gives an empty list, not stale configured peers.
- No live GUI/input, remote-shell login attempts on arbitrary peers, or automatic authorization changes.
- Preserve other uncommitted files and actual Jarq native Sway source. No commit/push.

## Tasks
- [x] RED tests for self exclusion, merge/dedup, malformed data, SSH argv/security, menu cancellation and protocol availability.
- [x] Implement focused connections.py, existing controller delegation, desktop-entry comment.
- [x] Unit/mock flow tests and private actual UI/SSH argv fixture; retain native capture/clipboard/video tests and hotplug regression.
- [x] Read-only independent review and scoped backed-up application OrgM/Jarq. Verify real discovery and existing desktop capture; do not log in to third-party tailnet peers.
- [x] Document boundaries and usage; local session summary (Engram writes currently prohibited by runtime hook).
