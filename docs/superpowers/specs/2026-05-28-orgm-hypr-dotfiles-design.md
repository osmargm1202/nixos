# orgm-hypr dotfiles bootstrap design

`orgm-hypr` should make Osmar's expected dotfiles checkout available on first run by cloning `https://github.com/osmargm1202/dotfiles` into `~/Hobby/dotfiles` only when that directory is missing. Existing directories, `dotfiles.json`, and theme registry entries must be left untouched.

## Decision

Add a small bootstrap step to the current `orgm-hypr` binary startup path. The step checks for `~/Hobby/dotfiles` and runs a guarded `git clone` only when the directory does not exist.

| Topic | Decision |
|-------|----------|
| Target path | `~/Hobby/dotfiles`, resolved from `HOME`. |
| Repository URL | Hardcode `https://github.com/osmargm1202/dotfiles` for the current `orgm-hypr` binary. JSON-driven URL configuration can be evaluated later, but is out of scope for this change. |
| Existing directory behavior | If `~/Hobby/dotfiles` exists, do nothing. Do not overwrite, delete, reset, pull, or validate contents. |
| Existing config behavior | Do not touch existing `config/dotfiles.json`, generated config, or theme registry entries. Bootstrap only ensures the repository directory exists when missing. |
| Failure behavior | If `git clone` fails, report a clear error and exit non-zero for the command that triggered bootstrap. Do not leave partially managed config behind. |
| Scope limit | Design spec only in this commit. No implementation or production code changes. |

## Proposed flow

1. Resolve `HOME`.
2. Build target path: `$HOME/Hobby/dotfiles`.
3. If target path exists, return success without mutation.
4. If target path is missing, ensure parent directory `$HOME/Hobby` exists.
5. Run `git clone https://github.com/osmargm1202/dotfiles $HOME/Hobby/dotfiles`.
6. If clone succeeds, continue normal `orgm-hypr` command flow.
7. If clone fails, return an error that includes the target path and source URL.

## Non-goals

- No overwrite of any existing `~/Hobby/dotfiles` directory.
- No automatic `git pull`, reset, checkout, or migration.
- No edits to `dotfiles.json`.
- No edits to orgm-hypr theme JSON or theme entries.
- No JSON-configurable repository URL in this change.
- No implementation in this commit.

## Testing plan

Write failing tests before implementation.

### Missing directory clones repository

- Arrange a temporary `HOME` with no `Hobby/dotfiles` directory.
- Put a fake `git` executable first in `PATH` that records arguments and simulates successful clone by creating target directory.
- Run an `orgm-hypr` command that enters bootstrap.
- Assert `git clone https://github.com/osmargm1202/dotfiles $HOME/Hobby/dotfiles` was called once.
- Assert normal command behavior continues after bootstrap success.

### Existing directory skips clone and does not overwrite

- Arrange a temporary `HOME` with existing `Hobby/dotfiles` containing sentinel files, including `config/dotfiles.json`.
- Put a fake `git` executable first in `PATH` that fails if invoked.
- Run the same `orgm-hypr` command.
- Assert `git` was not called.
- Assert sentinel files and `config/dotfiles.json` remain byte-for-byte unchanged.

### Git failure reports error

- Arrange a temporary `HOME` with no `Hobby/dotfiles` directory.
- Put a fake `git` executable first in `PATH` that exits non-zero and emits a known message.
- Run the bootstrap-triggering `orgm-hypr` command.
- Assert command exits non-zero.
- Assert error output names the dotfiles URL and target path.
- Assert no `dotfiles.json` or theme registry file was created or modified by bootstrap failure.

## Review checklist

- [x] Design preserves existing directories by skipping clone when target path exists.
- [x] Design does not overwrite or mutate `dotfiles.json`.
- [x] Design does not touch theme registry entries.
- [x] Hardcoded repository URL is explicit and scoped to current binary.
- [x] Future JSON URL support is mentioned only as later consideration, not current scope.
- [x] Testing plan starts with failing tests for clone, skip/no-overwrite, and git failure paths.
- [x] This commit contains design and test planning only; no implementation files are changed.
