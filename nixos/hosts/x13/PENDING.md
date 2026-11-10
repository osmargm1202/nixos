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

## 2026-11-07: GNOME native application menus applied

User explicitly accepted adapting Rofi-dependent apps to native GTK dialogs.
Fresh pinned SSH confirmed X13 .67 running cb79 before work. Source remains
in `.worktrees/x13-gnome-followups`, preserving unrelated Starship/printing drafts.
GNOME now packages Zenity, orgm-menu, orgm-clipboard-menu, Python and playerctl.
Rofi remains installed for compatibility; adapted GNOME paths do not invoke it.

Updated Osmarg scripts: Firefox URL entry; windows-rdp remote selection/free-text
and masked password entry; bookmark selection/deletion; visual-profile menus;
video timer. Other desktops keep Rofi. Native GNOME visual-profile operations use
GSettings wallpaper URIs and interface settings instead of i3 commands. Video
timer keeps GNOME's current workspace and uses playerctl. Bookmark typing copies
exact text with wl-copy and asks the user to paste with Ctrl+V; no wtype injection.

GNOME Clipboard Indicator 71 was verified installed, enabled, state1/error empty.
No reply arrived to the optional history preference, so the stated recommended
assumption was applied: preserve this existing native history, add no collector.
The three legacy clipboard menu scripts route to its native panel menu through a
narrow ShowClipboard D-Bus method added to the existing X13 shortcut extension.
The method exposes no history data, accepts no arbitrary commands and refuses
locked/greeter sessions. It unexports on disable. The running extension still
uses its old code: the new bridge requires the user's next logout/login. Until
then the helper reports using Clipboard Indicator from the top bar. No logout,
Shell restart, unsafe Eval, real clipboard/history inspection or destructive
clipboard action was invoked. Native deletion/selection happen in that menu.

Checks passed: tests/gnome-menus.test.py (selection/index, duplicate/tab labels,
no values in argv, password masking, cancellation/invalid index, exact bookmark
copy and native history routing, mocked GNOME visual operations); extended
x13-focus-shortcuts Node tests (D-Bus lifecycle/missing extension/locked guard);
existing firefox-open-tab, windows-rdp-client and visual-profiles regressions;
x13 and x13-server evaluations/complete derivations, git diff --check. Actual
GTK entry/list/cancel also passed in isolated Xvfb using the selected Zenity4.2.2.
The GUI fixture needed viewable-window focus and corrected keyboard selection;
these harness issues were resolved, with no effect on the user's real display.
Normal and Server full builds completed locally and on X13 (local build retained
unrelated existing printer edits; those edits were not deployed).

Fourteen source files and nine existing mutable runtime scripts passed original
hash/symlink guards and were backed up before task-only replacement. A follow-up
bookmark correction preserves exact text without a trailing newline, also backed
up under the same stage. Backups and manifest remain in
`/home/osmarg/Hobby/nixos/.x13-deploy/20261107-gnome-menus`.
Target-local build and user-run `nh os switch` succeeded; running closure:
`/nix/store/8lazvh0nxb39ycnwwrp4a681rkzk3iq0-nixos-system-x13-gnome`.
An exact display-manager unit comparison preceded activation; its actual MainPID
and active user Wayland session13 survived the switch. Home Manager, GDM,
Tailscale, user graphical target and Syncthing active; zero failed system/user
units. New package executables and updated runtime scripts verified. No reboot,
new Git repository, commit or publishing. Physical menu/endpoint/password use and
native clipboard bridge activation after next login remain human acceptance.

## 2026-11-10: read-only GNOME duplication audit

User asked to review duplicate GNOME components before further configuration,
starting with the mounting tray. No application/service/settings changes or
rebuild were performed. Fresh pinned SSH to osmarg@10.0.0.67 verified hostname
X13, same running 8laz closure and active Wayland session13. Original root is
now at 2bbf6ba with unrelated Hyprland edits; do not treat its older X13 source
as the deployed GNOME configuration. The follow-ups worktree remains dirty at
1689dc7 with the task changes from prior turns. All unrelated edits preserved.

Confirmed active redundancy: systemd user udiskie.service is running with
--automount --notify --tray while GNOME media-handling automount/automount-open
are both true and its GVfs UDisks2 monitor is active. Removable Drive Menu is
also enabled, providing another disk menu. Blueman applet/tray processes and
blueman.desktop autostart are present alongside GNOME's native Bluetooth UI.
Recommended future cleanup: disable udiskie and Blueman only in X13 GNOME,
retaining UDisks2, BlueZ, GVfs (including MTP/AFC) and native GNOME interfaces.
Do not implement this recommendation until it becomes the requested task.

Installed overlap, verified through actual desktop entries/commands/Flatpak
inventory: Rofi remains installed after GTK adaptation; Epiphany alongside
Firefox and the Chromium webapp engine; Totem and Showtime alongside preferred
VLC; Evince and Papers alongside PDFCraft; Simple Scan installed natively and
as org.gnome.SimpleScan Flatpak; GNOME Connections alongside Remmina and the
existing remote helper; GNOME Maps alongside selected Google Maps webapp.
GNOME Music and Decibels are optional extra local-audio apps, not equivalent
to Spotify's streaming service. Native Discord and Discord Flatpak coexist;
keep Discord, but its packaging choice needs a decision before deduplication.

Preference exclusions: user explicitly wanted both GNOME Console and Kitty;
Chromium supports chosen isolated webapps; Firefox/VLC/Thunderbird/ArtCraft,
webapps, KDE Connect, gaming/Flatpak catalogs are personal selections. mpv is
used by the YouTube Music CLI and is not a free-standing cleanup candidate.
Printing/HP utilities have specific functions and drivers must be retained.

False positives checked: both System Monitor desktop files resolve to the
same package; one is OnlyShowIn=KDE and the other NotShowIn=KDE, so GNOME does
not have a duplicate monitor. GTK and GNOME portals cooperate; GNOME keyring,
Seahorse, GVfs monitors, UDisks2/BlueZ are infrastructure, not duplicate tray
apps. No cliphist/dunst/swaync commands or competing processes were found;
Clipboard Indicator remains the single enabled history. Syncthing/Tailscale
tray autostart masks are still Hidden=true while background services remain.
Power-profiles-daemon active; tlp/auto-cpufreq inactive.

Effective MIME defaults observed: directory Nautilus; PDF PDFCraft; audio/video
VLC; text WordCraft. Do not change these as an accidental consequence of a
future package cleanup. Actual Flatpak inventory now includes ArtCraft and its
apps (installed, not authenticated/runtime acceptance); earlier download notes
are historical, and this audit did not validate the full emulator/catalog use.

## 2026-11-10: Brave Origin shared-profile webapps

User authorized checking native nixpkgs support, implementation and NH switch
on X13 and ORGM. Official release-26.05 PR #584546 merged 2026-11-07 adds
brave-origin 1.99.55. Existing system pin lacks it; new nixpkgs-browser input
is fixed at ac588ef1c914865dad517b337ea0eb9694a4021c, without updating the
system/kernel or other locked inputs. The old local beta builder now delegates
to the official package. Enablement is limited to Osmarg's canonical X13/GNOME
and ORGM/Hyprland configurations; other hosts/profiles retain their backend.

Current Origin supports distinct URL-app identities in a shared Default
profile: brave-<host>_<path-with-slashes-replaced>-Default. Launchers use
--app=URL, --profile-directory=Default and native Wayland; desktop filenames
and StartupWMClass match the observed identity. No per-app user-data-dir or
disable-sync flag for Origin. Existing Chromium profile directories remain
untouched. No cookies/passwords were copied between browser profiles.

Verified real fixtures: two apps share one browser process and a loopback
session cookie; actual nwg-dock clicks focus exact windows across workspaces
and reopen the correct closed app. Isolated GNOME Shell 50 on X13 also
associates two shared-process app windows with two separate desktop IDs.
These are real fixture runtime tests, not physical user acceptance of every
selected endpoint. Profile/pin migration tests and unchanged Chromium
Hyprland/i3 regressions passed. Firefox fallback/helper and X13 shortcut
callback tests passed; full builds completed on controller and target.

NH switch completed on both hosts. ORGM running
/nix/store/qiwmx9qm5zrv8hwpric2r1hlrxs8rgrr-nixos-system-orgm-hyprland;
X13 running /nix/store/f5bcn1cqgng36v8c66v0jsvrqa11q7l1-nixos-system-x13-gnome.
Exact display-manager unit comparisons passed before activation. X13 kept
GDM MainPID25927 and active Wayland session13. Both hosts' Home Manager and
display-manager are active with no failed system/user units. Origin executable,
HTTPS MIME default and vertical-tabs setting verified; Origin opened in both
actual sessions. No logout/reboot or closure of old browser windows.

GNOME favorites and nwg pins migrated with backups; duplicate Firefox/Chromium
browser pins collapse into Origin while unrelated entries/order survive.
Existing Origin preferences are preserved except the requested vertical-tabs
and free Linux-tier choices, with private same-profile backups; never written
while SingletonLock is present. No profile data printed in logs or notes.
Guarded mutable Firefox helper updates preserve its GNOME dialogs; ORGM's
runtime menu/autostart patches preserve existing local Obsidian/other startup
additions rather than replacing them with the older repository snapshots.

X13 source/runtime backups: NH_FLAKE/.x13-deploy/20261110-origin, with original
source hash manifest. Only scoped browser files were transferred; unrelated
printer/clipboard/other changes were preserved. X13 canonical local source
remains .worktrees/x13-gnome-followups, not the older original-root X13 files.
ORGM mutable-file/pin backups: ~/.local/state/orgm-origin. The X13 focus
extension's source now targets brave-origin.desktop; its already-loaded code
can retain Firefox until next GNOME login. No Shell restart/Eval was used.
User acceptance of current GNOME shortcut behavior is separate from installed
source. Old browser windows remain open: closing them voluntarily is needed
to reclaim their RAM. No RAM saving percentage was measured. No publishing.

## Pending for another agent: camera and microphone recorder across Osmarg profiles

User explicitly requested GNOME camera and microphone recording applications
for the other `osmarg` profiles, then limited the CURRENT implementation to X13:
"pero trabaja solo en x13 y deja en memoria local pendiente esto para que cuando
otro agente lo trabaje lo agregue". Keep this cross-profile rollout PENDING.

Chosen X13 applications: `pkgs.snapshot` (GNOME Camera, photos/video; already
installed on X13 and now explicitly retained) and `pkgs.gnome-sound-recorder`
(GNOME Sound Recorder / Vocalis, microphone recording; selected locked version
43.beta). The other-profile agent should add these to Osmarg's shared desktop
application selection, with proper desktop entries and required PipeWire/portal
integration for each compositor, without enabling a GNOME session or applying
X13's desktop cleanup to other hosts/users. Evaluate actual selected package
versions again at that time. Do not install two alternative camera/recorders.
No camera or microphone capture was performed by this task; physical runtime
acceptance and the older X13 camera permission complaint remain unverified.
Never weaken camera/microphone privacy guards as a package-install workaround.

The user explicitly states another agent owns the browser/webapp work. Do not
edit, restore or redeploy that agent's flake/browser/webapp/shared-source changes.
Current X13 cleanup is isolated in `nixos/hosts/x13/native-desktop.nix`, imported
only by the X13 GNOME wrapper, in `.worktrees/x13-gnome-followups`. It does not
remove browser packages/Rofi or choose a Discord package format. The original
working tree and this worktree both now have concurrent browser-agent edits;
inspect Git status and preserve them before any future source delivery.

## 2026-11-10: X13 native-desktop cleanup activated

Only two task-owned source files were transferred with baseline hashes/backups:
X13 gnome.nix import plus new native-desktop.nix. Stage/backup path:
`/home/osmarg/Hobby/nixos/.x13-deploy/20261110-native-cleanup`.
The module filters final system and HM package lists only in X13, avoiding edits
to shared/browser/webapp files under concurrent development. Removed from X13
profiles: udiskie, Blueman, GNOME Maps/Connections, Totem/Showtime, Papers and
native Simple Scan. Evince remains as native PDF fallback; installed preferred
Simple Scan Flatpak, VLC, Remmina, PDFCraft and other personal apps retained.
Browser packages/Rofi and the native-vs-Flatpak Discord choice remain outside
this cleanup, respecting concurrent work/preferences. No Flatpak was uninstalled.

Snapshot50.0 explicitly retained, GNOME Sound Recorder43.beta newly added.
Recorder --help passed without microphone capture; desktop entries and runtime
hardware acceptance must be distinguished. No camera permissions, portal guards,
biometric/authentication or default file handlers were intentionally changed.

X13 Normal and Server full builds passed on target. New focused test
`tests/x13-native-desktop.test.py` passed on target, checking package exclusion,
required apps, GDM/Server policy, UDisks2/BlueZ/GVfs/printing/SANE and preferred
Flatpaks. Module ownership and source import are X13-only. An initial attempt to
evaluate module declarations across ALL historical hosts hit an unavailable
private orgm-amux Git dependency (lenovo-server); no credentials/fetch bypass
attempted. Broad cross-host evaluation is NOT claimed green. The test was scoped
to the requested X13 plus a structural sole-import check; this passed.

Target-local user-run `nh os switch` succeeded. Running closure:
`/nix/store/slmmrangfjymg95lc5d5xryl99drv7wp-nixos-system-x13-gnome`.
Display-manager unit exact-match preflight, actual MainPID and existing active
Wayland session13 all preserved. Home Manager, GDM, UDisks2 and Bluetooth active;
user graphical target active; udiskie inactive/masked and no failed system/user
units. Blueman's already-running UI survived package removal; owned applet/tray
processes were subsequently terminated (not bluetoothd). No reboot/logout.

The other Osmarg profiles' camera/microphone-recorder rollout remains pending
as requested in the preceding handoff. No commit/push/merge in this task.

## 2026-11-10: shared desktop/login wallpaper implementation

User asked whether Origin/webapp improvements survived the cleanup and requested
GDM share the desktop wallpaper instead of gray. Fresh pinned SSH verified the
running slmm closure has brave-origin, HTTPS default brave-origin.desktop and
installed brave-<host>_<path>-Default webapp desktop identities. Thus the prior
browser-agent deployment is included; no browser/webapp source was edited here.

Desktop effective wallpaper before this task: GNOME Amber light/dark JXL files,
prefer-dark active. New X13-only login-background.nix imports from the X13 GNOME
wrapper and declares Amber dark once as the shared desktop/screensaver/GDM image.
The existing public GNOME background is converted losslessly to PNG at Nix build
time for Shell CSS compatibility; no personal photos/private files are copied.
A single Nix binding is the source of truth. Changing wallpaper only through
GNOME Settings does NOT dynamically synchronize GDM: change the shared Nix image
and rebuild to change all three. No privileged wallpaper-watching daemon added.

GNOME50.5 normally paints #lockDialogGroup gray. The task preserves stock CSS
and appends only its background properties to dark/light CSS through GLib's
G_RESOURCE_OVERLAYS. A systemd user drop-in targets ONLY org.gnome.Shell@gdm,
never org.gnome.Shell@user. High-contrast resources stay stock. No Shell package
rebuild/patch, extension requirement, PAM/login logic, GDM manager environment
or authentication gate changes. restartIfChanged=false preserves a live greeter.
The service's generated environment is forced empty to avoid overriding the
inherited greeter PATH; only the resource overlay and normal locale metadata
remain in the generated drop-in.

Source delivery changed only X13 gnome.nix plus new login-background.nix, with
baseline guards/backups under NH_FLAKE/.x13-deploy/20261110-login-background.
Normal/Server full builds passed on X13. New tests/x13-login-background.test.py
passed on target: shared immutable valid PNG URI, GDM-only instance/drop-in,
user and Server isolation, Origin still enabled, original CSS retained and
actual Gio global resource URI lookups honor both overlays. Initial test
projection attempted to serialize unset service metadata; narrowed to the
specific options rather than adding arbitrary service defaults. No physical
GDM login image acceptance is claimed until the next greeter starts.

No forced logout/reboot/Shell restart. New greeter appearance needs the next
login screen lifecycle (voluntary logout or reboot). Existing active user session
must be preserved; use exact GDM-manager and Shell-template comparisons during
any activation. The Origin shortcut extension's earlier next-login requirement
also remains distinct from browser/webapp installed-state verification.

Final wallpaper activation: user-run NH switch completed to
`/nix/store/mjlw3k7r5gzd5yslkci03s6z4vxs7ff5-nixos-system-x13-gnome`.
Same GDM MainPID and active Wayland session13 preserved; GDM/Home Manager
active, zero failed system/user units. Desktop/lock/shared image is
`/nix/store/li7gihcd29pgiwbcc6lnxmn21g6n5wmz-x13-shared-wallpaper/background.png`.
HTTPS default remains brave-origin.desktop. The greeter user had no active
D-Bus socket for a live manager check; the next greeter start reads the verified
installed instance drop-in. Physical login appearance pending. No publishing.
