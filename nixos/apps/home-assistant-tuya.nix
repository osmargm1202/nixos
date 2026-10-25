{ pkgs, ... }:
{
  services.home-assistant = {
    enable = true;
    package = pkgs.home-assistant.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [ ../hosts/orgm/tuya-znjdq.patch ];
    });
    extraComponents = [ "tuya" ];
    config = {
      default_config = { };
      http.server_host = [ "127.0.0.1" "::1" ];
    };
  };
}
