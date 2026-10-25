{ config, lib, pkgs, userName, ... }:
let
  cfg = config.orgm.bomba;
  package = import ./bomba/package.nix { inherit pkgs; };
  sshConfig = {
    mode = "ssh";
    host = "100.94.177.77";
    user = "osmarg";
    identity = if cfg.proxy then "/var/lib/bomba/id_ed25519" else "/home/${userName}/.config/bomba/id_ed25519";
    known_hosts = if cfg.proxy then "/var/lib/bomba/known_hosts" else "/home/${userName}/.config/bomba/known_hosts";
  };
  localConfig = {
    mode = "local";
    url = "http://127.0.0.1:8123";
    token_file = cfg.tokenFile;
    switch = cfg.switchEntity;
    countdown = cfg.countdownEntity;
  } // lib.optionalAttrs cfg.proxy { state_dir = "/var/lib/bomba"; };
in
{
  options.orgm.bomba = {
    enable = lib.mkEnableOption "pump commands through the OrgM Home Assistant";
    controller = lib.mkEnableOption "local Home Assistant pump controller";
    proxy = lib.mkEnableOption "private pump socket for the multimedia user";
    localFirst = lib.mkEnableOption "local Home Assistant with OrgM as a backup";
    tokenFile = lib.mkOption {
      type = lib.types.str;
      default = if cfg.proxy then "/var/lib/bomba/ha-token" else "/home/${userName}/.config/bomba/ha-token";
      description = "Private runtime token for this host's Home Assistant; never read into the store.";
    };
    switchEntity = lib.mkOption {
      type = lib.types.str;
      default = "switch.bomba";
    };
    countdownEntity = lib.mkOption {
      type = lib.types.str;
      default = "number.bomba_countdown";
    };
  };
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ package ];
    system.activationScripts.bombaClientWrapper.text = ''
      ${pkgs.python3}/bin/python3 - <<'PY'
      from pathlib import Path
      path = Path("/home/${userName}/.local/bin/bomba")
      marker = "#!/bin/sh\n# ORGM pump client: temporary deployment wrapper\n"
      if path.is_file() and not path.is_symlink() and path.read_text().startswith(marker):
          path.unlink()
      PY
    '';
    environment.etc."bomba/config.json".text = builtins.toJSON (
      if cfg.controller then localConfig else if cfg.proxy then {
        mode = "unix";
        socket = "/run/bomba/control.sock";
      } else sshConfig
    );
    environment.etc."bomba/proxy.json" = lib.mkIf cfg.proxy {
      text = builtins.toJSON (if cfg.localFirst then {
        mode = "failover";
        primary = localConfig;
        fallback = sshConfig;
      } else sshConfig);
    };
    users.groups.bomba-clients = lib.mkIf cfg.proxy {
      members = [ "media" userName ];
    };
    users.users.bomba = lib.mkIf cfg.proxy {
      isSystemUser = true;
      group = "bomba-clients";
      home = "/var/lib/bomba";
    };
    systemd.services.bomba = lib.mkIf cfg.proxy {
      description = "Private pump gateway for the multimedia controls";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        ExecStart = "${package}/bin/bomba --config /etc/bomba/proxy.json serve";
        User = "bomba";
        Group = "bomba-clients";
        StateDirectory = "bomba";
        StateDirectoryMode = "0700";
        RuntimeDirectory = "bomba";
        RuntimeDirectoryMode = "0750";
        UMask = "0007";
        Restart = "on-failure";
        RestartSec = 3;
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
      };
    };
  };
}
