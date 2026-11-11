{ pkgs, userName, ... }:
{
  # Includes Bitwarden's upstream polkit action; authentication is still required.
  environment.systemPackages = [ pkgs.bitwarden-desktop ];
  home-manager.users.${userName}.xdg.configFile.
    "BraveSoftware/Brave-Origin/NativeMessagingHosts/com.8bit.bitwarden.json".text = builtins.toJSON {
      name = "com.8bit.bitwarden";
      description = "Bitwarden desktop to Brave Origin bridge";
      path = "${pkgs.bitwarden-desktop}/libexec/desktop_proxy";
      type = "stdio";
      # Only the official Chrome Web Store Bitwarden extension may use the host.
      allowed_origins = [ "chrome-extension://nngceckbapebfimnlniiiahkandclblb/" ];
    };
}
