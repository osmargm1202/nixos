# Managed Windows GPU Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans inline. No parallel implementation is needed.

**Goal:** Persist the verified NVIDIA container fixes and make `windows-rdp start`, `stop`, and `connect` work with the managed Compose configuration.

**Architecture:** An opt-in NixOS module publishes a GPU overlay and immutable image build context through Home Manager. Existing Compose files, credentials and VM volumes remain user-owned. The helper reconciles the overlay before starting Windows, while retaining legacy and Lenovo VFIO behavior.

**Tech Stack:** NixOS/Home Manager, Bash, Docker Compose, Python test assertions.

**Spec:** User-approved continuation of the per-host integration described in chat.

## Global Constraints
- Preserve all existing local changes, VM disks, OEM files, passwords and `.env`.
- Enable only ORGM desktop hosts; other hosts explicitly opt in.
- NVIDIA: explicit CDI, libxext6, driver-library/EGL/GBM/Vulkan mounts, persistent GBM_BACKEND=nvidia-drm and GBM_BACKENDS_PATH=/usr/lib/nvidia/gbm.
- Derive store paths from the selected Nix NVIDIA package, not this session's driver revision.
- Keep Lenovo VFIO/render-node profiles and their engine selection unchanged.
- No activation, commits or container operations claimed successful without runtime evidence.

## Review Focus
- Existing user Compose must win over fallback base; storage and credentials must not migrate implicitly.
- Start/stop/connect must preserve failure reporting and readiness checks.
- Missing base or `.env` must fail clearly, before starting a container.
- NVIDIA build context must not include VM storage or rely on symlinked Dockerfiles.
- Non-NVIDIA/disabled/Lenovo profiles must not receive NVIDIA-specific changes.

## Tasks
- [ ] Extend helper tests for managed NVIDIA start, stop, connect, failure, and legacy fallback; run RED.
- [ ] Detect overlays/base files and reconcile Compose on generic starts; run helper suites GREEN.
- [ ] Add NVIDIA image/Compose template and opt-in NixOS module; preserve generic render/software paths.
- [ ] Add vendor-specific Compose behavior tests; run RED then GREEN against actual Compose normalization.
- [ ] Enable ORGM desktops and document migration, other-host opt-in, activation and runtime checks.
- [ ] Run helper/Compose/syntax checks; attempt full Nix validation, report sandbox limitations precisely.
- [ ] Obtain fresh code review and address substantive findings before final status.

## Execution Rulings
- Work in place: `.git` is read-only in this sandbox, so worktree creation/commits are unavailable. Previous unrelated changes stay intact.
- Preserve user's existing `docker-compose.yml` instead of replacing it or writing credentials into Nix Store.
- Source tests can run with fake engine boundaries; actual host Docker/RDP and Nix activation require user-terminal verification.
