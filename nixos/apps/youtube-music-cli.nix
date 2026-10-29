{ config, lib, pkgs, ... }:
{
  options.orgm.youtubeMusicCli.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Install YouTube Music CLI and its playback tools.";
  };
  config = lib.mkIf config.orgm.youtubeMusicCli.enable {
    environment.systemPackages = [
      (pkgs.callPackage ../packages/youtube-music-cli.nix { })
      pkgs.yt-dlp
      pkgs.mpv
    ];
  };
}
