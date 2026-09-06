{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
}:

stdenvNoCC.mkDerivation {
  pname = "sddm-greenshift";
  version = "1.1.1";

  src = fetchurl {
    url = "https://github.com/amitpadhan525/sddm-themes/releases/download/v1.1.1/GreenShift.zip";
    hash = "sha256-g226WYW/fIzFYui4QzyARlBWVeEUsLCcGRDTboxDFkw=";
  };

  nativeBuildInputs = [ unzip ];
  sourceRoot = "GreenShift";
  dontBuild = true;

  # Honor the selected user and SDDM's session NameRole (260), not DirectoryRole.
  postPatch = ''
    substituteInPlace Main.qml --replace-fail \
      $'        if (typeof userModel !== "undefined" && userModel && userModel.lastUser) {\n            return userModel.lastUser\n        }' "" \
      --replace-fail 'sessionsList.index(selectedSessionIndex, 0), 257)' \
        'sessionsList.index(selectedSessionIndex, 0), 260)'
  '';

  installPhase = ''
    runHook preInstall
    themeDir="$out/share/sddm/themes/GreenShift"
    mkdir -p "$themeDir"
    cp -r Main.qml metadata.desktop theme.conf assets backgrounds components fonts "$themeDir/"
    install -Dm644 LICENSE "$out/share/licenses/sddm-greenshift/LICENSE"
    runHook postInstall
  '';

  meta = {
    description = "GreenShift Qt 6 SDDM theme with green accents and bundled fonts";
    homepage = "https://github.com/amitpadhan525/sddm-themes";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
