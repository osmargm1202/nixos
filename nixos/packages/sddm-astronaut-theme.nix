{ stdenvNoCC, src }:

stdenvNoCC.mkDerivation {
  pname = "sddm-astronaut-theme";
  version = "unstable";

  inherit src;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/sddm/themes"
    cp -R "$src" "$out/share/sddm/themes/sddm-astronaut-theme"
    runHook postInstall
  '';
}
