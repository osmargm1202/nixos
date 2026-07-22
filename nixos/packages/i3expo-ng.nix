{
  lib,
  fetchFromGitHub,
  libX11,
  python3Packages,
}:

python3Packages.buildPythonApplication {
  pname = "i3expo-ng";
  version = "0-unstable-2023-01-24";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "morrolinux";
    repo = "i3expo-ng";
    rev = "2c273b0ec8d9d0b75dca80744574bffeb9330a28";
    hash = "sha256-I8bQWIv0zbRJmwZytYapU7mIet4ugULCla7kK4Y5ErA=";
  };

  patches = [ ./i3expo-ng-ready.patch ];

  build-system = [ python3Packages.setuptools ];
  buildInputs = [ libX11 ];
  dependencies = with python3Packages; [
    pygame
    i3ipc
    pillow
    xdg
    pyxdg
  ];

  doCheck = false;

  postInstall = ''
    # Upstream's console entry point imports a top-level module that setup.py
    # does not install. Keep the complete script installed through scripts=.
    rm -f "$out/bin/i3expod"
    install -Dm644 defaultconfig "$out/share/i3expo/defaultconfig"
  '';

  meta = {
    description = "Expo-style visual workspace overview for i3";
    homepage = "https://github.com/morrolinux/i3expo-ng";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "i3expod.py";
  };
}
