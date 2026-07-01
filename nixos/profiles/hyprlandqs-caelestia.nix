{
  config,
  pkgs,
  lib,
  inputs,
  userName ? "osmarg",
  ...
}:

let
  system = pkgs.stdenv.hostPlatform.system;
  caelestiaShell = (inputs.caelestia-shell.packages.${system}.with-cli).overrideAttrs (old: {
    buildInputs = old.buildInputs ++ [ pkgs.qt6.qtmultimedia ];
    postPatch = (old.postPatch or "") + ''
      substituteInPlace modules/launcher/services/Emojis.qml \
        --replace-fail 'function recordUsage(char: string)' 'function recordUsage(charStr: string)' \
        --replace-fail 'frequencies[char] = (frequencies[char] || 0) + 1' 'frequencies[charStr] = (frequencies[charStr] || 0) + 1'
      sed -i 's/\bid: char\b/id: charItem/g; s/\btarget: char\b/target: charItem/g; s/char\.index/charItem.index/g' \
        modules/lock/center/InputField.qml \
        components/PolkitDialog.qml
    '';
  });
in
{
  imports = [
    ./common_hyprland.nix
  ];

  programs.gpu-screen-recorder.enable = true;

  environment.systemPackages = with pkgs; [
    # Launcher / menus
    rofi

    # Display management
    nwg-displays
    nwg-look

    # Power menu
    wlogout

    # Screen recorder (used by caelestia record)
    gpu-screen-recorder

    # Video wallpapers
    mpvpaper

    # Fonts — hypremoji / emoji support in bar
    noto-fonts-color-emoji
    nerd-fonts.jetbrains-mono
    nerd-fonts.symbols-only
  ];

  home-manager.users.${userName} = {
    imports = [
      inputs.caelestia-shell.homeManagerModules.default
    ];

    programs.caelestia = {
      enable = true;
      package = caelestiaShell;
      settings = {
        ai = {
          enableCelestialMode = false;
          enableOllama = true;
        };
        appearance = {
          islands = false;
          pitchBlack = false;
          padding.scale = 0.974;
          rounding.scale = 0.799;
          spacing.scale = 0.739;
          transparency = {
            enabled = true;
            base = 0.920;
            layers = 0.309;
          };
        };
        background = {
          enabled = true;
          wallpaperEnabled = true;
          videoWallpaperPaused = true;
          videoWallpaperMuteOnMedia = true;
          videoWallpaperPauseOnFullscreen = true;
          desktopClock = {
            enabled = true;
            invertColors = false;
            position = "top-right";
            background = {
              enabled = true;
              blur = true;
              opacity = 0.669;
            };
          };
          desktopLyrics.enabled = true;
          visualiser = {
            enabled = true;
            autoHide = true;
          };
        };
        bar = {
          persistent = true;
          position = "bottom";
          entries = [
            { id = "logo";        enabled = true; }
            { id = "workspaces";  enabled = true; }
            { id = "spacer";      enabled = true; }
            { id = "activeWindow"; enabled = true; }
            { id = "dock";        enabled = true; }
            { id = "spacer";      enabled = true; }
            { id = "tray";        enabled = true; }
            { id = "github";      enabled = true; }
            { id = "clock";       enabled = true; }
            { id = "statusIcons"; enabled = true; }
            { id = "power";       enabled = true; }
          ];
          activeWindow = { compact = false; inverted = false; };
          clock = { background = false; showDate = true; showIcon = true; };
          dock.monitorCenter = true;
          github.background = false;
          popouts = { activeWindow = true; statusIcons = true; tray = true; };
          scrollActions = { volume = true; workspaces = true; };
          status = { showAudio = true; showKbLayout = true; showMicrophone = true; };
          tray = { background = false; compact = false; recolour = false; };
          workspaces = {
            shown = 10;
            activeIndicator = true;
            activeTrail = true;
            occupiedBg = false;
            perMonitorWorkspaces = true;
            showWindows = true;
            showWindowsOnSpecialWorkspaces = true;
            useIcon = true;
          };
        };
        dashboard.showOnHover = true;
        general = {
          showOverFullscreen = true;
          apps = {
            explorer = [ "nautilus" "--new-window" ];
            terminal = [ "kitty" ];
          };
          idle.timeouts = [
            { idleAction = "lock";      timeout = 180; }
            { idleAction = [ "suspend" ]; timeout = 600; }
          ];
        };
        launcher = {
          enableDangerousActions = false;
          maxShown = 7;
          showOnHover = false;
          favouriteApps = [ "app.zen_browser.zen" "kitty" "whatsapp" "chatgpt" ];
          useFuzzy = { actions = true; apps = true; schemes = true; wallpapers = true; };
        };
        services.pipPaused = true;
        sidebar.enabled = true;
        utilities.toasts = {
          fullscreen = "all";
          gameModeChanged = true;
          transparency = true;
        };
      };
    };
  };
}
