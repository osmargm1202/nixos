{
  stdenv,
  hyprland,
  pkg-config,
  pixman,
  libdrm,
  src,
}:
stdenv.mkDerivation {
  pname = "hyprglass";
  version = "0.7.0";

  inherit src;
  # Release EventBus listeners when toggling this shared plugin off.
  patches = [ ../ryoku/hyprglass-unload-listeners.patch ];

  nativeBuildInputs = hyprland.nativeBuildInputs ++ [
    pkg-config
  ];
  buildInputs = hyprland.buildInputs ++ [
    hyprland
    pixman
    libdrm
  ];

  enableParallelBuilding = true;
  dontConfigure = true;

  buildPhase = ''
    runHook preBuild
    make
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 hyprglass.so "$out/lib/hyprglass.so"
    runHook postInstall
  '';
}
