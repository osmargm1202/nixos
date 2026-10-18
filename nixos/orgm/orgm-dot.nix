{ lib, buildGoModule, makeWrapper, diffutils }:
buildGoModule {
  pname = "orgm-dot";
  version = "1.1.0";
  src = ./orgm-dot-src;
  vendorHash = null;
  nativeBuildInputs = [ makeWrapper ];
  postInstall = ''
    wrapProgram "$out/bin/orgm-dot" --prefix PATH : ${lib.makeBinPath [ diffutils ]}
  '';
  meta = {
    description = "Per-application dotfile copies, snapshots, diff and restore";
    mainProgram = "orgm-dot";
    platforms = lib.platforms.linux;
  };
}
