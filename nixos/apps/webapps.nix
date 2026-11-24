{
  config,
  pkgs,
  lib,
  userName ? "osmarg",
  ...
}:
let
  enabled = builtins.elem "webapps" config.orgm.user.programs;
  selectedIds = config.orgm.user.webapps;
  catalog = import ./webapps.catalog.nix;
  chromium = pkgs.chromium.override { enableWideVine = true; };
  origin = config.orgm.browser.enable or false;
  backend = if origin then config.orgm.browser.package else chromium;
  gnome = config.services.desktopManager.gnome.enable or false;
  sessionSpecific = !origin && userName == "osmarg"
    && builtins.elem (config.networking.hostName or "") [ "x13" "orgm" ];
  nativeWayland = origin || sessionSpecific || config.programs.hyprland.enable;
  urlAppId =
    prefix: url:
    let
      parts = builtins.match "https?://([^/?#]+)(/[^?#]*)?([?#].*)?" url;
      host = builtins.elemAt parts 0;
      path = builtins.elemAt parts 1;
      # Chromium canonicalizes an origin-only URL to "/" before deriving the
      # native-Wayland app ID. Preserve that root slash so desktop IDs match
      # the compositor class used by nwg-dock.
      appName = "${host}_${if path == null then "/" else path}";
    in
    assert parts != null;
    "${prefix}-${lib.replaceStrings [ "/" ] [ "_" ] appName}-Default";
  categoryFor =
    category:
    {
      multimedia = [ "AudioVideo" ];
      gaming = [ "Game" ];
      office = [ "Office" ];
      development = [ "Development" ];
      social = [
        "Network"
        "WebBrowser"
      ];
    }
    .${category};
  apps = lib.concatLists (
    lib.mapAttrsToList (
      category: entries: map (app: app // { categories = categoryFor category; }) entries
    ) catalog
  );
  ids = map (app: app.id) apps;
  unknownIds = lib.filter (id: !(builtins.elem id ids)) selectedIds;
  selectedApps = lib.filter (app: builtins.elem app.id selectedIds) apps;
  duplicates = lib.filter (id: lib.count (other: other == id) selectedIds > 1) (
    lib.unique selectedIds
  );
  valid = builtins.all (
    app:
    if builtins.match "[a-z0-9]+(-[a-z0-9]+)*" app.id == null then
      throw "Invalid Chromium webapp id '${app.id}'"
    else if builtins.match "https?://[^[:space:]]+" app.url == null then
      throw "Invalid Chromium webapp URL '${app.url}' for '${app.id}'"
    else
      true
  ) apps;
  # Validate selected IDs before constructing any attribute set: duplicate IDs
  # must never silently overwrite a launcher or share its credentials directory.
  checkedApps =
    assert unknownIds == [ ];
    assert valid;
    if duplicates != [ ] then
      throw "Duplicate Chromium webapp ids: ${lib.concatStringsSep ", " duplicates}"
    else
      selectedApps;
  webapps = map (
    app:
    let
      identity = "orgm-webapp-${app.id}";
      desktopId = if nativeWayland then urlAppId (if origin then "brave" else "chrome") app.url else identity;
      launcherFlags = [
        "--app=${app.url}"
      ]
      ++ (
        if origin then
          [ "--profile-directory=Default" ]
        else
          [
            "--user-data-dir=/home/${userName}/.local/share/chromium-webapps/${app.id}"
          ]
      )
      ++ lib.optionals (!nativeWayland) [ "--class=${identity}" ]
      ++ lib.optionals (!origin) [ "--disable-sync" ]
      ++ [ "--no-default-browser-check" ]
      # Origin detects the active session at launch, including optional i3.
      ++ lib.optionals (!origin && !sessionSpecific) [
        # Native Wayland keeps Nautilus file transfer inside one protocol.
        # X11 desktops retain the explicit WM_CLASS used by their launchers.
        "--ozone-platform=${if nativeWayland then "wayland" else "x11"}"
      ];
      launcher = pkgs.writeShellScriptBin identity ''
        ${lib.optionalString sessionSpecific ''
          if [[ "''${XDG_SESSION_TYPE:-}" != x11 && -n "''${WAYLAND_DISPLAY:-}" ]]; then
            set -- --ozone-platform=wayland
          else
            set -- --ozone-platform=x11 --class=${identity}
          fi
        ''}
        exec ${lib.getExe backend} ${lib.escapeShellArgs launcherFlags}${lib.optionalString sessionSpecific " \"$@\"" }
      '';
    in
    {
      inherit launcher;
      entry = lib.nameValuePair desktopId {
        inherit (app) name categories;
        icon = "${app.icon}";
        exec = "${launcher}/bin/${identity}";
        comment = "${app.name} in ${if origin then "Brave Origin" else "Chromium"}";
        terminal = false;
        settings = {
          StartupNotify = "true";
        }
        // lib.optionalAttrs (!nativeWayland || origin || sessionSpecific) {
          StartupWMClass = if origin then desktopId else identity;
        };
      };
    }
  ) checkedApps;
  migratePins = origin || sessionSpecific;
  pinMap = lib.listToAttrs (
    (if origin then [
      (lib.nameValuePair "firefox" "brave-origin")
      (lib.nameValuePair "chromium-browser" "brave-origin")
    ] else [
      (lib.nameValuePair "brave-origin" "firefox")
    ])
    ++ lib.concatMap (
      app:
      let
        target = urlAppId (if origin then "brave" else "chrome") app.url;
      in
      map (name: lib.nameValuePair name target) (
        [
          "orgm-webapp-${app.id}"
          (urlAppId (if origin then "chrome" else "brave") app.url)
        ]
        ++ lib.optionals (app.id == "outlook") [
          "brave-outlook.office.com__-Default"
          "chrome-outlook.office.com__-Default"
        ]
      )
    ) checkedApps
  );
in
{
  config = lib.mkIf enabled {
    home-manager.users.${userName} = { config, lib, ... }: {
      home.packages = map (app: app.launcher) webapps;
      xdg.desktopEntries = lib.listToAttrs (map (app: app.entry) webapps);
      home.file = lib.mkIf migratePins (lib.listToAttrs (map (app:
        lib.nameValuePair ".local/share/applications/${app.entry.name}.desktop" {
          source = "${config.home.path}/share/applications/${app.entry.name}.desktop";
        }) webapps));
      home.activation.browserLauncherPins = lib.mkIf migratePins (
        lib.hm.dag.entryAfter [ "linkGeneration" ] ''
          $DRY_RUN_CMD ${pkgs.coreutils}/bin/env PATH=${lib.makeBinPath [ pkgs.glib ]}:$PATH \
            ${lib.optionalString gnome "GSETTINGS_SCHEMA_DIR=${pkgs.gnome-shell}/share/gsettings-schemas/${pkgs.gnome-shell.name}/glib-2.0/schemas"} \
            ${pkgs.python3}/bin/python3 ${./browser-pins.py} \
            ${pkgs.writeText "browser-pin-map.json" (builtins.toJSON pinMap)} ${if origin then "origin" else "chromium"}
        ''
      );
    };
  };
}
