# Apply Progress: wallpaper-picker-gtk

## Workload / PR Boundary

- Delivery path: single focused dotfiles slice for GTK4 wallpaper picker as directly assigned.
- Review workload forecast: above 400 lines because this adds a standalone GTK app, README, tests, and launchers; no chained PR path was provided by parent.
- Scope boundary: managed dotfiles only; no `orgm-dot sync`; no backend reimplementation.

## Completed Tasks

- [x] Created managed picker folder under `config/shared/.config/hypr/wallpaper-picker/`.
- [x] Implemented Python GTK4 app using `orgm-wallpaper` backend commands only.
- [x] Added dark/light/auto theme handling with Waybar-Hypr palette, JetBrainsMono Nerd Font, 12px radius, and 2px surface border.
- [x] Added JSON picker loading with old schema support, fallback directory scanning, thumbnail inference, monitor discovery, pagination, status refresh, apply/random actions, and best-effort `warm-page`.
- [x] Added launchers: `hypr-wallpaper-picker`, `hypr-wallpaper-picker-dark`, `hypr-wallpaper-picker-light`.
- [x] Updated `config/dotfiles.json` so individual `.local/bin` launchers are managed.
- [x] Added README documenting usage and backend contract.
- [x] Added lightweight helper test for syntax, JSON helpers, fallback scan, and backend command building.
- [x] Removed `__pycache__` bytecode directories from the worktree and added Python cache ignores to `.gitignore`.
- [x] Integrated completed `.worktrees/wallpaper-picker-gtk` dirty worktree changes into main working tree after confirming main was clean.
- [x] Fixed launcher dependency handling for missing `gi`: system `python3` is used only after GTK4 PyGObject import succeeds; otherwise launchers fall back to transient `nix-shell`/`nix` environment or print clear Arch/NixOS install hints.
- [x] Updated README dependency and troubleshooting notes for `ModuleNotFoundError: No module named 'gi'`.
- [x] Added launcher helper coverage for system-Python success path, theme forwarding, original argument forwarding, and `nix-shell` fallback arguments.

## Files Changed

- `config/shared/.config/hypr/wallpaper-picker/wallpaper_picker.py`
- `config/shared/.config/hypr/wallpaper-picker/README.md`
- `config/shared/.local/bin/hypr-wallpaper-picker`
- `config/shared/.local/bin/hypr-wallpaper-picker-dark`
- `config/shared/.local/bin/hypr-wallpaper-picker-light`
- `config/dotfiles.json`
- `tests/helpers/hypr-wallpaper-picker-python.bats.sh`
- `openspec/changes/wallpaper-picker-gtk/apply-progress.md`
- `.gitignore`
- Removed tracked Python bytecode under `config/shared/.pi/agent/skills/*/__pycache__/`

## TDD Cycle Evidence

| Task | RED | GREEN | TRIANGULATE / REFACTOR | Verification |
| --- | --- | --- | --- | --- |
| Data/helper contract | `bash tests/helpers/hypr-wallpaper-picker-python.bats.sh` failed: missing `wallpaper_picker.py` | Implemented app/helpers; test passed | Fixed GTK imports to use `Gdk`/`Pango` correctly after helper tests | `bash tests/helpers/hypr-wallpaper-picker-python.bats.sh` passed; `python3 -m py_compile ...` passed; `python3 ... --help` passed |
| Launcher dependency fallback | `bash tests/helpers/hypr-wallpaper-picker-python.bats.sh` failed with fake missing-`gi` `python3`: `unexpected direct python execution` / exit 42 | Added robust launcher: import-check system `python3`, then `nix-shell`, then `nix`, else install hints; dark/light delegate through shared launcher with theme env | Kept logic in main launcher to avoid three divergent copies; helper covers theme and arg forwarding | `bash tests/helpers/hypr-wallpaper-picker-python.bats.sh` passed; `bash -n ...` passed |

## Verification Commands

- `bash tests/helpers/hypr-wallpaper-picker-python.bats.sh` → passed
- `python3 config/shared/.config/hypr/wallpaper-picker/wallpaper_picker.py --help | head -40` → passed
- `python3 -m py_compile config/shared/.config/hypr/wallpaper-picker/wallpaper_picker.py` → passed
- `git diff --check` → passed
- `PYTHONDONTWRITEBYTECODE=1 python3 -B - <<'PY' ... py_compile.compile(..., cfile='/tmp/wallpaper_picker.pyc', doraise=True) ... PY` → passed; `/tmp/wallpaper_picker.pyc` removed
- `find . -type d -name '__pycache__' -print` → no output after cleanup
- `git status --short` → captured cleanup state
- Main integration verification: `git status --short`, `git diff --check`, `PYTHONDONTWRITEBYTECODE=1 python3 -B - <<'PY' ... py_compile.compile(..., cfile='/tmp/wallpaper_picker.pyc', doraise=True) ... PY`, `find config/shared/.config/hypr/wallpaper-picker -type d -name '__pycache__' -print`, and changed-file listing → passed/no pycache output.
- `bash tests/helpers/hypr-wallpaper-picker-python.bats.sh` → passed after launcher fallback tests were added.
- `bash -n config/shared/.local/bin/hypr-wallpaper-picker config/shared/.local/bin/hypr-wallpaper-picker-dark config/shared/.local/bin/hypr-wallpaper-picker-light` → passed.
- `python3 -m py_compile config/shared/.config/hypr/wallpaper-picker/wallpaper_picker.py` → passed; generated `__pycache__` removed after verification.
- `git diff --check` → passed.

## Deviations From Design

- User requested location `config/shared/.config/hypr/wallpaper-picker/`; implemented there instead of earlier read-only design suggestion `config/shared/.config/orgm-wallpaper-picker/`.
- Did not run `orgm-dot sync`, per instruction.

## Remaining Tasks

- Optional live GTK smoke test on host with PyGObject/display available.
- Optional bind existing Hyprland/Waybar shortcut to new launcher in separate review slice if desired.
