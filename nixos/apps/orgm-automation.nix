{
  config,
  inputs,
  lib,
  userName,
  ...
}:
{
  imports = [ inputs.orgm-automation.nixosModules.default ];
  services.orgm-automation = {
    # Development runs Compose manually; enable this only for formal promotion.
    enable = false;
    proxy.enable = true;
    user = userName;
    uid = 1000;
    gid = 1000;
    projectDirectory = "/home/${userName}/Code/orgm-automation";
    stateDirectory = "/home/${userName}/Code/orgm-automation/data";
    domain = "automation.or-gm.com";
    cloudflareTokenFile = "/home/${userName}/Code/orgm-automation/data/secrets/cloudflare.token";
  };

  # Behind the host's emailed-code login (app-login), with its own list of allowed emails
  # (admin panel: https://automation.or-gm.com/_auth/admin). localhost:3080 skips it.
  services.app-login.apps = lib.mkIf config.services.app-login.enable {
    ${config.services.orgm-automation.domain} = {
      name = "ORGM Automation";
      sessionTtlHours = 720;
    };
  };
}
