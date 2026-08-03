{
  stdenv,
  fetchFromGitHub,
  hyprland,
  gcc14,
  pkg-config,
  lua5_4,
}:
stdenv.mkDerivation {
  pname = "hyprland-scroll-overview";
  version = "2efa6168e072194005152106ded1d7acd3a5170c";

  src = fetchFromGitHub {
    owner = "yayuuu";
    repo = "hyprland-scroll-overview";
    rev = "2efa6168e072194005152106ded1d7acd3a5170c";
    hash = "sha256-l+47qR3CWO/3xdTLuC23Nktmys7ibRjhVU4gW19NtYg=";
  };

  inherit (hyprland) buildInputs;
  nativeBuildInputs = hyprland.nativeBuildInputs ++ [
    hyprland
    gcc14
    pkg-config
    lua5_4
  ];

  enableParallelBuilding = true;

  buildPhase = ''
    runHook preBuild
    export SCROLLOVERVIEW_BUILD_VERSION=$version
    make all
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 libscrolloverview.so "$out/lib/libscrolloverview.so"
    runHook postInstall
  '';
}
