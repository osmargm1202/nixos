# Shell Tools Repair Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans; inline implementation with one final fresh review.

**Goal:** Restore z/zi and audit the user's selected terminal integrations after Ryoku→Hyprland migration.
**Architecture:** Use existing standard Bash dotfiles; preserve private local files during application. Retain NixOS ownership of Blesh/Atuin. Restore supported Blesh FZF completion and declare missing `file` preview dependency. No second prompt/history initialization.
**Tech Stack:** Bash, Blesh, Atuin, zoxide, fzf, NixOS, Python/PTY tests.
**Spec:** User reports z/zi absent and requests review of all their tools; scope is configured terminal tools, not installation of arbitrary optional packages.

## Global Constraints

- No system rebuild/switch, full Home Manager activation, reboot, commit or push.
- Preserve actual credentials/history/zoxide DB, local-only Bash files and previous ScrollOverview/Syncthing fixes.
- Do not change unrelated Git, terminal multiplexers or prompt preferences without a demonstrated fault.
- Work in existing own isolated worktree 9279; copy only owned diffs with base-content guards.
- Apply Bash ourselves using orgm-dot with backup, preserve local-only files; existing parent shells need a new Bash to acquire functions.

## Review Focus

- Real z/zi navigation with private database and whitespace paths; one directory hook.
- Blesh and FZF/Atuin compatibility; retain Ctrl+R Atuin and custom Alt bindings.
- Noninteractive shells remain clean; repeated source doesn't duplicate hooks/PATH.
- Preview text/directory/image/archive paths have dependencies; no secrets/network AI calls in tests.
- Never delete local-only private-env/user files during full-directory pull.

### Task 1: Audit, regression tests, minimal repair and apply

**Files:** new tests/shell-tools.test.py; nixos/common.nix; base/personal .blerc if FZF completion regression confirmed; report and dotfiles docs as needed.
**Interfaces:** standard .bashrc loads config.bash after /etc/bashrc; Blesh .blerc initializes FZF widgets, Atuin is then initialized by /etc/bashrc. `file` must be present with shell program selection.

- [x] Observe RED live audit: z and zi absent, exit31; old Ryoku loader uses --cmd cd and old imports lack compatibility wrappers.
- [x] Test current repo standard Bash in private HOME: z/zi already work; this part is deployment drift, not a missing zoxide package.
- [x] Add/run RED actual Blesh/FZF/preview-dependency regression, including reload and noninteractive behavior.
- [x] Apply only confirmed source fixes; run GREEN and adjacent tests.
- [x] Independent final review; preserve all private files, apply owned changes and orgm-dot pull bash ourselves.
- [x] Verify native interactive Bash startup, z/zi, FZF widgets/completion, Atuin, Starship, PATH, previews and selected CLI availability. Record limits/optional absent tools, no blanket all-tools claim.

## Evidence / rulings

- Live -ic audit deliberately skips Blesh by upstream design (`BASH_EXECUTION_STRING`); do not misreport those missing functions as native REPL failures. Test actual native startup or real Blesh library separately.
- Do not install optional mise/direnv/fnm/yazi/ftdv/tre merely because legacy functions/completions mention them. Existing selected tools remain the inventory.

## Completion

Focused source/native tests and independent review passed; guarded copy and Bash pull applied, four private local files retained. Actual previews pass after exposing cached declared file package. No full-suite green claim; existing terminal processes require a new terminal. See report for inventory and optional-tool limits.
