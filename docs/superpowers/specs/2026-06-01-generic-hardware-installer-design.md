# Generic Hardware Installer Design

## Goal

Make the generic ORGMOS installer usable across common hardware profiles without burying non-generated NixOS options inside host `hardware-configuration.nix` files.

## Scope

- Add reusable GPU modules for Intel, Radeon/AMD, NVIDIA desktop, and NVIDIA hybrid offload.
- Add reusable kernel modules for Zen and LTS.
- Leave CachyOS kernel documented as pending.
- Update current hosts to import reusable modules instead of duplicating GPU configuration inside generated hardware files.
- Update `install.sh` to ask for GPU and kernel choices.
- For NVIDIA offload, auto-detect Bus IDs with `lspci`, show detected values, and let the user confirm or override them manually.

## Architecture

### GPU modules

Create:

- `nixos/hardware/gpu/intel.nix`
- `nixos/hardware/gpu/radeon.nix`
- `nixos/hardware/gpu/nvidia.nix`
- `nixos/hardware/gpu/nvidia-offload.nix`

`nvidia.nix` contains desktop/discrete NVIDIA defaults. `nvidia-offload.nix` contains shared hybrid PRIME offload defaults, but Bus IDs stay configurable by the importing host or generated flake.

### Kernel modules

Create:

- `nixos/hardware/kernel/zen.nix`
- `nixos/hardware/kernel/lts.nix`

`common.nix` may keep Zen as `mkDefault`, but installer-selected kernel module must override it.

CachyOS kernel remains documented as pending because no CachyOS input/overlay will be added in this change.

### Flake exports

Expose modules through `nixosModules`:

```nix
nixosModules = {
  gpu.intel = ./nixos/hardware/gpu/intel.nix;
  gpu.radeon = ./nixos/hardware/gpu/radeon.nix;
  gpu.nvidia = ./nixos/hardware/gpu/nvidia.nix;
  gpu.nvidia-offload = ./nixos/hardware/gpu/nvidia-offload.nix;

  kernel.zen = ./nixos/hardware/kernel/zen.nix;
  kernel.lts = ./nixos/hardware/kernel/lts.nix;
};
```

### Installer flow

`install.sh` asks:

1. Profile.
2. GPU.
3. Kernel.
4. Hostname.
5. Offload Bus IDs only when GPU is `nvidia-offload`.

For offload:

- Run `lspci -nn` and show `VGA|3D|Display` lines.
- Detect Intel and NVIDIA PCI addresses when possible.
- Convert `00:02.0` to `PCI:0:2:0`.
- Ask user to accept detected Bus IDs or type manual values.
- Validate manual values using basic `PCI:<num>:<num>:<num>` format.

Generated flake uses `extraModules` with selected GPU/kernel modules and optional offload Bus ID override.

## Host migration

- `orgm` imports `gpu/nvidia.nix` and keeps generated hardware focused on filesystems, boot modules, host platform, and CPU microcode.
- `lenovo` imports `gpu/nvidia-offload.nix` and keeps Bus IDs in a local small module or host-specific config.
- Existing host-specific Plymouth/audio modules remain separate.

## Testing

- `bash -n install.sh`.
- `nix flake check` or targeted `nix eval` where available.
- Verify generated flake text for Intel, Radeon, NVIDIA, NVIDIA offload, Zen, and LTS paths.
- Ensure offload Bus ID conversion handles common `lspci` addresses.

## Non-goals

- No CachyOS kernel implementation in this change.
- No full generic username migration yet.
- No removal of all Osmar-specific defaults beyond hardware/kernel modularization.
