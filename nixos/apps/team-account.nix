# Team account: a second, unprivileged Unix user that collaborators' Codeman sessions
# run as (the hub's "<host> · trabajo" remote host). It reaches only the shared work
# folders of the owner, through ACLs, so what a collaborator types in a terminal is
# bounded by this account, not by the web UI.
#
#   orgm.teamAccount = { enable = true; folders = [ "Nextcloud/Proyectos" "Code/calc" ]; };
#
# Files either account creates in those folders stay readable and writable by both
# (default ACLs), so the owner's Nextcloud client keeps syncing them.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkEnableOption mkOption types;
  cfg = config.orgm.teamAccount;
  ownerHome = config.users.users.${cfg.owner}.home;
  folders = map (f: "${ownerHome}/${f}") cfg.folders;
  # Every directory between the owner's home and each folder needs traverse (x) only.
  parents = lib.unique (
    lib.concatMap (
      f:
      let
        parts = lib.splitString "/" f;
      in
      lib.genList (i: "${ownerHome}/${lib.concatStringsSep "/" (lib.take i parts)}") (lib.length parts)
    ) cfg.folders
  );
  setfacl = "${pkgs.acl}/bin/setfacl";
in
{
  options.orgm.teamAccount = {
    enable = mkEnableOption "the team (trabajo) account for collaborators' sessions";
    user = mkOption {
      type = types.str;
      default = "trabajo";
    };
    owner = mkOption {
      type = types.str;
      default = "osmarg";
      description = "Whose folders the team works in.";
    };
    folders = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "Nextcloud/Proyectos" ];
      description = "Folders under the owner's home the team account may read and write.";
    };
    authorizedKeys = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "SSH keys allowed to log in as the team account (the Codeman hub).";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.${cfg.user} = {
      isNormalUser = true;
      description = "Equipo (sesiones de colaboradores en Codeman)";
      shell = pkgs.bashInteractive;
      openssh.authorizedKeys.keys = cfg.authorizedKeys;
      # tmux and bun for the remote Codeman sessions; the agent CLIs live in its own
      # ~/.bun (Codeman updates them through bun).
      packages = [
        pkgs.tmux
        pkgs.bun
        pkgs.git
      ];
    };

    # The owner's repos are owned by the owner: let git work in them as the team.
    programs.git.enable = true;
    programs.git.config.safe.directory = folders;

    # Re-applied at boot and on every switch: traverse on the parents, read/write
    # (plus defaults for new files) on the folders, for the team and the owner.
    systemd.services.team-account-acl = {
      description = "ACLs for the team account on the shared folders";
      wantedBy = [ "multi-user.target" ];
      after = [ "local-fs.target" ];
      restartTriggers = [ (builtins.toJSON cfg.folders) ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        set -eu
        ${lib.concatMapStrings (p: ''
          if [ -d ${lib.escapeShellArg p} ]; then ${setfacl} -m u:${cfg.user}:--x ${lib.escapeShellArg p}; fi
        '') parents}
        ${lib.concatMapStrings (f: ''
          if [ -d ${lib.escapeShellArg f} ]; then
            ${setfacl} -R -m u:${cfg.user}:rwX,u:${cfg.owner}:rwX,m::rwX ${lib.escapeShellArg f}
            find ${lib.escapeShellArg f} -type d -exec ${setfacl} -m d:u:${cfg.user}:rwX,d:u:${cfg.owner}:rwX,d:m::rwx {} +
          fi
        '') folders}
      '';
    };
  };
}
