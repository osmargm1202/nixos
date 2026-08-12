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
  options.orgm.gaming.gamescopeTty1.enable = lib.mkEnableOption "Gamescope Steam Gaming Mode on tty1";

  config = lib.mkMerge [
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

      environment.systemPackages = with pkgs; [
        mangohud
        gamescope
        protonup-qt
        steam-run
      ];
    }
    (lib.mkIf config.orgm.gaming.gamescopeTty1.enable {
      programs.bash.loginShellInit = lib.mkForce ''
        if [[ $- == *i* && -r "$HOME/.bashrc" ]]; then
          . "$HOME/.bashrc"
        fi
        if [[ $- == *i* && "$USER" = "${userName}" && "$(tty)" = /dev/tty1 && -z "$DISPLAY" && -z "$WAYLAND_DISPLAY" ]]; then
          exec ${gamescopeCommand} -e -- steam -gamepadui
        fi
      '';

      systemd.services = {
        "getty@tty1".serviceConfig.ExecStart = lib.mkForce [
          ""
          "${pkgs.util-linux}/sbin/agetty --autologin ${userName} --noclear %I $TERM"
        ];
        "autovt@tty1".serviceConfig.ExecStart = lib.mkForce [
          ""
          "${pkgs.util-linux}/sbin/agetty --autologin ${userName} --noclear %I $TERM"
        ];
      };
    })
  ];
}
