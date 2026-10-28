{
  config,
  lib,
  pkgs,
  userName,
  ...
}:
{
  imports = [ ./i3.nix ];
  # These broad desktop stacks are optional for a small X11 machine.
  disabledModules = [
    ../../sddm/sddm.nix
    ../../print/printer.nix
  ];

  orgm.i3.lightweight = true;
  orgm.user.programs = [ "i3-lightweight" ];
  orgm.osk.enable = lib.mkForce false;
  orgm.chromium.enable = lib.mkDefault false;
  orgm.remoteDesktop.enable = false;
  orgm.flatpak.remmina.enable = false;
  nixpkgs.overlays = [
    (_: prev: {
      bun = prev.callPackage ../../packages/bun-baseline.nix { bun = prev.bun; };
    })
  ];

  services.displayManager.sddm.enable = lib.mkForce false;
  services.xserver.displayManager.lightdm = {
    enable = true;
    greeters.gtk.enable = true;
  };
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages;
  zramSwap = {
    enable = true;
    algorithm = "lz4";
    memoryPercent = 50;
    priority = 100;
  };
  # Let swap absorb short bursts before killing applications.
  services.earlyoom = {
    freeSwapThreshold = lib.mkForce 10;
    freeSwapKillThreshold = lib.mkForce 5;
  };
  boot.tmp.useTmpfs = false;
  services.fstrim.enable = true;
  services.journald.extraConfig = "SystemMaxUse=128M\nRuntimeMaxUse=32M";
  programs.nh.clean.extraArgs = lib.mkForce "--keep 3 --keep-since 7d";
  boot.loader.grub.configurationLimit = 3;
  services.logind.settings.Login = {
    HandleLidSwitch = lib.mkForce "suspend";
    HandleLidSwitchExternalPower = lib.mkForce "suspend";
    HandleLidSwitchDocked = lib.mkForce "ignore";
  };

  # Build this configuration elsewhere and copy its closure to the laptop.
  # Custom derivations must never quietly compile on a 4 GB target.
  nix.settings = {
    max-jobs = 0;
    cores = 1;
  };
  environment.variables = {
    EDITOR = lib.mkForce (if builtins.elem "neovim" config.orgm.user.programs then "nvim" else "vim");
    VISUAL = lib.mkForce (if builtins.elem "neovim" config.orgm.user.programs then "nvim" else "vim");
  };
  xdg.mime.defaultApplications =
    lib.genAttrs
      [
        "application/x-zerosize"
        "text/x-lua"
        "text/x-python"
        "application/json"
        "application/x-shellscript"
      ]
      (
        _:
        lib.mkOverride 40 [
          (
            if builtins.elem "neovim" config.orgm.user.programs then
              "nvim.desktop"
            else
              "org.xfce.mousepad.desktop"
          )
        ]
      );
  environment.systemPackages = with pkgs; [
    vim
    mousepad
    ristretto
    mupdf
    file-roller
    xterm
    python3
    aichat
  ];
  home-manager.users.${userName} = {
    home.sessionVariables.TERMINAL = "xterm";
    xresources.properties = {
      "orgm.i3.terminal" = "xterm";
      "orgm.i3.alternateTerminal" = "xterm";
      "orgm.i3.statusCommand" = "exec env I3_STATUS_PICOM=0 ~/.local/bin/i3status-localized";
      "orgm.i3.barFont" = "JetBrainsMono Nerd Font 9.5";
      "XTerm*renderFont" = true;
      "XTerm*faceName" = "JetBrainsMono Nerd Font Mono";
      "XTerm*faceSize" = 10;
      "XTerm*saveLines" = 2000;
      "XTerm*selectToClipboard" = true;
      "XTerm*background" = "#1a1b26";
      "XTerm*foreground" = "#c0caf5";
      "XTerm*scrollBar" = false;
      # Permit OSC 52 clipboard writes from SSH/tmux; clipboard reads stay denied.
      "XTerm*disallowedWindowOps" = "GetChecksum,GetIconTitle,GetSelection,GetWinTitle,SetXprop";
      "XTerm*allowWindowOps" = false;
    };
    programs.firefox = {
      enable = true;
      # Keep the system's signed tab bridge/native host in the per-user browser.
      package = config.programs.firefox.finalPackage;
      configPath = ".mozilla/firefox";
      profiles.default = {
        isDefault = true;
        settings = {
          "dom.ipc.processCount" = 2;
          "browser.preferences.defaultPerformanceSettings.enabled" = false;
          "browser.sessionstore.interval" = 60000;
          "browser.tabs.unloadOnLowMemory" = true;
        };
      };
    };
  };
}
