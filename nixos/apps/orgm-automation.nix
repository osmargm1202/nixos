{ inputs, userName, ... }:
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
}
