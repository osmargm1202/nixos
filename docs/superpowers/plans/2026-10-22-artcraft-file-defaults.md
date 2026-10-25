# ArtCraft File Defaults Implementation Plan

> Execution: inline, following TDD and verification-before-completion; no commit
> or push requested for these changes.

**Goal:** Prefer installed ArtCraft applications for their published document/media
formats, automatically falling back to native desktop applications when absent.
**Architecture:** Standard ordered XDG desktop-ID lists; no launch interception,
no daemon. Shared Nix module applies defaults and synchronizes only affected keys
in the user's higher-priority mimeapps.list, preserving unrelated preferences.
**Tech Stack:** NixOS/Home Manager, Python stdlib, XDG/GIO.
**Spec:** User request in chat: ArtCraft principal; native fallback if unavailable.
CADCraft single-instance is a separate integration decision, not a MIME setting.

## Constraints
- Preserve browser/URL associations, code MIME types and directory manager.
- Source format claims from official .desktop exports; do not invent formats for
  EffectCraft (no published MimeType field).
- One owning ArtCraft app per format, never arbitrary cross-suite importers;
  if that app is absent, use native fallback. PDF: PdfCraft; CAD: CADCraft; raster PhotoCraft,
  vector VectorCraft; RAW LightCraft; documents Word/Grid/Deck; video/audio Film/Sound.
- Preserve existing profile-native defaults before generic native alternatives.
- No app installs/restarts or opening real files to test; backups and atomic update.
- Current CADCraft remains untouched until the user chooses integration approach.

## Steps
- [x] RED: updater preservation/idempotence/backup/error safety + actual GIO
  resolution with ArtCraft installed/absent/reinstalled and native fallback.
- [x] Add format policy, shared Nix module and atomic user preference updater.
- [x] Evaluate public hosts and a terminal fixture; verify activation ordering.
- [x] Regressions; review; apply evaluated policy to current user with backup,
  verify actual GIO-selected defaults without launching files.
- [x] Document partial scope: single-instance CADCraft not yet implemented.

**Result:** completed the association portion, applied in OrgM and saved for all
desktop profiles. CADCraft same-window integration remains explicitly pending;
no control server enabled and no application closed. See the session report.
