{
  stdenv,
  hyprland,
  pkg-config,
  cairo,
  freetype,
  libpng,
  pixman,
  libdrm,
  libglvnd,
  src,
}:
stdenv.mkDerivation {
  pname = "hyprwindowshade";
  version = "5fcc906";

  inherit src;

  nativeBuildInputs = hyprland.nativeBuildInputs ++ [
    pkg-config
  ];
  buildInputs = hyprland.buildInputs ++ [
    hyprland
    hyprland.dev
    cairo
    freetype
    libpng
    pixman
    libdrm
    libglvnd
  ];

  enableParallelBuilding = true;
  dontConfigure = true;

  buildPhase = ''
    runHook preBuild
    $CXX -shared -fPIC -O3 -std=c++23 *.cpp -o HyprWindowShade.so \
      -lGLESv2 -lEGL -lGL
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 HyprWindowShade.so "$out/lib/HyprWindowShade.so"
    runHook postInstall
  '';
}
