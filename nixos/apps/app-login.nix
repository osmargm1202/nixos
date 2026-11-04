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
# Owners have fixed access to every app and can't be removed. Each app has its own list of
# allowed emails, managed in its admin panel (https://<app>/_auth/admin), which also asks for the
# panel user and PANEL_PASSWORD (secrets/shared/app-login.yaml).
# Mail goes through Resend when secrets/shared/resend.yaml (RESEND_API_KEY) exists;
# until then the code is written to the journal (journalctl -u app-login).
let
  cfg = config.services.app-login;
  resendFile = ../../secrets/shared/resend.yaml;
  panelFile = ../../secrets/shared/app-login.yaml;
  hasResend = builtins.pathExists resendFile;
  hasPanel = builtins.pathExists panelFile;
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
    # Temporary panel user; the password lives in sops (PANEL_PASSWORD).
    panel.user = lib.mkIf hasPanel (lib.mkDefault "osmarg");
    environmentFile = lib.mkIf (hasResend || hasPanel) config.sops.templates."app-login.env".path;
  };

  sops = lib.mkIf (cfg.enable && (hasResend || hasPanel)) {
    age.keyFile = lib.mkDefault "/home/${userName}/.config/sops/age/keys.txt";
    secrets.RESEND_API_KEY = lib.mkIf hasResend { sopsFile = resendFile; };
    secrets.PANEL_PASSWORD = lib.mkIf hasPanel { sopsFile = panelFile; };
    templates."app-login.env" = {
      content =
        lib.optionalString hasResend "RESEND_API_KEY=${config.sops.placeholder.RESEND_API_KEY}\n"
        + lib.optionalString hasPanel "PANEL_PASSWORD=${config.sops.placeholder.PANEL_PASSWORD}\n";
      restartUnits = [ "app-login.service" ];
    };
  };
}
