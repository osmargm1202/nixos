{
  inputs,
  pkgs,
  lib,
  userName ? "osmarg",
  profileName ? null,
  ...
}:

let
  zenBrowser = pkgs.callPackage ./packages/zen-browser.nix {
    zenBrowserFlakeSrc = inputs.zen-browser-flake;
  };
  psd = pkgs.callPackage ./packages/psd-zen.nix { };
in
{
  environment.systemPackages = [
    zenBrowser
    psd
  ];

  xdg.mime.defaultApplications = lib.mkIf (profileName != "i3") {
    "text/html" = [ "zen-browser.desktop" ];
    "application/xhtml+xml" = [ "zen-browser.desktop" ];
    "x-scheme-handler/http" = [ "zen-browser.desktop" ];
    "x-scheme-handler/https" = [ "zen-browser.desktop" ];
    "x-scheme-handler/chrome" = [ "zen-browser.desktop" ];
  };

  home-manager.users.${userName} =
    { lib, pkgs, ... }:
    {
      xdg.configFile."psd/psd.conf".text = ''
        BROWSERS=(zen chromium)
      '';

      systemd.user.services.psd = {
        Unit = {
          Description = "Profile-sync-daemon";
          Wants = [ "psd-resync.service" ];
          RequiresMountsFor = [ "/home/" ];
        };
        Service = {
          Type = "oneshot";
          RemainAfterExit = true;
          Environment = "PATH=${
            lib.makeBinPath [
              pkgs.rsync
              pkgs.gnugrep
              pkgs.gawk
              pkgs.coreutils
              pkgs.util-linux
              pkgs.procps
              pkgs.psmisc
            ]
          }";
          ExecStart = "${psd}/bin/profile-sync-daemon startup";
          ExecStop = "${psd}/bin/profile-sync-daemon unsync";
          TimeoutStopSec = 60;
        };
        Install.WantedBy = [ "default.target" ];
      };

      systemd.user.services.psd-resync = {
        Unit = {
          Description = "Timed resync";
          After = [ "psd.service" ];
          BindsTo = [ "psd.service" ];
        };
        Service = {
          Type = "oneshot";
          Environment = "PATH=${
            lib.makeBinPath [
              pkgs.rsync
              pkgs.gnugrep
              pkgs.gawk
              pkgs.coreutils
              pkgs.util-linux
              pkgs.procps
              pkgs.psmisc
            ]
          }";
          ExecStart = "${psd}/bin/profile-sync-daemon resync";
        };
      };

      systemd.user.timers.psd-resync = {
        Unit.Description = "Timer for profile-sync-daemon - 1Hour";
        Unit.BindsTo = [ "psd.service" ];
        Timer.OnUnitActiveSec = "1h";
        Install.WantedBy = [ "timers.target" ];
      };
    };
}
