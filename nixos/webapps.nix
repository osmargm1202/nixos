{
  lib,
  userName ? "osmarg",
  ...
}:
let
  catalog = import ./webapps.catalog.nix;
  categoryFor = category:
    {
      multimedia = [ "AudioVideo" ];
      gaming = [ "Game" ];
      office = [ "Office" ];
      development = [ "Development" ];
      social = [ "Network" "WebBrowser" ];
    }.${category};
  slugFor = name: lib.toLower (lib.replaceStrings [ " " ] [ "-" ] name);
  desktopEntries = lib.flatten (
    lib.mapAttrsToList (
      category: apps:
      map (
        app:
        lib.nameValuePair "orgm-webapp-${slugFor app.name}" {
          name = app.name;
          exec = "/home/${userName}/.local/bin/firefox-open-tab ${app.url}";
          inherit (app) icon;
          comment = "${app.name} in Firefox";
          categories = categoryFor category;
          settings = {
            StartupNotify = "true";
            StartupWMClass = "firefox";
          };
        }
      ) apps
    ) catalog
  );
in
{
  home-manager.users.${userName}.xdg.desktopEntries = lib.listToAttrs desktopEntries;
}
