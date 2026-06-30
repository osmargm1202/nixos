# Lightweight NixOS Server Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a standalone lightweight NixOS server profile for `ero` that avoids `nixos/common.nix` and supports a Docker Compose homelab host.

**Architecture:** Create one self-contained `nixos/server.nix` module with tunables at the top for SSH, firewall, fail2ban, Docker, backups, and auto-upgrade. Add a separate `ero-server` flake output that imports only the `ero` hardware config plus `server.nix`, bypassing the existing desktop constructors that force `common.nix`.

**Tech Stack:** NixOS 25.11, Nix flakes, OpenSSH, Docker, Docker Compose, fail2ban, NixOS native firewall, restic-ready backup config, fish, server CLI tools.

---

### Task 1: Add standalone server module

**Files:**

- Create: `nixos/server.nix`

- [ ] **Step 1: Create `nixos/server.nix`**

Create a self-contained NixOS module with top-level variables for SSH port, Pi-hole DNS exposure, fail2ban, firewall ports, Docker pruning, restic backup, and auto-upgrade.

- [ ] **Step 2: Keep server defaults light**

Do not import `nixos/common.nix`, Home Manager, desktops, RDP, KVM, Flatpak, PipeWire, CUPS, Bluetooth, or Plymouth.

- [ ] **Step 3: Include Docker-compatible tooling**

Enable real Docker, Compose, Buildx, lazydocker, ctop, and `dtop` only if the package exists in nixpkgs.

### Task 2: Add flake output

**Files:**

- Modify: `flake.nix`

- [ ] **Step 1: Add `ero-server` under `nixosConfigurations`**

Use `nixpkgs.lib.nixosSystem` directly with modules:

```nix
./nixos/hosts/ero/hardware-configuration.nix
./nixos/server.nix
{ networking.hostName = "ero"; }
```

- [ ] **Step 2: Do not use `mkHost` or `mkProfile`**

Those constructors import `./nixos/common.nix`, which is intentionally excluded from this server profile.

### Task 3: Verify formatting and evaluation

**Files:**

- Verify: `nixos/server.nix`
- Verify: `flake.nix`

- [ ] **Step 1: Format if `nixfmt-rfc-style` is available**

Run from repo root:

```bash
nix fmt
```

Expected: formatting succeeds or local environment lacks Nix.

- [ ] **Step 2: Evaluate/build on a Nix-enabled host**

Run from repo root:

```bash
nix flake check
nixos-rebuild build --flake .#ero-server
```

Expected: evaluation succeeds. If running inside the current Arch distrobox without Nix, document that verification must be run on the NixOS host.
