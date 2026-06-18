{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Emulators for heavier local platforms. Smaller ROM libraries can stay in RomM.
    dolphin-emu # GameCube / Wii
    pcsx2 # PlayStation 2
    rpcs3 # PlayStation 3
  ];

  services.flatpak.packages = [
    "org.yuzu_emu.yuzu"
  ];
}
