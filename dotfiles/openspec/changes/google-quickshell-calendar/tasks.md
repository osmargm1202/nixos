# Tasks: Google Quickshell Calendar

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | Total 500-750 likely; target <=300 changed lines per PR |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1 backend/cache/reminders/tests/docs scaffold → PR 2 Hyprland/Nix/dotfile startup → PR 3 Quickshell UI/polish/docs |
| Delivery strategy | ask-on-risk |
| Chain strategy | pending |

Decision needed before apply: Yes
Chained PRs recommended: Yes
Chain strategy: pending
400-line budget risk: High

## Implementation Tasks

> Constraints for apply: do not implement until this tasks artifact is approved. Backend is `gcalcli`; `orgm-hypr calendar` is command glue in the existing Go binary, not the Google Calendar data backend. Startup is Hyprland `exec-once`, not systemd. Quickshell reads a local JSON cache contract.
>
> User correction applied: do not create or use a standalone `orgm-calendar` binary. Preserve host-local `dota.desktop` and `silksong.desktop` launchers as authoritative host files. Keep cache/state compatibility paths under `orgm-calendar` where useful, but all command entrypoints are `orgm-hypr calendar <function>`.

### 0. Apply preflight and current-source confirmation

- [ ] Confirm active managed paths before edits:
  - `config/shared/.config/hypr/lua/autostart.lua`
  - `config/shared/.config/hypr/hyprland.lua`
  - `config/shared/.config/quickshell/wallpaper-picker/shell.qml`
  - `config/dotfiles.json`
  - `nixos/profiles/hyprland.nix`
  - the active Waybar time/date/day module config
  - the active Hyprland keybinding config/source
- [x] Confirm no standalone `.local/bin/orgm-calendar` should be managed; use existing Go binary `orgm-hypr calendar` instead.
- [x] Confirm available test harness for helper code; create focused Go tests under `internal/calendar/` and CLI tests under `cmd/orgm-hypr/`.
- [ ] Verification boundary: no runtime code changed yet; this is discovery only.
- [ ] Rollback boundary: no rollback needed.

### 1. PR 1 RED: backend/cache/reminder tests and fixtures

- [x] Add failing tests before helper implementation:
  - `tests/orgm_calendar/test_cache_contract.py`
  - `tests/orgm_calendar/test_reminders.py`
  - `tests/orgm_calendar/test_actions.py`
  - fixture samples under `tests/fixtures/gcalcli/`
- [x] Cover scenarios from `openspec/changes/google-quickshell-calendar/spec.md`:
  - timed events, all-day events, empty calendar;
  - missing `gcalcli`, OAuth/token error, network error, malformed output;
  - atomic cache write preserves previous valid cache;
  - reminder horizons `1440`, `720`, `240`, `60` minutes;
  - duplicate prevention across state reload;
  - `open-web`, `open-event`, `add`, and UI toggle command behavior.
- [x] Verification: run the focused tests and confirm they fail for missing implementation, then run `nix flake check` if the test harness is wired into the flake.
- [x] Acceptance check: RED failures map directly to spec scenarios; no production helper logic added in this task.
- [ ] Rollback: remove `tests/orgm_calendar/` and `tests/fixtures/gcalcli/` if abandoning PR 1.

### 2. PR 1 GREEN: implement `gcalcli` JSON cache/action helper

- [x] Add `internal/calendar + cmd/orgm-hypr calendar` as the stable command wrapper and daemon entrypoint.
- [x] Implement subcommands:
  - `orgm-hypr calendar daemon`
  - `orgm-hypr calendar sync`
  - `orgm-hypr calendar status`
  - `orgm-hypr calendar open-web [date]`
  - `orgm-hypr calendar open-event <id>`
  - `orgm-hypr calendar add [date]`
- [x] Write runtime cache/state only under XDG paths:
  - `${XDG_CACHE_HOME:-$HOME/.cache}/orgm-calendar/events.json`
  - `${XDG_STATE_HOME:-$HOME/.local/state}/orgm-calendar/reminders.json`
  - optional `${XDG_STATE_HOME:-$HOME/.local/state}/orgm-calendar/status.json`
- [x] Implement schema version `1` fields from `design.md`: `generatedAt`, `lastSuccessAt`, `timezone`, `source`, `status`, and `events[]` with `stableKey`, times, dates, all-day flag, and link fields when available.
- [x] Implement atomic JSON writes with temp file + rename; preserve previous valid cache on refresh/parse/serialization failure.
- [x] Implement dependency and error classification for `gcalcli`, OAuth/auth, network, parse, `notify-send`, and browser opener failures.
- [x] Implement reminder state and `notify-send` emission only after successful notification exit unless an explicit best-effort semantic is documented in the helper.
- [x] Verification: focused helper tests pass; `orgm-hypr calendar status` reports clear dependency/OAuth state in the local environment; `gcalcli` remains the data backend.
- [x] Acceptance check: Quickshell can consume `events.json` without invoking Google APIs; duplicate-safe reminders are represented in local state.
- [ ] Rollback: remove `internal/calendar`, `cmd/orgm-hypr` calendar wiring, and Go test additions; no `.local/bin/orgm-calendar` manifest entry is expected.

### 3. PR 1 TRIANGULATE/REFACTOR: harden backend edge cases

- [x] Add or extend tests for timezone boundaries, all-day multi-day events, missing event IDs/html links, stale cache metadata, and late reminder grace-window behavior.
- [x] Refactor helper parsing and schema generation to keep date/time normalization small and auditable.
- [x] Document chosen sync cadence and late reminder semantics in `openspec/changes/google-quickshell-calendar/support/gcalcli-calendar.md` or a tracked repo doc chosen during apply.
- [x] Verification: focused tests pass; `nix flake check` passes if tests are included in flake checks.
- [x] Acceptance check: backend slice is independently reviewable and usable from CLI.
- [ ] Rollback: revert backend/helper/test/doc files from PR 1 only.

### 4. PR 2 RED: package/startup/dotfile validation checks

- [ ] Add failing checks or review checklist entries for package/startup expectations before changing startup:
  - `gcalcli` available from the Hyprland profile;
  - `notify-send` provider available, likely via `libnotify`;
  - no systemd user service/timer files added;
  - Hyprland autostart uses `exec-once` semantics through `config/shared/.config/hypr/lua/autostart.lua`;
  - `Win+Shift+C` and Waybar time/date/day click route to the same calendar UI toggle command.
- [ ] Concrete files to inspect/change:
  - `nixos/profiles/hyprland.nix`
  - `config/shared/.config/hypr/lua/autostart.lua`
  - `config/dotfiles.json`
  - the active Waybar time/date/day module config
  - the active Hyprland keybinding config/source
- [ ] Verification: `nix flake check` should fail or report missing package/check until GREEN work is applied, where practical.
- [ ] Rollback: no persistent runtime changes expected.

### 5. PR 2 GREEN/REFACTOR: add packages and Hyprland startup

- [ ] Update `nixos/profiles/hyprland.nix` to include `gcalcli` and ensure `notify-send` is available via the appropriate package.
- [ ] Update `config/shared/.config/hypr/lua/autostart.lua` with `exec-once` entries equivalent to:
  - `sh -lc 'orgm-hypr calendar daemon >>${XDG_STATE_HOME:-$HOME/.local/state}/orgm-calendar/helper.log 2>&1'`
  - `quickshell -c calendar`
- [ ] Do not add `.local/bin/orgm-calendar` to `config/dotfiles.json`; the command is provided by the existing `orgm-hypr` binary.
- [ ] Add or update the Hyprland keybinding so `Win+Shift+C` opens/toggles the calendar UI through the same command used by Waybar.
- [ ] Add or update the Waybar time/date/day module `on-click` so clicking the clock/date/day opens/toggles the calendar UI.
- [ ] Ensure activation triggers do not spawn duplicate `orgm-hypr calendar daemon` processes.
- [ ] Do not add systemd user units or timers.
- [ ] Verification:
  - `nix flake check`
  - `orgm-dot diff --host orgm`
  - focused NixOS build if package/profile behavior is risky: `nix build .#nixosConfigurations.orgm-hyprland.config.system.build.toplevel --no-link`
- [ ] Acceptance check: startup is disableable by removing/commenting the autostart entries; package changes do not disturb unrelated Hyprland behavior.
- [ ] Rollback: remove the autostart entries, remove package additions if unused, revert `config/dotfiles.json` entry if added.

### 6. PR 3 RED: Quickshell cache-reader/UI behavior tests or fixtures

- [ ] Add cache fixtures for UI development under `openspec/changes/google-quickshell-calendar/support/fixtures/` or `tests/fixtures/calendar-cache/`:
  - normal month with events;
  - selected day with no events;
  - stale/error cache;
  - malformed cache.
- [ ] Define manual UI acceptance checklist before QML implementation:
  - month grid renders;
  - today and selected day are visually distinct;
  - selected-day agenda updates on click;
  - stale/error/empty states are visible and non-crashing;
  - buttons call `orgm-hypr calendar sync/add/open-web/open-event`;
  - Waybar click and `Win+Shift+C` open/toggle the same UI.
- [ ] Verification: QML work not started until fixtures/checklist exist.
- [ ] Rollback: remove fixture/checklist files.

### 7. PR 3 GREEN: implement Quickshell calendar widget

- [ ] Add `config/shared/.config/quickshell/calendar/shell.qml` and optional components under `config/shared/.config/quickshell/calendar/components/`.
- [ ] Read `${XDG_CACHE_HOME:-$HOME/.cache}/orgm-calendar/events.json` using repo-native Quickshell patterns such as `FileView`, watched reloads, JSON parsing, `Process`, and detached actions.
- [ ] Render Caelestia-inspired, repo-native UI:
  - header with month title and prev/next controls;
  - seven-column weekday/month grid;
  - current day, selected day, outside-month styling;
  - event dots/counts;
  - selected-day event cards/list;
  - empty, stale, and error states;
  - sync, add, view/open, and Google Calendar web buttons;
  - visible key hint or affordance for `Win+Shift+C` where appropriate.
- [ ] Ensure render path never calls `gcalcli` directly; QML only reads cache and calls `orgm-hypr calendar` actions.
- [ ] Verification: run Quickshell manually with fixture cache and real cache where available; confirm malformed cache does not crash the shell.
- [ ] Acceptance check: UI satisfies month grid, selected-day agenda, add/view/open actions, and calm visual style.
- [ ] Rollback: remove `config/shared/.config/quickshell/calendar/` and the `quickshell -c calendar` autostart line.

### 8. PR 3 TRIANGULATE/REFACTOR: UI polish and failure feedback

- [ ] Test UI against all fixture states and at least one real `orgm-hypr calendar sync` cache when `gcalcli` OAuth is configured.
- [ ] Refactor QML to keep date helpers, action launching, and card rendering readable; avoid wholesale external theme imports.
- [ ] Add keyboard/mouse polish where practical: `Win+Shift+C` toggle, Esc close if panel mode supports it, PageUp/PageDown month navigation, Enter/open selected event or day if straightforward.
- [ ] Verification:
  - `nix flake check`
  - `orgm-dot diff --host orgm`
  - manual Quickshell launch and action-button smoke test.
- [ ] Rollback: revert Quickshell calendar files and autostart launch only; keep backend cache helper if PR 1 remains useful.

### 9. Final documentation and acceptance verification

- [ ] Add or finalize documentation for OAuth/bootstrap and troubleshooting, covering:
  - installing/configuring `gcalcli` through the Nix profile;
  - first-run OAuth via normal `gcalcli` commands;
  - missing calendars, expired tokens, network failures;
  - cache/state file locations;
  - notification duplicate state and reset procedure;
  - rollback steps.
- [ ] Run final validation commands after all accepted slices:
  - `nix flake check`
  - `orgm-dot diff --host orgm`
  - focused build if Nix profile changed: `nix build .#nixosConfigurations.orgm-hyprland.config.system.build.toplevel --no-link`
  - `nix fmt` if Nix files changed.
- [ ] Manual acceptance checks:
  - `gcalcli` is documented and actual data backend;
  - `orgm-hypr calendar sync` creates valid cache JSON;
  - Hyprland startup uses `exec-once`, not systemd;
  - Quickshell displays month grid and selected-day events from cache;
  - Waybar time/date/day click and `Win+Shift+C` open/toggle the same calendar UI;
  - add/view/open-web buttons work or fail visibly;
  - `notify-send` reminders are duplicate-safe for 24h/12h/4h/1h;
  - malformed cache and dependency failures do not break unrelated desktop behavior.
- [ ] Rollback confirmation: removing the two autostart entries disables runtime behavior while leaving `gcalcli` credentials untouched.

## Review Notes

- Preferred chain strategy must be chosen before apply because total implementation likely exceeds the 400-line review budget even if each PR is kept small.
- The backend/cache PR should land before UI so reviewers can validate the JSON contract independently.
- Do not reintroduce a standalone `.local/bin/orgm-calendar`; command entrypoints must stay under `orgm-hypr calendar`.
- `orgm-hypr calendar` is command glue/supervision only; `gcalcli` remains the primary data path.
