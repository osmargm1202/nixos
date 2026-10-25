# CADCraft same-window integration

## Why another window was opened

The vendor desktop entry runs `flatpak run ... cadcraft <files>` for every
activation. CADCraft 0.8.0 exposes `app.open`, but its desktop launcher does not
forward a new request to an existing process.

Upstream references:
- [CADCraft 0.8.0 control protocol](https://github.com/storytold/cadcraft/blob/v0.8.0/docs/control-protocol.md)
- [Desktop entry point](https://github.com/storytold/cadcraft/blob/v0.8.0/apps/cadcraft/src/main.rs)
- [Engine file opening](https://github.com/storytold/cadcraft/blob/v0.8.0/crates/engine/src/cmd/file.rs)

## Implementation

`orgm-cadcraft` serializes requests using a private runtime lock, finds the
existing Flatpak instance, activates only its exact window and opens each
drawing through the upstream protocol. It starts CADCraft only if none exists.
The app binary is not patched or replaced, so ArtCraft updates remain intact.

The upstream control protocol includes destructive editing/quit operations and
has no authentication. It must **never** be enabled on the host network. The
Flatpak already lacks network sharing; the installer additionally pins
`--unshare=network`. Requests enter that sandbox and verify that its actual
network namespace differs from the host before contacting private loopback.
The production client allows only ping, open and focus.

Original paths are retained when readable in the sandbox (important for relative
references). Otherwise a per-file, per-app document portal grant is used, with
write access only when the source is writable. No home-wide filesystem grant.

On Sway/Hyprland the focus target is both the CADCraft app ID and a descendant of
the exact Flatpak instance's sandbox PID. `flatpak ps` child-pid is not always the
GUI PID. Hidden egui windows can stop processing RPC, so focus precedes ping.
There are no global activation changes and no synthetic keyboard input.

## Installation and recovery

The `cadcraft-opening` orgm-dot application installs the helper and three Python
modules. Home Manager calls `orgm-cadcraft install` after bootstrap, and only an
installed CADCraft receives a shadow desktop entry. After installing CADCraft
later, run `orgm-cadcraft install` or activate the system configuration again.

The shadow preserves `ai.storyteller.cadcraft.desktop`, icon and MIME types.
Its TryExec references the stable Flatpak active binary, so an uninstalled app
does not mask native alternatives. MIME associations are not rewritten here.
The broader ArtCraft/native MIME policy remains a separate change.

Before changing the desktop entry and per-app override, the installer stores
their previous contents and presence in
`$XDG_STATE_HOME/orgm-cadcraft/backups/<id>/` (default `~/.local/state`). Failures
roll back both paths. Font and other unrelated Flatpak overrides are preserved.
For manual rollback, restore `desktop` to
`~/.local/share/applications/ai.storyteller.cadcraft.desktop` and `override` to
`~/.local/share/flatpak/overrides/ai.storyteller.cadcraft`, removing paths whose
`presence.json` value was false, then run `update-desktop-database` on applications.

If an old CADCraft is already open without the control server, save and close it
once, then open the drawing again. The helper will not close it or start another.
Errors after sending an open request are reported without retrying it.

A pending Flatpak launch also retains its PID/boot/start-time identity in
`$XDG_RUNTIME_DIR/orgm-cadcraft/launch.json`, so a timeout before it appears in
`flatpak ps` cannot lead to another launch. A crash during the spawn handoff
leaves an uncertain marker and fails closed; inspect the log/processes before
manually removing that runtime marker. No process is terminated automatically.
The installer needs `update-desktop-database` from desktop-file-utils (provided
on the declarative activation PATH). The Jarq user-only rollout uses its already
present Nix-store binary without changing the system generation.

## Verification

- Unit/transaction/client tests: `cadcraft-{opening,install,sandbox}.test.py`.
- `cadcraft-opening-session.test.py`: native private Sway, vendor Flatpak 0.8.0,
  actual DWG writer/reader, real GIO desktop launch, one instance/PID, preserved
  dirty drawing, switch-away/workspace-focus, per-file portal and concurrent opens.
- Jarq test evidence (2026-10-22 local): instance `3032436858`, sandbox child PID
  `373580`, fixture directory `~/.cache/orgm-cadcraft-fixture-cnuslcxr`.
  All fixture processes exited. User documents/session were not used.

## Review and Jarq deployment

A fresh read-only review found three important edge cases: startup timed out
before `flatpak ps` discovery could permit another launch, desktop restoration
failure skipped override restoration, and cold-start polling lacked focus.
All three have reproducing RED→GREEN regressions and fixes. Real GIO tests also
cover special characters in helper paths, and the wrapper disables bytecode
creation so orgm-dot does not report generated-cache drift. Final targeted tests:
14 launcher + 9 installer + 5 fixed-client cases pass; the Nix activation
projection passes all six public hosts and manifest ownership on three profiles.

Applied to Jarq between **2026-10-22 23:59 and 2026-10-23 00:03 local** using SSH key authentication and
per-user operations only. Its existing native Sway generation remained exactly
`/nix/store/args6pzvicwngvk7frxv5nv199znmd7q-nixos-system-jarq-sway`.
No sudo password, rebuild, switch, reboot or user-application restart was needed.

New helper/manifest files were added to Jarq's current orgm-dot source and pulled
as **cadcraft-opening only**. Existing source files, native Sway capability
patches, OSK configuration and MIME preferences were not replaced. The new Nix
activation hook is in this checkout for future configuration deployment.

Backups on Jarq:
- `~/.local/state/orgm-cadcraft/deployments/20261023T035932Z/` — deployment record.
- `~/.local/state/orgm-cadcraft/backups/08f471694f934d89bb421ae3ed1412c5/` — previous
  desktop/override contents and presence before installation.
- orgm-dot pull backups `20261023T035932.356202664-cadcraft-opening-pull` and
  `20261023T040051.092564154-cadcraft-opening-pull` (bytecode-free wrapper update).
  The final CLI error-handling update has backup
  `20261023T040307.951923937-cadcraft-opening-pull`.

The final native test used the **installed helper, library and actual shadow
desktop entry**, not merely repository copies: private Sway fixture
`~/.cache/orgm-cadcraft-fixture-b8zrozed`, instance `4254837400`, sandbox child PID
`381103`. It passed real GIO opening, multiple genuine DWGs in one process,
preservation of a dirty drawing, workspace reactivation, document portal access,
concurrent opens and private-network verification. All fixture processes exited.
Post-check: DWG default is CADCraft, no CADCraft was left running, no pending
startup marker remains, and `orgm-dot diff cadcraft-opening` is empty.

Installer failure reporting also has a real CLI regression: invoking the module
as a script now shares its Error class with the imported installer, preventing
an unintended traceback instead of the intended notification.

## Repository-wide regression run

**204 test scripts executed: 192 passed, 12 failed.** The focused final CADCraft
tests above were rerun after review fixes. All twelve failing script names also
had exit 1 in the retained 2026-10-21 repository run; none is hidden by the
successful DWG-specific checks. This rollout does not repair unrelated tests:

| Failing script | Observed failure |
| --- | --- |
| `hypr-device-support.bats.sh` | Exit 1 without diagnostic output |
| `i3-bar-caffeine.bats.sh` | Missing `i3status_localized.resource_blocks` |
| `i3-cursor-size.bats.sh` | Expected old i3-layer GTK settings path |
| `i3-firefox-tabs.bats.sh` | Personal program layer deployment assertion |
| `install-installer.bats.sh` | Installer desktop inventory excludes Sway |
| `nvim-x11-clipboard.bats.sh` | Stops at `orgm-cinnamon`, no diagnostic |
| `orgm-status.bats.sh` | `KeyError: 0` |
| `qylock-session.test.py` | Required `ORGM_TEST_QYLOCK_PACKAGE` fixture unset |
| `runtime-generated-desktop-config.bats.sh` | Removed `initGeneratedConfigs` activation attribute |
| `ryoku-profile.bats.sh` | Missing `programs.ryoku.enable` attribute |
| `ryoku-provider-compat.bats.sh` | Old per-host default assertion |
| `ryoku-startup.bats.sh` | Missing old tray autostart config entries |

Full per-script logs and result list are in the local ignored ledger
`.superpowers/sdd/2026-10-22-jarq-cadcraft/suite/`. No commit/push was requested.
