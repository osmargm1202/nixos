{
  config,
  pkgs,
  lib,
  ...
}:

# Recurring cleanup automation for interactive `nixclean`, systemd-ized.
# Imported by common.nix, terminal.nix and server.nix; every job is guarded so hosts without flatpak/desktop
# caches just skip those steps.
#
# Weekly (root):  nix generations keep-3 + GC (nh clean all), journal 30d
# Monthly (root): nix store optimise, unused flatpaks, old coredumps
# Monthly (user): thumbnails, nix/uv/bun/pnpm/npm caches, trash >30d

{
  # Generations + garbage collection. `nh clean all` covers the system
  # profile plus per-user and home-manager profiles, keeping the last 3
  # generations and collecting garbage afterwards.
  programs.nh = {
    enable = lib.mkDefault true;
    clean = {
      enable = true;
      dates = "weekly";
      # keep-since 30d: los store paths de apps efimeras (`nix run`)
      # sobreviven mas tiempo entre re-descargas.
      extraArgs = "--keep 3 --keep-since 30d";
    };
  };

  systemd.services.clean-weekly = {
    description = "Weekly system cleanup (journal retention)";
    serviceConfig.Type = "oneshot";
    script = ''
      ${pkgs.systemd}/bin/journalctl --vacuum-time=30d
    '';
  };
  systemd.timers.clean-weekly = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
  };

  systemd.services.clean-monthly = {
    description = "Monthly system cleanup (store optimise, flatpak, coredumps)";
    serviceConfig.Type = "oneshot";
    script = ''
      ${config.nix.package}/bin/nix store optimise

      flatpak=/run/current-system/sw/bin/flatpak
      if [ -x "$flatpak" ]; then
        "$flatpak" uninstall --unused --assumeyes --noninteractive || true
      fi

      if [ -d /var/lib/systemd/coredump ]; then
        ${pkgs.findutils}/bin/find /var/lib/systemd/coredump -type f -mtime +30 -delete
      fi
    '';
  };
  systemd.timers.clean-monthly = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "monthly";
      Persistent = true;
      RandomizedDelaySec = "2h";
    };
  };

  # Per-user caches. Defined at the system level so it applies to every
  # user session without involving home-manager.
  systemd.user.services.clean-user-monthly = {
    description = "Monthly user cache cleanup (thumbnails, package manager caches, trash)";
    serviceConfig.Type = "oneshot";
    script = ''
      rm -rf "$HOME/.cache/thumbnails"/*
      rm -rf "$HOME/.cache/nix"
      rm -rf "$HOME/.cache/uv"
      rm -rf "$HOME/.cache/bun" "$HOME/.bun/install/cache"
      rm -rf "$HOME/.cache/pnpm" "$HOME/.local/share/pnpm/store"
      rm -rf "$HOME/.npm/_cacache" "$HOME/.npm/_logs"
      # Only empty trash items older than 30 days, not everything.
      ${pkgs.trash-cli}/bin/trash-empty 30 -f || true
    '';
  };
  systemd.user.timers.clean-user-monthly = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "monthly";
      Persistent = true;
      RandomizedDelaySec = "2h";
    };
  };
}
