# Tablet: conservar dock de aplicaciones — Implementation Plan

**Goal:** User explicitly requests keeping the normal app dock with larger icons in tablet mode, and removing duplicate visible keyboard controls on OrgM; also fix confusing tablet UI on Envy.
**Design:** Supersede the three-action Quickshell replacement. Sway keeps its exact native dock command/favorites, increasing icons32→48 only in tablet mode. Hyprland keeps its normal process ownership/pins/launch/focus wrapper, choosing48vs32 by manual policy. Removing the replacement leaves the existing tablet-only corner OSK button as the single floating keyboard access. Waybar stays reduced but gives the control-center action a large icon and visible label. No global hide/lock policy changes, no user pin/cache rewrites.
**Approval:** Direct user instruction: “necesito que dock siga y tenga iconos mas grandes”; implementation summary communicated in chat, no unresolved design choices. Existing manual-only tablet policy retained.

- [x] RED unit tests for native command/pin preservation and tablet icon size; retain safe session boundaries.
- [x] Implement minimal shared dock args + wrappers, readable control-center label.
- [x] Replace obsolete strip expectations in private integration test with native dock verification; keep real Waybar click/inhibitor assertions, private screenshot proof.
- [x] Verify Hyprland wrapper process/pin ownership regressions, independent review.
- [x] Back up and selectively deploy to OrgM/Envy sources+HOME; refresh only their bar/dock with mode unchanged; make Envy's existing runtime dispatcher persistent via marked per-user drop-in.
- [x] Report evidence and local session summary (Engram attribution writes forbidden until runtime hook registration).
