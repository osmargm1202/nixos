# X13: GNOME on encrypted Btrfs

`x13` is Osmarg's Lenovo X13 Gen 4 (Intel i7-1365U, Iris Xe, 16 GB RAM).
It starts with the shared GNOME profile and Osmarg's applications, without
Nextcloud, a Windows VM or passthrough. Normal GNOME is the first boot choice;
the `server` specialisation provides headless SSH rescue.

## Install and rebuild

The internal WD SN740 (serial `232949803515`) was explicitly authorized for
whole-disk installation. **It has already been partitioned; do not format it
again.** The generated hardware file belongs to this machine only.

From the installer, with the encrypted filesystems mounted under `/mnt`, use
the canonical host rather than the generic interactive installer:

```bash
nixos-install --root /mnt --flake .#x13 --no-root-passwd
nixos-enter --root /mnt -c 'passwd osmarg'
```

The interactive installer's automatic disk preparation uses ext4 and is not
appropriate for this host. After installation, rebuild from a checkout with:

```bash
sudo nixos-rebuild switch --flake .#x13
```

Before first user activation, provision the editable source tree at
`/home/osmarg/Hobby/nixos`, including `dotfiles/apps`, owned by Osmarg. The
inherited `orgmDotBootstrap` expects this path; placing sources only in
`/etc/nixos` does not satisfy it. Initial provisioning can use a source snapshot;
use a proper repository clone there for later version-controlled editing.

After networking and DNS are ready, check `home-manager-osmarg.service` and
`flatpak-managed-install.service`. Flatpak downloads are asynchronous; declared
applications are not necessarily installed yet.

The installed SSH account is `osmarg`; root SSH login is disabled. Installer
connections use disposable known-host storage. Verify the installed host's
SSH fingerprint independently before trusting its new identity; do not clear
unrelated known-host entries or disable host-key verification permanently.

## Headless server rescue

Select the generation's `server` entry in systemd-boot (the menu timeout remains
one second; hold Space at startup to open the menu). Normal keeps GNOME and all
existing applications. Server boots to `multi-user.target` without GNOME, GOA,
display-manager/autologin, X/Xwayland, Steam/gaming sessions or Flatpak installers.
The user's application catalog remains declared; rescue does not uninstall apps.

SSH and NetworkManager remain enabled. Connect as `osmarg` using the existing
credentials and network profile; root SSH stays disabled and sudo still requires
a password. A working network connection/profile is required for SSH access.

**This is operational rescue, not independent root recovery.** It shares the
same LUKS device, Btrfs root and other essential mounts with normal. LUKS still
requires physical unlocking before either mode can reach SSH. A broken root or
initrd can still require the installer.

Only server tolerates an unavailable EFI partition: `/boot` uses `nofail` and
`x-systemd.device-timeout=10s`. Both modes use the observed EFI PARTUUID
`5512d8ef-bc51-4ea9-a3f6-cf575351fa72` with restrictive FAT masks. Normal keeps
`/boot` required, so bootloader failures are not silently ignored.

**Before any rebuild or bootloader repair, ensure the real ESP is mounted.**
Do not write boot files into an ordinary unmounted `/boot` directory:

```bash
sudo mount /boot
findmnt --mountpoint /boot -o TARGET,SOURCE,FSTYPE,OPTIONS
lsblk -o NAME,PARTUUID,FSTYPE,MOUNTPOINTS
```

Proceed only when `/boot` is a mounted `vfat` filesystem whose source partition
has the PARTUUID above. If mounting fails or the identity differs, stop and
repair the mount/device first; do not rebuild against the empty directory.

Verify both evaluated boot configurations (including complete derivations) with
`python3 tests/x13-server.test.py`. Building/deploying and a real rescue boot
remain separate acceptance steps.

## What is configured

| Area | Policy |
| --- | --- |
| Storage | 1 GiB FAT EFI; remaining SSD LUKS2 with Btrfs |
| Subvolumes | `@`, `@home`, `@nix`, `@log`, `@snapshots` |
| Mount policy | Zstd compression, noatime; EFI permissions restricted |
| Memory | Zram; disk swap and hibernation not configured |
| Desktop | GNOME, Nautilus, native GNOME utilities, Firefox and Kitty |
| Accounts | GNOME Online Accounts; no Nextcloud client/autostart |
| Extensions | Shared GNOME extension packages installed for Osmarg only |
| Games | Steam inside GNOME; existing Flatpak emulator catalog |
| Applications | Existing Osmarg Flatpaks, integration services, printing and AI |
| Hardware | Stock NixOS kernel, early i915, Intel microcode, SOF firmware |

User extension packaging does not enable a new extension selection. The final
extension list, personal shortcuts and touch-oriented Quickshell/Hyprland/Sway
experiment remain separate decisions. Modern emulators may exceed this GPU's
performance; installation is not a performance guarantee.

## Private provisioning and credential changes

No password or hash is stored in this configuration. Change the temporary
account password with `passwd`. Change the LUKS password separately with:

```bash
sudo cryptsetup luksChangeKey /dev/disk/by-uuid/dde6b70b-af6f-4eba-8cd0-8825ddcb5968
```

The inherited SOPS/AI integration needs an authorized age identity privately
provisioned at `/home/osmarg/.config/sops/age/keys.txt` (directory mode 0700,
file mode 0600, owned by Osmarg). This host does not use a Nextcloud recovery
path. Installing AI tools does not configure their authentication.

## Verification

Run `python3 tests/x13.test.py` to evaluate the host contract, then build
`nix build .#nixosConfigurations.x13.config.system.build.toplevel`.

After first boot, verify LUKS unlocking, Wi-Fi, audio/microphone, camera capture,
touch, suspend/resume, printer discovery, Firefox, Flatpak installation and
Steam. USB/input enumeration alone does not prove these features work.
