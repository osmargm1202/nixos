# X13 development handoff

Read this before resuming X13 work. This is local, session-derived memory, not a
fresh runtime inspection or authorization. Exact requirements and chronological
evidence are in [the feature tracker](../../../odd/tasks/x13-bootstrap.md).
Do not store credentials here. No callable persistent-memory/Engram tool was
available; these repository files are the continuity record.

## Start here

1. Inspect `git status` before switching branches or updating files. Unfinished
   Starship diagnostics are deliberately separate from the published X13 base.
2. Read the feature tracker and [host README](README.md); reconcile observations
   with the actual laptop before operating on it.
3. Treat Normal and Server boot as verified, but do not close Flatpak, biometric,
   camera, touchpad or prompt issues without their missing evidence.
4. Never run disk preparation again: installation/recovery must preserve the
   existing encrypted filesystem and user data.

## Verified baseline

| Area | Last verified state |
| --- | --- |
| Machine | Lenovo ThinkPad X13 Gen 4, Intel i7-1365U, 16 GB RAM, UEFI |
| Graphics | Single Intel Iris Xe, i915; graphics and 32-bit graphics enabled |
| User | `osmarg`; installed-system SSH verified |
| Storage | WD SN740 256 GB / 238.5 GiB, serial `232949803515` |
| Disk layout | 1 GiB FAT ESP; remaining partition LUKS2 with Btrfs |
| Subvolumes | `@`, `@home`, `@nix`, `@log`, `@snapshots`; Zstd/noatime |
| Swap | Zram; no disk swap or hibernation configured |
| Normal | Shared GNOME, Wayland; real graphical session and SSH verified |
| Server | Real headless boot, Wi-Fi and SSH verified; user confirmed console login |
| Boot menu | Generation 3 installed by NH; Normal default, timeout 1 second; Server available |
| Kernel | Stock Linux 6.18.56 at the verified deployment, not shared Zen |
| Login | SDDM retained; Astronaut/Black hole previews shown; no new theme applied |
| Extensions | Inherited GNOME extension packages moved to user scope; no custom enabled list selected |
| Applications | Firefox and Kitty version commands passed; printing and AI configuration included |
| Exclusions | No Nextcloud client/autostart, Windows VM or passthrough |
| Secrets | Existing SOPS files decrypted successfully during private provisioning; no plaintext logged |

The user requested Osmarg's Flatpaks, emulator catalog, Steam and ArtCraft Launcher.
Selected packages are not the same as completed runtime installation.

## Boot failure: diagnosed and repaired

The first real boot reached LUKS unlock and mounted Btrfs, then entered emergency
mode because `/boot` referenced missing FAT UUID `AAB4-8899`. Recovery inspection
found FAT UUID `B109-E7E0`, while the GPT partition identity was unchanged. The
reason the FAT UUID changed was not established; do not invent an explanation.

The authoritative mount now uses:

```text
/dev/disk/by-partuuid/5512d8ef-bc51-4ea9-a3f6-cf575351fa72
```

LUKS remains:

```text
/dev/disk/by-uuid/dde6b70b-af6f-4eba-8cd0-8825ddcb5968
```

Recovery required no formatting. Generated `hardware-configuration.nix` was
intentionally corrected to use the stable EFI PARTUUID. Its current recorded
SHA256 is `0cfc6b9322a7c33c7f0e5edefa89da4f4a37bbafedf0ccf1c922ad0d426a037e`.
Do not restore the original generated file or its stale FAT UUID.

The persistent journal supplied the boot-failure evidence. Consult the detailed
feature log for recovery observations rather than assuming a particular saved-log
path exists on a later boot.

Server inherits the same encrypted root and essential mounts; it is not independent
root recovery. Only Server makes `/boot` optional (`nofail`, device timeout 10s).
Always require the real ESP to be mounted before rebuilding/installing boot entries.
Generation 1 retains the old mount reference; do not recommend it as a proven fallback.

When inspecting from the installer, mount the separate `@log` subvolume before
reading journals. Reading `/mnt/etc/fstab` directly can follow an absolute symlink
into the live installer's `/etc`; inspect it inside the target chroot or evaluate
`environment.etc.fstab.text` instead. Do not mistake an unmounted log subvolume
or the live installer's state for evidence about the installed system.

## Access and current-state caveats

- Last known address: `10.0.0.67`. Installer access used root; installed access uses
  `osmarg`. Installed root SSH login is disabled. Do not assume an old address is
  still this machine without verifying identity.
- Installed ED25519 fingerprint:
  `SHA256:bx7vsoVd+ZLeVeqBVP7Bl3k/8HvxUdcXtfhF/pj3I1s`.
- Installer SSH keys changed across boots. Session-only known-host files under
  `.git/` kept these out of the ordinary user `known_hosts`. Never clear unrelated
  entries or disable host verification permanently.
- Temporary account and LUKS credentials were set as requested, but are intentionally
  absent from all handoff files. Changing the account password does not change LUKS.
- The user now confirms entering GNOME ("ya inicie"). Later SSH verified hostname
  `x13`, user `osmarg`, available `nh` and the original `nppd5fyx93pz42ivg58fd3rdkiqnsx6g`
  prior running system. Follow-ups are now activated as generation3/rg664; the
  same GNOME Wayland session stayed active throughout the switch.
  Normal remains the persistent default.
- Returning to Normal can start the inherited Flatpak installer again. The stop
  performed for the Server test was temporary, not a persistent mask.
- Private age identity was provisioned at `/home/osmarg/.config/sops/age/keys.txt`
  and permissions were checked. Keep it private with the correct local owner;
  do not read its contents for continuity checks. Historical permission to provision
  it is not permission for another agent to read/copy private material.

## Pending work and decisions

### 1. Flatpak catalog and ArtCraft — blocked on downloads

Home Manager initially failed because its editable source path did not exist:
`/home/osmarg/Hobby/nixos/dotfiles/apps`. A source snapshot was provisioned there,
then Home Manager activation passed and failed system/user units cleared.
Sources also exist at `/etc/nixos`. These deployed trees are source archives, not
necessarily Git clones. Bootstrap preserves existing mutable files; a rebuild does
not necessarily update an already-initialized dotfile.

Flatpak first encountered an early DNS race; DNS later worked. Downloads then
failed with HTTP timeouts on Podman Desktop and, during the service's own retry,
`org.gnome.Platform` version 49 static deltas. Several apps and emulators installed,
including Podman at the last inventory. The full catalog has not been validated.
ArtCraft (`ai.storyteller.artcraft-launcher`) was absent at its last explicit check.
Do not report it installed from its declaration or an "Installing" journal line.

The user explicitly selected pausing Flatpak without uninstalling apps and testing
Server. The service was stopped successfully; no download workaround or catalog
removal was applied. Resume according to the current user's disposition, not an
old monitor or an automatic replay of a timed-out command. All session monitors
used for this work have been stopped/completed.

### 2. Starship — real-terminal evidence missing

The user clarified: **Starship for user `osmarg` in all hosts/profiles, including
Ryoku**, not only hostname exceptions. They want the previous Mythos appearance.

Actual X13 files contain Starship initialization and Mythos TOML; forced Bash
showed the binary/functions, but that alone does not prove prompt rendering.
A later isolated genuine PTY test already rendered the expected lambda, directory
pills and colors on GNOME, Hyprland and pinned native Ryoku. No production fix was
justified or applied. Do not claim the reported terminal issue is solved.

Inspect the affected terminal's actual shell/arguments, local overrides, effective
`STARSHIP_CONFIG` and an actual post-command prompt/screenshot. Ryoku deliberately
bypasses ordinary Osmarg Bash seeds and owns its native startup chain. `bash` and
`starship` are distinct orgm-dot applications. Do not blindly pull Bash, overwrite
Ryoku/native files, or change global bootstrap behavior. Back up and compare any
proven task-owned prompt file before a targeted deployment.

Uncommitted diagnostic work in the original working tree:

- `tests/osmarg-starship.test.py`
- `tests/shell-tools-session.test.py`
- `docs/osmarg-starship.md`
- the current feature tracker changes

Recorded diagnostic Starship PTY, session and Blesh checks passed. The worker's
full report was truncated in the retained conversation; do not infer additional
suite results or rely on an unverified reason for missing checks. Read the actual
report/drafts before resuming. No meaningful production RED was observed. Preserve
these drafts; do not discard, merge or publish them as a completed prompt repair.

### 3. Fingerprint — eligibility investigation only

USB ID `27c6:6594`, Goodix MOC. `fprintd` was not enabled. Envy instead uses
Synaptics `06cb:00c9` with a specific synatudor setup: do not copy that backend,
pairing state, firmware assumptions or device rules to X13.

The exact Goodix ID appears in the upstream supported-device table:
<https://fprint.freedesktop.org/supported-devices.html>.
Earlier source research reported libfprint 1.94.10, but the actual selected lock
version was not independently verified; do not treat that lookup as pinned-release
proof. The exact selected release ID table and working device recognition remain
unproven. Upstream recognition is not enrollment/runtime success. The sensor's
physical placement in the power button was not verified.

No biometric enrollment, PAM/login/sudo change, storage reset or firmware update
was performed. Clarify authentication scope before implementing. Fingerprint does
not automatically unlock LUKS or a password-protected keyring.

### 4. SDDM themes — previews shown, selection pending

The user explicitly retained SDDM and requested theme choices, not GDM. Official
Astronaut/current Black hole images were shown; no theme was applied.

Official gallery:
<https://github.com/Keyitdev/sddm-astronaut-theme#preview-of-all-themes>.
Upstream screenshot assets need not exactly match the locked package version.
Local session previews are in `.git/x13-theme-previews/` and are not tracked.
Inspect the actual SDDM configuration and selected package's available themes
before implementing a choice; do not assume an upstream preview is a valid
configuration value or introduce a speculative override mechanism.

### 5. Touchpad, camera, audio and other physical acceptance

The user reported touchpad movement feeling slower/laggier than Windows. No tuning
was applied. Distinguish pointer speed/acceleration from actual input/compositor
latency in GNOME; do not copy unrelated Lenovo TrackPoint or Hyprland policies.
Saved GNOME settings were not obtained: the CLI/schema was unavailable in the
current Server environment. No effective-value or latency claim is justified.

Camera nodes and internal audio were enumerated. GNOME/Wayland and
PipeWire/WirePlumber were observed.
An automatic camera-frame check was unavailable because ffmpeg was absent; no
image was captured or stored. Human confirmation of camera image, touch behavior,
speaker/microphone, suspend/resume and printer operation remains pending.

Firefox and Kitty version commands succeeded; Nautilus was the directory default.
These are not a complete graphical application smoke test. AI tools are selected
and SOPS decryption worked, but authenticated AI use remains unverified.

Only Iris Xe was inventoried: no PRIME/dGPU offload policy exists on X13. Rendering,
VA-API video acceleration and GPU compute are separate; multimedia acceleration
and local GPU inference were not verified/configured as part of this work.

## Verification and published history

Observed successful functional/configuration checks:

```bash
python3 tests/x13.test.py
python3 tests/x13-server.test.py
git diff --check
nix build --impure --no-link --print-out-paths path:.#nixosConfigurations.x13.config.system.build.toplevel
```

Both full configurations built, and independent configuration/security verification
passed. Normal and Server real boots/SSH were observed, plus human Server console
confirmation. The final integration worktree repeated the tests and full build.

Known pre-existing failure: `bash tests/install-installer.bats.sh` exits 1 because
the desktop menu omits `sway`. The same exact failure was reproduced on baseline
`ef57411`. It was not fixed in this feature and the full repository suite was not
claimed green. Do not rerun automatic disk preparation on this existing Btrfs
installation.
Native review assessments were recorded; review switch state was unknown and no
native review was started. Do not invent review receipts.

Published to `https://github.com/osmargm1202/nixos.git`:

| Ref | Verified commit |
| --- | --- |
| `master` / `origin/master` | `7ab99a5cf5b6b3a0a3fdfb49cb7183d79ae1a91e` |
| `feat/x13-bootstrap` | `cd99cafeefb96facbe8ff81fbd2c8a67b986636f` |
| `feat/x13-recovery` | `edb444502bc2a3264c09ede5f700a1ce186fbbbb` |

The repository's actual default is `master`, not `main`; the user explicitly
confirmed that destination. Integration used an atomic non-force push. No PR was
created. Base and recovery were split according to the approved feature-branch
chain. Recovery work-unit commit: `aec6977`.

Original working tree is on `feat/osmarg-starship`, based at `edb4445`, with the
uncommitted diagnostics above. Published master is checked out in the registered
same-clone worktree `.worktrees/x13-delivery`. Do not switch/reset/clean the dirty
original tree to make it match master; preserve its draft changes. These branch
and runtime observations may become stale: check them, rather than trusting notes
as live state. Past publishing, formatting or private-key permissions are historical,
not new operational consent.

## New GNOME follow-ups: applied as generation 3

Read [the follow-up tracker](../../../odd/tasks/x13-gnome-followups.md).
Source is on local `feat/x13-gnome-followups` in `.worktrees/x13-gnome-followups`.
Commits `455edb5` and `6391933` implement six standalone SLC/ORGM webapps,
X13-only tray retirement while retaining daemons, and native GNOME shortcuts:
Super+Q closes the active window; Super+Return Console, Super+W Firefox,
Super+E Nautilus focus/open without a duplicate Firefox tab/window.

Actual evaluated Shell is 50.5. Locked GNOME 4x UI Improvements release25 supports
45–49, so only X13 excludes it. The new native shortcut extension requires the
first logout/login; no session logout or unsafe Shell mode was attempted.

Writer and independent tests passed, including exact ORGM/Envy/Ryoku baseline
service/selection/package/activation parity. The earlier missing encrypted input
was resolved by explicit human authorization for ordinary Nix dependency use only;
no secret-name search or direct decryption is authorized. Full build succeeded:
`/nix/store/rg664lncdzql7inpg0ihhzc7iqxllzy7-nixos-system-x13-gnome`, including Server.

Applied successfully via `nh os switch` on X13, generation3. The running system
is the exact rg664 closure above. Baseline-hash-guarded patch updated only11 task
source files in the existing `/home/osmarg/Hobby/nixos`, preserving other files.
Backups: `.x13-deploy/6391933-gnome/backup` under that source root. An optional
store-copy attempt rejected one unsigned evaluator output; normal target-local
build recreated it without weakening signature policy. A preflight capture issue
was corrected by combining stdout/stderr, retaining the same strict no-GNOME-restart
guard. Actual switch exit0, postcheckexit0: Home Manager, SDDM, Tailscale and
Syncthing active, six desktop menu entries and both tray autostart masks present,
native close setting exactly Super+Q, shortcut login unit enabled/successful,
zero failed system/user units. Same live GNOME Wayland session preserved.

No forced logout occurred. First logout/login and physical shortcut testing still
belong to the user; no actual endpoint authentication or browser launch was claimed.
The newly built Server closure was not physically reboot-tested in this update;
the earlier Server boot proof belongs to generation2.

Camera app/error identity and Tailscale SOPS key-name/authentication scope remain
blocked; neither permission guards nor automatic authentication were changed.
No new commits have been pushed. Original Starship drafts remain untouched.

## Native GNOME locking: new blocker

User reports no Lock action and Super+L does not lock. GNOME50.5 primary source
`js/misc/loginManager.js` requires the GDM `org.gnome.DisplayManager` system-bus
service in `canLock()`; `main.js` creates ScreenShield only when that passes.
`systemActions.js` uses the same gate for the menu action. Upstream warning:
"Screen Locking requires the GNOME display manager".
<https://github.com/GNOME/gnome-shell/blob/50.5/js/misc/loginManager.js>

X13 still runs SDDM. The user has now explicitly authorized X13-only GDM and
native Super+L for the next boot, without forced logout; source not yet changed.
Runtime settings/Lock reproduction did NOT run: last X13 address10.0.0.67 had
No route to host. The user confirms X13 is disconnected. Address10.0.0.63 is a
DIFFERENT machine, now console/SSH-confirmed thinkpad11e with user hm, never an
X13 address or hostkey alias. Clipboard belongs only to thinkpad11e/hm. User later
clarified printing belongs to BOTH; X13 already imports the existing printer module
through GNOME, retain it. Await reachable X13 before deployment/lock proof; do not
weaken the GDM capability gate.

The .63 machine's first strict SSH check failed before authentication with a changed
hostkey (old RSA entry in global known_hosts); new offered ED25519 fingerprint:
`SHA256:LJ78GQihJKcqNn8eQujvSlGGTBdZ32aFl379sKP3wwU`.
That initial check ended before authentication. The human subsequently confirmed
this exact fingerprint and hostname from physical console. A separate session pin
was validated without global known_hosts/X13-pin edits; hm login succeeded and
confirmed thinkpad11e/i3/X11, Home Manager active and i3-clipcat.service active/enabled.
No target source, user configuration or clipboard/history contents were modified.
Printing source/build is prepared in existing feat/x13-gnome-followups; see
odd/tasks/thinkpad11e-hm-tools.md there for partial-verification blocker before apply.

## 2026-11-07: native lock and Thunar cleanup prepared for next boot

Current source lives in `.worktrees/x13-gnome-followups` on
`feat/x13-gnome-followups`; original Starship drafts remain untouched.
The user requested removing Thunar and restoring Lock/Win+L, then supplied
fresh X13 connectivity/access. Strict pinned SSH verified `osmarg@10.0.0.67`
as X13; the mounted vfat ESP and recorded PARTUUID matched.

Implemented X13-only GDM by omitting the shared SDDM import while retaining
printing, enabled native locking and declared Super+L through Home Manager.
Server explicitly disables GDM. Common Thunar selection excludes only X13;
Nautilus remains the directory default. Other hosts retain existing policy.

`tests/x13.test.py`, `tests/x13-server.test.py`, `tests/x13-trays.test.py`,
`node tests/x13-focus-shortcuts.test.js`, `git diff --check` and the local
full Normal/Server build passed. Local full build includes the previously
pending printer edits; those edits were NOT transferred with this task.
Only three task-owned Nix files were baseline-hash checked, backed up and
updated on X13. Backups remain at
`/home/osmarg/Hobby/nixos/.x13-deploy/20261107-native-lock/backup`.
Target-local configuration assertions and full Normal/Server build passed.

`nh os boot` succeeded: generation 4, default `nixos-generation-4.conf`,
timeout 1; generation-4 Server entry present. Next boot closure:
`/nix/store/cb79plz84yv2r8ig6p48srl6qaf4clqa-nixos-system-x13-gnome`.
Its system path contains Nautilus and no Thunar. Current running system remains
rg664 (generation 3), same active GNOME Wayland session 3 and display-manager,
zero failed system/user units. No reboot or forced logout occurred.
After the user's next reboot, physically verify GDM login, the Lock menu,
Super+L and password unlock; these runtime results are not yet established.

The first boot-install attempt built successfully but failed before setting
the system profile because sudo had no terminal. A temporary environment-based
askpass/elevation helper then allowed ordinary user-run NH and normal sudo;
helpers were removed, no credentials saved, no signature/root-check bypass.
Read-only GSettings inspection reported locking allowed/enabled, but the SSH
CLI lacked the media-keys schema: no live shortcut-value proof is claimed.
No commit, push or merge was performed in this task.

## 2026-11-07: user-requested live switch completed

User reported a failed `git pull --ff-only` and requested `nh os switch`.
Fresh strict-pinned SSH verified X13 .67. Both deployed source directories
(`/home/osmarg/Hobby/nixos`, `/etc/nixos`) lack Git metadata; no pull, Git
initialization, reset, commit or publishing was performed. The newer source
already exists under the user's NH_FLAKE; /etc/nixos is an older snapshot.

Verified source evaluates to cb79, ESP mounted with correct PARTUUID.
User-run `nh os switch /home/osmarg/Hobby/nixos -H x13 --no-specialisation`
completed normally using temporary environment-based askpass for normal sudo.
Running system is now
`/nix/store/cb79plz84yv2r8ig6p48srl6qaf4clqa-nixos-system-x13-gnome`.

IMPORTANT correction: dry activation said display-manager would NOT stop,
but this did NOT preserve the SDDM session. The new unit's GDM BusName was
not owned; systemd logged its disappearance/grace timeout and terminated SDDM,
then started GDM. Session3 ended during activation; a new successful GDM/PAM
Wayland login created session13. Parent acknowledged the mistaken prediction
and interruption to the user. Never infer safe live display-manager migration
from the dry-activate no-stop line alone; use boot-only migration to preserve
an existing graphical session.

Postchecks: GDM owns org.gnome.DisplayManager; GNOME ScreenSaver.GetActive
responds (false, without invoking Lock). dconf screensaver shortcut exactly
['<Super>l'], disable-lock-screen false, Nautilus executable, no Thunar in
current system path. Home Manager/display-manager/Tailscale and user graphical
session/Syncthing active, zero failed system/user units. Shortcut login helper
Result=success/ExecMainStatus=0. Actual keyboard lock/password unlock remain
human acceptance; do not claim physically tested. Reboot is no longer required
to start GDM, since it is now actually running after the live switch.
