{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.orgm.gaming.emulators;
  classic = [
    "org.libretro.RetroArch"
    "org.DolphinEmu.dolphin-emu"
    "org.duckstation.DuckStation"
    "org.ppsspp.PPSSPP"
    "net.pcsx2.PCSX2"
  ];
  modern = [
    "info.cemu.Cemu"
    "io.github.ryubing.Ryujinx"
    "net.rpcs3.RPCS3"
    "net.shadps4.shadPS4"
  ];
in
{
  options.orgm.gaming.emulators = {
    tier = lib.mkOption {
      type = lib.types.enum [
        "all"
        "classic"
      ];
      default = "all";
      description = "Classic systems through PS2/GameCube/PSP, or the complete emulator catalog.";
    };
    backend = lib.mkOption {
      type = lib.types.enum [
        "flatpak"
        "native"
      ];
      default = "flatpak";
      description = "Install prebuilt Flatpaks or native Nix packages.";
    };
  };
  config = lib.mkMerge [
    (lib.mkIf (cfg.backend == "flatpak") {
      services.flatpak.packages = classic ++ lib.optionals (cfg.tier == "all") modern;
    })
    (lib.mkIf (cfg.backend == "native") {
      # Nixpkgs removed DuckStation at upstream's request. Retain the existing
      # prebuilt Flatpak instead of compiling or substituting another emulator.
      services.flatpak.packages = [ "org.duckstation.DuckStation" ];
      assertions = [
        {
          assertion = cfg.tier == "classic";
          message = "The native emulator catalog currently supports the classic tier only.";
        }
      ];
      environment.systemPackages = with pkgs; [
        (retroarch.withCores (
          cores: with cores; [
            fceumm
            snes9x
            gambatte
            mgba
            genesis-plus-gx
            mupen64plus
            pcsx-rearmed
            fbneo
            stella
            beetle-pce-fast
          ]
        ))
        dolphin-emu
        ppsspp
        pcsx2
      ];
    })
  ];
}
