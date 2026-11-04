{
  config,
  inputs,
  lib,
  userName,
  ...
}:
# app-login: email one-time-code login in front of nginx apps (repo osmargm1202/app-login).
# Shared ORGM parameters; each host sets its own loginHost and apps, e.g.
#   services.app-login = { enable = true; loginHost = "login.or-gm.com"; apps."x.or-gm.com".name = "X"; };
# Owners have fixed access to every app and are the only ones who see the access panel
# (https://<app>/_auth/admin); everyone else is added and removed there.
# Mail goes through Resend when secrets/shared/resend.yaml (RESEND_API_KEY) exists;
# until then the code is written to the journal (journalctl -u app-login).
let
  cfg = config.services.app-login;
  resendFile = ../../secrets/shared/resend.yaml;
  hasResend = builtins.pathExists resendFile;
in
{
  imports = [
    inputs.sops-nix.nixosModules.sops
    inputs.app-login.nixosModules.default
  ];

  services.app-login = {
    instance = lib.mkDefault "orgm";
    brand.template = lib.mkDefault "orgm";
    mailFrom = lib.mkDefault "ORGM <acceso@orgm.com.do>";
    owners = lib.mkDefault [ "osmargm1202@gmail.com" ];
    settings = {
      # "Remember this device": 30 days without a new code on this browser.
      SSO_TTL = lib.mkDefault "720h";
    };
    environmentFile = lib.mkIf hasResend config.sops.templates."app-login.env".path;
  };

  sops = lib.mkIf (cfg.enable && hasResend) {
    age.keyFile = lib.mkDefault "/home/${userName}/.config/sops/age/keys.txt";
    secrets.RESEND_API_KEY.sopsFile = resendFile;
    templates."app-login.env" = {
      content = ''
        RESEND_API_KEY=${config.sops.placeholder.RESEND_API_KEY}
      '';
      restartUnits = [ "app-login.service" ];
    };
  };
}
