# Handoff: caelestia-cli tasks unblocked by `feat/rust-migration-phase2` work

**Date:** 2026-07-10
**For:** agent owning `~/Hobby/caelestia-cli` (fork `osmargm1202/caelestia-cli`)
**From:** session in `~/Hobby/nixos` doing shell-only follow-up
**Status:** shell main is at `f2ba2874` (5 commits pushed to `origin/main`).

## What changed in the shell fork

- `feat(ipc): expose clipboard and emoji launcher modes` (`40fed784`)
  - `modules/Shortcuts.qml` now exposes a shared `openLauncherAction(action)` helper and an `IpcHandler` with target `launcher`, methods `openClipboard()` / `openEmoji()`.
  - Existing global shortcuts `caelestia:clipboard` and `caelestia:emoji` and the new IPC methods both funnel through the helper, preserving the fullscreen guard.
  - Invocation form: `qs -c caelestia ipc call launcher openClipboard` (and `openEmoji`).

- `fix(ai): advertise operational CLI commands` (`2cb57e97`)
  - `modules/sidebar/AiAssistant.qml:817` description trimmed to: `Valid subcommands: shell, toggle, scheme, search, screenshot, record, clipboard, emoji, wallpaper, resizer.`

- `fix(scripts): load qml-lint helpers before first use` (`f2ba2874`)
  - `scripts/qml-lint-conventions.py` had a latent `NameError: name 'Violation' is not defined` at import time. The `Violation` and `ScopeTracker` classes were defined below `check_imports`, which the runner invokes during module load. They are now defined above first use. Add `tests/scripts/test_qml_lint_loads.py` smoke-tests the load.

## What the CLI must implement to unblock Tasks 2 and 4 of `docs/superpowers/plans/2026-07-10-cli-shell-boundary-followup.md`

### 1. Turn `clipboard` and `emoji` into thin IPC clients

- The current Rust files `src/subcommands/clipboard.rs` and `src/subcommands/emoji.rs` are stubs that `bail!` with a "removed in this fork" message.
- Replace the stubs with `caelestia clipboard` / `caelestia emoji` that exec exactly:

  ```bash
  qs -c caelestia ipc call launcher openClipboard
  qs -c caelestia ipc call launcher openEmoji
  ```

- The invoked IPC method names `openClipboard` and `openEmoji` over target `launcher` are part of the frozen contract. Same `SHELL_CMD = ["qs", "-c", "caelestia"]` pattern already used by `subcommands/search.rs` and `subcommands/shell.rs`.
- Failures to exec `qs`, or `qs` exiting non-zero, must propagate as a non-zero CLI exit (the shell does not provide a Fuzzel fallback — that would re-duplicate the picker UI).
- Required CLI tests:
  - argv matches exactly: `["ipc", "call", "launcher", "openClipboard"]` and `["ipc", "call", "launcher", "openEmoji"]`.
  - `openClipboard` is called when `clipboard` is invoked, and `openEmoji` when `emoji` is invoked.
  - non-zero IPC failure propagates as a non-zero CLI exit.

### 2. Add `scheme preview --variant <variant>`

- New Rust subcommand (or extend `scheme` with a `preview` mode) under `src/subcommands/scheme.rs` and `src/cli.rs`.
- Behaviour: compute the material palette for the **current** scheme, flavour and mode, with the supplied `--variant` swapped in. Emit exactly one JSON object to stdout with shape:

  ```json
  {
    "name": "<string>",
    "flavour": "<string>",
    "mode": "<string>",
    "variant": "<requested variant, verbatim>",
    "colours": { /* full palette object as produced by the existing scheme engine */ }
  }
  ```

- Must NOT:
  - write or touch `~/.local/state/caelestia/scheme.json` (byte-identical guarantee);
  - apply theme, generate hyprland fuzzel/css, or otherwise push the result to other config files;
  - run the `WALLPAPER_PATH`/`SCHEME_*`/`THUMBNAIL_PATH` post-hook;
  - send desktop notifications (no `notify-send` call).

- Must: return non-zero exit on failure and emit the diagnostic on stderr; never emit a partial JSON object on stdout.
- Required CLI tests covering:
  - JSON shape validation (jq `.variant == "<v>" and (.colours | type == "object")`).
  - persisted scheme byte-identical before and after (the plan's `before=$(sha256sum …)`; `after` must equal `before`).
  - no subprocess invocation of `dconf`, `notify-send`, the theme hook runner, or wallpapers config writer (assert through whatever mocking/fake-bin strategy this fork uses today).

### 3. Documentation cleanup tied to the IPC/preview work

- README of the CLI no longer presents clipboard/emoji as "use fuzzel" — when the implementation lands, also drop `fuzzel` from the runtime dependency list. `cliphist` may stay because `shell/plugin/src/Caelestia/Services/clipboard.cpp` still spawns `cliphist list` for the in-shell picker.
- Update `docs/superpowers/specs/2026-07-10-rust-migration-design.md` if the deletion of clipboard/emoji picking from the CLI is not yet mentioned, and add a new spec section covering `scheme preview` (or append to the existing design).

### 4. Required delivery surface for the shell to integrate

- A pinned revision on the default branch (`main` or equivalent) of `github:osmargm1202/caelestia-cli` that ships:
  - the IPC-delegating `clipboard` and `emoji`;
  - the `scheme preview --variant` command;
  - the relevant CLI tests.
- Once that revision exists, the shell fork will run `nix flake update caelestia-cli` and dispatch Task 2 (replace `python3 -c` import in `modules/launcher/services/M3Variants.qml` with `caelestia scheme preview --variant …`) and Task 4 (full integration verification) from the plan.

## Files in the shell repo the CLI agent can read without edits

- `docs/superpowers/specs/2026-07-10-cli-shell-boundary-followup-design.md` — the full ownership/freeze statement.
- `docs/superpowers/plans/2026-07-10-cli-shell-boundary-followup.md` — Task 1 through 4 with concrete executable checks for Tasks 2 and 4.
- `modules/Shortcuts.qml` — diff source for the new IPC handler; relevant for matching the helper convention.
- `modules/launcher/services/M3Variants.qml` — current consumer of the preview contract; calls `caelestia scheme preview` byte-for-byte in Task 2.
- `modules/sidebar/AiAssistant.qml:817` — final advertised command list.

## M3Variants exact transition snippet (Task 2)

The shell side will execute the following replacement when both contracts land:

```qml
// modules/launcher/services/M3Variants.qml
function previewVariant(variant: string): void {
    getPreviewColoursProc.output = "";
    getPreviewColoursProc.command = ["caelestia", "scheme", "preview", "--variant", variant];
    getPreviewColoursProc.running = true;
}

Process {
    id: getPreviewColoursProc
    property string output
    stdout: StdioCollector {
        onStreamFinished: getPreviewColoursProc.output = text
    }
    // qmllint disable signal-handler-parameters
    onExited: code => {
        if (code !== 0) {
            console.warn(`M3 variant preview failed with exit code ${code}`);
            return;
        }
        try {
            const preview = JSON.parse(output);
            if (typeof preview !== "object" || preview === null || typeof preview.colours !== "object" || preview.colours === null)
                throw new Error("invalid scheme preview payload");
            Colours.load(output, true);
            Colours.showPreview = true;
        } catch (error) {
            console.warn(`M3 variant preview returned invalid JSON: ${error}`);
        }
    }
}
```

The CLI must satisfy:

- non-zero exit on any failure (no partial stdout);
- valid JSON object: `{ name, flavour, mode, variant, colours }` where `variant == <requested variant verbatim>`.

## Notes for shell integration once both contracts land

- The shell expects deterministic success on:

  ```bash
  qs -c caelestia ipc call launcher openClipboard
  qs -c caelestia ipc call launcher openEmoji
  caelestia clipboard
  caelestia emoji
  caelestia scheme preview --variant vibrant | jq -e '.variant == "vibrant" and (.colours | type == "object")'
  ```

- The persisted `~/.local/state/caelestia/scheme.json` must remain byte-identical after a preview run; verification is already scripted in Task 2 of the shell plan.
- The cliphist runtime dependency stays in the shell because `Caelestia.Services.clipboard` (C++ plugin) uses `cliphist list/decode` directly.

Return the commit hash (or PR URL) of a default-branch revision that ships both contracts; the shell session will pick up Task 2 and Task 4 once available.
