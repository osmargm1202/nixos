# CADCraft existing-window opening and Jarq rollout

**Goal:** Opening another DWG from the file manager adds it to the existing
CADCraft window instead of starting another application instance.

**Scope:** Preserve ArtCraft's vendor CADCraft Flatpak and updates. Deploy only
this integration to Jarq; do not replace its native Sway system generation,
switch the canonical i3 configuration, deploy unrelated OSK/MIME changes, or
restart/close user applications. No synthetic input or broad focus rules.

**Architecture:** A host Python launcher serializes requests, discovers the
Flatpak instance, focuses its precise compositor window, and calls `app.open`
through a fixed Python client entered into the sandbox. Enable the upstream
control server only with Flatpak network isolation; verify the real namespace
before every connection. Keep the existing desktop ID and vendor metadata.

## Tasks / verification checklist

- [x] Reproduce with the installed CADCraft 0.8.0 on a private Sway display;
  generate two actual DWGs with its writer and verify different document indexes
  in the same PID/instance. Never use user documents.
- [x] Test existing/absent/ambiguous/legacy instances, invalid paths, Unicode,
  portal preflight, uncertain delivery and private locking; implement launcher.
- [x] Reproduce hidden-workspace failure; focus the exact sandbox descendant
  before ping/open, without enabling global activation or typing shortcuts.
- [x] Test conditional installer, backup/rollback, preservation of font overrides,
  shell-free desktop Exec escaping and real GIO removal/reinstall fallback.
- [x] Add a dedicated orgm-dot manifest and conditional Home Manager activation.
- [x] Fresh independent code review and important fixes with regression tests
  (pending-launch identity, independent rollback, cold-start focus; also real-GIO
  special-character escaping and bytecode-free managed dotfiles).
- [x] Run relevant Nix/module and repository regression tests; report unrelated
  failures by name instead of claiming a green suite.
- [x] Back up and deploy selected helpers/desktop/override on Jarq; verify the
  installed bytes, desktop default, isolation and real file-manager opening.

## Failure policies

An existing unresponsive instance is never killed, replaced or duplicated:
ask the user to save/close it once. Ambiguous instances fail closed. An uncertain
`app.open` is never retried. Only a pre-send inaccessible-file response permits
a retry after a scoped document-portal export. The production bridge supports
only ping/open/focus, not arbitrary RPC, save, quit or synthetic input.

## Review focus

Hidden/minimized clients; sandbox init vs GUI PID; concurrent file-manager
requests; filenames with Unicode/quotes; paths outside sandbox grants; vendor
upgrade/removal and native fallback; failed/partial installation; shared-network
overrides; preservation of unsaved drawings. Real Wayland testing is isolated;
no physical touchscreen or live Hyprland acceptance is claimed.
