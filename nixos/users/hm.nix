{ pkgs, ... }:
{
  imports = [ ../gaming/emulators.nix ];
  orgm.gaming.emulators = {
    tier = "classic";
    backend = "native";
  };
  programs.steam.enable = true;
  programs.gamemode.enable = true;
  orgm.chromium.enable = true;
  # Keep profiles on disk on a 4 GB machine instead of copying them into RAM.
  home-manager.users.hm.systemd.user = {
    services.psd.Install.WantedBy = pkgs.lib.mkForce [ ];
    timers.psd-resync.Install.WantedBy = pkgs.lib.mkForce [ ];
  };
  # Reproducible native clients; personal authentication remains in hm's HOME.
  environment.systemPackages = [
    pkgs.codex
    pkgs.pi-coding-agent
    pkgs.claude-code
    pkgs.kitty
  ];
  # User choices, independent of the machine and its hardware.
  orgm.artcraft.launcher = {
    version = "0.8.1";
    sha256 = "afc464f56b1728785de1b7c9b2dedc8f7b30e45ae746d3844f1a3e9ad3fe91f4";
  };
  orgm.user = {
    programs = [
      "shell"
      "git"
      "tmux"
      "xterm"
      "orgm"
      "ai"
      "webapps"
      "flatpak"
      "steam"
    ];
    autostart = [ ];
    flatpakPackages = [
      "com.spotify.Client"
      "io.github.flattool.Warehouse"
      "com.github.tchx84.Flatseal"
      {
        appId = "ai.storyteller.cadcraft";
        origin = "cadcraft-origin";
        bundle = "${pkgs.fetchurl {
          url = "https://github.com/storytold/cadcraft/releases/download/v0.13.0/cadcraft-0.13.0-linux-x86_64.flatpak";
          sha256 = "a2d72179c280779303c7d2edebf8d5c2c87bfdf4c5a56924f0edf022766c5a4d";
        }}";
        sha256 = "a2d72179c280779303c7d2edebf8d5c2c87bfdf4c5a56924f0edf022766c5a4d";
      }
    ];
    webapps = [
      "fast" "netflix" "disney-plus" "hbo-max" "kick" "youtube"
      "youtube-kids" "poki" "crunchyroll" "chatgpt" "claude" "twitch"
    ];
  };
}
