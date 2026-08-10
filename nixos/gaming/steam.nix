{
  lib,
  pkgs,
  userName ? "osmarg",
  ...
}:

{
  programs.gamemode.enable = true;

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    gamescopeSession.enable = true;
  };

  # TTY6 is the on-demand Steam Gaming Mode console on every Steam-enabled host.
  programs.bash.loginShellInit = lib.mkAfter ''
    if [[ $- == *i* && "$USER" = "${userName}" && "$(tty)" = /dev/tty6 && -z "$DISPLAY" && -z "$WAYLAND_DISPLAY" ]]; then
      exec gamescope -e -- steam -gamepadui
    fi
  '';

  systemd.services."autovt@tty6" = {
    serviceConfig.ExecStart = [
      ""
      "${pkgs.util-linux}/sbin/agetty --autologin ${userName} --noclear %I $TERM"
    ];
  };

  environment.systemPackages = with pkgs; [
    mangohud
    gamescope
    protonup-qt
    steam-run
  ];
}
