# SDD Init Report: hyprchy

status: completed

executive_summary:

- Initialized OpenSpec/SDD project context for `/home/osmarg/Hobby/dotfiles`.
- Created `openspec/config.yaml` because it was missing.
- Confirmed `.atl/skill-registry.md` exists.
- Did not implement `hyprchy.nix` or modify feature code.

artifacts:

- path: `openspec/config.yaml`
  description: SDD project context, strict TDD setting, phase rules, validation commands, and NixOS/dotfiles conventions.
- path: `sdd-init-hyprchy.md`
  description: This initialization report.

project_context:
cwd: `/home/osmarg/Hobby/dotfiles`
git_project: true
environment:
container: podman/distrobox detected
distro: Arch Linux container image
tmux: not detected
nix_shell: not detected
stack: - NixOS flake with `nixpkgs` and `home-manager` inputs on release/nixos 25.11 channels. - Host/profile pattern via `mkHost` and `mkProfile` in `flake.nix`. - Existing Hyprland profile at `nixos/profiles/hyprland.nix` using upstream git Hyprland and hyprpaper flake inputs. - Bash dotfile sync tool `./dot.sh`, configured by `config/dotfiles.json`.
relevant_existing_behavior: - Hyprland profile disables X server display manager and auto-starts Hyprland from fish login on tty1. - Current profile configures portals, GNOME Keyring/PAM, terminal defaults, MIME defaults, Wayland environment variables, and a broad Hyprland/Wayland package set. - Current flake already supports multiple hosts: `orgm`, `ero`, and `lenovo` with per-host hardware and extra modules.

sdd_configuration_created:
strict_tdd: true
default_runner: `nix flake check`
validation_commands: - `nix flake check` - `nix build .#nixosConfigurations.orgm-hyprland.config.system.build.toplevel --no-link` - `nix build .#nixosConfigurations.orgm-hyprchy.config.system.build.toplevel --no-link` - `./dot.sh diff --host orgm`
review_budget_changed_lines: 400
phase_order: init -> explore -> proposal -> spec -> design -> tasks -> apply -> verify -> archive

next_recommended:

- Continue with SDD explore/proposal for change `hyprchy`.
- Before implementation, decide how Walker and Elephant git sources should be represented in `flake.nix` inputs and whether `hyprchy.nix` should import or factor common Hyprland behavior from `hyprland.nix`.
- Preserve existing Hyprland behavior as an explicit compatibility requirement in spec/design.

risks:

- `nix build .#nixosConfigurations.orgm-hyprchy...` will fail until the new profile/configuration is intentionally added during apply; this is expected RED evidence once implementation starts.
- Strict TDD for NixOS configuration is validation-oriented rather than unit-test-oriented; the configured runner is Nix evaluation/build evidence.
- Existing working tree has unrelated untracked files: `progress.md`, `sdd-hyprchy-research.md`, and `sdd-hyprchy-scout.md`.
- Engram memory tools were not available in this subagent toolset, so discoveries were written to repository artifacts only.

skill_resolution: fallback-registry
skill_notes:

- Parent did not inject a `Project Standards (auto-resolved)` block.
- `.atl/skill-registry.md` was present and checked as degraded self-healing for registry availability.
