{
  stdenv,
  fetchFromGitLab,
  pkg-config,
  libxcb,
  xcbutilkeysyms,
  cairo,
  fontconfig,
  libjpeg_turbo,
}:
{
  autotiling = stdenv.mkDerivation {
    pname = "autotiling";
    version = "unstable-2026-07-20";

    src = fetchFromGitLab {
      owner = "ngcbg";
      repo = "autotiling";
      rev = "fd2be0de7c23799db2cc9677f43816139d476c1e";
      hash = "sha256-ioWFg4JIXvjcbL8o4HXvbKMJzC1//diuqc/aZgJLRFs=";
    };

    installPhase = ''
      make install PREFIX="$out"
    '';
  };

  rootbtnd = stdenv.mkDerivation {
    pname = "rootbtnd";
    version = "unstable-2026-07-20";

    src = fetchFromGitLab {
      owner = "ngcbg";
      repo = "rootbtnd";
      rev = "2c560ebb879be4ea23568a426042dece5136078b";
      hash = "sha256-Tl6CvCtKuT1P3S5Xwxj4Z5uPMX5a0mEdAgnt1yCIyK4=";
    };

    nativeBuildInputs = [ pkg-config ];
    buildInputs = [ libxcb ];

    installPhase = ''
      make install DESTDIR="$out" PREFIX=
    '';
  };

  i3swallow = stdenv.mkDerivation {
    pname = "i3swallow";
    version = "unstable-2026-07-20";

    src = fetchFromGitLab {
      owner = "ngcbg";
      repo = "i3swallow";
      rev = "54802c4ea1ff59018108941973713851b775227c";
      hash = "sha256-ID6pRJUxi7fPBY5Kxuu31rliE7p0Nbdcg0cRNYpePA4=";
    };

    buildInputs = [ libxcb ];

    installPhase = ''
      make install DESTDIR="$out" PREFIX=
    '';
  };

  xlogout = stdenv.mkDerivation {
    pname = "xlogout";
    version = "unstable-2026-07-20";

    src = fetchFromGitLab {
      owner = "ngcbg";
      repo = "xlogout";
      rev = "0639bff86d7efd4cf51e64c0e748e234dd146651";
      hash = "sha256-/ZYGmkAm75qOSAu+M8H48jNSsqAZR/jzoYjQA3+Hhe8=";
    };

    nativeBuildInputs = [ pkg-config ];
    buildInputs = [
      cairo
      libxcb
      xcbutilkeysyms
      fontconfig
      libjpeg_turbo
    ];

    installPhase = ''
      make install DESTDIR="$out" PREFIX=
    '';
  };
}
