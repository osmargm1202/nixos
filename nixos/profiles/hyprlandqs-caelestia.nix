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

  caelestiaDefaultSettings = builtins.toJSON {
    ai = {
      enableCelestialMode = false;
      enableOllama = true;
    };
    appearance = {
      islands = false;
      pitchBlack = false;
      padding.scale = 0.9744502069185059;
      rounding.scale = 0.7990623201956272;
      spacing.scale = 0.7388705588319907;
      transparency = {
        enabled = true;
        base = 0.9204424872665535;
        layers = 0.30916410229202035;
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
        background = { enabled = true; blur = true; opacity = 0.669305648395722; };
      };
      desktopLyrics.enabled = true;
      visualiser = { enabled = true; autoHide = true; };
    };
    bar = {
      persistent = true;
      position = "bottom";
      entries = [
        { id = "logo";         enabled = true; }
        { id = "workspaces";   enabled = true; }
        { id = "spacer";       enabled = true; }
        { id = "activeWindow"; enabled = true; }
        { id = "dock";         enabled = true; }
        { id = "spacer";       enabled = true; }
        { id = "tray";         enabled = true; }
        { id = "github";       enabled = true; }
        { id = "clock";        enabled = true; }
        { id = "statusIcons";  enabled = true; }
        { id = "power";        enabled = true; }
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
      apps = { explorer = [ "nautilus" "--new-window" ]; terminal = [ "kitty" ]; };
      idle.timeouts = [
        { idleAction = "lock";        timeout = 180; }
        { idleAction = [ "suspend" ]; timeout = 600; }
      ];
    };
    launcher = {
      enableDangerousActions = false;
      maxShown = 7;
      showOnHover = false;
      favouriteApps = [
        "zen-browser" "kitty" "org.gnome.Nautilus"
        "whatsapp" "chatgpt" "org.gnome.Calculator"
        "windows-rdp" "code" "claude" "vesktop"
      ];
      hiddenApps = [ "gmail" ];
      useFuzzy = { actions = true; apps = true; schemes = true; wallpapers = true; };
    };
    services = {
      pipPaused = true;
      arpcEnabled = true;
      arpcSteamAutoDetect = true;
      arpcTargetWindows = [ ];
    };
    session.commands.logout = [ "hyprctl" "dispatch" "hl.dsp.exit()" ];
    sidebar.enabled = true;
    utilities = {
      gameMode.autoEnableRegexes = [ "dota2" "Hollow Knight Silksong" ];
      toasts = { fullscreen = "all"; gameModeChanged = true; transparency = true; };
    };
  };

  caelestiaShell = (inputs.caelestia-shell.packages.${system}.with-cli).overrideAttrs (old: {
    buildInputs = old.buildInputs ++ [ pkgs.qt6.qtmultimedia ];
    postPatch = (old.postPatch or "") + ''
      substituteInPlace modules/launcher/services/Emojis.qml \
        --replace-fail 'function recordUsage(char: string)' 'function recordUsage(charStr: string)' \
        --replace-fail 'frequencies[char] = (frequencies[char] || 0) + 1' 'frequencies[charStr] = (frequencies[charStr] || 0) + 1'
      sed -i 's/\bid: char\b/id: charItem/g; s/\btarget: char\b/target: charItem/g; s/char\.index/charItem.index/g' \
        modules/lock/center/InputField.qml \
        components/PolkitDialog.qml

      # Material's tertiary role is deliberately hue-rotated away from primary
      # (triadic colour design) -- on a blue-derived wallpaper this renders as
      # an unrelated purple/pink for the clock and OS logo, regardless of
      # wallpaper. Bind them to primary instead so they always match the
      # dominant theme colour.
      sed -i 's/Colours\.palette\.m3tertiary/Colours.palette.m3primary/' \
        modules/bar/components/Clock.qml \
        modules/bar/components/OsIcon.qml
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
  ];

  home-manager.users.${userName} = { lib, pkgs, ... }: {
    imports = [
      inputs.caelestia-shell.homeManagerModules.default
    ];

    programs.caelestia = {
      enable = true;
      package = caelestiaShell;
    };

    # Seed shell.json on first install only. Use install (not a symlink or a bare
    # cp) so the file is a real, writable copy — caelestia rewrites it at runtime,
    # and cp from the nix store would inherit read-only 0444 perms.
    home.activation.caelestiaDefaultSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      shell_cfg="$HOME/.config/caelestia/shell.json"
      if [ ! -f "$shell_cfg" ]; then
        $DRY_RUN_CMD install -Dm644 ${pkgs.writeText "caelestia-shell-defaults.json" caelestiaDefaultSettings} "$shell_cfg"
      fi
    '';
  };
}
