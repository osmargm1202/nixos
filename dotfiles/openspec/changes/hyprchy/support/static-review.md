# Hyprchy Static Review

Scope: uncommitted hyprchy SDD implementation. Static/lightweight only; no real builds and no `nix flake check` run.

## Findings

### Blocker — review workload exceeds approved slice size

- Evidence: `git diff --stat` reports 13 tracked files and 1107 inserted lines, plus untracked Walker/Elephant config and scripts. `openspec/changes/hyprchy/tasks.md` forecasts "Likely over 400 changed lines" and recommends chained slices.
- Risk: flake/profile work, launcher migration, services, scripts, and OpenSpec artifacts are mixed in one review, increasing regression risk.
- Recommended fix: split before final review/merge: (1) flake + `hyprchy.nix`, (2) Walker/Elephant config/startup, (3) launcher migration, (4) OpenSpec artifacts.

### Major — shared Hyprland dotfiles make Hyprchy startup global

- Evidence: `config/shared/.config/hypr/lua/autostart.lua:18` starts `~/.local/bin/hyprchy-session-start`; `config/shared/.config/hypr/lua/programs.lua:4` changes the shared menu to `hypr-launcher`.
- Risk: this affects existing Hyprland sessions, not only the new `hyprchy` NixOS profile. If Walker exists from another source, existing Hyprland will start Elephant/Walker too.
- Recommended fix: gate startup on an explicit env/profile marker, or move Hyprchy-specific autostart/program changes into a separate Hypr config path/profile.

### Major — `mkProfile` generic hardware behavior changed for all generic outputs

- Evidence: `flake.nix:56` adds `defaultHardware = ./nixos/hosts/orgm/hardware-configuration.nix`; `flake.nix:81-84` uses it for every generic profile (`gnome`, `hyprland`, `niri`, etc.).
- Risk: generic outputs are now silently evaluated with orgm hardware, which can hide host assumptions or change unrelated profile evaluation behavior.
- Recommended fix: either keep this in a dedicated flake-check module/minimal test hardware, or document/accept that all generic profiles are orgm-backed.

### Major — launcher migration is incomplete relative to the spec/tasks

- Evidence: `openspec/changes/hyprchy/spec.md` REQ-5 says common launcher actions should use Walker/wrapper; `tasks.md` Slice 3 calls out Waybar, keybindings, helper scripts, and help text. Static grep still finds Hyprland/Waybar fuzzel entry points, e.g. `config/shared/.config/waybar-hypr/config:35`, `:251`, `config/shared/.config/hypr/lua/keybindings.lua:24-29,38`, and `config/shared/.local/bin/hypr-keybindings-help:25`.
- Risk: `SUPER+SPACE` uses the wrapper, but many visible launcher/menu actions still use fuzzel and help text is stale.
- Recommended fix: either defer Slice 3 explicitly and mark it incomplete, or update Waybar/keybindings/help/scripts to use Walker-aware wrappers where safe.

### Note — Walker/Elephant config is duplicated in NixOS and dotfiles

- Evidence: `nixos/profiles/hyprchy.nix:21-63` defines `programs.walker.config` and Elephant providers; `config/shared/.config/walker/config.toml:4-46` and `config/shared/.config/elephant/elephant.toml:4` also define runtime config.
- Risk: two sources of truth can diverge; user config may override module-generated config depending on Walker lookup precedence.
- Recommended fix: choose one owner for runtime config, or document precedence and keep the Nix module limited to installation/service wiring.

### Note — conservative provider requirement is partially stretched

- Evidence: `nixos/profiles/hyprchy.nix:52-60` enables `clipboard` and `windows` Elephant providers, while `spec.md` REQ-6 says these are optional only after validation.
- Risk: not necessarily wrong, but it broadens the first runtime surface before manual smoke/CPU validation.
- Recommended fix: keep only desktopapplications/providerlist/runner/calc/websearch/menus for the first switch, then add clipboard/windows after validation.

### Correct / verified static checks

- `git diff --check` passed for changed tracked files excluding lockfile.
- `config/dotfiles.json` parses as JSON.
- Walker and Elephant TOML files parse with Python `tomllib`.
- `hypr-launcher` and `hyprchy-session-start` pass `bash -n` and are executable.
- `config/dotfiles.json:21` and `:46` register `.config/elephant` and `.config/walker`.
- `flake.lock` shows `walker.inputs.elephant` follows the root `elephant` input, matching the intended pin relationship.

## Final recommendation

Do not run final builds yet if the user wants them reserved for the final step. Before that, reduce the review surface and resolve the shared-Hyprland startup scope issue; then run the planned final `nix flake check`/focused builds and manual Walker smoke test.
