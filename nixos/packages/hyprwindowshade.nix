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
  glslang,
  niriShaders,
  src,
  wayland-protocols,
}:
stdenv.mkDerivation {
  pname = "hyprwindowshade";
  version = "5fcc906";

  inherit src;

  nativeBuildInputs = hyprland.nativeBuildInputs ++ [
    glslang
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
    install -Dm755 HyprWindowShade.so "$out/lib/HyprWindowShade.so"
    install -Dm644 ${niriShaders}/LICENSE "$out/share/hyprwindowshade/niri-shaders-LICENSE"
    mkdir -p "$out/share/hyprwindowshade/shaders/open"

    for source in ${niriShaders}/hyprwindowshade/open/*.glsl; do
      destination="$out/share/hyprwindowshade/shaders/open/$(basename "$source")"
      install -Dm644 "$source" "$destination"
      glslangValidator -S frag "$destination"
    done
  '';
}
