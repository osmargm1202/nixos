{ ... }:

{
  # These applications are installed and updated by Flathub.  They keep large
  # emulator closures out of the NixOS system build while remaining available
  # in every configuration that imports this gaming module.
  services.flatpak.packages = [
    # NES, SNES, Nintendo 64, Game Boy, Game Boy Advance, Mega Drive, arcade,
    # and other classic systems through Libretro cores.
    "org.libretro.RetroArch"

    # Nintendo platforms.
    "org.DolphinEmu.dolphin-emu" # GameCube and Wii
    "info.cemu.Cemu" # Wii U
    "io.github.ryubing.Ryujinx" # Nintendo Switch

    # Sony platforms.
    "org.duckstation.DuckStation" # PlayStation
    "org.ppsspp.PPSSPP" # PlayStation Portable
    "net.pcsx2.PCSX2" # PlayStation 2
    "net.rpcs3.RPCS3" # PlayStation 3
    "net.shadps4.shadPS4" # PlayStation 4; upstream compatibility remains early.
  ];
}
