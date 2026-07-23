# NixOS Repository Architecture Design

## Goal

Reorganize the full NixOS repository so every current host and profile uses a clear, reusable module architecture with a thin flake, explicit dependencies, and clean NixOS/Home Manager boundaries.

The migration must initially preserve all existing `nixosConfigurations` names, aliases, behavior, input revisions, and host-specific particulars.

## Scope

This design covers all hosts and profiles, not only `ero-server`:

- Hosts: `orgm`, `lenovo`, `ero`, `jarq`, and generic evaluation hosts.
- Roles: desktop, terminal, and server.
- Desktop sessions: Cinnamon, GNOME, Hyprland, Hyprland/Caelestia, i3, Labwc, MATE, and XFCE.
- Integrated Home Manager configuration for `osmarg` and `jarq`.
- Shared NixOS modules, Home Manager modules, packages, flake inputs, and checks.

Home Manager remains integrated as a NixOS module. This project does not add standalone `homeConfigurations`.

## Research Basis

The comparison used LibrePhoenix commit [`7b11edde495b58a981999e1714aae17d35c7b4f9`](https://github.com/librephoenix/nixos-config/tree/7b11edde495b58a981999e1714aae17d35c7b4f9) and local commit `7256d2b925ff11f227246e9eca7da15fbe06b894`.

Useful LibrePhoenix patterns:

- Uniform host directories.
- Physical separation between NixOS and Home Manager modules.
- Small modules with typed options and conditional configuration.
- Hosts describing intended capabilities rather than implementation details.
- A documented host template.

Patterns that must not be copied:

- Recursive import of every `.nix` file under `modules/system` ([source](https://github.com/librephoenix/nixos-config/blob/7b11edde495b58a981999e1714aae17d35c7b4f9/modules/system/default.nix#L5-L27)).
- Unrestricted host discovery, which exports `hosts/TEMPLATE` as a real configuration ([source](https://github.com/librephoenix/nixos-config/blob/7b11edde495b58a981999e1714aae17d35c7b4f9/flake.nix#L43-L92)).
- Global `systemSettings.*` and `userSettings.*` namespaces.
- Local secrets flake at `/etc/nixos.secrets`.
- Hardcoded users, paths, timezone, state version, kernels, desktop assumptions, and hardware details.
- Phoenix automation, passwordless doas rules, global Syncthing firewall rules, `/etc/hosts` blocklists, and Chaotic/CachyOS/SCX defaults.

## Current Local Findings

Local strengths:

- Imports and outputs are explicit.
- The host/profile matrix supports multiple desktop sessions on the same hardware.
- Hardware is separated from desktop profiles.
- Inputs with ABI constraints and exceptional pins are documented.
- The flake exports packages, formatter, development shell, reusable library functions, and modules.
- The server already has stronger SSH, fail2ban, Tailscale, Docker log rotation, Restic retention design, fstrim, smartd, and Nix cleanup than the reference repository.

Local structural debt:

- `flake.nix` contains five constructors and 40 repeated output declarations.
- `common.nix`, `terminal.nix`, and `server.nix` duplicate users, Nix settings, kernel selection, locale, boot, and CLI tooling.
- Home Manager declarations are distributed through NixOS profiles, `common-dotfiles.nix`, `webapps.nix`, and host files.
- `common-dotfiles.nix`, `common.nix`, `common_hyprland.nix`, `i3.nix`, `server.nix`, and `terminal.nix` each carry multiple responsibilities.
- Modules commonly receive the complete `inputs` attrset instead of named dependencies.
- `mkGeneralHost` references missing `nixos/general.nix`.
- `tests/flake-outputs.bats.sh` appears inconsistent with current `jarq` outputs.

## Chosen Approach

Use incremental explicit composition.

The repository will keep visible imports and an explicit configuration inventory. It will use custom options only for capabilities that are genuinely reusable or configurable. This avoids both the current flake repetition and the reference repository's hidden activation behavior.

Alternatives rejected:

1. A capability API for nearly every module: declarative, but creates a large internal API and additional coupling.
2. A minimal refactor limited to splitting large files: lower effort, but leaves weak host/profile and NixOS/Home Manager boundaries.

## Target Structure

```text
flake.nix
flake.lock
configurations.nix
lib/
  mk-system.nix
hosts/
  orgm/
    default.nix
    hardware-configuration.nix
    hardware.nix
  lenovo/
    default.nix
    hardware-configuration.nix
    hardware.nix
  ero/
    default.nix
    hardware-configuration.nix
  jarq/
    default.nix
    hardware-configuration.nix
  generic/
    default.nix
    hardware-configuration.nix
profiles/
  roles/
    desktop.nix
    terminal.nix
    server.nix
  sessions/
    cinnamon.nix
    gnome.nix
    hyprland.nix
    hyprlandqs-caelestia.nix
    i3.nix
    labwc.nix
    mate.nix
    xfce.nix
modules/
  nixos/
    core/
      default.nix
      nix.nix
      boot.nix
      locale.nix
      users.nix
    hardware/
      gpu/
      kernel/
    services/
      tailscale.nix
      flatpak.nix
      printing.nix
      backups.nix
      containers.nix
    features/
      ai.nix
      gaming.nix
      webapps.nix
  home/
    core/
    desktop/
    apps/
users/
  osmarg/home.nix
  jarq/home.nix
packages/
templates/
  host/
tests/
```

This tree is the target boundary for the migration. Empty directories are not created early, but each listed responsibility moves to its listed location before the corresponding phase is accepted.

## Assembly Model

### `flake.nix`

`flake.nix` owns only:

- Input declarations.
- System-independent package setup needed by outputs.
- Loading `lib/mk-system.nix` and `configurations.nix`.
- Exposing `nixosConfigurations`, packages, formatter, development shell, library functions, and reusable modules.

It must not contain the host/profile matrix or repeated module lists.

### `configurations.nix`

The configuration inventory is explicit data. Each entry identifies:

- Output name.
- Host.
- Role.
- Optional desktop session.
- Primary user.
- Explicit extra modules.

Aliases `orgm`, `lenovo`, and `jarq` remain available for hostname-based `nh os switch`. All current output names remain stable through the structural migration.

No directory scanning determines production outputs. A future host template is never part of `nixosConfigurations`.

### `lib/mk-system.nix`

A single constructor:

1. Resolves the selected host, role, and optional session through explicit registries.
2. Imports core modules once.
3. Imports the host entrypoint, role, session, and explicit extras.
4. Integrates Home Manager once.
5. Passes only required named dependencies and host metadata.
6. Adds assertions for invalid combinations.

The existing `mkHost`, `mkProfile`, `mkGeneralHost`, `mkServerHost`, and `mkMinimalHost` collapse into this constructor. Exported helpers remain as compatibility wrappers through this migration. The `mkGeneralHost` wrapper maps its existing `profile` argument to a desktop session and stops referencing missing `nixos/general.nix`. Removing any helper requires a later, explicitly approved breaking change.

### Hosts

A host entrypoint owns:

- Generated hardware configuration.
- GPU and board selection.
- Kernel override required by that hardware.
- Firmware, audio, display, storage, and boot quirks unique to the machine.
- Safe host defaults.

It must not select personal applications or contain desktop implementation details.

### Roles and Sessions

Roles express operating intent:

- `desktop`: interactive graphical base, audio, polkit, session support, and integrated Home Manager.
- `terminal`: CLI-focused system without a graphical stack.
- `server`: headless services, hardening, storage health, backup hooks, and operational tooling.

Sessions add a desktop environment or window manager to `desktop`. A session never imports host hardware. A non-desktop role cannot select a desktop session.

### NixOS Modules

Modules own one capability. Imports remain explicit.

Custom options use the `orgm.*` namespace, for example:

- `orgm.services.tailscale.enable`
- `orgm.backups.restic.enable`
- `orgm.virtualization.docker.enable`

A module that only needs direct composition does not require an enable option. Options are for reusable policy and host-specific parameters, not a requirement for every file.

### Home Manager

Home Manager remains part of each NixOS build, but its implementation moves to `modules/home` and `users/<name>/home.nix`.

- NixOS modules create users and connect their Home Manager entrypoints.
- Home Manager modules own dotfiles, user applications, desktop user services, and user-level settings.
- NixOS profiles must not directly implement personal Home Manager configuration.
- Host-specific user overrides remain possible through an explicit Home Manager import supplied by the inventory or host metadata.

## Dependency Rules

- `home-manager` follows the primary `nixpkgs` input.
- ABI-sensitive pins remain pinned and documented.
- Structural migration does not update `flake.lock`.
- External NixOS/Home Manager modules are imported by the feature that owns them.
- Modules receive named dependencies instead of the complete `inputs` attrset where practical.
- A module must not import upward into a profile, host, inventory, or flake.
- Hardware data, SSH keys, UUIDs, secrets, timezone, and `stateVersion` are never copied from another host.
- The template contains placeholders or safe generic defaults and is excluded explicitly from outputs.

## Functional Improvements from the Reference Review

These changes are separate from structural migration commits.

### Adopt or Adapt

1. Add size and rate limits to journald, dimensioned above the reference repository's 50 MB limit so useful incident history remains available.
2. Disable the systemd-boot editor on server configurations.
3. Enable `timesyncd` explicitly where server operations depend on reliable time.
4. Remove `@wheel` from server `nix.settings.trusted-users`; separate binary-cache configuration from daemon trust policy.
5. Add declarative secret management using agenix or sops-nix after a separate decision.
6. Activate the existing Restic design only after repository selection, secret provisioning, and a successful restore drill.
7. Enable conservative Docker pruning without `--all` initially.
8. Enable automatic system switching only from a controlled lock revision, without updating inputs during the switch.
9. Add headless libvirt only when a concrete VM requirement exists.
10. Add nix-community cache only after measuring useful cache hits.

### Do Not Import

- Phoenix Git/build automation.
- Passwordless doas rules with environment preservation.
- Global Syncthing firewall ports.
- StevenBlack data materialized in `/etc/hosts`.
- Chaotic/CachyOS/SCX as a default kernel stack.
- Desktop, gaming, Waydroid, printing, automount, LocalSend, or GUI `nix-ld` dependencies into the server role.

## Migration Plan

### Phase 0: Baseline

- Record all current output names and aliases.
- Record `mkGeneralHost` as a broken exported compatibility surface because it references missing `nixos/general.nix`.
- Align output tests with current policy.
- Capture representative configuration evaluations.
- Isolate the work from the existing dirty working tree.

Acceptance: no functional changes and a trustworthy compatibility baseline.

### Phase 1: Thin Flake

- Move constructor logic to `lib/mk-system.nix`.
- Move the output matrix to `configurations.nix`.
- Implement exported constructor helpers as wrappers over the single constructor, including a working `mkGeneralHost` mapping.
- Preserve output names, aliases, module order, and special arguments.

Acceptance: `builtins.attrNames nixosConfigurations` is unchanged and representative derivation paths evaluate.

### Phase 2: Uniform Hosts

- Create one entrypoint per host.
- Move current hardware and tuning without changing values.
- Keep a generic evaluation host separate.
- Add a documented, non-exported host template.

Acceptance: every configuration imports exactly one host entrypoint and retains the same hardware/profile relationship.

### Phase 3: Core, Roles, Sessions, and Capabilities

- Extract shared core from `common.nix`, `terminal.nix`, and `server.nix`.
- Separate role composition from graphical sessions.
- Split optional services and features into focused modules.
- Keep every import explicit.

Acceptance: core settings are declared once, sessions contain no hardware tuning, and role composition remains understandable from imports.

### Phase 4: Home Manager Boundary

- Move Home Manager implementation out of NixOS profiles, `webapps.nix`, and `common-dotfiles.nix`.
- Create user entrypoints and focused Home Manager modules.
- Centralize NixOS/Home Manager integration in the constructor.

Acceptance: NixOS modules only connect Home Manager; personal implementation lives under `modules/home` and `users`.

### Phase 5: Declarative Profiles

- Reduce roles and sessions to composition.
- Retire obsolete bridge modules only after proving no consumers remain.
- Introduce selected `orgm.*` options where they reduce repeated policy.

Acceptance: profiles express intent, modules implement capabilities, and hosts own particulars.

### Phase 6: Inputs, Checks, and Operational Improvements

- Reduce broad `inputs` propagation.
- Add structural and evaluation checks.
- Deliver server hardening, secrets, backups, pruning, and upgrades as separate changes.

Acceptance: input changes affect only consumers, all outputs evaluate, and each operational feature has its own deployment and rollback evidence.

## Validation

### Structural Checks

- Compare evaluated `nixosConfigurations` attribute names against the baseline.
- Ensure templates never appear as outputs.
- Detect nonexistent imports and paths.
- Reject recursive import discovery.
- Query evaluated outputs rather than grep the source text.

### Evaluation Matrix

Each migration commit evaluates:

- Default aliases `orgm`, `lenovo`, and `jarq`.
- At least one configuration for every physical host.
- Server, terminal, and desktop roles.
- Every desktop session at least once.

Before a phase is accepted, all preserved outputs evaluate.

Commands include targeted `nix eval` checks, `nix flake check -L`, `statix`, `deadnix`, and formatting checks. Targeted evaluations run first because the current full `nix flake check --no-build` exceeded a 120-second orchestration timeout.

### Functional Tests

Functional changes follow test-driven development:

- Hardening: boot editor, journald limits, timesyncd, and trusted users.
- Secrets: declaration, owner, mode, and absence of secret material from the Nix store and logs.
- Restic: timer, snapshot, and restoration of a controlled file.
- Docker pruning: timer and conservative flags.
- Automatic updates: controlled revision, no input update during switch, no automatic reboot unless separately approved.

## Deployment and Rollback

1. Implement in a clean worktree because the current tree contains unrelated changes.
2. Use one focused commit per migration phase or operational feature.
3. Run targeted evaluation, full checks, and `nixos-rebuild test --flake .#<host>`.
4. Perform host-specific smoke tests.
5. Deploy with `nh os switch -H <host>` only after test activation succeeds.
6. Roll back to the prior NixOS generation if runtime checks fail.

Structural commits must not change `flake.lock`, service enablement, ports, secrets, or host behavior. Operational changes follow later and remain independently reversible.

## Risks and Mitigations

- **Output breakage:** preserve names first and compare evaluated attribute sets.
- **Hidden module priority changes:** move one boundary at a time and compare evaluated configuration values.
- **Home Manager merge changes:** defer HM separation until system composition is stable, then migrate by user and feature.
- **Overdesigned option API:** add options only for repeated policy or required parameters.
- **Input incompatibility:** retain current pins during structural work and test input changes independently.
- **Template activation:** explicit inventory; never infer production outputs from directories.
- **Dirty tree contamination:** use a dedicated clean worktree and path-scoped commits.
- **Insufficient log retention:** dimension journald limits from observed usage rather than copying 50 MB.
- **Operational data loss:** require backup restore tests before auto-upgrades or aggressive pruning.

## Success Criteria

- The flake is thin and does not contain the configuration matrix.
- One constructor assembles every NixOS system.
- All current output names and aliases remain available during migration.
- Every host has one explicit entrypoint.
- Roles, sessions, hardware, NixOS modules, and Home Manager modules have distinct responsibilities.
- No recursive imports or unrestricted host discovery exist.
- Home Manager remains integrated but personal implementation is separated from NixOS modules.
- Inputs and exceptional pins have visible owners and dependencies.
- All preserved outputs evaluate after every completed phase.
- Server improvements are delivered separately with runtime tests and rollback evidence.
