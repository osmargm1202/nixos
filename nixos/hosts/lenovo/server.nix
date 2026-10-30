{ config, lib, pkgs, userName, ... }:
let
  setBootDefault = pkgs.writeShellApplication {
    name = "lenovo-server-boot-default";
    runtimeInputs = [ pkgs.gnused pkgs.systemd ];
    text = ''
      boot_root="''${SYSTEMD_BOOT_ROOT:-/boot}"
      loader_conf="$boot_root/loader/loader.conf"
      entry="$(sed -n 's/^default //p' "$loader_conf")"
      if [[ "$entry" =~ ^nixos-generation-[0-9]+\.conf$ ]] &&
        [[ -f "$boot_root/loader/entries/$entry" ]] &&
        [[ -z "''${SYSTEMD_BOOT_ROOT:-}" && -d /sys/firmware/efi/efivars ]]; then
        bootctl --esp-path="$boot_root" set-default "$entry"
      fi
    '';
  };
in {
  imports = [
    ./windows-vfio.nix
    ../../tmux
    ../../apps/sops.nix
    ../../apps/nextcloud-server.nix
    ../../apps/orgm-agents.nix
    ../../apps/orgm-automation.nix
  ];

  # Retain headless services and CLI tools without building a desktop session.
  orgm.user.programs = lib.mkForce [
    "shell" "git" "tmux" "development" "personal-development" "syncthing"
    "containers" "orgm" "ai" "sops" "nextcloud" "tailscale" "neovim" "bitwarden-cli"
  ];
  home-manager.users.${userName}.systemd.user.services.syncthing =
    import ../../syncthing/user-service.nix { inherit pkgs; };

  system.nixos.label = "lenovo-server";

  # ORGM agent hub (code.or-gm.com). Only the active hub manages the DNS record;
  # when legion-server takes over, move these two lines there.
  services.orgm-agents = {
    enable = true;
    dns.manage = true;
  };
  systemd.defaultUnit = "multi-user.target";
  # Keep the existing server mode's network access for its deployed services.
  networking.firewall.allowedTCPPorts = [ 80 443 7236 24800 27015 27036 27037 53317 ];
  networking.firewall.allowedUDPPorts = [ 5353 10400 10401 27015 27036 53317 ];
  environment.etc."orgm/desktop-profile".text = "server\n";
  boot.loader.systemd-boot.configurationLimit = 3;
  boot.loader.systemd-boot.extraInstallCommands = "${setBootDefault}/bin/lenovo-server-boot-default";
}
