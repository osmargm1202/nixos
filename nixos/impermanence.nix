# Persistence policy for hosts with tmpfs root (see hosts/<host>/hardware-configuration.nix).
# Requires fileSystems."/persist" with neededForBoot = true on the host.
# /home is NOT listed here — it lives on its own real partition on every host
# and is never wiped, so it needs no bind mounts.
{
  environment.persistence."/persist" = {
    hideMounts = true;

    directories = [
      "/etc/NetworkManager/system-connections"
      "/var/lib/bluetooth"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
      "/var/log"
    ];

    files = [
      "/etc/machine-id"
    ];
  };
}
