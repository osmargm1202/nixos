{ config, lib, pkgs, ... }:
let
  aliases = {
    clockwork = "clockwork/orbital";
    wuthering-waves = "wuwa";
    osu-mania = "osumania";
    ninja-gaiden = "ninja_gaiden";
  };
  selected = config.orgm.sddm.qylockTheme;
  runtime = pkgs.callPackage ./qylock-runtime.nix {
    defaultTheme = aliases.${selected} or selected;
    fprintd = config.services.fprintd.package;
    fingerprintEnabled = config.orgm.sway.fingerprint.enable;
  };
  # Preserve the compositor integration (and non-Qt settings), then use the
  # pinned Qt dependency closure required by ALL catalog themes.
  greeterBase = config.services.displayManager.sddm.settings.General.GreeterEnvironment or "";
  greeterEnvironment = lib.concatStringsSep "," (
    lib.optional (greeterBase != "") greeterBase
    ++ lib.mapAttrsToList (name: value: "${name}=${value}") runtime.greeterEnvironment
  );
in
{
  options.orgm.sway.fingerprint.enable = lib.mkEnableOption "parallel fingerprint authentication in the private Qylock PAM policy";
  config = lib.mkIf (config.programs.sway.enable || config.programs.hyprland.enable) {
    assertions = [ {
      assertion = !config.orgm.sway.fingerprint.enable || config.services.fprintd.enable;
      message = "Qylock fingerprint authentication requires services.fprintd.enable.";
    } ];
    environment.systemPackages = [ runtime ];
    # HOME launcher prefers this system metadata over the temporary GC root.
    environment.pathsToLink = [ "/share/orgm-qylock" ];
    security.polkit.enable = true;
    environment.etc."sddm.conf.d/90-orgm-qylock.conf".text = ''
      # Managed by orgm-qylock; changes take effect at the next login.
      [Theme]
      Current=current
      ThemeDir=/var/lib/orgm-qylock/sddm
      [General]
      GreeterEnvironment=${greeterEnvironment}
    '';
    system.activationScripts.orgmQylock = {
      deps = [ "etc" ];
      text = ''
        # Does not restart SDDM, touch the sensor or change user authentication.
        ${runtime}/bin/orgm-qylock-apply init
      '';
    };
  };
}
