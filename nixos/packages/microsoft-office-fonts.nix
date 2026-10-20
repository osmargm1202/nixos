{ lib, stdenvNoCC, fetchurl, libarchive, _7zz, fontconfig }:

# Office's public installer supplies the two families absent from corefonts
# and vista-fonts. Extract data only; never run the installer or its scripts.
stdenvNoCC.mkDerivation {
  pname = "microsoft-office-fonts";
  version = "15.11.1";

  src = fetchurl {
    url = "https://download.microsoft.com/download/8/1/3/8136bf31-4c2e-4b5f-bee9-117ab004ab35/microsoft_excel_15.11.1_updater.pkg";
    sha256 = "34024135a047ca0ef3b1ab499ab7a5584b313b9eb8954c1dd38712dc6c8a04ec";
  };

  arialNarrowSrc = fetchurl {
    # Office 2010 KB2589386 supplies all four Arial Narrow styles.
    url = "https://catalog.s.download.windowsupdate.com/d/msdownload/update/software/crup/2014/11/gfonts-x-none_23715aec547df5d7824747f46ff04e82f36a2d33.cab";
    hash = "sha256-EGqDgnIdIIyCEz8lwEQ5XB+qpA9F+MxlSnvm6KVIMzo=";
  };

  nativeBuildInputs = [ libarchive _7zz fontconfig ];
  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    mkdir extracted
    cd extracted
    bsdtar -xOf "$src" Microsoft_Excel.pkg/Payload \
      | bsdtar -xf - --include '*Century*Gothic*.ttf'
    bsdtar -xf "$arialNarrowSrc" gfonts-x-none.msp
    7zz e -y -bso0 -bsp0 gfonts-x-none.msp PATCH_CAB
    bsdtar -xf PATCH_CAB
    fontDir="$out/share/fonts/truetype"
    mkdir -p "$fontDir" "$out/share/doc/microsoft-office-fonts"
    find . -type f -iname '*.ttf' -exec install -m444 -t "$fontDir" {} +
    test "$(find "$fontDir" -type f | wc -l)" -eq 8
    bsdtar -xOf "$src" Distribution > "$out/share/doc/microsoft-office-fonts/Distribution.xml"

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    export XDG_CACHE_HOME="$TMPDIR/fontconfig-cache"
    # Arial Narrow also advertises Arial as its preferred typographic family.
    # Full face names identify the requested styles without depending on locale.
    fc-scan --format '%{fullname[0]}\n' "$out"/share/fonts/truetype/* \
      | LC_ALL=C sort > actual-styles
    printf '%s\n' \
      'Arial Narrow' 'Arial Narrow Bold' 'Arial Narrow Bold Italic' 'Arial Narrow Italic' \
      'Century Gothic' 'Century Gothic Bold' 'Century Gothic Bold Italic' 'Century Gothic Italic' \
      > expected-styles
    diff -u expected-styles actual-styles
    runHook postInstallCheck
  '';

  preferLocalBuild = true;
  allowSubstitutes = false;
  meta = {
    description = "Microsoft Office's Arial Narrow and Century Gothic font families";
    homepage = "https://learn.microsoft.com/en-us/typography/";
    license = lib.licenses.unfree;
    platforms = lib.platforms.all;
  };
}
