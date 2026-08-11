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

    for source in ${niriShaders}/*/open.glsl; do
      name="$(basename "$(dirname "$source")")"
      destination="$out/share/hyprwindowshade/shaders/open/$name.glsl"
      cat >"$destination" <<'GLSL'
// Ported at build time from liixini/shaders. See niri-shaders-LICENSE.
#version 320 es
precision highp float;

in vec2 v_texcoord;
out vec4 fragColor;

uniform sampler2D tex;
uniform float transition_progress;
uniform float transition_seed;
uniform vec2 surface_size;

#define niri_clamped_progress clamp(transition_progress, 0.0, 1.0)
#define niri_random_seed transition_seed
#define niri_geo_to_tex mat3(1.0)
#define niri_tex tex
#define texture2D texture
GLSL
      cat "$source" >>"$destination"
      cat >>"$destination" <<'GLSL'

void main() {
  fragColor = open_color(vec3(v_texcoord, 1.0), vec3(surface_size, 1.0));
}
GLSL
      glslangValidator -S frag "$destination"
    done
  '';
}
