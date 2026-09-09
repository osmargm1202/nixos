{
  stdenv,
  lib,
  fetchFromGitHub,
  cmake,
  pkg-config,
  qt6,
  wayland,
  wayland-scanner,
  libxkbcommon,
  libei,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "hypr-kdeconnect-fix";
  version = "0.1.0-unstable-2026-07-26";

  src = fetchFromGitHub {
    owner = "gfhdhytghd";
    repo = "hypr-kdeconnect-fix";
    rev = "e86a0fb17826cb8ea987665ded7428534e4a1a9d";
    hash = "sha256-VcXxVtlnkPjO6l0ky/n+0qa87Uc3c8hRM0twfgl+AiM=";
  };

  nativeBuildInputs = [
    cmake
    pkg-config
    wayland-scanner
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    qt6.qtbase
    wayland
    libxkbcommon
    libei
  ];

  doCheck = true;

  meta = {
    description = "RemoteDesktop portal bridge for KDE Connect input on Hyprland";
    homepage = "https://github.com/gfhdhytghd/hypr-kdeconnect-fix";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
})
