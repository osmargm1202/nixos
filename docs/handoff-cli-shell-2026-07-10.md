# Handoff: caelestia-cli — IPC delegation + scheme preview

**For:** agent on `~/Hobby/caelestia-cli` (`osmargm1202/caelestia-cli`, branch `feat/rust-migration-phase2`).
**Status of shell side:** already shipped and pushed to `osmargm1202/shell` (`f2ba2874`).
**Reason for this handoff:** two contracts need to land in the CLI before the shell can finish Tasks 2 and 4 of `docs/superpowers/plans/2026-07-10-cli-shell-boundary-followup.md`.

## What the shell already has — do not re-implement

- `plugin/src/Caelestia/Services/clipboard.cpp` — `ClipboardCore` (Q_PROPERTY `items`, `reload`, `getSortedItems`, `getImagePath`, `cliphist list/decode`).
- `plugin/src/Caelestia/Services/emojis.cpp` — `EmojisCore` (Q_PROPERTY `items`, source path `assets/emojis.txt`).
- `modules/Shortcuts.qml` now exposes IPC target `launcher` with methods `openClipboard()` and `openEmoji()` (commit `40fed784`).

Pickers, favourites, image previews, filtering — all owned by the shell. No Fuzzel fallback. Do **not** add `clipboard`/`emoji` UI code to the Rust CLI.

## Two changes the CLI must make

### 1. Turn `clipboard` and `emoji` into thin IPC clients

Replace the `bail!("removed in this fork")` stubs in `src/subcommands/clipboard.rs` and `src/subcommands/emoji.rs` with exec calls. Use the same `SHELL_CMD = ["qs", "-c", "caelestia"]` constant already present in `subcommands/search.rs` and `subcommands/shell.rs`.

```rust
const SHELL_CMD: &[&str] = &["qs", "-c", "caelestia"];

pub fn run(_args: ClipboardArgs) -> Result<()> {
    Command::new(SHELL_CMD[0])
        .args(&SHELL_CMD[1..])
        .args(["ipc", "call", "launcher", "openClipboard"])
        .status()
        .context("failed to invoke clipboard IPC")?
        .success()
        .then_some(())
        .ok_or_else(|| anyhow!("clipboard IPC failed"))
}
```

Mirror for `emoji` with `openEmoji`. Propagate non-zero exit. Tests must assert argv exactly `["ipc", "call", "launcher", "openClipboard"]` and `["ipc", "call", "launcher", "openEmoji"]`.

### 2. Add `caelestia scheme preview --variant <variant>`

Subcommand (extend `scheme` in `src/subcommands/scheme.rs` or add a new file). On success, emit exactly one JSON object to stdout:

```json
{
  "name": "<string>",
  "flavour": "<string>",
  "mode": "<string>",
  "variant": "<requested variant, verbatim>",
  "colours": { /* full material palette object */ }
}
```

Hard rules:

- DO NOT write or touch `~/.local/state/caelestia/scheme.json` (test must verify sha256 byte-identity before/after).
- DO NOT apply theme, run `WALLPAPER_PATH` / `SCHEME_*` / `THUMBNAIL_PATH` hooks, run `dconf`, send `notify-send`, or otherwise touch user-visible state.
- DO NOT emit partial JSON. On any failure: non-zero exit, diagnostic on stderr, nothing on stdout.

Test coverage required:

- `jq -e '.variant == "<v>" and (.colours | type == "object")'` passes.
- `scheme.json` is byte-identical before/after.
- `notify-send` / `dconf` / theme hooks are not spawned (use the existing fake-bin / mock strategy of this fork).

## Cleanup after these land

- Drop `fuzzel` from the CLI's runtime dependency list in `README.md` / `default.nix`. `cliphist` stays (the shell's C++ `ClipboardCore` still calls `cliphist list`).
- Update `docs/superpowers/specs/2026-07-10-rust-migration-design.md` to note that `clipboard`/`emoji` are now IPC delegators, and that `scheme preview` exists.

## Delivery

Return the commit hash (or PR URL) on the default branch of `github:osmargm1202/caelestia-cli`. The shell session will then:

1. `nix flake update caelestia-cli` (Task 4 Step 1).
2. Replace the `python3 -c` preview in `modules/launcher/services/M3Variants.qml` with `caelestia scheme preview --variant <v>` (Task 2).
3. Run full integration verification (Task 4 Steps 3–6).

## Reference files in the shell repo (read-only)

- `docs/superpowers/specs/2026-07-10-cli-shell-boundary-followup-design.md` — full contract.
- `docs/superpowers/plans/2026-07-10-cli-shell-boundary-followup.md` — Task 2 and Task 4 have the exact executable assertions.
- `modules/Shortcuts.qml` — IPC handler signature.
- `modules/launcher/services/M3Variants.qml` — eventual consumer of `scheme preview`.
- `modules/sidebar/AiAssistant.qml:817` — final advertised CLI surface.