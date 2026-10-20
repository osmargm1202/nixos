# Repair documented regressions and float VLC

> **For agentic workers:** Use systematic debugging, test-driven development and verification-before-completion for each independent task. Parallel ownership is assigned by subsystem.

**Goal:** Repair every failure listed in the 2026-10-19 pre-merge report and make VLC floating in both desktop compositors.

**Architecture:** Keep the current six-output inventory and per-user program selections. Test evaluated configuration and actual workflows rather than obsolete source layout. Separate fast configuration/copy fixtures from expensive desktop builds; preserve meaningful Ryoku fallback coverage.

**Tech Stack:** NixOS module evaluation, Bash/Python/Lua tests, native SwayFX and Hyprland rules.

**Spec:** User request: fix all previously documented failures; VLC must float.

## Constraints

- Preserve the pre-existing staged Roboto files and `lib/mk-system.nix` change.
- Do not remove selected programs or retained `orgm-ryoku` merely to satisfy old tests.
- Do not start VMs, rebuild/switch the system, or commit/push unless requested.
- Apply verified Sway/Hyprland dotfiles ourselves; retain native scrolling and media fullscreen controls.

## Tasks

- [x] Envy contracts: reproduce audio/inventory/monitor failures; repair relevant fixtures/expectations and interpreter discovery; rerun four scripts.
- [x] Dotfile integration: reproduce wrong Envy/Ryoku assumptions and transition timeout; retain real copy/disable tests without building unrelated desktops; rerun both entrypoints.
- [x] RDP failure path: distinguish cancellation from backend failure; exercise explicit VM selection, require controller invocation, error propagation and no RDP launch on failure.
- [x] Common Python, Jarq and VLC contracts: evaluate installed programs and MIME choices, assert selected vs explicitly disabled integrations, preserve exclusions/secrets isolation.
- [x] VLC floating: add failing Wayland/XWayland identity tests, add anchored app rules without forced fullscreen/size, run native parsers and real mapped-client checks.
- [x] Run all repaired regressions and adjacent tests together; review independent changes, apply dotfiles, update the report with outcomes and any genuine remaining limitations.

Results: [2026-10-20 regression repair report](../reports/2026-10-20-regression-repairs.md).
