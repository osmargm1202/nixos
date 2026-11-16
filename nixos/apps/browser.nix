{
  config,
  lib,
  pkgs,
  inputs,
  userName,
  ...
}:
let
  cfg = config.orgm.browser;
  native = import ./brave-origin.nix {
    inherit inputs;
    system = pkgs.stdenv.hostPlatform.system;
  };
  browser = pkgs.writeShellApplication {
    name = "orgm-browser";
    runtimeInputs = [
      pkgs.jq
      pkgs.i3
    ];
    text = ''
      export ORGM_BROWSER_EXECUTABLE=${lib.getExe cfg.package}
      export ORGM_BROWSER_ZENITY=${pkgs.zenity}/bin/zenity
    ''
    + builtins.readFile ./browser-launch.sh;
  };
in
{
  options.orgm.browser = {
    enable = lib.mkEnableOption "shared-profile Brave Origin browsing and webapps";
    package = lib.mkOption {
      type = lib.types.package;
      # The same package is used from the primary Wayland desktop and i3/X11.
      default = native;
    };
  };
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      cfg.package
      browser
    ];
    environment.etc."brave/policies/recommended/orgm.json".text = builtins.toJSON {
      RestoreOnStartup = 1;
      DefaultBrowserSettingEnabled = false;
    };
    xdg.mime = {
      enable = true;
      defaultApplications = lib.genAttrs [
        "text/html"
        "application/xhtml+xml"
        "x-scheme-handler/http"
        "x-scheme-handler/https"
      ] (_: [ "brave-origin.desktop" ]);
    };
    home-manager.users.${userName} = { lib, ... }: {
      # Keep user launchers in sync too, including a live session whose system
      # generation still contains the former Wayland-only package.
      home.file = {
        ".local/bin/brave-origin".source = lib.getExe cfg.package;
        ".local/bin/orgm-browser".source = "${browser}/bin/orgm-browser";
        ".local/share/applications/brave-origin.desktop".source =
          "${cfg.package}/share/applications/brave-origin.desktop";
      };
      # Set requested preferences (including Widevine) with private backups; never write a live profile.
      home.activation.originInitialPreferences = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        $DRY_RUN_CMD ${pkgs.python3}/bin/python3 ${./browser-profile.py}
      '';
    };
  };
}
