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

      "/var/lib/flatpak"
      "/etc/cups"

      "/var/lib/containers"
      "/var/lib/NetworkManager"
      "/var/lib/sunshine" # holds Moonlight pairing state + TLS key — treat as sensitive
      "/var/lib/fwupd"
      "/var/lib/smartmontools"
      "/var/lib/systemd/timers"
      "/var/lib/sddm"

      # Whole dir, not individual key files — covers host keys, moduli,
      # sshd_config.d drop-ins, authorized_keys, whatever openssh adds later.
      # sensitive: private key material.
      "/etc/ssh"

      # Pre-declared for services not installed yet — harmless, impermanence
      # mkdir -p's these on activation; they stay empty until actually used.
      "/var/lib/acme" # Let's Encrypt certs — sensitive, avoid reissue rate-limits
      "/var/lib/postgresql"
      "/var/lib/mysql"
      "/var/lib/libvirt"
      "/var/lib/tailscale"
      "/etc/wireguard" # sensitive: VPN private keys
      "/var/lib/nextcloud"
      "/var/lib/jellyfin"
      "/var/lib/plex"
      "/var/lib/nginx"
      "/var/lib/redis"
      "/var/lib/grafana"
      "/var/lib/samba"
      "/var/lib/syncthing"
    ];

    files = [
      "/etc/machine-id"
      # users.mutableUsers is on (default) and no hashedPassword/initialPassword
      # is declared in Nix — password only ever set imperatively via `passwd`.
      # Without persisting these, tmpfs root wipes /etc/shadow every boot and
      # locks everyone out (see wiki.nixos.org/wiki/Impermanence warning).
      "/etc/passwd"
      "/etc/shadow"
      "/etc/group"
      "/etc/subuid"
      "/etc/subgid"
    ];
  };
}
