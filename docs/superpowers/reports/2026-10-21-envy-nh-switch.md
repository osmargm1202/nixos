# Envy — authorized nh os switch

## Goal
Apply the OSK permanently through nh os switch on Envy, explicitly authorized by the user after runtime-only testing.

## Instructions
- Preserve Envy tablet/hardware, modes and existing deployment changes.
- No reboot, no Git commit/push, no root authentication bypass or password collection in chat.
- Engram writes remain prohibited until authoritative runtime registration.

## Discoveries
- Envy NH_FLAKE points to /home/osmarg/Hobby/nixos-tablet-20261020/source#envy, not its clean older ~/Hobby/nixos checkout.
- Current system before deployment: /nix/store/7yam4adjlxyw5shyafr18pnrhrdw13x7-nixos-system-envy-sway, system profile generation17.
- Remote sudo -n requires authentication. Use normal local terminal authentication if needed, not stored credentials or permissions changes.
- A fresh snapshot preserves the active tablet source and adds only OSK files/import, plus its own deployment-source pointer; remote Git checkout and original tablet source are unchanged.

## Accomplished
- Staged source: /home/osmarg/Hobby/nixos-osk-switch-20261021-Gvlor6/source.
- overlay-manifest.json lists all 12 changed/new paths; file-by-file comparison rejects unrelated changes.
- Evaluated target envy: Sway true, OSK true, sway-session.target, correct future NH and orgm-dot source pointers.
- nh os build completed successfully with locked inputs, out-link outside pure source, max-jobs2/cores2.
- Built target: /nix/store/gxbhlp0d7cni8s9g69kdp8gbqf3jmy3h-nixos-system-envy-sway. Closure diff adds only OSK engine/source, permanent service and Sway binding; net +13.5KiB, no application version changes.
- Existing and new display-manager.service are byte-identical. Unprivileged dry-activate was rejected as expected (requires root); no authentication bypass attempted.
- New permanent unit and sway-session.target.wants link verified inside the built system. New snapshot orgm-dot registry validated (exit0).
- Launched nh os switch path:/home/osmarg/Hobby/nixos-osk-switch-20261021-Gvlor6/source#envy --no-specialisation in an Envy graphical terminal titled Envy: nh os switch.
- Initial graphical sudo authentication timed out without activating. After explicit user authorization, reran the existing nh switch runner through an SSH PTY and supplied the temporary credential only to the ordinary sudo password prompt, with terminal echo disabled. No credential was persisted in scripts, arguments or reports.
- A post-success verifier automatically checks current/default system, removes only the recognized temporary runtime OSK unit/link, reloads and starts the permanent generated unit, and verifies engine ready. It runs only after nh returns0.
- nh os switch completed with exit0 and installed generation18 (system-18-link); /run/current-system and /nix/var/nix/profiles/system both resolve to /nix/store/gxbhlp0d7cni8s9g69kdp8gbqf3jmy3h-nixos-system-envy-sway.
- Post-activation verifier and independent follow-up both passed: permanent /etc/systemd/user/orgm-osk.service is active, engine ready/error empty, one screen; sway-session.target.wants link exists and the temporary runtime unit/link were removed.
- Sway PID remained15424, confirming the existing desktop session stayed running. No reboot or Git mutation occurred; ~/Hobby/nixos remains clean.

## Next Steps
User validates the real touch keyboard after the permanent activation. Keep the deployment source, result and previous-system rollback pointer. Jarq deployment remains a separate pending task; no reboot or further credential reuse is authorized by this completion.

## Relevant Files
- Envy deployment directory /home/osmarg/Hobby/nixos-osk-switch-20261021-Gvlor6 — pure source, rollback pointer, result and logs kept separate.
- Deployment source nixos/osk and lib/mk-system.nix — shared permanent service/package integration.
- Deployment source deployment.nix — points NH/orgm-dot at its own immutable working snapshot.
- Local .superpowers/sdd/2026-10-21-osk/envy-switch-source — deployment directory locator.

## Key Learnings:
1. Preserve the source selected by NH_FLAKE when a machine is running a staged deployment, rather than rebuilding its older Git checkout.
2. Build success is not activation success: verify nh exit0, current/default profiles and generated service origin after ordinary sudo authentication.
