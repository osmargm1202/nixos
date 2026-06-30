# Verify Report: google-quickshell-calendar

Date: 2026-05-24
Verifier: SDD apply correction executor
Status: PARTIAL PASS — focused/static checks pass; Nix and live desktop checks unavailable

## Executive summary

User corrections were applied: the standalone `orgm-calendar` helper was removed, the calendar command surface is now `orgm-hypr calendar <function>` in the existing Go binary, and `gcalcli` remains the Google Calendar data/OAuth backend. Runtime cache/state paths intentionally remain under `orgm-calendar` for compatibility.

The previous verify blockers for TSV parsing and repeated toggle identity were addressed by the Go implementation and current QML request handling (`requestedAt`). Remaining gaps are environmental: `nix` and `quickshell` are unavailable in this session, so full flake/build and live UI validation could not run.

## Focused verification results

| Check | Result | Evidence |
|---|---:|---|
| Go calendar package + CLI | ✅ | `go test ./cmd/orgm-hypr ./internal/calendar` passed. |
| Static QML/cache fixtures | ✅ | `python openspec/changes/google-quickshell-calendar/support/fixtures/validate_calendar_ui.py` passed. |
| Standalone command removal | ✅ | `git grep` found no `orgm-calendar <subcommand>` or `["orgm-calendar"]` command refs in config/openspec/cmd/internal. |
| Manifest removal | ✅ | `config/dotfiles.json` no longer lists `.local/bin/orgm-calendar`. |
| Standalone helper file removal | ✅ | `config/shared/.local/bin/orgm-calendar` is absent. |
| Hyprland/Waybar activation | ✅ | Autostart, `Win+Shift+C`, and Waybar clicks call `orgm-hypr calendar ...`. |
| gcalcli backend | ✅/manual gap | Go tests cover default-compatible TSV parsing and failure preservation; real OAuth/account sync still needs manual desktop smoke. |
| Python 3.13 concern | ✅ documented | Nix/support docs note `gcalcli` is Python and may pull Python; `python3Minimal` was pre-existing; Go helper adds no extra Python packages. |
| Nix flake check | ⚠️ not run | `nix: command not found`. |
| Live Quickshell UI | ⚠️ not run | `quickshell` unavailable in this session. |

## Commands run

```text
go test ./cmd/orgm-hypr ./internal/calendar
python openspec/changes/google-quickshell-calendar/support/fixtures/validate_calendar_ui.py
python/json checks for config/dotfiles.json and waybar-hypr config
lua loadfile checks for autostart.lua and keybindings.lua
git grep standalone orgm-calendar command checks
orgm-dot diff --host orgm
nix flake check
```

Results: focused Go/static/config checks passed; `orgm-dot diff --host orgm` exited 0 and showed expected Hyprland/Waybar/Quickshell managed diffs; `nix flake check` failed because `nix` is not installed/available in this session.

## Remaining verification gaps

- Run `nix flake check` and any focused NixOS build in an environment with `nix`.
- Run live desktop smoke once dotfiles are synced: `orgm-hypr calendar sync`, `orgm-hypr calendar toggle-ui`, Waybar click, `Win+Shift+C`, and a controlled reminder.
- Confirm real `gcalcli` OAuth/account output on the target desktop.
