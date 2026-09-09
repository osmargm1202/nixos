{
  fetchFromGitHub,
  stdenvNoCC,
  theme,
  themePath ? theme,
}:
stdenvNoCC.mkDerivation {
  pname = "qylock-sddm-themes";
  version = "2026-03-24";

  src = fetchFromGitHub {
    owner = "Darkkal44";
    repo = "qylock";
    rev = "22b92ae3318930c9e5b088b3c516b96d0fde6b15";
    hash = "sha256-AYoc6yEcp+yeud+GKkg5X8BKKSMq0ogEDuB4g+hosfs=";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/sddm/themes"
    cp -r "themes/${themePath}" "$out/share/sddm/themes/${theme}"
    runHook postInstall
  '';
}
