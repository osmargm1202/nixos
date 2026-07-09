{ pkgs, ... }:

let
  # Emuladores efimeros: closures de GBs que no vale la pena tener
  # instalados. Se lanzan con `nix run` (cache binario, mismo nixpkgs
  # del sistema via registry pin) desde el launcher o el alias fish.
  mkEphemeralEmulator =
    {
      name,
      desktopName,
      comment,
    }:
    pkgs.makeDesktopItem {
      name = "${name}-ephemeral";
      inherit desktopName comment;
      # `#` es caracter reservado en Exec — va entre comillas
      exec = ''nix run "nixpkgs#${name}"'';
      icon = "applications-games";
      terminal = false;
      categories = [ "Game" ];
    };
in
{
  environment.systemPackages = [
    # Emulators for heavier local platforms. Smaller ROM libraries can stay in RomM.
    (mkEphemeralEmulator {
      name = "dolphin-emu";
      desktopName = "Dolphin (GameCube/Wii)";
      comment = "Emulador GameCube/Wii — descarga efimera al lanzar";
    })
    (mkEphemeralEmulator {
      name = "pcsx2";
      desktopName = "PCSX2 (PlayStation 2)";
      comment = "Emulador PS2 — descarga efimera al lanzar";
    })
    (mkEphemeralEmulator {
      name = "rpcs3";
      desktopName = "RPCS3 (PlayStation 3)";
      comment = "Emulador PS3 — descarga efimera al lanzar";
    })
  ];

  services.flatpak.packages = [
    "org.yuzu_emu.yuzu"
  ];
}
