{
  lib,
  stdenv,
  fetchgit,
  cmake,
  ninja,
  pkg-config,
  qt6,
  kdePackages,
  glib,
  fd,
  rsync,
  xdg-utils,
  poppler-utils,
  bat,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "hyprfm";
  version = "0.5.3";

  src = fetchgit {
    url = "https://github.com/soyeb-jim285/hyprfm.git";
    rev = "b08e1987e883ec1d7493bd20e9c9e85834036f1f";
    hash = "sha256-1+7q0ntE0Zf9fqUfXB0+v1doO8vAblKSuUHGJDddqkg=";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    glib
    kdePackages.kwindowsystem
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtsvg
    qt6.qtwayland
  ];

  cmakeFlags = [
    "-DBUILD_TESTS=OFF"
    "-DHYPRFM_ENABLE_PCH=OFF"
  ];

  postFixup = ''
    wrapQtApp "$out/bin/hyprfm" \
      --prefix PATH : ${lib.makeBinPath [ fd rsync xdg-utils poppler-utils bat ]}
  '';

  meta = {
    description = "Keyboard-friendly Qt file manager for Hyprland and Wayland";
    homepage = "https://github.com/soyeb-jim285/hyprfm";
    license = lib.licenses.mit;
    mainProgram = "hyprfm";
    platforms = lib.platforms.linux;
  };
})
