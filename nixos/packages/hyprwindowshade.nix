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
  wayland-protocols,
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
    libdrm.dev
    wayland-protocols
    libglvnd
  ];

  enableParallelBuilding = true;
  dontConfigure = true;

  buildPhase = ''
    runHook preBuild
    mkdir -p protocols
    hyprwayland-scanner \
      ${wayland-protocols}/share/wayland-protocols/staging/color-management/color-management-v1.xml \
      protocols/
    $CXX -shared -fPIC -O3 -std=c++23 -Iprotocols $(pkg-config --cflags hyprland pixman-1 libdrm) *.cpp -o HyprWindowShade.so \
      -lGLESv2 -lEGL -lGL
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 HyprWindowShade.so "$out/lib/HyprWindowShade.so"
    install -Dm644 shaders/LICENSE "$out/share/hyprwindowshade/shaders/LICENSE"
    install -Dm644 shaders/open/fade.glsl "$out/share/hyprwindowshade/shaders/open/fade.glsl"
    install -Dm644 shaders/open/circle-reveal.glsl "$out/share/hyprwindowshade/shaders/open/circle-reveal.glsl"
    install -Dm644 shaders/open/pixelate.glsl "$out/share/hyprwindowshade/shaders/open/pixelate.glsl"
    runHook postInstall
  '';
}
