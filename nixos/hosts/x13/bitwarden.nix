{ config, lib, pkgs, userName, ... }:
let
  manifest = {
    name = "com.8bit.bitwarden";
    description = "Bitwarden desktop bridge";
    path = "${pkgs.bitwarden-desktop}/libexec/desktop_proxy";
    type = "stdio";
  };
in
{
  # Includes Bitwarden's upstream polkit action; authentication is still required.
  environment.systemPackages = [ pkgs.bitwarden-desktop ];
  programs.firefox.nativeMessagingHosts.packages = [
    (pkgs.writeTextDir "lib/mozilla/native-messaging-hosts/com.8bit.bitwarden.json"
      (builtins.toJSON (manifest // {
        allowed_extensions = [ "{446900e4-71c2-419f-a6a7-df9c091e268b}" ];
      })))
  ];
  home-manager.users.${userName}.xdg.configFile.
    "BraveSoftware/Brave-Origin/NativeMessagingHosts/com.8bit.bitwarden.json" =
    lib.mkIf config.orgm.browser.enable {
      text = builtins.toJSON (manifest // {
        allowed_origins = [ "chrome-extension://nngceckbapebfimnlniiiahkandclblb/" ];
      });
    };
}
