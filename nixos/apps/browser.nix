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
    runtimeInputs = [ pkgs.jq ];
    text = ''
      case "''${1:-}" in
        --focus|--restore-or-focus)
          if [[ "''${XDG_CURRENT_DESKTOP:-}" == *Hyprland* ]]; then
            address="$(hyprctl -j clients | jq -r '[.[] | select(.class == "brave-origin")] | sort_by(.focusHistoryID) | .[0].address // empty')"
            if [[ -n "$address" ]]; then
              exec hyprctl dispatch "hl.dsp.focus({ window = \"address:$address\" })"
            fi
          fi
          shift ;;
        --new) shift ;;
        --new-tab) shift ;;
      esac
      if [[ "''${1:-}" == --prompt ]]; then
        shift
        if [[ "''${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]]; then
          url="$(${pkgs.zenity}/bin/zenity --entry --title='Abrir web' --text='Dirección o búsqueda')" || exit 0
        else
          url="$("$HOME/.local/bin/orgm-rofi" -dmenu -i -p 'Abrir web')" || exit 0
        fi
        [[ -n "$url" ]] || exit 0
        set -- "$url" "$@"
      fi
      exec ${lib.getExe cfg.package} "$@"
    '';
  };
in
{
  options.orgm.browser = {
    enable = lib.mkEnableOption "shared-profile Brave Origin browsing and webapps";
    package = lib.mkOption {
      type = lib.types.package;
      default = native.override { commandLineArgs = "--ozone-platform=wayland"; };
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
      # Set two requested preferences with private backups; never write a live profile.
      home.activation.originInitialPreferences = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        $DRY_RUN_CMD ${pkgs.python3}/bin/python3 ${./browser-profile.py}
      '';
    };
  };
}
