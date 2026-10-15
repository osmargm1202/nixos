{ pkgs, ... }:
let
  # Local recovery only, NOT an independent/external backup. Btrfs snapshots
  # are non-recursive: the separate Nix, log and Windows subvolumes stay out.
  policy = {
    FSTYPE = "btrfs";
    ALLOW_USERS = [ ];
    ALLOW_GROUPS = [ ];
    SYNC_ACL = false;
    TIMELINE_CREATE = true;
    TIMELINE_CLEANUP = true;
    TIMELINE_LIMIT_HOURLY = 0;
    TIMELINE_LIMIT_DAILY = 7;
    TIMELINE_LIMIT_WEEKLY = 0;
    TIMELINE_LIMIT_MONTHLY = 0;
    TIMELINE_LIMIT_QUARTERLY = 0;
    TIMELINE_LIMIT_YEARLY = 0;
    # Explicit manual snapshots may opt into --cleanup-algorithm number.
    NUMBER_CLEANUP = true;
    NUMBER_LIMIT = 3;
    NUMBER_LIMIT_IMPORTANT = 0;
  };
  prepared = {
    requires = [ "envy-prepare-snapshots.service" ];
    after = [ "envy-prepare-snapshots.service" ];
  };
in
{
  services.snapper = {
    snapshotRootOnBoot = false;
    snapshotInterval = "daily";
    persistentTimer = true;
    cleanupInterval = "1d";
    configs = {
      root = policy // { SUBVOLUME = "/"; };
      home = policy // { SUBVOLUME = "/home"; };
    };
  };

  # The pinned NixOS Snapper module creates configs/timers, not .snapshots.
  # Require successful validation/preparation even for a DBus-triggered daemon.
  systemd.services = {
    envy-prepare-snapshots = {
      description = "Prepare root-only local Btrfs snapshot subvolumes";
      wantedBy = [ "multi-user.target" ];
      unitConfig.RequiresMountsFor = [ "/" "/home" ];
      path = [ pkgs.btrfs-progs pkgs.coreutils pkgs.util-linux ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        Group = "root";
        RemainAfterExit = true;
        UMask = "0077";
      };
      script = ''
        exec ${pkgs.bash}/bin/bash ${./prepare-snapshots.sh} / /home
      '';
    };
    snapperd = prepared;
    snapper-timeline = prepared;
    snapper-cleanup = prepared;
  };
}
