{
  config,
  pkgs,
  lib,
  userName ? "osmarg",
  ...
}:
let
  catalog = import ./webapps.catalog.nix;
  chromium = pkgs.chromium.override { enableWideVine = true; };
  ozonePlatform = if config.programs.hyprland.enable then "wayland" else "x11";
  categoryFor = category:
    {
      multimedia = [ "AudioVideo" ];
      gaming = [ "Game" ];
      office = [ "Office" ];
      development = [ "Development" ];
      social = [ "Network" "WebBrowser" ];
    }.${category};
  apps = lib.concatLists (lib.mapAttrsToList (
    category: entries: map (app: app // { categories = categoryFor category; }) entries
  ) catalog);
  ids = map (app: app.id) apps;
  duplicates = lib.filter (id: lib.count (other: other == id) ids > 1) (lib.unique ids);
  valid = builtins.all (
    app:
    if builtins.match "[a-z0-9]+(-[a-z0-9]+)*" app.id == null then
      throw "Invalid Chromium webapp id '${app.id}'"
    else if builtins.match "https?://[^[:space:]]+" app.url == null then
      throw "Invalid Chromium webapp URL '${app.url}' for '${app.id}'"
    else
      true
  ) apps;
  # Validate before constructing any attribute set: duplicate IDs must never
  # silently overwrite a launcher or share its credentials directory.
  checkedApps =
    assert valid;
    if duplicates != [ ] then
      throw "Duplicate Chromium webapp ids: ${lib.concatStringsSep ", " duplicates}"
    else
      apps;
  webapps = map (
    app:
    let
      identity = "orgm-webapp-${app.id}";
      launcher = pkgs.writeShellScriptBin identity ''
        exec ${lib.getExe chromium} ${lib.escapeShellArgs [
          "--app=${app.url}"
          "--user-data-dir=/home/${userName}/.local/share/chromium-webapps/${app.id}"
          "--class=${identity}"
          "--disable-sync"
          "--no-default-browser-check"
          # Native Wayland preserves Nautilus file drag-and-drop in Hyprland.
          # X11 profiles retain their compatible XWayland launch path.
          "--ozone-platform=${ozonePlatform}"
        ]}
      '';
    in {
      inherit launcher;
      entry = lib.nameValuePair identity {
        inherit (app) name icon categories;
        exec = "${launcher}/bin/${identity}";
        comment = "${app.name} in Chromium";
        terminal = false;
        settings = {
          StartupNotify = "true";
          StartupWMClass = identity;
        };
      };
    }
  ) checkedApps;
in
{
  home-manager.users.${userName} = {
    home.packages = map (app: app.launcher) webapps;
    xdg.desktopEntries = lib.listToAttrs (map (app: app.entry) webapps);
  };
}
