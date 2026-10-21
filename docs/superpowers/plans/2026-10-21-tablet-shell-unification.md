# Manual Tablet Shell and Secure Keyboard Unification Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Inline TDD, one final fresh whole-task review. No implementer agents.

**Goal:** One shared Quickshell OSK on Sway/Hyprland, manual-only tablet profile, complete shared control center, launcher-consistent helpers, and keyboard buttons inside SDDM/session-lock authentication.
**Architecture:** Keep existing desktop shell and Win+Space visual world. Persistent manual on/off preference drives generated larger/reduced Waybar and a three-action Quickshell tablet dock (Apps/Windows/Keyboard); normal nwg-dock remains unchanged. Extend existing ControlMenu/backend with all current Waybar actions, and reuse the current keyboard as a local Qt input widget inside immutable Qylock themes/lock surfaces, never as an external auth overlay. One common Rofi invocation/style path serves launcher and helper entry points.
**Tech Stack:** Existing Python stdlib, QML/Quickshell0.3, Rofi2, Sway/Hyprland adapters, NixOS.
**Spec:** User corrective request 2026-10-21: same keyboard on Sway/Jarq; remove automatic tablet mode; larger and fewer controls; complete CC normal+tablet; same Win+Space format for Win+D/Win+M and helpers; subsequent explicit SDDM+lock keyboard-button request. User answered yes to prior offer to proceed directly, so no repeated design questions. Layout implementation choices below are ours, not falsely attributed to user.

## Global Constraints
- No reboot/commit/push, no lock bypass or PAM changes, no credential persistence/reuse from previous operation. Preserve unrelated pending work and other agents/worktrees.
- Reuse existing owned isolated worktree9279; canonical remains guarded application destination.
- Active Envy source is staged tablet+OSK snapshot, not old clean Git checkout. Jarq current address pending; never claim applied without connection/health evidence.
- Manual tablet only: default/migrated auto => off; accept only on/off/toggle. No sensor watcher, no physical input disable, no Squeekboard launcher.
- Tablet changes shell controls only, not global monitor/app scaling. Preserve normal user config/pins and output targets.
- Tablet Waybar height52, font18; battery/clock/one control-center icon. Tablet dock three labeled touch targets >=64px, bottom-center; app/window/keyboard actions remain reachable without hover/right-click.
- Secure keyboard only inserts into local focused Qt field in the same authentication window; no global key injection, process IPC carrying password, credential logging, new authenticate/unlock API, or auth-service changes.
- Existing Hyprland Alt+Tab plugin stays intact; Sway touch Windows uses existing working window selector/focus adapter.
- Test private HOME/runtime/display only; no screenshots or typing into real lock/greeter/password fields.

## Review Focus
- Stale auto preferences or old tablet daemons cannot silently relaunch Squeekboard or override manual off.
- Profile rollback/current compositor targeting: no changes to other display sessions, normal pins/config preserved, no duplicate docks.
- Every current Waybar action reachable in CC with truthful unavailable state; touch interaction does not require right-click/hover.
- Secure keyboard focus, ñ/accents, Return/Backspace and hotplug; outside clicks/Escape/wrong input never unlock; no plaintext leakage.
- Rofi theme parity through effective per-user overrides, SSH multi-step prompts and Firefox URL prompt; desktop launcher reference retained.

### Task 1: Manual policy and tablet shell profile
**Files:** new profiles/wayland .local/lib/orgm-wayland/tablet.py and .local/bin/orgm-tablet; new tablet dock QML and launcher; new nixos/tablet.nix; mk-system import; Sway Waybar/startup+Nix dock command; Hypr waybar generator/dock wrapper; app manifests as ownership permits.
**Interfaces:** tablet.state()->dict(mode,active,available,keyboardVisible,...); mode on/off/toggle persists atomically, restarts only current owned bar+dock; keyboard show/hide/toggle delegates orgm-osk; profile generation pure. Dock launcher execs existing normal command or qs tablet dock; display-specific systemd lifecycle retained.
- [ ] RED tests/manual-tablet.test.py: default and legacy auto off, auto rejected, no detection/spawn, own-service restarts, generated compact large bars and untouched normal config.
- [ ] Implement shared policy/adapters and compact tablet dock; retain old daemon command only as harmless one-shot migration compatibility.
- [ ] GREEN unit/boundary tests plus real private Waybar/dock and mode-transition tests.

### Task 2: Shared user keyboard and local secure auth keyboard
**Files:** common OSK Keyboard.qml plus new AuthKeyboard.qml; Qylock runtime packaging/theme-wrapper generator; lock fallback integration; tests/secure-keyboard*.py and OSK tests.
**Interfaces:** shared visual Keyboard controller send({code,text,modifiers,dead}); secure controller edits only same-window Qt input, emits its normal accepted signal on Return, no global engine. Immutable generated wrapper reserves keyboard space and leaves original theme/auth signals intact; fallback inside WlSessionLockSurface.
- [ ] RED native fixture: button opens same visual board, actual taps produce expected dummy input/accepted signal and no external engine; no-ready target safe.
- [ ] Implement secure widget and package all pinned themes as wrapped originals with symlinked assets; local fallback widget, no PAM changes.
- [ ] GREEN private actual Sway session-lock/PAM fixture and SDDM test-mode render; preserve existing lock protocol/hotplug regressions.

### Task 3: Complete shared control center
**Files:** shared desktop.py/shell.py ControlMenu.qml, Style.qml/components as needed; tests/control-center*.py.
**Interfaces:** control-state includes manual tablet, available hardware and battery/connectivity; allowlisted control-action and control-choice catalog covers existing bar inventory. Same panel sections/behavior in normal and tablet, density adapts without losing actions.
- [ ] RED action coverage across all effective Sway/Hypr Waybar modules; require audio+mic devices, brightness, battery/power, network/Bluetooth, notifications/DND, media, caffeine, gaming, layout/workspace/window, appearance/wallpapers, helpers/tray apps and session actions.
- [ ] Extend existing panel/backends using existing dialogs/tools where appropriate; actionable direct +/-/toggle controls and clear unavailable hints, not decorative buttons.
- [ ] GREEN dispatch validation and private actual CC clicks, including mode switch and keyboard/window actions.

### Task 4: One launcher style for helper menus
**Files:** shared Rofi helper/launcher theme integration; Sway/Hypr libraries; Firefox prompt base+effective user copies; shell pick fallback.
**Interfaces:** common helper resolves current compositor theme+palette, emits launcher typography/radius/colors, respects semantic dmenu vs drun and list row needs; tablet touch dimensions read same manual preference.
- [ ] RED tests/menu-style-parity.test.py: launcher vs Win+D SSH/Win+M Firefox effective invocations, all user overrides, escape/cancel and malicious input preserved.
- [ ] Route helpers through shared launcher visual contract; retain SSH/Firefox behavior and safe argument arrays.
- [ ] GREEN existing SSH/Firefox/Rofi regression suites plus native Rofi input test.

### Task 5: Verify, review and apply
**Files:** deployment/session report and own ledger/artifacts; source edits only guarded task-owned paths.
- [ ] Focused and adjacent tests, one batched landscape/portrait visual inspection and at most one confirmation, one fresh read-only final review; Important/Critical fixes RED->GREEN then full focused suite.
- [ ] Apply owned canonical/home files with content guards and orgm-dot backup. Stop only old session-owned tablet daemon so its Squeekboard child exits; new shared OSK service used everywhere.
- [ ] Stage Envy from its current active source and apply user-runtime changes; build permanent integration and use ordinary authentication if required. Jarq only through verified current address; report any access/authentication blockers explicitly.
- [ ] Record exact active unit/source, manual state, focused evidence and remaining physical/user tests; no full-suite/permanent-deployment claims beyond evidence.
