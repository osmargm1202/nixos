{
  config,
  lib,
  pkgs,
  userName ? "osmarg",
  ...
}:
let
  nvidiaGameOffload = lib.attrByPath [ "orgm" "lenovo" "windowsVfio" "enable" ] false config == false
    && lib.attrByPath [ "hardware" "nvidia" "prime" "offload" "enable" ] false config;
  nvidiaOffloadEnv = {
    __NV_PRIME_RENDER_OFFLOAD = "1";
    __NV_PRIME_RENDER_OFFLOAD_PROVIDER = "NVIDIA-G0";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    __VK_LAYER_NV_optimus = "NVIDIA_only";
  };
  gamescopeCommand = if nvidiaGameOffload then "nvidia-game gamescope" else "gamescope";
in

{
  programs.gamemode.enable = true;

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    gamescopeSession.enable = true;
    package = lib.mkIf nvidiaGameOffload (pkgs.steam.override {
      extraEnv = nvidiaOffloadEnv;
    });
  };

  # TTY6 is the on-demand Steam Gaming Mode console on every Steam-enabled host.
  programs.bash.loginShellInit = lib.mkAfter ''
    if [[ $- == *i* && "$USER" = "${userName}" && "$(tty)" = /dev/tty6 && -z "$DISPLAY" && -z "$WAYLAND_DISPLAY" ]]; then
      exec ${gamescopeCommand} -e -- steam -gamepadui
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
