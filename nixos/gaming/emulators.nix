{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Emulators for heavier local platforms. Smaller ROM libraries can stay in RomM.
    dolphin-emu # GameCube / Wii
    pcsx2 # PlayStation 2
    rpcs3 # PlayStation 3
  ];

  # Flathub is enabled globally in common.nix. Install Yuzu manually when needed:
  # flatpak install flathub org.yuzu_emu.yuzu
}
