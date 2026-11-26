# osmar (hostname orgm): the team account for collaborators' Codeman sessions
# (host "osmar · trabajo" on the hub). See nixos/apps/team-account.nix.
{
  imports = [ ../../apps/team-account.nix ];

  orgm.teamAccount = {
    enable = true;
    folders = [
      "Nextcloud/Proyectos"
      "Code/calc"
    ];
    # The Codeman hub (lenovo-server, osmarg) connects as the team account.
    authorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBMqrA9vPAa8LccB+ZJLqR+T8/rIratiz/Zx/joSqDyE osmarg@radisson-paneles"
    ];
  };
}
